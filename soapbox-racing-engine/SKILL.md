---
name: soapbox-racing-engine
description: Build the 3D downhill racing game engine for a Red Bull Soapbox Race HTML game using Three.js. Use this skill whenever the user asks to create, modify, or improve the racing gameplay, track, downhill mechanics, obstacle system, lane switching, collision detection, race camera, speed controls, scoring, or game loop. Also trigger when the user mentions the race screen, gameplay feel, difficulty, power-ups, game over screen, countdown, or wants to change how the actual racing plays. This skill covers the Three.js race scene, procedural track generation, 3-lane movement system, obstacle spawning, collectibles, chase camera, HUD overlay, game states, and integration with the vehicle builder skill's data model.
---

# Soapbox Racing Engine Skill (3D / Three.js)

This skill guides creation of the downhill racing gameplay — the moment the
player's custom soapbox vehicle hits the hill and gravity takes over. The
racing is fast, simple, and satisfying: the vehicle accelerates downhill
automatically and the player taps left/right to dodge obstacles across three
lanes.

## Game Design Summary

**Inspiration:** Red Bull Soapbox Race meets Subway Surfers.

**Core loop:** The vehicle rolls downhill. Speed increases over time. Obstacles
appear ahead in the three lanes. The player taps/clicks left or right to switch
lanes and dodge them. Collecting coins and style items increases the score. The
run ends on collision with an obstacle. Higher style stat = higher score
multiplier.

**Controls:**
- **Desktop**: Left/Right arrow keys, or A/D keys
- **Mobile**: Tap left half / right half of screen, or swipe left/right
- **Single action**: Move one lane left or one lane right (no free movement)

**Camera**: Third-person chase camera, slightly above and behind the vehicle,
looking down the hill.

## Architecture Overview

The race is a single HTML artifact (`.html` or `.jsx`) using Three.js r128.
It reads the player's vehicle from persistent storage (written by the vehicle
builder skill) and renders it on a procedurally generated downhill track.

```
┌─────────────────────────────────────┐
│            GAME STATES              │
│                                     │
│  LOADING → COUNTDOWN → RACING → GAMEOVER
│              3..2..1     ↑          │
│                          │          │
│                     (collision)     │
│                                     │
│            RACING STATE:            │
│  ┌───────────────────────────────┐  │
│  │  HUD (score, distance, coins) │  │
│  ├───────────────────────────────┤  │
│  │                               │  │
│  │     THREE.JS VIEWPORT         │  │
│  │     Chase camera behind       │  │
│  │     vehicle on track          │  │
│  │                               │  │
│  ├───────────────────────────────┤  │
│  │  Touch zones (mobile)         │  │
│  └───────────────────────────────┘  │
└─────────────────────────────────────┘
```

## Integration with Vehicle Builder

On init, load the player's vehicle:

```javascript
let vehicleData;
try {
  const saved = await window.storage.get('currentVehicle');
  vehicleData = saved ? JSON.parse(saved.value) : DEFAULT_VEHICLE;
} catch (e) {
  vehicleData = DEFAULT_VEHICLE;
}
```

The `vehicleData` object has the same schema defined in the vehicle builder
skill. The stats affect gameplay:

| Stat     | Effect                                           |
|----------|--------------------------------------------------|
| Speed    | Max velocity: `3.0 + (speed - 1) * 0.5` units/frame |
| Handling | Lane switch duration: `400 - (handling - 1) * 62` ms  |
| Style    | Score multiplier: `1.0 + (style - 1) * 0.25`x        |

Use the same placeholder geometry or GLB loading system from the vehicle
builder skill to render the vehicle in the race. Read the vehicle builder's
`references/rendering-guide.md` for the `assembleVehicle()` pipeline and
toon shading setup — reuse those exact functions.

## Three.js Race Scene

### Scene Hierarchy

