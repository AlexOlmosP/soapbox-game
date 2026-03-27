---
name: soapbox-game-ui
description: Build the UI layer, screen flow, and state management for a Red Bull Soapbox Race HTML game. Use this skill whenever the user asks to create, modify, or improve the game menus, title screen, HUD, game over screen, pause menu, transition animations, screen navigation, persistent storage (high scores, saved vehicles, unlocks), settings, or any visual overlay that sits on top of the Three.js game canvas. Also trigger when the user mentions flow between garage/builder and race mode, loading screens, countdown UI, floating score text, or wants to polish the overall user experience and navigation of the game.
---

# Soapbox Game UI & State Management Skill

This skill covers everything the player sees that ISN'T the 3D world itself —
menus, overlays, transitions, HUD elements, and the persistent data layer that
ties the whole game together across sessions. Great 3D rendering means nothing
if the player can't navigate the game or see their score.

## Design Philosophy

The UI follows the **Subway Surfers** aesthetic: bold, chunky, loud, and
joyful. Every screen should feel like a sticker-covered skateboard — bright
colors, thick rounded fonts, playful animations, and zero subtlety. The UI
is an HTML/CSS layer that floats on top of the Three.js canvas using
`position: absolute` and `pointer-events` control.

Read `screen-flows.md` for the full navigation map, screen-by-screen specs,
and transition animations.

Read `hud-and-effects.md` for the in-race HUD layout, floating text system,
countdown sequence, and game over card design.

Read `persistence.md` for the complete `window.storage` data schema, save/load
patterns, high score tracking, vehicle garage, and unlock system.

## Screen Map (Overview)

```
┌──────────┐     ┌──────────────┐     ┌──────────┐
│  TITLE   │────→│   GARAGE     │────→│   RACE   │
│  SCREEN  │     │  (builder)   │     │  (game)  │
└──────────┘     └──────┬───────┘     └────┬─────┘
                        │                   │
                        │              ┌────▼─────┐
                        │              │ GAME OVER│
                        │              └────┬─────┘
                        │                   │
                        ◄───────────────────┘
                       "Garage" button   "Race Again" loops back
```

### Screen List

| Screen         | Purpose                                    | 3D Behind? |
|----------------|--------------------------------------------|------------|
| Title Screen   | Brand splash, "TAP TO START"               | Yes (idle vehicle on turntable) |
| Garage/Builder | Vehicle customizer (handled by builder skill) | Yes (builder scene) |
| Race           | Active gameplay (handled by racing skill)  | Yes (race scene) |
| Game Over      | Score summary, high score, retry/garage    | Yes (frozen race scene) |
| Pause (optional)| Pause menu during race                    | Yes (frozen, dimmed) |
| Settings (optional) | Sound toggle, reset data               | No (simple overlay) |

## UI Architecture

Every screen is an HTML `<div>` overlay that can be shown/hidden. The Three.js
canvas is always present underneath. Screen transitions are CSS animations.

```html
<div id="game-container" style="position:relative; width:100%; height:100vh; overflow:hidden;">
  <!-- Three.js canvas fills the entire container -->
  <canvas id="game-canvas" style="position:absolute; top:0; left:0; width:100%; height:100%;"></canvas>

  <!-- UI Layers (all absolute, all on top of canvas) -->
  <div id="screen-title" class="screen"></div>
  <div id="screen-hud" class="screen"></div>
  <div id="screen-countdown" class="screen"></div>
  <div id="screen-gameover" class="screen"></div>
  <div id="screen-pause" class="screen"></div>
  <div id="screen-settings" class="screen"></div>

  <!-- Floating effects layer (score popups, etc) -->
  <div id="effects-layer" class="screen" style="pointer-events:none;"></div>
</div>
```

```css
.screen {
  position: absolute;
  top: 0; left: 0; right: 0; bottom: 0;
  display: none;           /* Hidden by default */
  z-index: 10;
  pointer-events: none;    /* Let clicks pass through to canvas */
}
.screen.active {
  display: flex;
  flex-direction: column;
}
.screen.interactive {
  pointer-events: auto;    /* Block clicks when menu is showing */
}
```

