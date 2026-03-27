# Game Loop Reference

The main `requestAnimationFrame` loop, delta time handling, speed/physics,
scoring, and the complete game state machine.

## Table of Contents
1. [Main Loop & Delta Time](#main-loop--delta-time)
2. [Complete State Machine](#complete-state-machine)
3. [Speed & Physics](#speed--physics)
4. [Scoring System](#scoring-system)
5. [Collision Detection Details](#collision-detection-details)
6. [Visual Effects](#visual-effects)
7. [Full Frame Update (Racing State)](#full-frame-update)

---

## Main Loop & Delta Time

Use a fixed-timestep approach for consistent gameplay across frame rates:

```javascript
let lastTime = 0;
const MAX_DT = 0.05; // Cap at 50ms to prevent spiral of death

function gameLoop(timestamp) {
  requestAnimationFrame(gameLoop);

  const rawDt = (timestamp - lastTime) / 1000;
  lastTime = timestamp;
  const dt = Math.min(rawDt, MAX_DT); // Clamp

  // Update current state
  states[gameState].update(timestamp, dt);

  // Always render
  renderer.render(scene, camera);
}

// Kick off
requestAnimationFrame((t) => {
  lastTime = t;
  requestAnimationFrame(gameLoop);
});
```

The `MAX_DT` cap prevents the game from "teleporting" obstacles when the
tab is backgrounded and returns with a huge delta.

---

## Complete State Machine

### State: LOADING

```javascript
const loadingState = {
  async enter() {
    showLoadingUI();

    // 1. Load vehicle data
    vehicleData = await loadVehicle();

    // 2. Compute stats
    switchDuration = 400 - (vehicleData.stats.handling - 1) * 62;
    maxSpeed = BASE_SPEED + (vehicleData.stats.speed - 1) * 1.5;
    styleMultiplier = 1.0 + (vehicleData.stats.style - 1) * 0.25;

    // 3. Build scene
    setupScene();
    setupLighting();

    // 4. Assemble vehicle (placeholder or GLB)
    await assembleVehicle(vehicleData, vehicleGroup, assetManager, USE_PLACEHOLDERS);

    // 5. Build track
    trackManager = new TrackManager(scene);

    // 6. Initialize pools
    obstaclePool.addAllToScene(scene);
    coinPool.addAllToScene(scene);

    // 7. Position camera for countdown
    camera.position.set(3, 5, 8);
    camera.lookAt(0, 0.5, -3);

    hideLoadingUI();
    transition('countdown');
  },
  update() {},
};
```

### State: COUNTDOWN

```javascript
const countdownState = {
  enter() {
    this.startTime = performance.now();
    this.phase = 3; // 3, 2, 1, GO!
    showCountdownUI(3);
  },

  update(now, dt) {
    const elapsed = (now - this.startTime) / 1000;
    const phase = 3 - Math.floor(elapsed);

    if (phase !== this.phase && phase >= 0) {
      this.phase = phase;
      showCountdownUI(phase);
      // Play countdown sound effect if available
    }

    // Camera zoom from establishing shot → chase position
    const progress = Math.min(elapsed / 3.5, 1);
    const ease = 1 - Math.pow(1 - progress, 3); // ease-out cubic

    camera.position.lerpVectors(
      new THREE.Vector3(3, 5, 8),     // Wide start
      new THREE.Vector3(0, 3, 5.5),   // Chase position
      ease
    );
    camera.lookAt(0, 0.5, -3);

    // Show "GO!" briefly then start racing
    if (elapsed >= 3.0 && elapsed < 3.3) {
      showCountdownUI('GO!');
    }
    if (elapsed >= 3.5) {
      hideCountdownUI();
      transition('racing');
    }
  },
};
```

### State: RACING

See [Full Frame Update](#full-frame-update) below.

### State: GAMEOVER

```javascript
const gameoverState = {
  enter() {
    this.enterTime = performance.now();
    this.shakeIntensity = 0.3;
    this.cameraBase = camera.position.clone();

    // Stop spawning
    // Vehicle "crash" — slight rotation
    vehicleGroup.rotation.z = 0.15;
    vehicleGroup.rotation.x = -0.1;
  },

  update(now, dt) {
    const elapsed = (now - this.enterTime) / 1000;

    // Camera shake (decaying)
    if (this.shakeIntensity > 0.005) {
      camera.position.set(
        this.cameraBase.x + (Math.random() - 0.5) * this.shakeIntensity,
        this.cameraBase.y + (Math.random() - 0.5) * this.shakeIntensity,
        this.cameraBase.z
      );
      this.shakeIntensity *= 0.92;
    }

    // Show game over UI after brief delay
    if (elapsed >= 0.8 && !this.uiShown) {
      this.uiShown = true;
      showGameOverUI({
        score: Math.floor(score),
        distance: Math.floor(distance),
        coins: coins,
        styleMultiplier: styleMultiplier,
      });
      saveHighScore(Math.floor(score));
    }
  },
};
```

### State Transition Helper

```javascript
function transition(newState) {
  console.log(`State: ${gameState} → ${newState}`);
  gameState = newState;
  states[newState].enter();
}

function restartGame() {
  // Reset all game variables
  score = 0;
  distance = 0;
  coins = 0;
  scrollSpeed = BASE_SPEED * 0.6;
  currentLane = 1;
  playerX = 0;
  targetX = 0;
  isSwitching = false;
  isJumping = false;
  distanceSinceLastSpawn = 0;

  // Reset vehicle orientation
  vehicleGroup.rotation.set(0, 0, 0);
  vehicleGroup.position.set(0, 0, 0);
  playerGroup.position.set(0, 0, 0);

  // Clear obstacles and collectibles
  for (const obs of activeObstacles) obstaclePool.returnToPool(obs);
  for (const item of activeCollectibles) coinPool.returnToPool(item);
  activeObstacles = [];
  activeCollectibles = [];

  // Reset track
  trackManager.reset();

  hideGameOverUI();
  transition('countdown');
}
```

---

## Speed & Physics

### Speed Model

The vehicle is gravity-powered (rolling downhill), so it accelerates
from a slow start up to a maximum speed determined by the Speed stat.

```javascript
const BASE_SPEED = 8;         // Base max speed (units/sec)
const START_SPEED_RATIO = 0.5; // Start at 50% of base
const ACCEL_RATE = 0.2;       // Units/sec² acceleration
const BOOST_MULTIPLIER = 1.6;  // Speed during boost power-up
const BOOST_DURATION = 2000;   // ms

let scrollSpeed;
let maxSpeed;
let isBoosted = false;
let boostEndTime = 0;

function initSpeed() {
  maxSpeed = BASE_SPEED + (vehicleData.stats.speed - 1) * 1.5;
  scrollSpeed = BASE_SPEED * START_SPEED_RATIO;
}

function updateSpeed(dt, now) {
  // Check boost expiry
  if (isBoosted && now >= boostEndTime) {
    isBoosted = false;
  }

  const target = isBoosted ? maxSpeed * BOOST_MULTIPLIER : maxSpeed;
  scrollSpeed = Math.min(scrollSpeed + ACCEL_RATE * dt, target);

  // If coming down from boost, decelerate smoothly
  if (!isBoosted && scrollSpeed > maxSpeed) {
    scrollSpeed = Math.max(scrollSpeed - ACCEL_RATE * 3 * dt, maxSpeed);
  }
}

function applySpeedBoost() {
  isBoosted = true;
  boostEndTime = performance.now() + BOOST_DURATION;
}

function applySpeedPenalty() {
  scrollSpeed *= 0.7;
}
```

### Difficulty Speed Factor

As distance increases, the base acceleration also nudges up slightly so
the player feels pressure even at max speed:

```javascript
function getSpeedMultiplier() {
  const diff = getDifficulty(); // 0 to 1
  return 1.0 + diff * 0.3;     // Up to 30% faster at max difficulty
}
```

Apply this in `updateSpeed`:
```javascript
const effectiveAccel = ACCEL_RATE * getSpeedMultiplier();
scrollSpeed = Math.min(scrollSpeed + effectiveAccel * dt, target);
```

### Vehicle Wheel Animation

Spin the wheels based on scroll speed:
```javascript
function updateWheelSpin(dt) {
  const spinRate = scrollSpeed * 2; // radians per second
  ['wheelFL', 'wheelFR', 'wheelBL', 'wheelBR'].forEach(name => {
    const wheel = vehicleGroup.getObjectByName(name);
    if (wheel) wheel.rotation.x += spinRate * dt;
  });
}
```

---

## Scoring System

### Score Components

```javascript
let score = 0;
let distance = 0;
let coins = 0;
let nearMisses = 0;
let styleMultiplier = 1.0;

// Per frame (in racing state):
function updateScore(dt) {
  const distIncrement = scrollSpeed * dt;
  distance += distIncrement;

  // Distance points (10 per meter, modified by style)
  score += distIncrement * 10 * styleMultiplier;
}
```

### Item Collection

```javascript
function collectItem(item) {
  const type = item.userData.type;

  switch (type) {
    case 'coin':
      coins += 1;
      score += 100 * styleMultiplier;
      showFloatingText('+100', item.position);
      break;

    case 'star':
      score += 500 * styleMultiplier;
      showFloatingText('+500', item.position);
      break;

    case 'wrench':
      score += 250 * styleMultiplier;
      showFloatingText('+250 STYLE!', item.position);
      break;

    case 'boost':
      applySpeedBoost();
      showFloatingText('BOOST!', item.position);
      break;
  }
}
```

### Near-Miss Bonus

When the player barely avoids an obstacle (passes within 0.3m laterally),
award bonus points:

```javascript
function checkNearMisses() {
  for (const obs of activeObstacles) {
    if (!obs.visible || obs.userData.nearMissCounted) continue;

    // Check if obstacle is beside the player (just passed)
    if (obs.position.z > -0.5 && obs.position.z < 1.5) {
      const lateralDist = Math.abs(obs.position.x - playerX);
      const hitboxHalfW = obs.userData.hitbox.x / 2;
      const playerHalfW = 0.5;

      // Near miss: gap between edges is less than 0.3m
      const gap = lateralDist - hitboxHalfW - playerHalfW;
      if (gap > 0 && gap < 0.3) {
        nearMisses++;
        score += 50 * styleMultiplier;
        showFloatingText('CLOSE!', obs.position);
        obs.userData.nearMissCounted = true;
      }
    }
  }
}
```

### High Score Persistence

```javascript
async function saveHighScore(newScore) {
  try {
    const saved = await window.storage.get('soapbox-highscore');
    const current = saved ? parseInt(saved.value) : 0;
    if (newScore > current) {
      await window.storage.set('soapbox-highscore', newScore.toString());
      return true; // New high score!
    }
  } catch (e) {}
  return false;
}

async function getHighScore() {
  try {
    const saved = await window.storage.get('soapbox-highscore');
    return saved ? parseInt(saved.value) : 0;
  } catch (e) {
    return 0;
  }
}
```

---

## Collision Detection Details

### Player Bounding Box

The player hitbox is slightly smaller than the visual model to feel
"generous" — near-misses should feel good, not punishing.

```javascript
const PLAYER_HITBOX = new THREE.Vector3(0.8, 0.7, 0.9);
// Slightly smaller than the vehicle chassis visual size
// This makes the game feel fair

const playerBox = new THREE.Box3();
const obsBox = new THREE.Box3();

function updatePlayerBox() {
  const center = new THREE.Vector3(playerX, 0.4, 0);
  const halfSize = PLAYER_HITBOX.clone().multiplyScalar(0.5);
  playerBox.set(center.clone().sub(halfSize), center.clone().add(halfSize));
}
```

### Per-Frame Collision Check

```javascript
function checkCollisions() {
  updatePlayerBox();

  // Skip collision during jump
  if (isJumping && playerGroup.position.y > 0.5) return;

  for (const obs of activeObstacles) {
    if (!obs.visible) continue;

    // Only check obstacles near the player (Z optimization)
    if (obs.position.z < -2 || obs.position.z > 3) continue;

    const hb = obs.userData.hitbox;
    const center = obs.position.clone();
    center.y = hb.y / 2;
    const halfSize = hb.clone().multiplyScalar(0.5);
    obsBox.set(center.clone().sub(halfSize), center.clone().add(halfSize));

    if (playerBox.intersectsBox(obsBox)) {
      // Special obstacle handling
      if (obs.userData.type === 'ramp') {
        handleRampHit();
        obs.visible = false;
        return;
      }
      if (obs.userData.type === 'pothole') {
        applySpeedPenalty();
        obs.visible = false;
        return;
      }

      // Standard collision → game over
      transition('gameover');
      return;
    }
  }
}

function checkCollectibles() {
  for (const item of activeCollectibles) {
    if (!item.visible) continue;
    if (item.position.z < -1 || item.position.z > 2) continue;

    const center = item.position.clone();
    const halfSize = new THREE.Vector3(0.3, 0.3, 0.3);
    obsBox.set(center.clone().sub(halfSize), center.clone().add(halfSize));

    if (playerBox.intersectsBox(obsBox)) {
      collectItem(item);
      item.visible = false;
    }
  }
}
```

---

## Visual Effects

### Floating Score Text

Show "+100" text that floats upward and fades. Use HTML overlay elements:

```javascript
function showFloatingText(text, worldPos) {
  const el = document.createElement('div');
  el.className = 'floating-text';
  el.textContent = text;
  document.getElementById('effects-layer').appendChild(el);

  // Project 3D position to screen
  const screenPos = worldPos.clone().project(camera);
  el.style.left = ((screenPos.x + 1) / 2 * window.innerWidth) + 'px';
  el.style.top = ((-screenPos.y + 1) / 2 * window.innerHeight) + 'px';

  // Animate up and fade
  let opacity = 1;
  let y = parseFloat(el.style.top);
  function animate() {
    y -= 2;
    opacity -= 0.03;
    el.style.top = y + 'px';
    el.style.opacity = opacity;
    if (opacity > 0) requestAnimationFrame(animate);
    else el.remove();
  }
  requestAnimationFrame(animate);
}
```

```css
.floating-text {
  position: absolute;
  font-family: 'Arial Black', sans-serif;
  font-size: 22px;
  font-weight: bold;
  color: #FFD700;
  text-shadow: 2px 2px 0 #000;
  pointer-events: none;
  z-index: 20;
  transform: translate(-50%, -50%);
}
```

### Speed Lines

At high speeds, add radial speed lines around the viewport edges:

```javascript
function updateSpeedLines(speed) {
  const intensity = Math.max(0, (speed - BASE_SPEED * 0.8) / (maxSpeed * 0.5));
  const el = document.getElementById('speed-lines');
  el.style.opacity = intensity * 0.4;
}
```

Use a CSS radial gradient or SVG overlay for the speed line visual.

### Boost Visual

During speed boost, add a color tint and increased camera FOV:

```javascript
function updateBoostVisual(now) {
  if (isBoosted) {
    camera.fov = THREE.MathUtils.lerp(camera.fov, 70, 0.1);
    // Optional: tint the scene slightly
  } else {
    camera.fov = THREE.MathUtils.lerp(camera.fov, 60, 0.05);
  }
  camera.updateProjectionMatrix();
}
```

---

## Full Frame Update

The complete racing state update, called every frame:

```javascript
const racingState = {
  enter() {
    initSpeed();
    score = 0;
    distance = 0;
    coins = 0;
    nearMisses = 0;
    distanceSinceLastSpawn = 0;
    activeObstacles = [];
    activeCollectibles = [];
  },

  update(now, dt) {
    // 1. Update speed (acceleration + boost)
    updateSpeed(dt, now);

    // 2. Handle lane switching animation
    updateLanePosition(now);

    // 3. Handle jump (if active)
    updateJump(now);

    // 4. Scroll track, obstacles, collectibles toward camera
    scrollTrack(dt);

    // 5. Spawn new obstacles
    spawnObstacles(dt);

    // 6. Animate collectibles (spin, bob)
    updateCollectibles(now);

    // 7. Check collisions (obstacles → game over)
    checkCollisions();

    // 8. Check collectible pickups
    checkCollectibles();

    // 9. Check near-misses
    checkNearMisses();

    // 10. Update score
    updateScore(dt);

    // 11. Update camera (chase follow)
    updateCamera();

    // 12. Update vehicle animations (wheel spin)
    updateWheelSpin(dt);

    // 13. Update visual effects
    updateBoostVisual(now);
    updateSpeedLines(scrollSpeed);

    // 14. Update HUD
    updateHUD(Math.floor(score), Math.floor(distance), coins);
  },
};
```

### HUD Update

```javascript
function updateHUD(score, distance, coins) {
  document.getElementById('hud-score').textContent = score.toLocaleString();
  document.getElementById('hud-distance').textContent = distance + 'm';
  document.getElementById('hud-coins').textContent = coins;
}
```

### Game Over UI

```html
<div id="gameover-overlay" style="display:none">
  <div class="gameover-card">
    <h1>WIPEOUT!</h1>
    <div class="stat-row">
      <span>Distance</span><span class="final-distance">0m</span>
    </div>
    <div class="stat-row">
      <span>Score</span><span class="final-score">0</span>
    </div>
    <div class="stat-row">
      <span>Coins</span><span class="final-coins">0</span>
    </div>
    <div class="stat-row highlight">
      <span>High Score</span><span class="high-score">0</span>
    </div>
    <button onclick="restartGame()">RACE AGAIN</button>
    <button onclick="goToGarage()">GARAGE</button>
  </div>
</div>
```

Style the game over card with the same bold, chunky Subway Surfers aesthetic
as the rest of the UI — rounded corners, bold shadows, vibrant accent colors.
