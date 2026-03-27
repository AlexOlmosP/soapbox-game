# Obstacle Patterns Reference

Rules for spawning obstacles and collectibles to create fair, escalating
difficulty that feels challenging but never cheap.

## Table of Contents
1. [Core Rule: Always Leave an Exit](#core-rule)
2. [Obstacle Types & Hitboxes](#obstacle-types--hitboxes)
3. [Pattern Library](#pattern-library)
4. [Spawn Timing & Difficulty Curve](#spawn-timing--difficulty-curve)
5. [Collectible Placement](#collectible-placement)
6. [Object Pooling](#object-pooling)
7. [Placeholder Obstacle Geometry](#placeholder-obstacle-geometry)

---

## Core Rule

**At least one lane must ALWAYS be clear in every obstacle row.**

This is non-negotiable. If all three lanes are blocked, the player dies
through no fault of their own and the game feels unfair. The pattern system
enforces this structurally — patterns are pre-defined arrays where the
maximum number of obstacles per row is 2.

When two rows spawn close together, the combination must also be survivable.
If row N blocks lanes 0 and 1, and row N+1 arrives before the player can
switch, row N+1 must leave lane 2 clear (or at least lane 1, since the player
is already moving right). The `MIN_ROW_GAP` constant controls this.

---

## Obstacle Types & Hitboxes

Each obstacle has a bounding box used for collision detection. Sizes are in
meters (matching the GLB asset scale from the asset guide).

| Type            | Asset File              | Width | Height | Depth | Notes                     |
|----------------|-------------------------|-------|--------|-------|---------------------------|
| Barrel          | `obs_barrel.glb`        | 0.6   | 0.8    | 0.6   | Standard obstacle         |
| Cone            | `obs_cone.glb`          | 0.4   | 0.6    | 0.4   | Small, often in clusters  |
| Hay Bale        | `obs_hay_bale.glb`      | 1.2   | 0.8    | 0.8   | Wide, blocks lane fully   |
| Tire Stack      | `obs_tire_stack.glb`    | 0.7   | 1.0    | 0.7   | Tall                      |
| Barrier         | `obs_barrier.glb`       | 1.5   | 0.9    | 0.3   | Wide barricade            |
| Trash Can       | `obs_trash_can.glb`     | 0.5   | 0.7    | 0.5   | Medium                    |
| Shopping Cart   | `obs_shopping_cart.glb` | 0.7   | 0.9    | 1.0   | Long depth                |
| Ramp            | `obs_ramp.glb`          | 1.2   | 0.5    | 1.0   | Special: launches vehicle |
| Pothole         | `obs_pothole.glb`       | 1.0   | 0.05   | 1.0   | Ground-level, slows player|
| Crowd Barrier   | `obs_crowd_barrier.glb` | 1.8   | 1.0    | 0.2   | Lane-width blocker        |

### Hitbox Registration

```javascript
const OBSTACLE_HITBOXES = {
  barrel:        new THREE.Vector3(0.6, 0.8, 0.6),
  cone:          new THREE.Vector3(0.4, 0.6, 0.4),
  hay_bale:      new THREE.Vector3(1.2, 0.8, 0.8),
  tire_stack:    new THREE.Vector3(0.7, 1.0, 0.7),
  barrier:       new THREE.Vector3(1.5, 0.9, 0.3),
  trash_can:     new THREE.Vector3(0.5, 0.7, 0.5),
  shopping_cart: new THREE.Vector3(0.7, 0.9, 1.0),
  ramp:          new THREE.Vector3(1.2, 0.5, 1.0),
  pothole:       new THREE.Vector3(1.0, 0.05, 1.0),
  crowd_barrier: new THREE.Vector3(1.8, 1.0, 0.2),
};
```

### Special Obstacles

**Ramp** (`obs_ramp.glb`): Instead of ending the run, ramps launch the
vehicle briefly. During the jump, the vehicle rises on Y for ~1 second and
is invulnerable. This rewards risk — the ramp is dangerous to approach but
gives a brief safe window.

```javascript
function handleRampHit() {
  isJumping = true;
  jumpStartTime = performance.now();
  jumpDuration = 1000; // ms
  jumpHeight = 1.5;    // meters
}

function updateJump(now) {
  if (!isJumping) return;
  const t = (now - jumpStartTime) / jumpDuration;
  if (t >= 1) {
    isJumping = false;
    playerGroup.position.y = 0;
    return;
  }
  // Parabolic arc
  playerGroup.position.y = jumpHeight * 4 * t * (1 - t);
}
```

**Pothole** (`obs_pothole.glb`): Hitting a pothole doesn't end the run but
applies a brief speed penalty (reduce scrollSpeed by 30% for 1 second).

---

## Pattern Library

Patterns define which lanes have obstacles in a single row.
`true` = obstacle, `false` = clear.

### Single-Obstacle Patterns (easy)

```javascript
const PATTERNS_EASY = [
  [true,  false, false],  // Left only
  [false, true,  false],  // Center only
  [false, false, true ],  // Right only
];
```

### Double-Obstacle Patterns (medium)

```javascript
const PATTERNS_MEDIUM = [
  [true,  true,  false],  // Left + Center blocked → must go right
  [true,  false, true ],  // Left + Right blocked → must go center
  [false, true,  true ],  // Center + Right blocked → must go left
];
```

### Sequence Patterns (hard)

These are multi-row patterns that force specific movement sequences.
Each sub-array is a row, spawned with `MIN_ROW_GAP` between them.

```javascript
const PATTERNS_SEQUENCE = [
  // Zigzag: forces left then right
  {
    rows: [
      [false, true,  true ],  // Must go left
      [true,  true,  false],  // Must go right
    ],
    gap: 1.0,  // multiplier on MIN_ROW_GAP (tighter)
  },

  // Funnel center: forces to center lane
  {
    rows: [
      [true,  false, false],  // Go center or right
      [false, false, true ],  // Must be center now
    ],
    gap: 1.0,
  },

  // Slalom: left-center-right weave
  {
    rows: [
      [false, true,  true ],
      [true,  true,  false],
      [false, true,  true ],
    ],
    gap: 0.8,
  },

  // Wall with gap: two rows close, one lane open each
  {
    rows: [
      [true,  false, true ],
      [true,  true,  false],
    ],
    gap: 1.2,
  },
];
```

### Pattern Selection by Difficulty

```javascript
function pickPattern(difficulty) {
  // difficulty: 0.0 (start) to 1.0 (max)
  const r = Math.random();

  if (difficulty < 0.3) {
    // Early game: mostly singles
    if (r < 0.8) return randomFrom(PATTERNS_EASY);
    return randomFrom(PATTERNS_MEDIUM);
  }

  if (difficulty < 0.6) {
    // Mid game: mix of singles and doubles
    if (r < 0.3) return randomFrom(PATTERNS_EASY);
    if (r < 0.75) return randomFrom(PATTERNS_MEDIUM);
    return randomFrom(PATTERNS_SEQUENCE);
  }

  // Late game: doubles and sequences dominate
  if (r < 0.1) return randomFrom(PATTERNS_EASY);
  if (r < 0.45) return randomFrom(PATTERNS_MEDIUM);
  return randomFrom(PATTERNS_SEQUENCE);
}

function randomFrom(arr) {
  return arr[Math.floor(Math.random() * arr.length)];
}
```

### Obstacle Type Selection

Different obstacle types appear at different difficulties:

```javascript
const OBSTACLE_TIERS = {
  easy:   ['cone', 'barrel', 'trash_can'],
  medium: ['hay_bale', 'tire_stack', 'barrier', 'pothole'],
  hard:   ['shopping_cart', 'crowd_barrier'],
  special:['ramp'],  // Can appear at any difficulty
};

function pickObstacleType(difficulty) {
  const r = Math.random();

  // Small chance of ramp at any time
  if (r < 0.08) return 'ramp';

  if (difficulty < 0.3) {
    return randomFrom(OBSTACLE_TIERS.easy);
  } else if (difficulty < 0.6) {
    const pool = [...OBSTACLE_TIERS.easy, ...OBSTACLE_TIERS.medium];
    return randomFrom(pool);
  } else {
    const pool = [...OBSTACLE_TIERS.easy, ...OBSTACLE_TIERS.medium, ...OBSTACLE_TIERS.hard];
    return randomFrom(pool);
  }
}
```

---

## Spawn Timing & Difficulty Curve

### Spawn Distance

Obstacles spawn at a fixed distance ahead and scroll toward the player.
The gap between spawn rows decreases as difficulty increases.

```javascript
const SPAWN_DISTANCE = 60;       // meters ahead of player
const MIN_ROW_GAP_BASE = 12;     // meters between rows at start
const MIN_ROW_GAP_MIN = 5;       // minimum gap at max difficulty
const DIFFICULTY_RAMP_DISTANCE = 2000; // meters to reach max difficulty

let nextSpawnZ = -SPAWN_DISTANCE;
let distanceSinceLastSpawn = 0;

function getDifficulty() {
  return Math.min(trackManager.getDistanceTraveled() / DIFFICULTY_RAMP_DISTANCE, 1.0);
}

function getCurrentRowGap() {
  const diff = getDifficulty();
  return MIN_ROW_GAP_BASE - (MIN_ROW_GAP_BASE - MIN_ROW_GAP_MIN) * diff;
}

function shouldSpawnRow() {
  return distanceSinceLastSpawn >= getCurrentRowGap();
}
```

### Spawn Loop

Called every frame from the main game loop:

```javascript
function spawnObstacles(dt) {
  distanceSinceLastSpawn += scrollSpeed * dt;

  if (!shouldSpawnRow()) return;

  const difficulty = getDifficulty();
  const pattern = pickPattern(difficulty);

  if (Array.isArray(pattern[0])) {
    // It's a sequence pattern (multi-row)
    spawnSequencePattern(pattern);
  } else {
    // Single row
    spawnSingleRow(pattern, difficulty);
  }

  distanceSinceLastSpawn = 0;
}

function spawnSingleRow(lanes, difficulty) {
  const spawnZ = -SPAWN_DISTANCE;

  lanes.forEach((hasObs, laneIndex) => {
    if (!hasObs) return;
    const type = pickObstacleType(difficulty);
    const obs = getFromPool(type);
    obs.position.set(LANES[laneIndex], 0, spawnZ);
    obs.visible = true;
    obs.userData.type = type;
    obs.userData.hitbox = OBSTACLE_HITBOXES[type];
    activeObstacles.push(obs);
  });
}

function spawnSequencePattern(pattern) {
  const gap = (pattern.gap || 1.0) * getCurrentRowGap();
  const difficulty = getDifficulty();

  pattern.rows.forEach((row, i) => {
    const spawnZ = -SPAWN_DISTANCE - i * gap;
    row.forEach((hasObs, laneIndex) => {
      if (!hasObs) return;
      const type = pickObstacleType(difficulty);
      const obs = getFromPool(type);
      obs.position.set(LANES[laneIndex], 0, spawnZ);
      obs.visible = true;
      obs.userData.type = type;
      obs.userData.hitbox = OBSTACLE_HITBOXES[type];
      activeObstacles.push(obs);
    });
  });
}
```

### Difficulty Progression Summary

| Distance   | Difficulty | Row Gap | Patterns         | Obstacle Types      |
|-----------|------------|---------|------------------|---------------------|
| 0–200m    | 0.0–0.1    | 12m     | 80% easy singles | Cones, barrels      |
| 200–600m  | 0.1–0.3    | 10m     | Mixed singles    | + trash cans        |
| 600–1200m | 0.3–0.6    | 8m      | Doubles appear   | + hay, tires, walls |
| 1200–2000m| 0.6–1.0    | 6m      | Sequences appear | + carts, barriers   |
| 2000m+    | 1.0        | 5m      | Sequences dominate| All types           |

---

## Collectible Placement

Coins and items spawn in the clear lane(s) of each obstacle row, rewarding
the correct dodge.

```javascript
function spawnCollectiblesForRow(obstaclePattern, spawnZ) {
  // Place coins in clear lanes
  obstaclePattern.forEach((hasObs, laneIndex) => {
    if (hasObs) return; // Skip lanes with obstacles

    // 60% chance to place a coin in a clear lane
    if (Math.random() > 0.6) return;

    const item = getCoinFromPool();
    item.position.set(LANES[laneIndex], 0.8, spawnZ);
    item.visible = true;
    item.userData.type = 'coin';
    activeCollectibles.push(item);
  });

  // Occasionally spawn special items (5% chance per row)
  if (Math.random() < 0.05) {
    const clearLanes = obstaclePattern
      .map((has, i) => has ? -1 : i)
      .filter(i => i >= 0);
    if (clearLanes.length === 0) return;

    const lane = randomFrom(clearLanes);
    const types = ['star', 'wrench', 'boost'];
    const type = randomFrom(types);

    const item = getSpecialItemFromPool(type);
    item.position.set(LANES[lane], 1.0, spawnZ - 2); // Slightly offset
    item.visible = true;
    item.userData.type = type;
    activeCollectibles.push(item);
  }
}
```

### Coin Trails

Between obstacle rows, place coin trails — lines of 3–5 coins in a single
lane that guide the player:

```javascript
function spawnCoinTrail(lane, startZ, count) {
  for (let i = 0; i < count; i++) {
    const coin = getCoinFromPool();
    coin.position.set(LANES[lane], 0.8, startZ - i * 2);
    coin.visible = true;
    coin.userData.type = 'coin';
    activeCollectibles.push(coin);
  }
}

// Spawn a trail every 3-5 obstacle rows
let rowsSinceTrail = 0;
function maybeSpawnTrail(clearLanes, spawnZ) {
  rowsSinceTrail++;
  if (rowsSinceTrail < 3 + Math.floor(Math.random() * 3)) return;
  if (clearLanes.length === 0) return;

  const lane = randomFrom(clearLanes);
  spawnCoinTrail(lane, spawnZ + getCurrentRowGap() * 0.5, 3 + Math.floor(Math.random() * 3));
  rowsSinceTrail = 0;
}
```

### Collectible Animations

Coins and items should spin and bob to be visually distinct from obstacles:

```javascript
function updateCollectibles(time) {
  for (const item of activeCollectibles) {
    if (!item.visible) continue;
    // Spin around Y
    item.rotation.y = time * 0.003;
    // Bob up and down
    item.position.y = 0.8 + Math.sin(time * 0.004 + item.position.z) * 0.15;
  }
}
```

---

## Object Pooling

Pre-create obstacles and collectibles to avoid garbage collection spikes.

```javascript
class ObjectPool {
  constructor(createFn, initialSize = 20) {
    this.createFn = createFn;
    this.pool = [];
    for (let i = 0; i < initialSize; i++) {
      const obj = createFn();
      obj.visible = false;
      this.pool.push(obj);
    }
  }

  get() {
    // Find an inactive object
    for (const obj of this.pool) {
      if (!obj.visible) {
        obj.visible = true;
        return obj;
      }
    }
    // Pool exhausted — create new
    const obj = this.createFn();
    this.pool.push(obj);
    return obj;
  }

  returnToPool(obj) {
    obj.visible = false;
    obj.position.set(0, -100, 0); // Move offscreen
  }

  addAllToScene(scene) {
    for (const obj of this.pool) {
      scene.add(obj);
    }
  }
}

// Initialize pools
const obstaclePool = new ObjectPool(() => createPlaceholderObstacle(), 30);
const coinPool = new ObjectPool(() => createPlaceholderCoin(), 40);
const specialPool = new ObjectPool(() => createPlaceholderSpecial(), 10);
```

---

## Placeholder Obstacle Geometry

```javascript
function createPlaceholderObstacle(type) {
  const group = new THREE.Group();
  const hb = OBSTACLE_HITBOXES[type || 'barrel'];

  const geo = new THREE.BoxGeometry(hb.x, hb.y, hb.z);
  const colors = {
    barrel: 0xFF6633, cone: 0xFF8800, hay_bale: 0xDDBB44,
    tire_stack: 0x333333, barrier: 0xFF4444, trash_can: 0x888888,
    shopping_cart: 0xAAAAAA, ramp: 0xBB8844,
    pothole: 0x333333, crowd_barrier: 0xCCCCCC,
  };
  const mat = createToonMaterial(colors[type] || 0xFF4444);
  const mesh = new THREE.Mesh(geo, mat);
  mesh.position.y = hb.y / 2;
  mesh.castShadow = true;
  group.add(mesh);

  addOutline(group, 0.02);
  return group;
}

function createPlaceholderCoin() {
  const group = new THREE.Group();
  const geo = new THREE.CylinderGeometry(0.2, 0.2, 0.04, 12);
  geo.rotateZ(Math.PI / 2);
  const mat = createToonMaterial(0xFFDD00);
  group.add(new THREE.Mesh(geo, mat));
  addOutline(group, 0.02);
  return group;
}

function createPlaceholderSpecial() {
  const group = new THREE.Group();
  // Star shape approximation
  const geo = new THREE.OctahedronGeometry(0.2, 0);
  const mat = createToonMaterial(0xFF44FF);
  group.add(new THREE.Mesh(geo, mat));
  addOutline(group, 0.02);
  return group;
}
```