```
Scene
├── Lights (same rig as vehicle builder + adjusted for outdoor)
├── Sky (gradient or hemisphere background)
├── Fog (depth cue, hides track pop-in)
├── TrackGroup (scrolling road + scenery)
│   ├── RoadSegments[] (recycled pool of road meshes)
│   ├── SceneryLeft[] (trees, buildings, fences)
│   ├── SceneryRight[]
│   └── CrowdSegments[] (cheering spectators)
├── ObstaclePool[] (recycled obstacle meshes)
├── CollectiblePool[] (coins, stars, etc.)
├── PlayerGroup
│   └── VehicleGroup (from builder)
└── Camera (PerspectiveCamera, chase mode)
```

### Scene Setup

```javascript
const scene = new THREE.Scene();
scene.background = new THREE.Color(0x87CEEB);
scene.fog = new THREE.Fog(0x87CEEB, 25, 65);

// Lights
const ambient = new THREE.AmbientLight(0xffffff, 0.5);
const sun = new THREE.DirectionalLight(0xfff4e0, 0.9);
sun.position.set(3, 10, 5);
sun.castShadow = true;
sun.shadow.mapSize.set(1024, 1024);
sun.shadow.camera.near = 1;
sun.shadow.camera.far = 40;
sun.shadow.camera.left = -8;
sun.shadow.camera.right = 8;
sun.shadow.camera.top = 15;
sun.shadow.camera.bottom = -5;
const hemi = new THREE.HemisphereLight(0x87CEEB, 0x98B06F, 0.3);
scene.add(ambient, sun, hemi);

// Camera
const camera = new THREE.PerspectiveCamera(60, aspect, 0.1, 100);
```

### The Track Coordinate System

The track runs along the **negative Z axis** (the vehicle moves forward in -Z).
The player never truly moves — instead, the track, obstacles, and scenery
scroll toward the camera (classic infinite runner technique).

```
        Z- (forward / downhill)
        ↑
        │
  X- ←──┼──→ X+ (left / right lanes)
        │
        Z+ (behind camera)

Lane positions on X axis:
  Left lane:   x = -LANE_WIDTH
  Center lane:  x = 0
  Right lane:   x = +LANE_WIDTH

LANE_WIDTH = 1.8  (meters between lane centers)
```

The **Y axis** is up. The road has a slight downhill slope (cosmetic) achieved
by tilting the entire track group ~5° around X.

## Lane System

Read `references/game-loop.md` for the full movement and physics code.

The player occupies one of three lanes (0 = left, 1 = center, 2 = right).
Lane switching is a smooth lerp over a duration determined by the handling stat.

```javascript
const LANE_WIDTH = 1.8;
const LANES = [-LANE_WIDTH, 0, LANE_WIDTH];

let currentLane = 1; // Start center
let targetX = LANES[currentLane];
let playerX = targetX;
let switchStartTime = 0;
let switchDuration = 300; // ms, modified by handling stat
let isSwitching = false;

function switchLane(direction) {
  // direction: -1 (left) or +1 (right)
  if (isSwitching) return;
  const newLane = currentLane + direction;
  if (newLane < 0 || newLane > 2) return;

  currentLane = newLane;
  targetX = LANES[currentLane];
  switchStartTime = performance.now();
  isSwitching = true;
}

function updateLanePosition(now) {
  if (!isSwitching) return;
  const t = Math.min((now - switchStartTime) / switchDuration, 1);
  const eased = t < 0.5
    ? 2 * t * t                         // ease-in
    : 1 - Math.pow(-2 * t + 2, 2) / 2;  // ease-out
  playerX = playerX + (targetX - playerX) * eased;
  if (t >= 1) {
    playerX = targetX;
    isSwitching = false;
  }
  playerGroup.position.x = playerX;
}
```

## Input Handling

```javascript
// Keyboard
document.addEventListener('keydown', (e) => {
  if (gameState !== 'racing') return;
  if (e.key === 'ArrowLeft' || e.key === 'a') switchLane(-1);
  if (e.key === 'ArrowRight' || e.key === 'd') switchLane(+1);
});

// Touch (tap zones)
const canvas = renderer.domElement;
canvas.addEventListener('touchstart', (e) => {
  if (gameState !== 'racing') return;
  const x = e.touches[0].clientX;
  if (x < window.innerWidth / 2) switchLane(-1);
  else switchLane(+1);
});

// Swipe (alternative)
let touchStartX = 0;
canvas.addEventListener('touchstart', (e) => {
  touchStartX = e.touches[0].clientX;
});
canvas.addEventListener('touchend', (e) => {
  if (gameState !== 'racing') return;
  const dx = e.changedTouches[0].clientX - touchStartX;
  if (Math.abs(dx) > 30) {
    switchLane(dx > 0 ? 1 : -1);
  }
});
```

