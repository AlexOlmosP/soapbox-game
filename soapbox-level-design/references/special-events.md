# Special Events Reference

Scripted or semi-scripted sequences that break up the normal obstacle flow and give the race memorable moments.

## Event System Architecture

Special events temporarily take over obstacle spawning. During an event the normal spawn system pauses and the event controls the track.

```javascript
class EventManager {
  constructor(spawner) {
    this.spawner = spawner;
    this.activeEvent = null;
    this.lastEventEnd = 0;
    this.eventsTriggered = new Set();
  }

  update(distance, difficulty) {
    if (!this.activeEvent) {
      const event = this.checkTriggers(distance, difficulty);
      if (event) {
        this.activeEvent = event;
        this.activeEvent.start(distance);
      }
    }
    if (this.activeEvent) {
      const finished = this.activeEvent.update(distance);
      if (finished) { this.lastEventEnd = distance; this.activeEvent = null; }
      return true; // Skip normal spawning
    }
    return false;
  }

  checkTriggers(distance, difficulty) {
    if (distance - this.lastEventEnd < 200) return null; // Min 200m gap
    if (difficulty.wavePhase === 'peak') return null;     // Don't interrupt peaks
    for (const Ev of EVENT_TYPES) {
      if (Ev.shouldTrigger(distance, difficulty)) return new Ev(this.spawner);
    }
    return null;
  }
}

class SpecialEvent {
  constructor(spawner) { this.spawner = spawner; this.startDistance = 0; this.rows = []; }
  start(distance) { this.startDistance = distance; this.buildRows(); }
  update(currentDistance) {
    const elapsed = currentDistance - this.startDistance;
    while (this.rows.length > 0 && elapsed >= this.rows[0].distance) {
      this.spawner.spawnCustomRow(this.rows.shift());
    }
    return this.rows.length === 0;
  }
  buildRows() { /* Override */ }
  static shouldTrigger() { return false; }
}
```

---

## 1. Ramp Launch Sequence

A solo ramp with a coin arc above it. Hitting the ramp grants a jump with invulnerability and coins along the parabolic arc.

```javascript
class RampLaunchEvent extends SpecialEvent {
  buildRows() {
    const rampLane = Math.floor(Math.random() * 3);
    const others = [0, 1, 2].filter(l => l !== rampLane);

    // Warning cone in a non-ramp lane
    this.rows.push({ distance: 0,
      obstacles: [{ lane: others[0], type: 'cone' }], coins: [] });

    // The ramp + lead-in coins
    this.rows.push({ distance: 8,
      obstacles: [{ lane: rampLane, type: 'ramp' }],
      coins: [{ lane: rampLane, z: -3, y: 0.8 }, { lane: rampLane, z: -1, y: 0.8 }] });

    // Air coins along the jump arc
    this.rows.push({ distance: 12, obstacles: [],
      coins: [
        { lane: rampLane, z: 0, y: 1.8 }, { lane: rampLane, z: 2, y: 2.2 },
        { lane: rampLane, z: 4, y: 2.0 }, { lane: rampLane, z: 6, y: 1.5 },
      ] });

    // Easy landing row
    this.rows.push({ distance: 20,
      obstacles: [{ lane: others[0], type: 'barrel' }], coins: [] });
  }

  static shouldTrigger(distance) {
    if (distance < 550) return false;
    if (distance > 600 && distance < 650) return Math.random() < 0.5;
    return distance > 1000 && Math.random() < 0.008;
  }
}
```

---

## 2. Crowd Cheer Zone

No obstacles for 4 rows. Dense coins in all lanes. Extra crowd on both sides. Temporary 2x score multiplier. HUD shows "CHEER ZONE!" banner.

```javascript
class CrowdCheerEvent extends SpecialEvent {
  buildRows() {
    for (let i = 0; i < 4; i++) {
      this.rows.push({
        distance: i * 6,
        obstacles: [],
        coins: [0, 1, 2].map(lane => ({ lane, z: 0, y: 0.8 })),
        specials: i === 2 ? [{ lane: 1, z: 0, y: 1.0, type: 'star' }] : [],
        effects: {
          banner: i === 0 ? 'CHEER ZONE!' : null,
          scoreMultiplier: 2.0,
          spawnCrowd: true,
        },
      });
    }
  }

  static shouldTrigger(distance, difficulty) {
    if (distance < 800 || difficulty.wavePhase !== 'rest') return false;
    return Math.random() < 0.02;
  }
}
```

---

## 3. Coin Bonus Section

Dense coins forming a collectible pattern. No obstacles. Appears during rest phases.

```javascript
const COIN_PATTERNS = {
  arrow: [
    { lane: 1, row: 0 },
    { lane: 0, row: 1 }, { lane: 1, row: 1 }, { lane: 2, row: 1 },
    { lane: 1, row: 2 }, { lane: 1, row: 3 }, { lane: 1, row: 4 },
  ],
  zigzag: [
    { lane: 0, row: 0 }, { lane: 0, row: 1 },
    { lane: 1, row: 2 }, { lane: 1, row: 3 },
    { lane: 2, row: 4 }, { lane: 2, row: 5 },
  ],
  diamond: [
    { lane: 1, row: 0 },
    { lane: 0, row: 1 }, { lane: 2, row: 1 },
    { lane: 1, row: 2 },
  ],
  wave: [
    { lane: 0, row: 0 }, { lane: 1, row: 0 }, { lane: 2, row: 0 },
    { lane: 0, row: 2 }, { lane: 1, row: 2 }, { lane: 2, row: 2 },
    { lane: 0, row: 4 }, { lane: 1, row: 4 }, { lane: 2, row: 4 },
  ],
};

class CoinBonusEvent extends SpecialEvent {
  buildRows() {
    const names = Object.keys(COIN_PATTERNS);
    const pattern = COIN_PATTERNS[names[Math.floor(Math.random() * names.length)]];
    const rowMap = new Map();
    for (const c of pattern) {
      if (!rowMap.has(c.row)) rowMap.set(c.row, []);
      rowMap.get(c.row).push(c.lane);
    }
    for (const [row, lanes] of rowMap) {
      this.rows.push({
        distance: row * 4,
        obstacles: [],
        coins: lanes.map(lane => ({ lane, z: 0, y: 0.8 })),
      });
    }
  }

  static shouldTrigger(distance, difficulty) {
    if (distance < 400 || difficulty.wavePhase !== 'rest') return false;
    return Math.random() < 0.025;
  }
}
```

