# Track Generation Reference

How to build and manage the infinite scrolling downhill track, including road
segments, lane markings, roadside scenery, and the recycling pool system.

## Table of Contents
1. [Road Segment Pool](#road-segment-pool)
2. [Scrolling System](#scrolling-system)
3. [Lane Markings & Road Details](#lane-markings--road-details)
4. [Roadside Scenery](#roadside-scenery)
5. [Track Slope & Downhill Feel](#track-slope--downhill-feel)
6. [Environment Zones](#environment-zones)

---

## Road Segment Pool

The track is an infinite conveyor belt of road segments. A fixed number of
segments exist in a pool. As they scroll past the camera, they teleport to
the front of the queue.

```javascript
const SEGMENT_LENGTH = 12;    // meters per segment
const VISIBLE_SEGMENTS = 8;   // segments visible ahead
const ROAD_WIDTH = 7.0;       // total road width
const LANE_WIDTH = 1.8;       // distance between lane centers
const ROAD_COLOR = 0x555566;  // asphalt
const CURB_COLOR = 0xCC3333;  // red-white curbs

class TrackManager {
  constructor(scene) {
    this.scene = scene;
    this.segments = [];
    this.nextZ = 0;              // Z position of the next segment to place
    this.scrollOffset = 0;       // total distance scrolled

    // Create segment pool
    for (let i = 0; i < VISIBLE_SEGMENTS + 2; i++) {
      const seg = this.createSegment();
      seg.position.z = -i * SEGMENT_LENGTH;
      this.segments.push(seg);
      scene.add(seg);
    }
    this.nextZ = -(VISIBLE_SEGMENTS + 2) * SEGMENT_LENGTH;
  }

  createSegment() {
    const group = new THREE.Group();

    // Road surface
    const roadGeo = new THREE.PlaneGeometry(ROAD_WIDTH, SEGMENT_LENGTH);
    roadGeo.rotateX(-Math.PI / 2);
    const road = new THREE.Mesh(roadGeo, createToonMaterial(ROAD_COLOR));
    road.receiveShadow = true;
    road.position.y = 0;
    group.add(road);

    // Curbs (left and right raised edges)
    const curbGeo = new THREE.BoxGeometry(0.3, 0.1, SEGMENT_LENGTH);
    const curbMat = createToonMaterial(CURB_COLOR);
    const leftCurb = new THREE.Mesh(curbGeo, curbMat);
    leftCurb.position.set(-ROAD_WIDTH / 2 - 0.15, 0.05, 0);
    const rightCurb = new THREE.Mesh(curbGeo, curbMat.clone());
    rightCurb.position.set(ROAD_WIDTH / 2 + 0.15, 0.05, 0);
    group.add(leftCurb, rightCurb);

    // Lane dividers
    this.addLaneDividers(group);

    // Sidewalk/ground on both sides
    const groundGeo = new THREE.PlaneGeometry(15, SEGMENT_LENGTH);
    groundGeo.rotateX(-Math.PI / 2);
    const groundMat = createToonMaterial(0x88AA55); // Grass green
    const leftGround = new THREE.Mesh(groundGeo, groundMat);
    leftGround.position.set(-ROAD_WIDTH / 2 - 7.5, -0.02, 0);
    leftGround.receiveShadow = true;
    const rightGround = new THREE.Mesh(groundGeo, groundMat.clone());
    rightGround.position.set(ROAD_WIDTH / 2 + 7.5, -0.02, 0);
    rightGround.receiveShadow = true;
    group.add(leftGround, rightGround);

    return group;
  }

  addLaneDividers(group) {
    // Dashed white lines between lanes
    const dashLength = 1.5;
    const gapLength = 1.0;
    const dashGeo = new THREE.PlaneGeometry(0.12, dashLength);
    dashGeo.rotateX(-Math.PI / 2);
    const dashMat = new THREE.MeshBasicMaterial({ color: 0xffffff });

    const laneEdges = [-LANE_WIDTH / 2, LANE_WIDTH / 2];
    // Actually we need dividers between the 3 lanes
    // Lanes are at x = -1.8, 0, +1.8
    // Dividers at x = -0.9 and x = +0.9
    const dividerX = [-LANE_WIDTH * 0.5, LANE_WIDTH * 0.5];

    for (const x of dividerX) {
      for (let z = -SEGMENT_LENGTH / 2; z < SEGMENT_LENGTH / 2; z += dashLength + gapLength) {
        const dash = new THREE.Mesh(dashGeo, dashMat);
        dash.position.set(x, 0.01, z + dashLength / 2);
        group.add(dash);
      }
    }
  }

  update(dt, scrollSpeed) {
    const scrollDist = scrollSpeed * dt;
    this.scrollOffset += scrollDist;

    // Move all segments toward the camera
    for (const seg of this.segments) {
      seg.position.z += scrollDist;
    }

    // Recycle segments that passed behind the camera
    for (const seg of this.segments) {
      if (seg.position.z > SEGMENT_LENGTH) {
        // Find the furthest segment
        let minZ = Infinity;
        for (const s of this.segments) {
          if (s.position.z < minZ) minZ = s.position.z;
        }
        seg.position.z = minZ - SEGMENT_LENGTH;
        this.onSegmentRecycled(seg);
      }
    }
  }

  onSegmentRecycled(segment) {
    // Hook for scenery regeneration — randomize roadside objects
    // Called every time a segment wraps around to the front
  }

  getDistanceTraveled() {
    return this.scrollOffset;
  }
}
```

---

## Scrolling System

Everything moves toward the camera. The player's vehicle stays at Z=0 and
only moves laterally (X axis) between lanes.

```
Camera at Z = +5.5 (behind player)
Player at Z = 0
Obstacles spawn at Z = -60 to -80 (far ahead)
Obstacles recycle at Z = +15 (behind camera)
Road segments span from Z = +12 to Z = -(VISIBLE_SEGMENTS × 12)
```

Each frame:
```javascript
function scrollTrack(dt) {
  const scrollDist = scrollSpeed * dt;

  // Move track
  trackManager.update(dt, scrollSpeed);

  // Move obstacles toward player
  for (const obs of activeObstacles) {
    obs.position.z += scrollDist;
  }

  // Move collectibles
  for (const item of activeCollectibles) {
    item.position.z += scrollDist;
  }

  // Recycle obstacles that passed behind
  activeObstacles = activeObstacles.filter(obs => {
    if (obs.position.z > 15) {
      returnObstacleToPool(obs);
      return false;
    }
    return true;
  });

  // Same for collectibles
  activeCollectibles = activeCollectibles.filter(item => {
    if (item.position.z > 15) {
      returnCollectibleToPool(item);
      return false;
    }
    return true;
  });
}
```

---

## Lane Markings & Road Details

### Center Line Variation

Every few segments, vary the road surface for visual interest:

```javascript
const ROAD_VARIATIONS = [
  { color: 0x555566, name: 'asphalt' },      // Standard
  { color: 0x665544, name: 'dirt' },          // Dirt section
  { color: 0x556666, name: 'wet' },           // Wet road
  { color: 0x887766, name: 'cobblestone' },   // Cobblestone
];
```

### Start/Finish Markings

The start area has a checkered pattern on the road:
```javascript
function addCheckerPattern(group, zStart, zEnd) {
  const size = 0.5;
  for (let x = -ROAD_WIDTH / 2; x < ROAD_WIDTH / 2; x += size) {
    for (let z = zStart; z < zEnd; z += size) {
      const isBlack = (Math.floor(x / size) + Math.floor(z / size)) % 2 === 0;
      if (isBlack) {
        const geo = new THREE.PlaneGeometry(size, size);
        geo.rotateX(-Math.PI / 2);
        const mesh = new THREE.Mesh(geo, new THREE.MeshBasicMaterial({ color: 0x222222 }));
        mesh.position.set(x + size / 2, 0.015, z + size / 2);
        group.add(mesh);
      }
    }
  }
}
```

---

## Roadside Scenery

Each road segment has scenery attachment points on left and right sides.
When a segment is recycled, re-randomize its scenery.

### Scenery Slots

```javascript
const SCENERY_CONFIG = {
  leftOffset: ROAD_WIDTH / 2 + 2.5,  // X position for left scenery
  rightOffset: ROAD_WIDTH / 2 + 2.5,
  minSpacing: 3,     // min Z gap between scenery items
  maxSpacing: 8,
  types: [
    { asset: 'scene_tree',         weight: 30, scale: [0.8, 1.2] },
    { asset: 'scene_bush',         weight: 25, scale: [0.6, 1.0] },
    { asset: 'scene_lamppost',     weight: 10, scale: [1.0, 1.0] },
    { asset: 'scene_fence',        weight: 15, scale: [1.0, 1.0] },
    { asset: 'scene_building_a',   weight: 5,  scale: [1.0, 1.3] },
    { asset: 'scene_building_b',   weight: 5,  scale: [1.0, 1.3] },
    { asset: 'scene_crowd_person', weight: 8,  scale: [0.9, 1.1] },
    { asset: 'scene_flag_banner',  weight: 2,  scale: [1.0, 1.0] },
  ],
};
```

### Weighted Random Selection

```javascript
function pickSceneryType() {
  const totalWeight = SCENERY_CONFIG.types.reduce((sum, t) => sum + t.weight, 0);
  let r = Math.random() * totalWeight;
  for (const type of SCENERY_CONFIG.types) {
    r -= type.weight;
    if (r <= 0) return type;
  }
  return SCENERY_CONFIG.types[0];
}
```

### Scenery Pool

```javascript
class SceneryPool {
  constructor(scene, assetManager, usePlaceholders) {
    this.scene = scene;
    this.assets = assetManager;
    this.usePlaceholders = usePlaceholders;
    this.active = [];
  }

  async spawnForSegment(segmentZ) {
    // Left side
    await this.spawnSide(-SCENERY_CONFIG.leftOffset, segmentZ);
    // Right side
    await this.spawnSide(SCENERY_CONFIG.rightOffset, segmentZ);
  }

  async spawnSide(xBase, segmentZ) {
    let z = segmentZ - SEGMENT_LENGTH / 2;
    const zEnd = segmentZ + SEGMENT_LENGTH / 2;

    while (z < zEnd) {
      const type = pickSceneryType();
      const [minS, maxS] = type.scale;
      const scale = minS + Math.random() * (maxS - minS);

      let mesh;
      if (this.usePlaceholders) {
        mesh = createPlaceholderScenery(type.asset);
      } else {
        mesh = await this.assets.get('scenery', type.asset);
      }

      mesh.scale.setScalar(scale);
      mesh.position.set(
        xBase + (Math.random() - 0.5) * 2,  // Slight random offset
        0,
        z
      );
      mesh.rotation.y = Math.random() * Math.PI * 2;
      this.scene.add(mesh);
      this.active.push(mesh);

      z += SCENERY_CONFIG.minSpacing +
           Math.random() * (SCENERY_CONFIG.maxSpacing - SCENERY_CONFIG.minSpacing);
    }
  }

  recycle(scrollDist) {
    for (const mesh of this.active) {
      mesh.position.z += scrollDist;
    }
    this.active = this.active.filter(mesh => {
      if (mesh.position.z > 20) {
        this.scene.remove(mesh);
        return false;
      }
      return true;
    });
  }
}
```

### Placeholder Scenery

```javascript
function createPlaceholderScenery(type) {
  const group = new THREE.Group();

  if (type.includes('tree')) {
    // Trunk
    const trunk = new THREE.Mesh(
      new THREE.CylinderGeometry(0.1, 0.15, 1.2, 6),
      createToonMaterial(0x8B6914)
    );
    trunk.position.y = 0.6;
    group.add(trunk);
    // Canopy
    const canopy = new THREE.Mesh(
      new THREE.SphereGeometry(0.6, 8, 6),
      createToonMaterial(0x44AA44)
    );
    canopy.position.y = 1.5;
    group.add(canopy);
  } else if (type.includes('bush')) {
    const bush = new THREE.Mesh(
      new THREE.SphereGeometry(0.4, 6, 5),
      createToonMaterial(0x338833)
    );
    bush.position.y = 0.3;
    bush.scale.y = 0.7;
    group.add(bush);
  } else if (type.includes('lamppost')) {
    const pole = new THREE.Mesh(
      new THREE.CylinderGeometry(0.04, 0.05, 2.5, 6),
      createToonMaterial(0x444444)
    );
    pole.position.y = 1.25;
    group.add(pole);
    const lamp = new THREE.Mesh(
      new THREE.SphereGeometry(0.12, 8, 6),
      createToonMaterial(0xFFDD44)
    );
    lamp.position.y = 2.6;
    group.add(lamp);
  } else if (type.includes('building')) {
    const w = 2 + Math.random() * 2;
    const h = 2 + Math.random() * 3;
    const building = new THREE.Mesh(
      new THREE.BoxGeometry(w, h, 2),
      createToonMaterial(
        [0xDDBB88, 0xBB8866, 0xCCAA77, 0xEECC99][Math.floor(Math.random() * 4)]
      )
    );
    building.position.y = h / 2;
    group.add(building);
  } else if (type.includes('fence')) {
    const fence = new THREE.Mesh(
      new THREE.BoxGeometry(2, 0.8, 0.08),
      createToonMaterial(0xEEEEDD)
    );
    fence.position.y = 0.4;
    group.add(fence);
  } else if (type.includes('crowd')) {
    // Simple cylinder person
    const body = new THREE.Mesh(
      new THREE.CylinderGeometry(0.15, 0.15, 0.8, 6),
      createToonMaterial([0xFF4444, 0x4444FF, 0xFFAA00, 0x44CC44][Math.floor(Math.random() * 4)])
    );
    body.position.y = 0.5;
    group.add(body);
    const head = new THREE.Mesh(
      new THREE.SphereGeometry(0.12, 8, 6),
      createToonMaterial(0xFFCC99)
    );
    head.position.y = 1.02;
    group.add(head);
  } else {
    // Generic box
    const box = new THREE.Mesh(
      new THREE.BoxGeometry(0.5, 0.5, 0.5),
      createToonMaterial(0xAAAAAA)
    );
    box.position.y = 0.25;
    group.add(box);
  }

  addOutline(group, 0.02);
  return group;
}
```

---

## Track Slope & Downhill Feel

The vehicle is rolling downhill but we don't simulate real slope physics.
Instead, create the visual illusion:

1. **Tilt the entire track group** slightly (5° around X axis):
```javascript
trackGroup.rotation.x = -0.087; // ~5 degrees forward tilt
```

2. **Parallax sky movement**: shift the background color or skybox slightly
   each frame to suggest downward motion.

3. **Occasional steep sections**: every 200–400m of distance, increase the
   tilt briefly to 10–15° for 2–3 segments, giving a "steep drop" visual.

4. **Camera bob**: add a subtle vertical sine wave to the camera position
   (amplitude 0.05, frequency matched to scroll speed) to simulate road
   bumpiness.

```javascript
const bumpFrequency = scrollSpeed * 0.8;
const bumpAmplitude = 0.04;
camera.position.y += Math.sin(distance * bumpFrequency) * bumpAmplitude;
```

---

## Environment Zones

As the player progresses, the environment can shift to keep things visually
fresh. Change every ~500m of distance:

| Distance     | Zone           | Road Color  | Ground Color | Scenery Bias           |
|-------------|----------------|-------------|--------------|------------------------|
| 0–500m      | Suburban Start | 0x555566    | 0x88AA55     | Trees, fences, houses  |
| 500–1000m   | Urban          | 0x444455    | 0x888888     | Buildings, lampposts   |
| 1000–1500m  | Park           | 0x556655    | 0x66AA44     | Trees, bushes, crowd   |
| 1500–2000m  | Industrial     | 0x555555    | 0x999977     | Fences, barriers       |
| 2000m+      | Random mix     | varies      | varies       | All types              |

```javascript
function getZoneForDistance(dist) {
  const zones = [
    { maxDist: 500,  road: 0x555566, ground: 0x88AA55, name: 'suburban' },
    { maxDist: 1000, road: 0x444455, ground: 0x888888, name: 'urban' },
    { maxDist: 1500, road: 0x556655, ground: 0x66AA44, name: 'park' },
    { maxDist: 2000, road: 0x555555, ground: 0x999977, name: 'industrial' },
  ];
  for (const zone of zones) {
    if (dist < zone.maxDist) return zone;
  }
  return zones[Math.floor(Math.random() * zones.length)];
}
```