## Game States

Read `references/game-loop.md` for the full state machine implementation.

```
LOADING   → Load vehicle, assets, init scene
COUNTDOWN → "3... 2... 1... GO!" with camera zoom-in
RACING    → Main gameplay loop
GAMEOVER  → Crash animation, score display, "Play Again" / "Garage"
```

### State Transitions

```javascript
let gameState = 'loading';

const states = {
  loading: {
    enter() { /* load assets, build scene, then -> countdown */ },
    update() {},
  },
  countdown: {
    enter() { countdownTimer = 3; countdownStart = performance.now(); },
    update(now) {
      const elapsed = (now - countdownStart) / 1000;
      countdownTimer = 3 - Math.floor(elapsed);
      updateCountdownUI(countdownTimer);
      if (elapsed >= 3.5) transition('racing');
    },
  },
  racing: {
    enter() { scrollSpeed = BASE_SPEED; score = 0; distance = 0; },
    update(now, dt) {
      updateSpeed(dt);
      updateLanePosition(now);
      scrollTrack(dt);
      spawnObstacles(dt);
      spawnCollectibles(dt);
      checkCollisions();
      updateScore(dt);
      updateCamera();
      updateHUD();
    },
  },
  gameover: {
    enter() { playCrashEffect(); showGameOverUI(); saveHighScore(); },
    update() {},
  },
};

function transition(newState) {
  gameState = newState;
  states[newState].enter();
}
```

## Track System

Read `references/track-generation.md` for the full procedural track builder.

The track is built from **recycled road segments** that scroll toward the
camera. When a segment passes behind the camera, it jumps to the front of
the queue — an infinite conveyor belt of road.

```javascript
const SEGMENT_LENGTH = 10; // meters
const VISIBLE_SEGMENTS = 8; // how many ahead we render
const ROAD_WIDTH = 7;       // total road width (3 lanes + margins)

const roadPool = [];

function createRoadSegment() {
  const geo = new THREE.PlaneGeometry(ROAD_WIDTH, SEGMENT_LENGTH);
  geo.rotateX(-Math.PI / 2);
  const mat = createToonMaterial(0x555555); // Asphalt grey
  const mesh = new THREE.Mesh(geo, mat);
  mesh.receiveShadow = true;

  // Lane dividers (two white dashed lines)
  const lineGeo = new THREE.PlaneGeometry(0.1, SEGMENT_LENGTH);
  lineGeo.rotateX(-Math.PI / 2);
  const lineMat = new THREE.MeshBasicMaterial({ color: 0xffffff });
  [-LANE_WIDTH / 2, LANE_WIDTH / 2].forEach(x => {  // Adjust for your lane positions
    // Actually place between lanes
  });
  // ... lane divider logic

  return mesh;
}
```

### Scenery Spawning

Roadside objects (trees, buildings, crowd, fences) are spawned alongside each
road segment from a randomized pool. They're recycled the same way.

## Obstacle System

Read `references/obstacle-patterns.md` for the full pattern library and
spawning rules.

Obstacles spawn at intervals ahead of the player. Each obstacle occupies one
lane. The pattern system ensures at least one lane is always clear (the game
must be fair).

```javascript
function spawnObstacleRow() {
  const pattern = pickPattern(difficulty);
  // pattern is an array like [true, false, true]
  // meaning: obstacle in lane 0, clear lane 1, obstacle in lane 2

  pattern.forEach((hasObstacle, lane) => {
    if (!hasObstacle) return;
    const obs = getObstacleFromPool();
    obs.position.set(LANES[lane], 0, -spawnDistance);
    obs.visible = true;
    activeObstacles.push(obs);
  });
}
```

## Collision Detection

Simple AABB (axis-aligned bounding box) collision between the player and
each active obstacle:

```javascript
const PLAYER_BOX = new THREE.Box3();
const OBS_BOX = new THREE.Box3();
const PLAYER_HALF = new THREE.Vector3(0.5, 0.4, 0.6);

function checkCollisions() {
  PLAYER_BOX.setFromCenterAndSize(
    new THREE.Vector3(playerX, 0.4, 0),
    PLAYER_HALF.clone().multiplyScalar(2)
  );

  for (const obs of activeObstacles) {
    if (!obs.visible) continue;
    OBS_BOX.setFromObject(obs);
    if (PLAYER_BOX.intersectsBox(OBS_BOX)) {
      transition('gameover');
      return;
    }
  }
}
```

For collectibles, use the same approach but trigger collection instead of
game over:

```javascript
function checkCollectibles() {
  for (const item of activeCollectibles) {
    if (!item.visible) continue;
    OBS_BOX.setFromObject(item);
    if (PLAYER_BOX.intersectsBox(OBS_BOX)) {
      collectItem(item);
      item.visible = false;
    }
  }
}
```

## Chase Camera

The camera follows behind and above the vehicle with smooth interpolation:

```javascript
const CAM_OFFSET = new THREE.Vector3(0, 3.0, 5.5);
const CAM_LOOK_AHEAD = new THREE.Vector3(0, 0.5, -8);

function updateCamera() {
  const targetPos = new THREE.Vector3(
    playerX * 0.3,  // Slight lateral follow (don't track 100%)
    CAM_OFFSET.y,
    CAM_OFFSET.z
  );
  camera.position.lerp(targetPos, 0.08);
  camera.lookAt(playerX * 0.2, CAM_LOOK_AHEAD.y, CAM_LOOK_AHEAD.z);
}
```

The `0.3` and `0.2` multipliers create a subtle lag — the camera doesn't
perfectly track the vehicle sideways, which makes lane switches feel snappier
and more dynamic.

### Countdown Camera

During countdown, zoom the camera from a wide establishing shot down to the
chase position:

```javascript
function updateCountdownCamera(progress) {
  // progress: 0 → 1 over the countdown duration
  const startPos = new THREE.Vector3(3, 5, 8);
  const endPos = CAM_OFFSET.clone();
  camera.position.lerpVectors(startPos, endPos, easeOutCubic(progress));
  camera.lookAt(0, 0.5, -3);
}
```

## HUD (Heads-Up Display)

HTML overlay on top of the Three.js canvas:

```
┌─────────────────────────────────────┐
│  🏁 1,250m          ⭐ 3,400  🪙 12 │
│                                     │
│                                     │
│          (3D viewport)              │
│                                     │
│                                     │
│                       [SPD ███░░]   │
└─────────────────────────────────────┘
```

- **Distance** (top-left): meters traveled, primary progress metric
- **Score** (top-center): points with style multiplier applied
- **Coins** (top-right): collected coins count
- **Speed indicator** (bottom-right, optional): visual speed bar

### HUD Styling

```css
.hud {
  position: absolute;
  top: 0; left: 0; right: 0;
  padding: 12px 16px;
  display: flex;
  justify-content: space-between;
  font-family: 'Arial Black', sans-serif;
  font-size: 18px;
  color: white;
  text-shadow: 2px 2px 0 rgba(0,0,0,0.5);
  pointer-events: none;
  z-index: 10;
}
```

Use bold, chunky typography with dark text shadows — matching the Subway
Surfers UI aesthetic.

## Scoring System

```javascript
let score = 0;
let distance = 0;
let coins = 0;
const styleMultiplier = 1.0 + (vehicleData.stats.style - 1) * 0.25;

function updateScore(dt) {
  distance += scrollSpeed * dt;
  // Base points from distance
  score += scrollSpeed * dt * 10 * styleMultiplier;
}

function collectItem(item) {
  if (item.userData.type === 'coin') {
    coins += 1;
    score += 100 * styleMultiplier;
  } else if (item.userData.type === 'star') {
    score += 500 * styleMultiplier;
  } else if (item.userData.type === 'boost') {
    applySpeedBoost();
  }
}
```

## Speed Progression

The vehicle starts at a base speed and accelerates gradually, creating
increasing difficulty:

```javascript
const BASE_SPEED = 8;  // units per second
let maxSpeed;          // determined by vehicle speed stat
let scrollSpeed;
let speedAccel = 0.15; // acceleration per second

function initSpeed() {
  maxSpeed = BASE_SPEED + (vehicleData.stats.speed - 1) * 1.5;
  scrollSpeed = BASE_SPEED * 0.6; // Start at 60% of base
}

function updateSpeed(dt) {
  scrollSpeed = Math.min(scrollSpeed + speedAccel * dt, maxSpeed);
}
```

## Game Over & Restart

On collision:
1. Freeze the vehicle
2. Play a crash shake effect (camera oscillation)
3. Fade in the game over overlay after 0.5s
4. Show final score, distance, coins, and high score
5. Two buttons: **"Play Again"** (restart race) and **"Garage"** (back to builder)

```javascript
function showGameOverUI() {
  const overlay = document.getElementById('gameover-overlay');
  overlay.style.display = 'flex';
  overlay.querySelector('.final-score').textContent = Math.floor(score);
  overlay.querySelector('.final-distance').textContent = Math.floor(distance) + 'm';
  overlay.querySelector('.final-coins').textContent = coins;

  // High score
  checkHighScore();
}

async function checkHighScore() {
  try {
    const saved = await window.storage.get('soapbox-highscore');
    const highScore = saved ? parseInt(saved.value) : 0;
    if (score > highScore) {
      await window.storage.set('soapbox-highscore', Math.floor(score).toString());
      // Show "NEW HIGH SCORE!" animation
    }
  } catch (e) {}
}
```

### Crash Effect

```javascript
function playCrashEffect() {
  let shakeIntensity = 0.3;
  const originalPos = camera.position.clone();

  function shake() {
    if (shakeIntensity < 0.01) return;
    camera.position.set(
      originalPos.x + (Math.random() - 0.5) * shakeIntensity,
      originalPos.y + (Math.random() - 0.5) * shakeIntensity,
      originalPos.z
    );
    shakeIntensity *= 0.9;
    requestAnimationFrame(shake);
  }
  shake();
}
```

## Persistence

```javascript
// Save high score
await window.storage.set('soapbox-highscore', score.toString());

// Load high score
const hs = await window.storage.get('soapbox-highscore');
const highScore = hs ? parseInt(hs.value) : 0;

// Return to garage
async function goToGarage() {
  // The vehicle builder artifact reads from 'soapbox-vehicle'
  // No action needed — just navigate/reload to the builder
}
```

## Implementation Checklist

- [ ] Load vehicle data from `window.storage` and assemble 3D model
- [ ] Three.js scene with outdoor lighting, sky, and fog
- [ ] Procedural scrolling track with recycled road segments
- [ ] 3-lane system with smooth animated lane switching
- [ ] Keyboard controls (arrow keys / A,D)
- [ ] Touch controls (tap zones + swipe)
- [ ] Obstacle spawning with fair patterns (always 1+ lane clear)
- [ ] At least 6 obstacle types from the asset guide
- [ ] AABB collision detection → game over on hit
- [ ] Coin/collectible spawning and collection
- [ ] Chase camera with smooth follow and lateral lag
- [ ] Countdown sequence (3, 2, 1, GO!)
- [ ] HUD showing distance, score, and coins
- [ ] Speed increases over time (difficulty progression)
- [ ] Game over screen with score, distance, high score
- [ ] "Play Again" and "Garage" buttons on game over
- [ ] Crash camera shake effect
- [ ] High score saved to persistent storage
- [ ] Roadside scenery (trees, buildings, crowd, fences)
- [ ] Toon shading on all objects (matches vehicle builder style)
- [ ] Responsive: works on desktop and mobile
- [ ] Vehicle stats affect gameplay (speed, handling, style multiplier)

## Test Prompts

1. "Build the racing gameplay for the Red Bull Soapbox Race game"
2. "The lane switching feels too slow, make it snappier"
3. "Add ramps that launch the vehicle into the air briefly"
4. "The obstacles are too close together, adjust the spacing"
5. "Make the game progressively harder the further you get"
6. "Add cheering crowd sounds and visual effects when passing milestones"
