# HUD & In-Game Effects Reference

The in-race heads-up display and all real-time visual feedback systems.

## Table of Contents
1. [HUD Layout](#hud-layout)
2. [HUD Components](#hud-components)
3. [Floating Score Text](#floating-score-text)
4. [Speed Lines Effect](#speed-lines-effect)
5. [Boost Visual Effect](#boost-visual-effect)
6. [Milestone Celebrations](#milestone-celebrations)
7. [Screen Shake](#screen-shake)
8. [Coin Collection Flash](#coin-collection-flash)

---

## HUD Layout

The HUD is a non-interactive overlay during racing. It must be readable at a
glance, even at high speeds, without blocking the road ahead.

```
┌─────────────────────────────────────┐
│ 🏁 1,247m    ⭐ 15,820    🪙 23  ⏸ │  ← top bar
│                                     │
│                                     │
│          (3D race viewport)         │
│                                     │
│                                     │
│                          SPD ████░  │  ← optional speed bar
└─────────────────────────────────────┘
```

### HTML

```html
<div id="screen-hud" class="screen">
  <!-- Top bar -->
  <div class="hud-bar">
    <div class="hud-item">
      <span class="hud-icon">🏁</span>
      <span class="hud-value" id="hud-distance">0m</span>
    </div>
    <div class="hud-item hud-center">
      <span class="hud-icon">⭐</span>
      <span class="hud-value" id="hud-score">0</span>
    </div>
    <div class="hud-item">
      <span class="hud-icon">🪙</span>
      <span class="hud-value" id="hud-coins">0</span>
    </div>
    <button class="hud-pause-btn" onclick="togglePause()">⏸</button>
  </div>

  <!-- Multiplier indicator (shows during race) -->
  <div class="hud-multiplier" id="hud-multiplier">
    ×1.75 STYLE
  </div>

  <!-- Speed bar (bottom right) -->
  <div class="hud-speed" id="hud-speed-bar">
    <div class="speed-fill" id="speed-fill"></div>
    <span class="speed-label">SPD</span>
  </div>
</div>
```

### CSS

```css
.hud-bar {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 12px 16px;
  padding-top: max(12px, env(safe-area-inset-top));
  background: linear-gradient(180deg, rgba(0,0,0,0.5) 0%, transparent 100%);
  pointer-events: none;
}

.hud-item {
  display: flex;
  align-items: center;
  gap: 6px;
}

.hud-icon {
  font-size: 18px;
}

.hud-value {
  font-family: var(--font-mono);
  font-size: 20px;
  font-weight: bold;
  color: white;
  text-shadow: 2px 2px 0 rgba(0, 0, 0, 0.6);
  min-width: 60px;
}

.hud-center .hud-value {
  font-size: 24px;
  color: var(--yellow);
  min-width: 80px;
  text-align: center;
}

.hud-pause-btn {
  pointer-events: auto;
  font-size: 22px;
  background: rgba(255, 255, 255, 0.15);
  border: none;
  border-radius: 50%;
  width: 44px;
  height: 44px;
  cursor: pointer;
  color: white;
  backdrop-filter: blur(4px);
  -webkit-tap-highlight-color: transparent;
}

.hud-multiplier {
  position: absolute;
  top: 56px;
  left: 50%;
  transform: translateX(-50%);
  font-family: var(--font-display);
  font-size: 14px;
  color: var(--purple);
  text-shadow: 1px 1px 0 rgba(0, 0, 0, 0.5);
  opacity: 0.8;
}

.hud-speed {
  position: absolute;
  bottom: 20px;
  right: 16px;
  width: 100px;
  height: 12px;
  background: rgba(0, 0, 0, 0.4);
  border-radius: 6px;
  overflow: hidden;
}

.speed-fill {
  height: 100%;
  background: linear-gradient(90deg, var(--green), var(--yellow), var(--red));
  border-radius: 6px;
  transition: width 0.3s ease-out;
  width: 0%;
}

.speed-label {
  position: absolute;
  top: -18px;
  left: 0;
  font-family: var(--font-body);
  font-size: 11px;
  font-weight: 800;
  color: rgba(255, 255, 255, 0.6);
  letter-spacing: 2px;
}
```

## HUD Components

### Distance Counter

Updates every frame. Use whole meters only (no decimals):

```javascript
function updateHUDDistance(meters) {
  const el = document.getElementById('hud-distance');
  el.textContent = Math.floor(meters).toLocaleString() + 'm';
}
```

### Score Counter

Score updates rapidly. To prevent visual flicker, update at most 10× per
second, with a smooth CSS transition on the number:

```javascript
let displayedScore = 0;
let lastScoreUpdate = 0;

function updateHUDScore(actualScore, now) {
  if (now - lastScoreUpdate < 100) return; // 10 updates/sec max
  lastScoreUpdate = now;

  const el = document.getElementById('hud-score');
  displayedScore = Math.floor(actualScore);
  el.textContent = displayedScore.toLocaleString();
}
```

### Coin Counter

Coins update on collection. Add a brief "bump" animation:

```javascript
function updateHUDCoins(count) {
  const el = document.getElementById('hud-coins');
  el.textContent = count;

  // Bump animation
  el.style.transform = 'scale(1.4)';
  el.style.color = 'var(--yellow)';
  setTimeout(() => {
    el.style.transform = 'scale(1)';
    el.style.color = 'white';
  }, 200);
}
```

```css
.hud-value {
  transition: transform 0.2s cubic-bezier(0.34, 1.56, 0.64, 1), color 0.3s;
}
```

### Speed Bar

Maps current scrollSpeed to a 0–100% fill:

```javascript
function updateHUDSpeed(currentSpeed, maxSpeed) {
  const pct = Math.min((currentSpeed / maxSpeed) * 100, 100);
  document.getElementById('speed-fill').style.width = pct + '%';
}
```

---

## Floating Score Text

When the player collects an item or gets a near-miss, a text popup appears
at the collection point, floats upward, and fades out.

### System

```javascript
class FloatingTextSystem {
  constructor(camera, container) {
    this.camera = camera;
    this.container = container; // #effects-layer
    this.active = [];
  }

  spawn(text, worldPosition, color = '#FFD700') {
    const el = document.createElement('div');
    el.className = 'float-text';
    el.textContent = text;
    el.style.color = color;
    this.container.appendChild(el);

    // Project 3D → screen position
    const screenPos = this.projectToScreen(worldPosition);
    el.style.left = screenPos.x + 'px';
    el.style.top = screenPos.y + 'px';

    const entry = {
      el,
      startTime: performance.now(),
      startY: screenPos.y,
      duration: 1200,
    };
    this.active.push(entry);
  }

  projectToScreen(worldPos) {
    const v = worldPos.clone().project(this.camera);
    return {
      x: (v.x + 1) / 2 * window.innerWidth,
      y: (-v.y + 1) / 2 * window.innerHeight,
    };
  }

  update(now) {
    this.active = this.active.filter(entry => {
      const elapsed = now - entry.startTime;
      const t = elapsed / entry.duration;

      if (t >= 1) {
        entry.el.remove();
        return false;
      }

      // Float up and fade
      const yOffset = t * 80; // pixels to float up
      const opacity = 1 - Math.pow(t, 2);
      const scale = 1 + t * 0.3;

      entry.el.style.transform = `translate(-50%, -50%) translateY(-${yOffset}px) scale(${scale})`;
      entry.el.style.opacity = opacity;
      return true;
    });
  }
}
```

### CSS

```css
.float-text {
  position: absolute;
  font-family: var(--font-display);
  font-size: 26px;
  font-weight: bold;
  text-shadow: 3px 3px 0 rgba(0, 0, 0, 0.6);
  pointer-events: none;
  white-space: nowrap;
  transform: translate(-50%, -50%);
  z-index: 25;
}
```

### Usage

```javascript
const floatingText = new FloatingTextSystem(camera, document.getElementById('effects-layer'));

// On coin collection:
floatingText.spawn('+100', coin.position.clone(), '#FFD700');

// On near miss:
floatingText.spawn('CLOSE!', obstacle.position.clone(), '#FF44AA');

// On boost:
floatingText.spawn('BOOST!', player.position.clone(), '#00DDEE');

// On star:
floatingText.spawn('+500', star.position.clone(), '#FF8800');

// In the game loop:
floatingText.update(performance.now());
```

---

## Speed Lines Effect

At higher speeds, radial speed lines appear at the screen edges to convey
velocity. Implemented as a CSS overlay, not 3D geometry.

### HTML

```html
<div id="speed-lines" class="speed-lines-overlay"></div>
```

### CSS

```css
.speed-lines-overlay {
  position: absolute;
  inset: 0;
  pointer-events: none;
  z-index: 5;
  opacity: 0;
  transition: opacity 0.5s;
  background: radial-gradient(
    ellipse at center,
    transparent 40%,
    rgba(255, 255, 255, 0.03) 60%,
    rgba(255, 255, 255, 0.08) 80%,
    rgba(255, 255, 255, 0.15) 100%
  );
  /* Stretch vertically to suggest forward motion */
  transform: scaleY(2.5);
}
```

### Logic

```javascript
function updateSpeedLines(currentSpeed, maxSpeed) {
  const threshold = maxSpeed * 0.6; // Only show above 60% speed
  const intensity = Math.max(0, (currentSpeed - threshold) / (maxSpeed - threshold));
  document.getElementById('speed-lines').style.opacity = intensity * 0.5;
}
```

---

## Boost Visual Effect

When a speed boost is active, the screen gets a brief color tint and the
edges glow with energy.

### HTML

```html
<div id="boost-overlay" class="boost-overlay"></div>
```

### CSS

```css
.boost-overlay {
  position: absolute;
  inset: 0;
  pointer-events: none;
  z-index: 6;
  opacity: 0;
  transition: opacity 0.3s;
  background: radial-gradient(
    ellipse at center,
    transparent 50%,
    rgba(0, 220, 255, 0.1) 70%,
    rgba(0, 220, 255, 0.25) 100%
  );
  box-shadow: inset 0 0 60px rgba(0, 220, 255, 0.3);
}

.boost-overlay.active {
  opacity: 1;
  animation: boostPulse 0.5s ease-in-out infinite alternate;
}

@keyframes boostPulse {
  from { box-shadow: inset 0 0 40px rgba(0, 220, 255, 0.2); }
  to { box-shadow: inset 0 0 80px rgba(0, 220, 255, 0.4); }
}
```

### Logic

```javascript
function setBoostEffect(active) {
  const el = document.getElementById('boost-overlay');
  if (active) {
    el.classList.add('active');
    el.style.opacity = '1';
  } else {
    el.classList.remove('active');
    el.style.opacity = '0';
  }
}
```

---

## Milestone Celebrations

Every 500m, show a brief celebration banner:

```javascript
const MILESTONE_INTERVAL = 500; // meters
let lastMilestone = 0;

function checkMilestones(distance) {
  const milestone = Math.floor(distance / MILESTONE_INTERVAL) * MILESTONE_INTERVAL;
  if (milestone > lastMilestone && milestone > 0) {
    lastMilestone = milestone;
    showMilestoneBanner(milestone);
  }
}
```

### Banner

```javascript
function showMilestoneBanner(meters) {
  const banner = document.createElement('div');
  banner.className = 'milestone-banner';
  banner.innerHTML = `<span class="milestone-value">${meters}m</span><span class="milestone-label">DOWNHILL!</span>`;
  document.getElementById('effects-layer').appendChild(banner);

  // Auto-remove after animation
  setTimeout(() => banner.remove(), 2000);
}
```

```css
.milestone-banner {
  position: absolute;
  top: 30%;
  left: 50%;
  transform: translateX(-50%);
  display: flex;
  flex-direction: column;
  align-items: center;
  animation: milestonePop 2s ease-out forwards;
  pointer-events: none;
}

.milestone-value {
  font-family: var(--font-display);
  font-size: 56px;
  color: var(--yellow);
  text-shadow: var(--text-shadow-heavy);
}

.milestone-label {
  font-family: var(--font-body);
  font-size: 18px;
  color: white;
  text-shadow: var(--text-shadow);
  letter-spacing: 4px;
}

@keyframes milestonePop {
  0% { transform: translateX(-50%) scale(0.3); opacity: 0; }
  15% { transform: translateX(-50%) scale(1.1); opacity: 1; }
  25% { transform: translateX(-50%) scale(1); }
  75% { opacity: 1; }
  100% { transform: translateX(-50%) translateY(-30px); opacity: 0; }
}
```

---

## Screen Shake

Used on crash (game over). Shakes the entire game container:

```javascript
function shakeScreen(intensity = 10, duration = 500) {
  const container = document.getElementById('game-container');
  const start = performance.now();

  function tick(now) {
    const elapsed = now - start;
    const t = elapsed / duration;

    if (t >= 1) {
      container.style.transform = '';
      return;
    }

    const decay = 1 - t;
    const dx = (Math.random() - 0.5) * intensity * decay;
    const dy = (Math.random() - 0.5) * intensity * decay;
    container.style.transform = `translate(${dx}px, ${dy}px)`;
    requestAnimationFrame(tick);
  }
  requestAnimationFrame(tick);
}
```

This works in addition to the Three.js camera shake from the racing engine —
the CSS shake affects the entire viewport including the HUD, making it feel
more impactful.

---

## Coin Collection Flash

A brief golden flash on the screen edge when collecting a coin:

```css
.coin-flash {
  position: absolute;
  inset: 0;
  pointer-events: none;
  z-index: 7;
  background: radial-gradient(
    circle at 50% 50%,
    rgba(255, 215, 0, 0.3) 0%,
    transparent 70%
  );
  animation: coinFlash 0.3s ease-out forwards;
}

@keyframes coinFlash {
  0% { opacity: 1; }
  100% { opacity: 0; }
}
```

```javascript
function flashCoinCollect() {
  const flash = document.createElement('div');
  flash.className = 'coin-flash';
  document.getElementById('effects-layer').appendChild(flash);
  setTimeout(() => flash.remove(), 300);
}
```
