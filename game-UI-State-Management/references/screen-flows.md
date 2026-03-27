# Screen Flows Reference

Every screen in the game, its layout, content, and transitions.

## Table of Contents
1. [Title Screen](#title-screen)
2. [Garage / Builder Screen](#garage--builder-screen)
3. [Countdown Overlay](#countdown-overlay)
4. [Pause Menu](#pause-menu)
5. [Game Over Screen](#game-over-screen)
6. [Settings Panel](#settings-panel)
7. [Loading States](#loading-states)
8. [Transition Animations](#transition-animations)

---

## Title Screen

The first thing the player sees. Sets the tone for the entire game.

### Layout

```
┌─────────────────────────────────────┐
│                                     │
│         🏎️ (3D vehicle idle         │
│          on turntable behind)       │
│                                     │
│     ╔═══════════════════════╗       │
│     ║   SOAPBOX             ║       │
│     ║       RACE!           ║       │
│     ╚═══════════════════════╝       │
│                                     │
│        ✦ TAP TO START ✦            │
│           (pulsing)                 │
│                                     │
│     🏆 High Score: 12,400          │
│     🪙 Total Coins: 347            │
│                                     │
│                        ⚙️ Settings   │
└─────────────────────────────────────┘
```

### HTML Structure

```html
<div id="screen-title" class="screen">
  <div class="title-content">
    <div class="title-logo">
      <h1 class="title-text">SOAPBOX</h1>
      <h1 class="title-text title-accent">RACE!</h1>
    </div>

    <button class="tap-to-start" onclick="startGame()">
      ✦ TAP TO START ✦
    </button>

    <div class="title-stats">
      <div class="title-stat">
        <span class="stat-icon">🏆</span>
        <span class="stat-label">High Score</span>
        <span class="stat-value" id="title-highscore">0</span>
      </div>
      <div class="title-stat">
        <span class="stat-icon">🪙</span>
        <span class="stat-label">Total Coins</span>
        <span class="stat-value" id="title-coins">0</span>
      </div>
    </div>
  </div>

  <button class="settings-btn" onclick="showSettings()">⚙️</button>
</div>
```

### Styles

```css
#screen-title {
  justify-content: center;
  align-items: center;
  background: linear-gradient(
    180deg,
    transparent 0%,
    rgba(0, 0, 0, 0.3) 60%,
    rgba(0, 0, 0, 0.6) 100%
  );
}

.title-logo {
  text-align: center;
  margin-bottom: 32px;
}

.title-accent {
  color: var(--red);
  font-size: 80px;
  margin-top: -12px;
}

.tap-to-start {
  font-family: var(--font-display);
  font-size: 24px;
  color: white;
  background: none;
  border: none;
  cursor: pointer;
  text-shadow: var(--text-shadow);
  letter-spacing: 4px;
  animation: tapPulse 2s ease-in-out infinite;
}

@keyframes tapPulse {
  0%, 100% { opacity: 1; transform: scale(1); }
  50% { opacity: 0.5; transform: scale(0.97); }
}

.title-stats {
  display: flex;
  gap: 32px;
  margin-top: 40px;
}

.title-stat {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 4px;
}

.settings-btn {
  position: absolute;
  bottom: 24px;
  right: 24px;
  font-size: 28px;
  background: var(--bg-card);
  border: none;
  border-radius: 50%;
  width: 48px;
  height: 48px;
  cursor: pointer;
  backdrop-filter: blur(8px);
}
```

### 3D Background

While the title screen is showing, the Three.js scene renders the player's
last-used vehicle on a turntable, slowly rotating. If no vehicle exists,
show a default bathtub soapbox.

```javascript
function setupTitleScene() {
  // Clear race scene if any
  clearScene();

  // Load vehicle (or default)
  const vehicle = await loadVehicle();
  await assembleVehicle(vehicle, vehicleGroup, assetManager, USE_PLACEHOLDERS);

  // Position camera for a nice hero shot
  camera.position.set(2.5, 2, 3.5);
  camera.lookAt(0, 0.3, 0);

  // Auto-rotate
  titleRotation = true;
}
```

### Interaction

Tap/click anywhere (or the button specifically) triggers:
1. Play a whoosh sound effect (if audio enabled)
2. Fade out title screen
3. Transition to Garage/Builder

---

## Garage / Builder Screen

The vehicle builder UI is managed by the `soapbox-vehicle-builder` skill.
This screen flow section only covers how the builder integrates with the
overall game navigation.

### Navigation Elements Added by Game UI

The builder skill provides the part picker, color picker, canvas preview, and
stats bars. The Game UI skill adds:

- **Back button** (top-left): returns to title screen
- **"RACE!" button** (bottom-right): saves vehicle, transitions to race
- **Vehicle name** (top-center): editable text input

```html
<div id="builder-nav" class="builder-overlay">
  <button class="nav-btn back-btn" onclick="switchMode('title')">
    ← BACK
  </button>

  <input type="text" id="vehicle-name" class="vehicle-name-input"
         placeholder="Name your ride..."
         maxlength="20" />

  <button class="game-btn large pulse race-cta" onclick="startRace()">
    🏁 RACE!
  </button>
</div>
```

```css
.builder-overlay {
  position: absolute;
  top: 0; left: 0; right: 0; bottom: 0;
  pointer-events: none;
  z-index: 15;
}

.builder-overlay > * {
  pointer-events: auto;
}

.back-btn {
  position: absolute;
  top: 16px;
  left: 16px;
  font-family: var(--font-body);
  font-size: 16px;
  font-weight: 800;
  color: white;
  background: var(--bg-card);
  border: none;
  border-radius: 12px;
  padding: 10px 16px;
  cursor: pointer;
  backdrop-filter: blur(8px);
  text-shadow: var(--text-shadow);
}

.vehicle-name-input {
  position: absolute;
  top: 16px;
  left: 50%;
  transform: translateX(-50%);
  font-family: var(--font-display);
  font-size: 22px;
  color: white;
  text-align: center;
  background: var(--bg-card);
  border: 2px solid rgba(255, 255, 255, 0.2);
  border-radius: 12px;
  padding: 8px 20px;
  width: 200px;
  outline: none;
  backdrop-filter: blur(8px);
  text-shadow: var(--text-shadow);
}

.vehicle-name-input::placeholder {
  color: rgba(255, 255, 255, 0.4);
}

.race-cta {
  position: absolute;
  bottom: 24px;
  right: 24px;
}
```

---

## Countdown Overlay

Shown after leaving the garage, before racing starts. Full-screen numbers
that scale and fade.

### Sequence

| Time     | Display  | Animation                               |
|----------|----------|-----------------------------------------|
| 0.0–1.0s | "3"      | Scale from 2x→1x, fade in, hold, fade  |
| 1.0–2.0s | "2"      | Same                                    |
| 2.0–3.0s | "1"      | Same                                    |
| 3.0–3.5s | "GO!"    | Scale from 0.5x→1.5x, green color, fade|
| 3.5s     | (hide)   | Transition to racing HUD                |

### HTML

```html
<div id="screen-countdown" class="screen">
  <div class="countdown-number" id="countdown-display">3</div>
</div>
```

### CSS

```css
#screen-countdown {
  justify-content: center;
  align-items: center;
  background: rgba(0, 0, 0, 0.3);
}

.countdown-number {
  font-family: var(--font-display);
  font-size: 150px;
  color: white;
  text-shadow: 6px 6px 0 rgba(0, 0, 0, 0.5);
  animation: countdownPop 0.8s cubic-bezier(0.34, 1.56, 0.64, 1);
}

.countdown-number.go {
  color: var(--green);
  font-size: 120px;
}

@keyframes countdownPop {
  0% { transform: scale(2.5); opacity: 0; }
  40% { transform: scale(0.9); opacity: 1; }
  60% { transform: scale(1.05); }
  100% { transform: scale(1); opacity: 1; }
}
```

### Logic

```javascript
function startCountdownSequence() {
  const display = document.getElementById('countdown-display');
  const steps = [
    { text: '3', delay: 0 },
    { text: '2', delay: 1000 },
    { text: '1', delay: 2000 },
    { text: 'GO!', delay: 3000, className: 'go' },
  ];

  steps.forEach(step => {
    setTimeout(() => {
      display.textContent = step.text;
      display.className = 'countdown-number' + (step.className ? ' ' + step.className : '');
      // Re-trigger animation
      display.style.animation = 'none';
      display.offsetHeight; // reflow
      display.style.animation = '';
    }, step.delay);
  });

  setTimeout(() => {
    sm.show('hud', 'fade');
    startRacing(); // Begin game loop
  }, 3500);
}
```

---

## Pause Menu

Triggered by a pause button in the HUD or pressing Escape on desktop.

### Layout

```
┌─────────────────────────────────────┐
│          (dimmed 3D scene)          │
│                                     │
│         ╔═══════════════╗           │
│         ║    PAUSED     ║           │
│         ╠═══════════════╣           │
│         ║               ║           │
│         ║  [▶ RESUME]   ║           │
│         ║  [🏠 GARAGE]  ║           │
│         ║  [⚙ SETTINGS] ║           │
│         ║               ║           │
│         ╚═══════════════╝           │
│                                     │
└─────────────────────────────────────┘
```

### HTML

```html
<div id="screen-pause" class="screen">
  <div class="pause-backdrop"></div>
  <div class="pause-card">
    <h2 class="pause-title">PAUSED</h2>
    <div class="pause-buttons">
      <button class="game-btn" onclick="resumeGame()">▶ RESUME</button>
      <button class="game-btn secondary" onclick="quitToGarage()">🏠 GARAGE</button>
      <button class="game-btn secondary" onclick="showSettings()">⚙ SETTINGS</button>
    </div>
  </div>
</div>
```

### CSS

```css
.pause-backdrop {
  position: absolute;
  inset: 0;
  background: rgba(0, 0, 0, 0.6);
  backdrop-filter: blur(4px);
}

.pause-card {
  position: relative;
  z-index: 1;
  background: var(--bg-card-solid);
  border-radius: var(--border-radius-lg);
  padding: 32px 40px;
  text-align: center;
  box-shadow: 0 12px 40px rgba(0, 0, 0, 0.5);
  margin: auto;
}

.pause-title {
  font-family: var(--font-display);
  font-size: 48px;
  color: white;
  text-shadow: var(--text-shadow-heavy);
  margin-bottom: 24px;
}

.pause-buttons {
  display: flex;
  flex-direction: column;
  gap: 12px;
}
```

### Pause/Resume Logic

```javascript
let isPaused = false;

function togglePause() {
  if (gameState !== 'racing' && gameState !== 'paused') return;

  if (isPaused) {
    resumeGame();
  } else {
    pauseGame();
  }
}

function pauseGame() {
  isPaused = true;
  gameState = 'paused';
  sm.show('pause', 'fade');
  // The game loop checks isPaused and skips update
}

function resumeGame() {
  isPaused = false;
  gameState = 'racing';
  sm.show('hud', 'fade');
  lastTime = performance.now(); // Reset delta to prevent time jump
}

function quitToGarage() {
  isPaused = false;
  switchMode('garage');
}

// Keyboard shortcut
document.addEventListener('keydown', (e) => {
  if (e.key === 'Escape' || e.key === 'p') togglePause();
});
```

---

## Game Over Screen

The most important screen for retention — it needs to celebrate the player
and make them want to try again immediately.

### Layout

```
┌─────────────────────────────────────┐
│          (frozen 3D scene)          │
│                                     │
│       ╔═════════════════════╗       │
│       ║     WIPEOUT!        ║       │
│       ║                     ║       │
│       ║  🏁 Distance  1,247m║       │
│       ║  ⭐ Score    15,820 ║       │
│       ║  🪙 Coins        23 ║       │
│       ║  🎯 Near Misses   7 ║       │
│       ║                     ║       │
│       ║  ── x1.75 STYLE ── ║       │
│       ║                     ║       │
│       ║  🏆 HIGH SCORE!    ║  ← conditional
│       ║     NEW RECORD     ║       │
│       ║                     ║       │
│       ║  [🔄 RACE AGAIN]  ║       │
│       ║  [🏠 GARAGE]      ║       │
│       ╚═════════════════════╝       │
│                                     │
└─────────────────────────────────────┘
```

### HTML

```html
<div id="screen-gameover" class="screen">
  <div class="gameover-backdrop"></div>
  <div class="gameover-card">
    <h1 class="gameover-title">WIPEOUT!</h1>

    <div class="gameover-stats">
      <div class="go-stat-row">
        <span class="go-stat-icon">🏁</span>
        <span class="go-stat-label">Distance</span>
        <span class="go-stat-value" id="go-distance">0m</span>
      </div>
      <div class="go-stat-row">
        <span class="go-stat-icon">⭐</span>
        <span class="go-stat-label">Score</span>
        <span class="go-stat-value" id="go-score">0</span>
      </div>
      <div class="go-stat-row">
        <span class="go-stat-icon">🪙</span>
        <span class="go-stat-label">Coins</span>
        <span class="go-stat-value" id="go-coins">0</span>
      </div>
      <div class="go-stat-row">
        <span class="go-stat-icon">🎯</span>
        <span class="go-stat-label">Near Misses</span>
        <span class="go-stat-value" id="go-nearmisses">0</span>
      </div>
    </div>

    <div class="go-multiplier">
      <span>× <span id="go-multiplier">1.00</span> STYLE</span>
    </div>

    <div class="go-highscore" id="go-highscore-badge" style="display:none">
      <div class="highscore-burst">🏆</div>
      <div class="highscore-text">NEW HIGH SCORE!</div>
    </div>

    <div class="go-buttons">
      <button class="game-btn large pulse" onclick="restartGame()">
        🔄 RACE AGAIN
      </button>
      <button class="game-btn secondary" onclick="switchMode('garage')">
        🏠 GARAGE
      </button>
    </div>
  </div>
</div>
```

### High Score Animation

When a new record is set, the badge appears with a burst animation:

```css
.go-highscore {
  text-align: center;
  margin: 16px 0;
  animation: highscoreBounce 0.6s cubic-bezier(0.34, 1.56, 0.64, 1);
}

.highscore-burst {
  font-size: 48px;
  animation: burstSpin 1s ease-out;
}

.highscore-text {
  font-family: var(--font-display);
  font-size: 28px;
  color: var(--yellow);
  text-shadow: var(--text-shadow-heavy);
  animation: highscoreGlow 1.5s ease-in-out infinite alternate;
}

@keyframes highscoreBounce {
  0% { transform: scale(0); opacity: 0; }
  60% { transform: scale(1.2); }
  100% { transform: scale(1); opacity: 1; }
}

@keyframes burstSpin {
  0% { transform: rotate(0deg) scale(0); }
  50% { transform: rotate(180deg) scale(1.3); }
  100% { transform: rotate(360deg) scale(1); }
}

@keyframes highscoreGlow {
  from { text-shadow: var(--text-shadow-heavy); }
  to { text-shadow: 0 0 20px rgba(255, 215, 0, 0.8), var(--text-shadow-heavy); }
}
```

### Populating Stats

```javascript
async function populateGameOverStats() {
  document.getElementById('go-distance').textContent = Math.floor(distance) + 'm';
  document.getElementById('go-score').textContent = Math.floor(score).toLocaleString();
  document.getElementById('go-coins').textContent = coins;
  document.getElementById('go-nearmisses').textContent = nearMisses;
  document.getElementById('go-multiplier').textContent = styleMultiplier.toFixed(2);

  // Animate numbers counting up
  animateCountUp('go-score', 0, Math.floor(score), 1200);
  animateCountUp('go-distance', 0, Math.floor(distance), 800);

  // Check high score
  const isNewRecord = await saveHighScore(Math.floor(score));
  if (isNewRecord) {
    document.getElementById('go-highscore-badge').style.display = 'block';
  } else {
    document.getElementById('go-highscore-badge').style.display = 'none';
  }

  // Add coins to lifetime total
  await addCoinsToTotal(coins);
}

function animateCountUp(elementId, from, to, duration) {
  const el = document.getElementById(elementId);
  const start = performance.now();

  function tick(now) {
    const progress = Math.min((now - start) / duration, 1);
    const eased = 1 - Math.pow(1 - progress, 3); // ease-out cubic
    const current = Math.floor(from + (to - from) * eased);
    el.textContent = current.toLocaleString();
    if (progress < 1) requestAnimationFrame(tick);
  }
  requestAnimationFrame(tick);
}
```

---

## Settings Panel

Simple overlay for toggling sound, resetting data, and viewing credits.

```html
<div id="screen-settings" class="screen">
  <div class="settings-backdrop" onclick="hideSettings()"></div>
  <div class="settings-card">
    <h2 class="settings-title">SETTINGS</h2>

    <div class="setting-row">
      <span>🔊 Sound</span>
      <button class="toggle-btn" id="sound-toggle" onclick="toggleSound()">ON</button>
    </div>

    <div class="setting-row">
      <span>📳 Vibration</span>
      <button class="toggle-btn" id="vibration-toggle" onclick="toggleVibration()">ON</button>
    </div>

    <div class="setting-row danger">
      <span>🗑️ Reset All Data</span>
      <button class="game-btn small" onclick="confirmReset()">RESET</button>
    </div>

    <button class="game-btn secondary" onclick="hideSettings()">
      ✕ CLOSE
    </button>
  </div>
</div>
```

---

## Loading States

### Initial Load

While the game boots up (loading 3D assets, fonts, vehicle data):

```html
<div id="loading-screen">
  <div class="loading-spinner"></div>
  <div class="loading-text">Building your soapbox...</div>
</div>
```

```css
.loading-spinner {
  width: 48px;
  height: 48px;
  border: 5px solid rgba(255, 255, 255, 0.2);
  border-top-color: var(--yellow);
  border-radius: 50%;
  animation: spin 0.8s linear infinite;
}

@keyframes spin {
  to { transform: rotate(360deg); }
}

.loading-text {
  font-family: var(--font-body);
  font-size: 16px;
  color: var(--text-secondary);
  margin-top: 16px;
}
```

### Transition Loading

When switching from garage to race (building the race scene), show a brief
loading bar at the top of the screen instead of a full overlay:

```javascript
function showTransitionLoader() {
  const bar = document.getElementById('transition-bar');
  bar.style.display = 'block';
  bar.style.width = '0%';
  bar.style.transition = 'width 1.5s ease-out';
  bar.offsetHeight;
  bar.style.width = '100%';
}
```

---

## Transition Animations

### Screen-to-Screen Transitions

| From → To            | Animation         | Duration | Notes                        |
|----------------------|-------------------|----------|------------------------------|
| Title → Garage       | slide-up          | 400ms    | Garage slides up from below  |
| Garage → Countdown   | fade              | 300ms    | Quick fade to race           |
| Countdown → HUD      | fade              | 200ms    | Almost instant               |
| Racing → Game Over   | pop               | 300ms    | Card pops in after shake     |
| Game Over → Countdown| fade              | 300ms    | "Race Again"                 |
| Game Over → Garage   | slide-up          | 400ms    | Back to builder              |
| Any → Pause          | fade              | 200ms    | Quick dim                    |
| Pause → HUD          | fade              | 200ms    | Quick resume                 |

### 3D Scene Transitions

When changing the 3D scene (e.g., garage → race), avoid a jarring cut:

1. Fade the screen to black (200ms)
2. Swap the 3D scene while black
3. Fade back in (300ms)

```javascript
async function transitionScenes(buildNewScene) {
  const blackout = document.getElementById('blackout');
  blackout.style.display = 'block';
  blackout.style.opacity = '0';
  blackout.style.transition = 'opacity 0.2s';
  blackout.offsetHeight;
  blackout.style.opacity = '1';
  await sleep(200);

  await buildNewScene();

  blackout.style.transition = 'opacity 0.3s';
  blackout.style.opacity = '0';
  await sleep(300);
  blackout.style.display = 'none';
}
```
