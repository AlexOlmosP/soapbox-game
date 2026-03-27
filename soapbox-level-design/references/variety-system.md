# Variety System Reference

Rules and algorithms that prevent repetition and ensure every run feels fresh.

## Obstacle Type Cooldowns

The same obstacle type should not appear more than twice in a row.

```javascript
class ObstacleTypeTracker {
  constructor() {
    this.history = [];
    this.maxRepeat = 2;
    this.historyLength = 8;
  }

  pick(availableTypes) {
    const filtered = availableTypes.filter(type => this.countRecent(type) < this.maxRepeat);
    const pool = filtered.length > 0 ? filtered : availableTypes;

    const weighted = pool.map(type => ({
      type,
      weight: this.getFreshnessWeight(type),
    }));
    const chosen = weightedRandom(weighted);
    this.record(chosen);
    return chosen;
  }

  countRecent(type) {
    let count = 0;
    for (let i = this.history.length - 1; i >= 0; i--) {
      if (this.history[i] === type) count++;
      else break;
    }
    return count;
  }

  getFreshnessWeight(type) {
    const lastSeen = this.history.lastIndexOf(type);
    if (lastSeen === -1) return 3.0;
    return Math.min((this.history.length - lastSeen) / 3, 2.0);
  }

  record(type) {
    this.history.push(type);
    if (this.history.length > this.historyLength) this.history.shift();
  }
}

function weightedRandom(items) {
  const total = items.reduce((sum, i) => sum + i.weight, 0);
  let r = Math.random() * total;
  for (const item of items) {
    r -= item.weight;
    if (r <= 0) return item.type;
  }
  return items[items.length - 1].type;
}
```

### Visual Variety Within Type

Even when the same type appears twice, vary its presentation:

```javascript
function getObstacleVariant(type) {
  const variants = {
    barrel:    [{ rotY: 0 }, { rotY: Math.PI / 4 }, { rotY: Math.PI / 2 }],
    cone:      [{ scale: 0.9 }, { scale: 1.0 }, { scale: 1.1 }],
    hay_bale:  [{ rotY: 0 }, { rotY: Math.PI / 6 }],
    trash_can: [{ rotY: 0 }, { rotY: Math.PI / 3 }, { rotY: -Math.PI / 4 }],
  };
  const options = variants[type];
  if (!options) return {};
  return options[Math.floor(Math.random() * options.length)];
}
```

---

## Pattern Shuffle System

Instead of random selection, shuffle a deck and deal from it. When empty, re-shuffle. This guarantees all patterns appear before any repeats.

```javascript
class PatternDeck {
  constructor() {
    this.decks = {
      single:   { patterns: [...PATTERNS_EASY], remaining: [] },
      double:   { patterns: [...PATTERNS_MEDIUM], remaining: [] },
      sequence: { patterns: [...PATTERNS_SEQUENCE], remaining: [] },
    };
  }

  draw(tier) {
    const deck = this.decks[tier];
    if (deck.remaining.length === 0) {
      deck.remaining = this.shuffle([...deck.patterns]);
      // Anti-repeat: if new top matches last dealt, move it to middle
      if (deck.lastDealt && deck.remaining.length > 1 &&
          JSON.stringify(deck.remaining[deck.remaining.length - 1]) === JSON.stringify(deck.lastDealt)) {
        const top = deck.remaining.pop();
        deck.remaining.splice(Math.floor(deck.remaining.length / 2), 0, top);
      }
    }
    const picked = deck.remaining.pop();
    deck.lastDealt = picked;
    return picked;
  }

  shuffle(array) {
    for (let i = array.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [array[i], array[j]] = [array[j], array[i]];
    }
    return array;
  }
}
```

---

## Lane Bias Prevention

Track lane usage and bias toward underused lanes to prevent clustering.

```javascript
class LaneBalancer {
  constructor() {
    this.laneCounts = [0, 0, 0];
    this.window = 20;
    this.laneHistory = [];
    this.lastClearLane = -1;
  }

  recordLane(lane) {
    this.laneHistory.push(lane);
    this.laneCounts[lane]++;
    if (this.laneHistory.length > this.window) {
      this.laneCounts[this.laneHistory.shift()]--;
    }
  }

  getLeastUsedLane() {
    return this.laneCounts.indexOf(Math.min(...this.laneCounts));
  }

  adjustPattern(pattern) {
    // For doubles, ensure the clear lane rotates
    const clearLane = pattern.indexOf(false);
    if (clearLane >= 0 && clearLane === this.lastClearLane && Math.random() < 0.6) {
      return this.rotatePattern(pattern);
    }
    if (clearLane >= 0) this.lastClearLane = clearLane;
    return pattern;
  }

  rotatePattern(pattern) {
    const shift = Math.random() < 0.5 ? 1 : 2;
    const rotated = pattern.map((_, i) => pattern[(i + shift) % 3]);
    if (rotated.every(v => v)) rotated[Math.floor(Math.random() * 3)] = false;
    return rotated;
  }
}
```

### Player Position Awareness

If the player stays in one lane for 5+ rows, force an obstacle into that lane:

```javascript
function shouldForcePlayerMove(playerLane, rowsSinceMove) {
  if (rowsSinceMove < 5) return false;
  return Math.random() < (rowsSinceMove - 4) * 0.15;
}
```

---

## Environment Zone Randomization

Zones transition at slightly different distances each run (+/-20% length variance):

```javascript
const ZONE_BASE = [
  { zone: 'suburban',   length: 500 },
  { zone: 'urban',      length: 500 },
  { zone: 'park',       length: 500 },
  { zone: 'industrial', length: 500 },
  { zone: 'sunset',     length: 1000 },
];

function generateZoneSchedule(seed) {
  const rng = seededRandom(seed);
  const schedule = [];
  let start = 0;
  for (const base of ZONE_BASE) {
    const variance = base.length * 0.2;
    const length = base.length + (rng() - 0.5) * 2 * variance;
    schedule.push({ zone: base.zone, start, end: start + length });
    start += length;
  }
  // After defined zones, cycle randomly
  const allZones = ZONE_BASE.map(z => z.zone);
  for (let i = 0; i < 10; i++) {
    const zone = allZones[Math.floor(rng() * allZones.length)];
    const length = 300 + rng() * 400;
    schedule.push({ zone, start, end: start + length });
    start += length;
  }
  return schedule;
}
```

### Scenery Weights Per Zone

```javascript
const ZONE_SCENERY_WEIGHTS = {
  suburban:   { scene_tree: 25, scene_bush: 20, scene_fence: 20, scene_building_a: 15, scene_lamppost: 10, scene_crowd_person: 10 },
  urban:      { scene_building_a: 20, scene_building_b: 25, scene_lamppost: 20, scene_crowd_person: 15, scene_tree: 10, scene_fence: 10 },
  park:       { scene_tree: 35, scene_bush: 25, scene_crowd_person: 15, scene_flag_banner: 10, scene_fence: 10, scene_lamppost: 5 },
  industrial: { scene_fence: 25, scene_building_b: 20, scene_lamppost: 15, scene_building_a: 15, scene_bush: 15, scene_tree: 10 },
  sunset:     { scene_tree: 20, scene_bush: 15, scene_crowd_person: 20, scene_flag_banner: 15, scene_building_a: 15, scene_lamppost: 15 },
};
```

---

## Run Seeding

For reproducible runs and future daily challenges:

```javascript
function seededRandom(seed) {
  let s = seed | 0;
  return function() {
    s = s + 0x6D2B79F5 | 0;
    let t = Math.imul(s ^ s >>> 15, 1 | s);
    t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t;
    return ((t ^ t >>> 14) >>> 0) / 4294967296;
  };
}

class SeededRunGenerator {
  constructor(seed = null) {
    this.seed = seed || Date.now();
    this.rng = seededRandom(this.seed);
  }

  random() { return this.rng(); }
  randomInt(min, max) { return min + Math.floor(this.rng() * (max - min + 1)); }
  randomFrom(array) { return array[Math.floor(this.rng() * array.length)]; }

  shuffle(array) {
    const copy = [...array];
    for (let i = copy.length - 1; i > 0; i--) {
      const j = Math.floor(this.rng() * (i + 1));
      [copy[i], copy[j]] = [copy[j], copy[i]];
    }
    return copy;
  }
}

// Daily challenge seed:
function getDailyChallengeSeed() {
  const d = new Date();
  return d.getFullYear() * 10000 + (d.getMonth() + 1) * 100 + d.getDate();
}
```

---

## Freshness Metrics

Diagnostic system to verify variety is working during development:

```javascript
class FreshnessAnalyzer {
  constructor() { this.types = []; this.patterns = []; this.lanes = []; }

  record(type, pattern, clearLane) {
    this.types.push(type); this.patterns.push(pattern); this.lanes.push(clearLane);
  }

  analyze() {
    return {
      maxTypeRepeat: this.longestRepeat(this.types),
      maxLaneRepeat: this.longestRepeat(this.lanes),
      typeDistribution: this.distribution(this.types),
      laneDistribution: this.distribution(this.lanes),
    };
  }

  longestRepeat(seq) {
    let max = 0, run = 1;
    for (let i = 1; i < seq.length; i++) {
      if (seq[i] === seq[i-1]) run++; else { max = Math.max(max, run); run = 1; }
    }
    return Math.max(max, run);
  }

  distribution(seq) {
    const counts = {};
    for (const item of seq) counts[item] = (counts[item] || 0) + 1;
    const total = seq.length;
    const dist = {};
    for (const [k, v] of Object.entries(counts)) dist[k] = (v / total * 100).toFixed(1) + '%';
    return dist;
  }
}
```

### Health Targets

| Metric                     | Healthy            | Unhealthy          |
|---------------------------|--------------------|--------------------|
| Max same-type consecutive | <= 2               | > 3                |
| Max same-lane clear       | <= 4               | > 6                |
| Type distribution spread  | Within 2x each     | One type > 40%     |
| Lane distribution spread  | 28-38% each        | Any lane < 20%     |
| Events per 1000m          | 1-3                | 0 or > 5           |
