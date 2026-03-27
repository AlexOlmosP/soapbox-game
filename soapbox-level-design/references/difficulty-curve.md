# Difficulty Curve Reference

The math and logic behind how the game gets harder, the wave/rest cycle, spawn timing tables, and speed progression.

## Difficulty Score

A single `0.0 -> 1.0` value drives all difficulty parameters. It trends upward with distance but oscillates locally due to the wave system.

```javascript
class DifficultyManager {
  constructor() {
    this.baseLevel = 0;        // Trends up with distance
    this.waveOffset = 0;       // Oscillates +/-0.15 around base
    this.effective = 0;        // baseLevel + waveOffset, clamped 0-1
    this.wavePhase = 'build';  // 'build' | 'peak' | 'rest'
    this.waveTimer = 0;        // Rows since wave phase started
    this.waveNumber = 0;
    this.phaseDurations = {
      build: { min: 4, max: 6 },
      peak:  { min: 2, max: 3 },
      rest:  { min: 2, max: 4 },
    };
  }

  update(distance) {
    // Base difficulty: 0 at 0m, 1.0 at 2000m, stays at 1.0 after
    this.baseLevel = Math.min(distance / 2000, 1.0);

    // Wave offset depends on current phase
    const targetOffset = { build: 0.05, peak: 0.15, rest: -0.15 }[this.wavePhase];
    this.waveOffset += (targetOffset - this.waveOffset) * 0.15;

    // Effective difficulty (clamped)
    this.effective = Math.max(0, Math.min(1, this.baseLevel + this.waveOffset));
  }

  onRowSpawned() {
    this.waveTimer++;
    if (this.waveTimer >= this.getCurrentPhaseDuration()) {
      this.advancePhase();
    }
  }

  getCurrentPhaseDuration() {
    const range = this.phaseDurations[this.wavePhase];
    const squeeze = 1 - this.baseLevel * 0.3; // At max, durations are 70% of base
    const base = range.min + Math.random() * (range.max - range.min);
    return Math.round(base * squeeze);
  }

  advancePhase() {
    this.waveTimer = 0;
    const transitions = { build: 'peak', peak: 'rest', rest: 'build' };
    this.wavePhase = transitions[this.wavePhase];
    if (this.wavePhase === 'build') this.waveNumber++;
  }

  getRowGap() { return 12 - this.effective * 7; } // 12m at 0, 5m at 1

  getPatternTier() {
    if (this.effective < 0.25) return 'easy';
    if (this.effective < 0.55) return 'medium';
    if (this.effective < 0.80) return 'hard';
    return 'extreme';
  }

  isRestPhase() { return this.wavePhase === 'rest'; }
}
```

---

## Wave Cycle System

Each wave takes roughly 8-13 obstacle rows:

```
Row:  1   2   3   4   5   6   7   8   9  10  11
      |-- BUILD ------||- PEAK -||--- REST ---|
Diff: .3  .35  .4  .45  .55  .6  .35  .25  .2
```

### What Changes Per Phase

| Parameter          | Build              | Peak               | Rest               |
|-------------------|--------------------|--------------------|--------------------|
| Pattern types     | Singles + doubles   | Doubles + sequences| Singles mostly     |
| Row gap           | Tightening         | Tightest           | Widest             |
| Obstacle types    | Mix                | Harder types       | Easier types       |
| Coin density      | Normal             | Low                | High               |
| Special events    | None               | None               | Can trigger        |

### Rest Valley Content

Rest valleys are reward zones, not dead zones:

```javascript
function spawnRestContent(spawnZ) {
  if (Math.random() < 0.7) {
    // Coin trail in a random lane
    const lane = Math.floor(Math.random() * 3);
    spawnCoinTrail(lane, spawnZ, 4 + Math.floor(Math.random() * 3));
  } else if (Math.random() < 0.67) {
    // Star item
    const lane = Math.floor(Math.random() * 3);
    spawnSpecialItem('star', lane, spawnZ);
  }
  // 10% chance: completely empty (breathing room)
}
```

---

## Spawn Timing Tables

### Row Gap by Difficulty

| Effective Difficulty | Row Gap (m) | React Time at Max Speed | Feeling     |
|---------------------|-------------|------------------------|-------------|
| 0.0                 | 12.0        | ~1.5s                  | Relaxed     |
| 0.2                 | 10.6        | ~1.3s                  | Comfortable |
| 0.4                 | 9.2         | ~1.1s                  | Engaged     |
| 0.6                 | 7.8         | ~0.95s                 | Tense       |
| 0.8                 | 6.4         | ~0.8s                  | Intense     |
| 1.0                 | 5.0         | ~0.6s                  | Survival    |