## Global Screen Manager

A lightweight state machine that manages which screen is visible, handles
transitions, and coordinates with the Three.js scene:

```javascript
class ScreenManager {
  constructor() {
    this.current = null;
    this.screens = {};
    this.onTransition = null; // callback for 3D scene changes
  }

  register(name, element, options = {}) {
    this.screens[name] = {
      el: element,
      interactive: options.interactive !== false,
      onEnter: options.onEnter || (() => {}),
      onExit: options.onExit || (() => {}),
    };
  }

  async show(name, transition = 'fade') {
    const next = this.screens[name];
    if (!next) return;

    // Exit current
    if (this.current) {
      const curr = this.screens[this.current];
      curr.onExit();
      await this.animateOut(curr.el, transition);
      curr.el.classList.remove('active', 'interactive');
    }

    // Enter next
    next.el.classList.add('active');
    if (next.interactive) next.el.classList.add('interactive');
    await this.animateIn(next.el, transition);
    next.onEnter();

    this.current = name;
    if (this.onTransition) this.onTransition(name);
  }

  async animateIn(el, type) {
    if (type === 'fade') {
      el.style.opacity = '0';
      el.style.transition = 'opacity 0.3s ease-out';
      // Force reflow
      el.offsetHeight;
      el.style.opacity = '1';
      await sleep(300);
    } else if (type === 'slide-up') {
      el.style.transform = 'translateY(100%)';
      el.style.transition = 'transform 0.4s cubic-bezier(0.16, 1, 0.3, 1)';
      el.offsetHeight;
      el.style.transform = 'translateY(0)';
      await sleep(400);
    } else if (type === 'pop') {
      el.style.transform = 'scale(0.8)';
      el.style.opacity = '0';
      el.style.transition = 'transform 0.3s cubic-bezier(0.34, 1.56, 0.64, 1), opacity 0.2s';
      el.offsetHeight;
      el.style.transform = 'scale(1)';
      el.style.opacity = '1';
      await sleep(300);
    } else {
      // instant
    }
  }

  async animateOut(el, type) {
    if (type === 'fade') {
      el.style.transition = 'opacity 0.2s ease-in';
      el.style.opacity = '0';
      await sleep(200);
    } else if (type === 'slide-up') {
      el.style.transition = 'transform 0.3s ease-in';
      el.style.transform = 'translateY(-20%)';
      el.style.opacity = '0';
      await sleep(300);
    } else {
      el.style.opacity = '0';
      await sleep(50);
    }
  }
}

function sleep(ms) {
  return new Promise(r => setTimeout(r, ms));
}
```

### Wiring the Screen Manager to Game Flow

```javascript
const sm = new ScreenManager();

sm.register('title', document.getElementById('screen-title'), {
  onEnter: () => { setupTitleScene(); },
  onExit: () => {},
});

sm.register('hud', document.getElementById('screen-hud'), {
  interactive: false, // HUD doesn't block clicks
  onEnter: () => {},
  onExit: () => {},
});

sm.register('countdown', document.getElementById('screen-countdown'), {
  interactive: false,
  onEnter: () => { startCountdownSequence(); },
});

sm.register('gameover', document.getElementById('screen-gameover'), {
  onEnter: () => { populateGameOverStats(); },
});

sm.register('pause', document.getElementById('screen-pause'), {
  onEnter: () => { pauseGameLoop(); },
  onExit: () => { resumeGameLoop(); },
});

// Screen transition callback — tells the 3D engine what to render
sm.onTransition = (screenName) => {
  switch (screenName) {
    case 'title':
      set3DMode('title');    // Idle turntable
      break;
    case 'hud':
    case 'countdown':
      set3DMode('race');     // Race scene
      break;
    case 'gameover':
      set3DMode('frozen');   // Freeze last frame
      break;
  }
};
```

## Typography & Color System

### Font Stack

The Subway Surfers aesthetic uses thick, rounded, bouncy typography. In an
HTML artifact, use Google Fonts or system fallbacks:

