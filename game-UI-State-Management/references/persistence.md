# Persistence & Data Management Reference

How to save, load, and manage all game state across sessions using the
`window.storage` API available in Claude artifacts.

## Table of Contents
1. [Storage Schema](#storage-schema)
2. [Vehicle Storage](#vehicle-storage)
3. [Score & Stats Storage](#score--stats-storage)
4. [Settings Storage](#settings-storage)
5. [GameDataManager Class](#gamedatamanager-class)
6. [Error Handling Patterns](#error-handling-patterns)
7. [Data Reset](#data-reset)

---

## Storage Schema

All keys follow the prefix `soapbox:` to namespace the game's data and avoid
collisions with other artifacts.

| Key                        | Type    | Description                           |
|----------------------------|---------|---------------------------------------|
| `soapbox:vehicle`          | JSON    | Current vehicle build data            |
| `soapbox:vehicle-name`     | string  | Vehicle name (for quick display)      |
| `soapbox:highscore`        | string  | Best single-run score (number as str) |
| `soapbox:best-distance`    | string  | Longest single-run distance in meters |
| `soapbox:total-coins`      | string  | Lifetime accumulated coins            |
| `soapbox:total-runs`       | string  | Total number of race runs completed   |
| `soapbox:settings`         | JSON    | Sound, vibration, preferences         |
| `soapbox:garage`           | JSON    | Saved vehicle slots (future feature)  |
| `soapbox:unlocks`          | JSON    | Unlocked parts/cosmetics (future)     |

### Key Design Rules

- All keys use `:` as separator (no slashes, spaces, or quotes)
- Numeric values stored as strings (storage only holds text)
- Complex objects stored as `JSON.stringify()` output
- Each key holds one logical "unit" of data to minimize reads
- Combine related data in single keys to reduce sequential calls

---

## Vehicle Storage

### Saving the Vehicle

Called on every part change in the builder (debounced) and before starting
a race:

```javascript
async function saveVehicle(vehicleData) {
  try {
    await window.storage.set(
      'soapbox:vehicle',
      JSON.stringify(vehicleData)
    );
    await window.storage.set(
      'soapbox:vehicle-name',
      vehicleData.name || 'My Soapbox'
    );
  } catch (e) {
    console.error('Failed to save vehicle:', e);
  }
}
```

### Loading the Vehicle

Called on game init and when entering the builder:

```javascript
const DEFAULT_VEHICLE = {
  version: 2,
  name: 'My Soapbox',
  chassis: { type: 'bathtub', color: '#FF4444' },
  wheels: { type: 'chunky', color: '#333333' },
  decorations: [],
  driver: { helmet: 'classic', helmetColor: '#2244FF', goggles: true },
  stats: { speed: 3, handling: 3, style: 3 },
};

async function loadVehicle() {
  try {
    const result = await window.storage.get('soapbox:vehicle');
    if (result && result.value) {
      const data = JSON.parse(result.value);
      // Validate version compatibility
      if (data.version !== 2) return migrateVehicle(data);
      return data;
    }
  } catch (e) {
    console.warn('No saved vehicle, using defaults');
  }
  return { ...DEFAULT_VEHICLE };
}
```

### Debounced Auto-Save

Don't save on every single color or part click — debounce to avoid
hammering storage:

```javascript
let saveTimer = null;

function scheduleSave(vehicleData) {
  if (saveTimer) clearTimeout(saveTimer);
  saveTimer = setTimeout(() => {
    saveVehicle(vehicleData);
    saveTimer = null;
  }, 500); // Save 500ms after last change
}
```

### Quick Load for Title Screen

The title screen only needs the vehicle name and basic info for display,
not the full model. Use the separate name key:

```javascript
async function getVehicleName() {
  try {
    const result = await window.storage.get('soapbox:vehicle-name');
    return result ? result.value : 'My Soapbox';
  } catch (e) {
    return 'My Soapbox';
  }
}
```

---

## Score & Stats Storage

### High Score

```javascript
async function saveHighScore(score) {
  try {
    const result = await window.storage.get('soapbox:highscore');
    const current = result ? parseInt(result.value) : 0;
    if (score > current) {
      await window.storage.set('soapbox:highscore', score.toString());
      return true; // New record
    }
    return false;
  } catch (e) {
    // If read fails, save anyway
    try {
      await window.storage.set('soapbox:highscore', score.toString());
      return true;
    } catch (e2) {
      return false;
    }
  }
}

async function getHighScore() {
  try {
    const result = await window.storage.get('soapbox:highscore');
    return result ? parseInt(result.value) : 0;
  } catch (e) {
    return 0;
  }
}
```

### Best Distance

```javascript
async function saveBestDistance(meters) {
  try {
    const result = await window.storage.get('soapbox:best-distance');
    const current = result ? parseInt(result.value) : 0;
    if (meters > current) {
      await window.storage.set('soapbox:best-distance', meters.toString());
      return true;
    }
    return false;
  } catch (e) {
    return false;
  }
}
```

### Total Coins (Lifetime)

Coins persist across runs. They're a currency that could be spent on unlocks
in a future version.

```javascript
async function addCoinsToTotal(newCoins) {
  try {
    const result = await window.storage.get('soapbox:total-coins');
    const current = result ? parseInt(result.value) : 0;
    const updated = current + newCoins;
    await window.storage.set('soapbox:total-coins', updated.toString());
    return updated;
  } catch (e) {
    return newCoins;
  }
}

async function getTotalCoins() {
  try {
    const result = await window.storage.get('soapbox:total-coins');
    return result ? parseInt(result.value) : 0;
  } catch (e) {
    return 0;
  }
}
```

### Total Runs

Track how many races the player has completed:

```javascript
async function incrementTotalRuns() {
  try {
    const result = await window.storage.get('soapbox:total-runs');
    const current = result ? parseInt(result.value) : 0;
    await window.storage.set('soapbox:total-runs', (current + 1).toString());
  } catch (e) {}
}
```

### End-of-Run Save (all at once)

After each run, save everything in a batch:

```javascript
async function saveRunResults(score, distance, coins) {
  const isNewHighScore = await saveHighScore(Math.floor(score));
  const isNewBestDist = await saveBestDistance(Math.floor(distance));
  const totalCoins = await addCoinsToTotal(coins);
  await incrementTotalRuns();

  return {
    isNewHighScore,
    isNewBestDist,
    totalCoins,
  };
}
```

---

## Settings Storage

Game preferences (sound, vibration, etc.):

```javascript
const DEFAULT_SETTINGS = {
  sound: true,
  vibration: true,
  showSpeedBar: true,
};

async function saveSettings(settings) {
  try {
    await window.storage.set('soapbox:settings', JSON.stringify(settings));
  } catch (e) {}
}

async function loadSettings() {
  try {
    const result = await window.storage.get('soapbox:settings');
    if (result && result.value) {
      return { ...DEFAULT_SETTINGS, ...JSON.parse(result.value) };
    }
  } catch (e) {}
  return { ...DEFAULT_SETTINGS };
}
```

---

## GameDataManager Class

A single entry point for all persistence operations:

```javascript
class GameDataManager {
  constructor() {
    this.vehicle = null;
    this.settings = null;
    this.highScore = 0;
    this.bestDistance = 0;
    this.totalCoins = 0;
    this.totalRuns = 0;
    this.loaded = false;
  }

  async init() {
    // Load everything in parallel
    const [vehicle, settings, hs, bd, tc, tr] = await Promise.all([
      loadVehicle(),
      loadSettings(),
      getHighScore(),
      getBestDistance(),
      getTotalCoins(),
      getTotalRuns(),
    ]);

    this.vehicle = vehicle;
    this.settings = settings;
    this.highScore = hs;
    this.bestDistance = bd;
    this.totalCoins = tc;
    this.totalRuns = tr;
    this.loaded = true;
  }

  async saveVehicle(data) {
    this.vehicle = data;
    await saveVehicle(data);
  }

  async endRun(score, distance, coins) {
    const results = await saveRunResults(score, distance, coins);
    if (results.isNewHighScore) this.highScore = Math.floor(score);
    if (results.isNewBestDist) this.bestDistance = Math.floor(distance);
    this.totalCoins = results.totalCoins;
    this.totalRuns++;
    return results;
  }

  async updateSettings(partial) {
    this.settings = { ...this.settings, ...partial };
    await saveSettings(this.settings);
  }

  async resetAll() {
    const keys = [
      'soapbox:vehicle', 'soapbox:vehicle-name',
      'soapbox:highscore', 'soapbox:best-distance',
      'soapbox:total-coins', 'soapbox:total-runs',
      'soapbox:settings', 'soapbox:garage', 'soapbox:unlocks',
    ];
    for (const key of keys) {
      try { await window.storage.delete(key); } catch (e) {}
    }

    // Reset in-memory state
    this.vehicle = { ...DEFAULT_VEHICLE };
    this.settings = { ...DEFAULT_SETTINGS };
    this.highScore = 0;
    this.bestDistance = 0;
    this.totalCoins = 0;
    this.totalRuns = 0;
  }
}

// Helper functions referenced above
async function getBestDistance() {
  try {
    const result = await window.storage.get('soapbox:best-distance');
    return result ? parseInt(result.value) : 0;
  } catch (e) { return 0; }
}

async function getTotalRuns() {
  try {
    const result = await window.storage.get('soapbox:total-runs');
    return result ? parseInt(result.value) : 0;
  } catch (e) { return 0; }
}
```

### Usage in Game Init

```javascript
const gameData = new GameDataManager();

async function bootGame() {
  showLoadingScreen();

  await gameData.init();

  // Populate title screen
  document.getElementById('title-highscore').textContent =
    gameData.highScore.toLocaleString();
  document.getElementById('title-coins').textContent =
    gameData.totalCoins.toLocaleString();

  hideLoadingScreen();
  sm.show('title', 'fade');
}
```

---

## Error Handling Patterns

Storage operations can fail. The game must remain playable even if storage
is completely unavailable.

### Graceful Degradation

Every storage function uses try-catch and returns a sensible default:

```javascript
// Pattern: try to read, fall back to default
async function safeGet(key, defaultValue) {
  try {
    const result = await window.storage.get(key);
    return result ? result.value : defaultValue;
  } catch (e) {
    return defaultValue;
  }
}

// Pattern: try to write, silently fail
async function safeSet(key, value) {
  try {
    await window.storage.set(key, value);
    return true;
  } catch (e) {
    return false;
  }
}
```

### No Blocking on Save

Never `await` a save operation in the game loop. Fire-and-forget:

```javascript
// GOOD — non-blocking
function onCoinCollected() {
  coins++;
  updateHUDCoins(coins);
  flashCoinCollect();
  // Save happens in the background, doesn't stall the frame
  addCoinsToTotal(1); // intentionally not awaited
}

// BAD — blocks the frame
async function onCoinCollected() {
  coins++;
  await addCoinsToTotal(1); // stalls rendering!
  updateHUDCoins(coins);
}
```

### Save Only at Checkpoints

During a race, only save at the end (game over). Don't save mid-run.
The builder saves on a debounce timer (every 500ms after last change).

---

## Data Reset

When the player chooses "Reset All Data" from settings:

```javascript
async function confirmReset() {
  // Show confirmation dialog (not a browser confirm — a styled game dialog)
  const confirmed = await showGameConfirm(
    'RESET ALL DATA?',
    'This will delete your vehicle, scores, and coins. This cannot be undone!',
    'RESET',
    'CANCEL'
  );

  if (confirmed) {
    await gameData.resetAll();
    // Reload the title screen with fresh state
    switchMode('title');
  }
}
```

### Styled Confirm Dialog

Don't use `window.confirm()` — it breaks the game aesthetic. Build a
modal dialog in HTML:

```javascript
function showGameConfirm(title, message, confirmText, cancelText) {
  return new Promise((resolve) => {
    const overlay = document.createElement('div');
    overlay.className = 'confirm-overlay';
    overlay.innerHTML = `
      <div class="confirm-card">
        <h3 class="confirm-title">${title}</h3>
        <p class="confirm-message">${message}</p>
        <div class="confirm-buttons">
          <button class="game-btn" id="confirm-yes">${confirmText}</button>
          <button class="game-btn secondary" id="confirm-no">${cancelText}</button>
        </div>
      </div>
    `;
    document.body.appendChild(overlay);

    overlay.querySelector('#confirm-yes').onclick = () => {
      overlay.remove();
      resolve(true);
    };
    overlay.querySelector('#confirm-no').onclick = () => {
      overlay.remove();
      resolve(false);
    };
  });
}
```

```css
.confirm-overlay {
  position: fixed;
  inset: 0;
  display: flex;
  justify-content: center;
  align-items: center;
  background: rgba(0, 0, 0, 0.7);
  z-index: 100;
  animation: fadeIn 0.2s;
}

.confirm-card {
  background: var(--bg-card-solid);
  border-radius: var(--border-radius-lg);
  padding: 28px 32px;
  text-align: center;
  max-width: 340px;
  box-shadow: 0 12px 40px rgba(0, 0, 0, 0.5);
}

.confirm-title {
  font-family: var(--font-display);
  font-size: 28px;
  color: var(--red);
  text-shadow: var(--text-shadow);
  margin-bottom: 12px;
}

.confirm-message {
  font-family: var(--font-body);
  font-size: 15px;
  color: var(--text-secondary);
  margin-bottom: 24px;
  line-height: 1.5;
}

.confirm-buttons {
  display: flex;
  gap: 12px;
  justify-content: center;
}
```

---

## Future: Vehicle Garage (Multiple Saved Vehicles)

For a future version, support saving multiple vehicle builds:

```javascript
// Schema for garage storage:
// soapbox:garage = { slots: [ vehicleData, vehicleData, ... ], active: 0 }

async function saveToGarageSlot(index, vehicleData) {
  const garage = await loadGarage();
  garage.slots[index] = vehicleData;
  await window.storage.set('soapbox:garage', JSON.stringify(garage));
}

async function loadGarage() {
  try {
    const result = await window.storage.get('soapbox:garage');
    if (result) return JSON.parse(result.value);
  } catch (e) {}
  return { slots: [DEFAULT_VEHICLE], active: 0 };
}
```

## Future: Unlock System

Parts gated behind lifetime coin totals:

```javascript
const UNLOCK_COSTS = {
  chassis_banana: 500,
  chassis_couch: 800,
  wheel_monster: 300,
  helmet_viking: 400,
  helmet_astronaut: 600,
};

async function checkUnlocks(totalCoins) {
  const unlocks = await loadUnlocks();
  const newUnlocks = [];

  for (const [part, cost] of Object.entries(UNLOCK_COSTS)) {
    if (!unlocks[part] && totalCoins >= cost) {
      unlocks[part] = true;
      newUnlocks.push(part);
    }
  }

  if (newUnlocks.length > 0) {
    await window.storage.set('soapbox:unlocks', JSON.stringify(unlocks));
  }
  return newUnlocks;
}
```