### Minimum Visibility Time

The player must see an obstacle for at least 1.5 seconds:

```javascript
const MIN_VISIBILITY_TIME = 1.5;

function getSpawnDistance(scrollSpeed) {
  return Math.max(scrollSpeed * MIN_VISIBILITY_TIME + 10, 40);
}
```

### Sequence Internal Gap

Rows within a multi-row sequence are tighter than standalone rows:

```javascript
function getSequenceInternalGap(baseGap) {
  return baseGap * (0.6 + Math.random() * 0.2); // 60-80% of normal
}
```

---

## Speed Progression

Speed ramps independently from difficulty:

```javascript
const SPEED_TABLE = {
  0:    5.0,   // Gentle start
  200:  6.5,
  500:  8.0,
  800:  9.5,
  1200: 11.0,
  1800: 12.0,
  2500: 13.0,  // Absolute max
};

function getTargetSpeed(distance, vehicleSpeedStat) {
  const keys = Object.keys(SPEED_TABLE).map(Number).sort((a, b) => a - b);
  let lower = keys[0], upper = keys[keys.length - 1];
  for (let i = 0; i < keys.length - 1; i++) {
    if (distance >= keys[i] && distance <= keys[i + 1]) {
      lower = keys[i]; upper = keys[i + 1]; break;
    }
  }
  const t = upper === lower ? 1 : (distance - lower) / (upper - lower);
  const baseSpeed = SPEED_TABLE[lower] + (SPEED_TABLE[upper] - SPEED_TABLE[lower]) * t;
  // Vehicle stat modifier: speed 1-5 maps to 0.85-1.15 multiplier
  return baseSpeed * (0.85 + (vehicleSpeedStat - 1) * 0.075);
}
```

During rest valleys, ease the acceleration:

```javascript
function updateSpeed(dt, difficultyManager, targetSpeed) {
  const accelRate = difficultyManager.isRestPhase() ? 0.05 : 0.2;
  scrollSpeed = Math.min(scrollSpeed + accelRate * dt, targetSpeed);
}
```

---

## Pattern Selection by Difficulty

```javascript
const PATTERN_WEIGHTS = {
  easy:    { single: 80, double: 15, sequence: 5 },
  medium:  { single: 35, double: 45, sequence: 20 },
  hard:    { single: 10, double: 40, sequence: 50 },
  extreme: { single: 5,  double: 25, sequence: 70 },
};

function selectPattern(difficultyManager) {
  const tier = difficultyManager.getPatternTier();

  // During rest, force easier patterns
  if (difficultyManager.wavePhase === 'rest') {
    return Math.random() < 0.85 ? pickSinglePattern() : pickDoublePattern();
  }

  // During peak, bias toward harder
  if (difficultyManager.wavePhase === 'peak') {
    const type = pickPatternType(tier);
    if (type === 'single' && Math.random() < 0.4) return pickDoublePattern();
    if (type === 'double' && Math.random() < 0.3) return pickSequencePattern();
  }

  const type = pickPatternType(tier);
  switch (type) {
    case 'single': return pickSinglePattern();
    case 'double': return pickDoublePattern();
    case 'sequence': return pickSequencePattern();
  }
}
```

---

## Adaptive Difficulty (Optional)

A subtle rubber band for casual players. Should be a settings toggle.

```javascript
class AdaptiveDifficulty {
  constructor() {
    this.recentDeaths = [];
    this.recentNearMisses = 0;
    this.modifier = 0; // -0.1 to +0.1
  }

  onDeath(distance) {
    this.recentDeaths.push(distance);
    if (this.recentDeaths.length > 3) this.recentDeaths.shift();
    if (this.recentDeaths.length >= 3) {
      const avg = this.recentDeaths.reduce((a, b) => a + b) / 3;
      if (avg < 400) this.modifier = -0.1; // Ease up
    }
  }

  onRunStart() {
    this.recentNearMisses = 0;
    this.modifier *= 0.8;
  }

  onNearMiss() {
    this.recentNearMisses++;
    if (this.recentNearMisses > 10) {
      this.modifier = Math.min(this.modifier + 0.02, 0.1);
    }
  }

  apply(baseDifficulty) {
    return Math.max(0, Math.min(1, baseDifficulty + this.modifier));
  }
}
```