```css
@import url('https://fonts.googleapis.com/css2?family=Boogaloo&family=Nunito:wght@800;900&display=swap');

:root {
  /* Primary game font — titles, buttons, big numbers */
  --font-display: 'Boogaloo', 'Arial Black', sans-serif;

  /* Secondary — stats, labels, body text */
  --font-body: 'Nunito', 'Arial Black', sans-serif;

  /* Monospace for score counters (prevents layout shift) */
  --font-mono: 'Courier New', monospace;
}
```

### Color Palette

```css
:root {
  /* Background layers */
  --bg-dark: #1a1a2e;
  --bg-overlay: rgba(0, 0, 0, 0.6);
  --bg-card: rgba(255, 255, 255, 0.12);
  --bg-card-solid: #2a2a4a;

  /* Brand / accent colors */
  --red: #FF3344;
  --orange: #FF8800;
  --yellow: #FFD700;
  --green: #44DD66;
  --blue: #4488FF;
  --purple: #AA44FF;
  --pink: #FF44AA;
  --cyan: #00DDEE;

  /* Text */
  --text-primary: #FFFFFF;
  --text-secondary: rgba(255, 255, 255, 0.7);
  --text-shadow: 3px 3px 0 rgba(0, 0, 0, 0.5);
  --text-shadow-heavy: 4px 4px 0 rgba(0, 0, 0, 0.7);

  /* UI elements */
  --btn-primary: #FF3344;
  --btn-primary-hover: #FF5566;
  --btn-secondary: #4488FF;
  --btn-border: 4px solid rgba(0, 0, 0, 0.3);
  --border-radius: 16px;
  --border-radius-lg: 24px;
}
```

### Button Style

Every button in the game should feel pressable and chunky:

```css
.game-btn {
  font-family: var(--font-display);
  font-size: 24px;
  color: white;
  text-shadow: var(--text-shadow);
  background: var(--btn-primary);
  border: var(--btn-border);
  border-radius: var(--border-radius);
  padding: 14px 36px;
  cursor: pointer;
  transition: transform 0.1s, box-shadow 0.1s;
  box-shadow: 0 6px 0 rgba(0, 0, 0, 0.3);
  text-transform: uppercase;
  letter-spacing: 2px;
  -webkit-tap-highlight-color: transparent;
  user-select: none;
}

.game-btn:hover {
  transform: translateY(-2px);
  box-shadow: 0 8px 0 rgba(0, 0, 0, 0.3);
}

.game-btn:active {
  transform: translateY(3px);
  box-shadow: 0 2px 0 rgba(0, 0, 0, 0.3);
}

.game-btn.secondary {
  background: var(--btn-secondary);
}

.game-btn.large {
  font-size: 32px;
  padding: 18px 48px;
  border-radius: var(--border-radius-lg);
}

/* Pulse animation for CTA buttons */
.game-btn.pulse {
  animation: btnPulse 1.5s ease-in-out infinite;
}

@keyframes btnPulse {
  0%, 100% { transform: scale(1); }
  50% { transform: scale(1.05); }
}
```

### Text Styles

```css
.title-text {
  font-family: var(--font-display);
  font-size: 64px;
  color: var(--yellow);
  text-shadow: var(--text-shadow-heavy);
  text-transform: uppercase;
  text-align: center;
  line-height: 1.1;
}

.subtitle-text {
  font-family: var(--font-body);
  font-size: 20px;
  color: var(--text-secondary);
  text-shadow: var(--text-shadow);
  text-align: center;
}

.stat-label {
  font-family: var(--font-body);
  font-size: 14px;
  color: var(--text-secondary);
  text-transform: uppercase;
  letter-spacing: 3px;
}

.stat-value {
  font-family: var(--font-display);
  font-size: 36px;
  color: var(--text-primary);
  text-shadow: var(--text-shadow);
}

.score-counter {
  font-family: var(--font-mono);
  font-size: 22px;
  color: var(--text-primary);
  text-shadow: var(--text-shadow);
  min-width: 80px;
  text-align: right;
}
```

## Single-Artifact vs Multi-Artifact Architecture

The game can be built as either:

**Option A — Single artifact (recommended for prototype):**
One HTML file contains everything: builder + race + all UI screens. Use
the ScreenManager to swap between builder mode and race mode, toggling
visibility of UI panels and swapping the Three.js scene. Simpler to manage
but the file gets large.

**Option B — Multi-artifact with shared storage:**
The builder is one artifact, the race is another. They communicate through
`window.storage`. The title screen lives in one or both. Better separation
but requires the user to manually switch between artifacts (or use links).

For either option, the UI layer works identically — it's all HTML/CSS on
top of a canvas, controlled by the ScreenManager.

### Single-Artifact Mode Switching

```javascript
let currentMode = 'title'; // 'title' | 'garage' | 'race'

function switchMode(newMode) {
  // 1. Tear down current 3D scene
  clearScene();

  // 2. Build new scene
  switch (newMode) {
    case 'title':
      buildTitleScene();
      sm.show('title', 'fade');
      break;
    case 'garage':
      buildGarageScene();   // From vehicle builder skill
      sm.show('builder', 'slide-up');
      break;
    case 'race':
      buildRaceScene();     // From racing engine skill
      sm.show('countdown', 'fade');
      break;
  }

  currentMode = newMode;
}
```

## Responsive Design

The game must work on both desktop and mobile. Key rules:

```css
/* Base: mobile-first */
.screen {
  padding: 16px;
  padding-top: env(safe-area-inset-top, 16px);
  padding-bottom: env(safe-area-inset-bottom, 16px);
}

/* Scale text and buttons for small screens */
@media (max-width: 480px) {
  .title-text { font-size: 42px; }
  .game-btn { font-size: 20px; padding: 12px 28px; }
  .game-btn.large { font-size: 26px; padding: 14px 36px; }
  .stat-value { font-size: 28px; }
}

/* Landscape on mobile: keep HUD compact */
@media (max-height: 500px) {
  .hud-bar { padding: 6px 12px; }
  .hud-bar .score-counter { font-size: 16px; }
}

/* Desktop: constrain width for readability */
@media (min-width: 768px) {
  .gameover-card {
    max-width: 420px;
    margin: 0 auto;
  }
}
```

### Touch Target Sizes

All interactive elements must be at least 44×44px (Apple HIG guideline).
Part selector buttons in the builder and HUD elements need generous padding.

### Preventing Scroll/Bounce

```css
html, body {
  margin: 0;
  padding: 0;
  overflow: hidden;
  position: fixed;
  width: 100%;
  height: 100%;
  touch-action: none; /* Prevent browser gestures */
}
```

## Implementation Checklist

- [ ] ScreenManager class with show/hide and transitions (fade, slide-up, pop)
- [ ] Title screen with game logo, idle vehicle, "TAP TO START" pulse
- [ ] Countdown overlay (3, 2, 1, GO!) with scaling number animation
- [ ] In-race HUD: distance, score, coins — non-interactive overlay
- [ ] Floating score text system (+100, CLOSE!, BOOST!)
- [ ] Game Over card: score, distance, coins, high score, new record badge
- [ ] "Race Again" and "Garage" buttons on game over
- [ ] Pause button (top-right during race) and pause menu
- [ ] Screen transitions are animated (not just show/hide)
- [ ] All text uses the game font stack (Boogaloo / Nunito)
- [ ] Color palette is consistent across all screens
- [ ] Buttons have press/hover states with depth illusion
- [ ] Responsive: works on 320px–1920px wide screens
- [ ] Touch targets ≥ 44px
- [ ] No page scroll or bounce on mobile
- [ ] Persistent storage for: current vehicle, high score, coins total
- [ ] Loading indicator while 3D assets initialize
- [ ] "New High Score!" animation on game over when record is beaten

## Test Prompts

1. "Build the title screen and menu flow for the soapbox race game"
2. "The game over screen looks too plain, make it more exciting"
3. "Add a pause button to the race HUD"
4. "The transition between garage and race is jarring, smooth it out"
5. "Add a total coins counter that persists across runs"
6. "Make the HUD work better on iPhone with the notch"