---

## 4. Narrow Gate Challenge

Two wide obstacles block two lanes leaving only a narrow gap. Preceded by hint cones. Awards +300 style bonus for threading through.

```javascript
class NarrowGateEvent extends SpecialEvent {
  buildRows() {
    const clearLane = Math.floor(Math.random() * 3);
    const blocked = [0, 1, 2].filter(l => l !== clearLane);

    // Hint cones guiding toward the clear lane
    this.rows.push({ distance: 0,
      obstacles: [{ lane: blocked[0], type: 'cone' }],
      coins: [{ lane: clearLane, z: 0, y: 0.8 }] });
    this.rows.push({ distance: 6,
      obstacles: [{ lane: blocked[1], type: 'cone' }],
      coins: [{ lane: clearLane, z: 0, y: 0.8 }] });

    // THE GATE
    this.rows.push({ distance: 12,
      obstacles: [
        { lane: blocked[0], type: 'crowd_barrier' },
        { lane: blocked[1], type: 'crowd_barrier' },
      ],
      coins: [
        { lane: clearLane, z: -1, y: 0.8 },
        { lane: clearLane, z: 0, y: 1.0 },
        { lane: clearLane, z: 1, y: 0.8 },
      ],
      effects: { onPass: 'gateBonus' } });

    // Reward star
    this.rows.push({ distance: 16, obstacles: [],
      specials: [{ lane: clearLane, z: 0, y: 1.0, type: 'star' }] });
  }

  static shouldTrigger(distance, difficulty) {
    if (distance < 1200 || difficulty.wavePhase === 'rest') return false;
    return Math.random() < 0.012;
  }
}
```

Gate pass detection:
```javascript
function checkGateBonus(gateRow, playerZ) {
  if (gateRow.effects?.onPass === 'gateBonus' && !gateRow.bonusAwarded && playerZ >= gateRow.z) {
    gateRow.bonusAwarded = true;
    score += 300 * styleMultiplier;
    floatingText.spawn('+300 STYLE!', playerPosition, '#AA44FF');
    showMilestoneBanner('THREAD THE NEEDLE!');
  }
}
```

---

## 5. Speed Boost Corridor

A clean corridor with ground arrows and a boost power-up. No obstacles.

```javascript
class SpeedBoostEvent extends SpecialEvent {
  buildRows() {
    for (let i = 0; i < 3; i++) {
      this.rows.push({ distance: i * 5, obstacles: [],
        coins: [{ lane: 1, z: 0, y: 0.8 }],
        groundDecals: [{ type: 'arrow', lane: 1 }] });
    }
    this.rows.push({ distance: 10, obstacles: [],
      specials: [{ lane: 1, z: 0, y: 1.0, type: 'boost' }] });
  }

  static shouldTrigger(distance) {
    return distance > 700 && Math.random() < 0.01;
  }
}
```

---

## 6. Multi-Ramp Airshow

All three lanes have ramps — the player MUST jump. Extended air time with dense coin arc.

```javascript
class MultiRampEvent extends SpecialEvent {
  buildRows() {
    this.rows.push({ distance: 0,
      obstacles: [
        { lane: 0, type: 'ramp' }, { lane: 1, type: 'ramp' }, { lane: 2, type: 'ramp' },
      ] });

    const heights = [1.5, 2.5, 2.8, 2.3, 1.5];
    heights.forEach((y, i) => {
      this.rows.push({ distance: 3 + i * 3, obstacles: [],
        coins: [0, 1, 2].map(lane => ({ lane, z: 0, y })) });
    });
  }

  static shouldTrigger(distance, difficulty) {
    if (distance < 1500 || difficulty.wavePhase !== 'rest') return false;
    return Math.random() < 0.008;
  }
}
```

---

## Event Registration & Scheduling

```javascript
const EVENT_TYPES = [
  RampLaunchEvent, CrowdCheerEvent, CoinBonusEvent,
  NarrowGateEvent, SpeedBoostEvent, MultiRampEvent,
];
```

### Scheduling Constraints

| Constraint                      | Value  | Reason                            |
|--------------------------------|--------|-----------------------------------|
| Min gap between events         | 200m   | Prevent event fatigue             |
| Max events per 1000m           | 3      | Keep events special               |
| No events before               | 400m   | Let player learn basics           |
| No narrow gates before         | 1200m  | Requires lane mastery             |
| No multi-ramps before          | 1500m  | Advanced maneuver                 |
| Cheer/coin in rest phase only  | Always | They ARE the reward               |
| Gates/ramps in any phase       | Always | They are challenges               |

### Event Frequency by Distance

| Distance   | Events per 1000m | Types Available                   |
|-----------|------------------|-----------------------------------|
| 0-400m    | 0                | None                              |
| 400-800m  | ~1               | Ramp launch, coin bonus           |
| 800-1200m | ~2               | + Crowd cheer, speed boost        |
| 1200-2000m| ~2.5             | + Narrow gate                     |
| 2000m+    | ~3               | + Multi-ramp airshow, all events  |
