---
name: soapbox-level-design
description: Design obstacle layouts, difficulty curves, special events, and level pacing for the Red Bull Soapbox Race HTML game. Use this skill whenever the user asks to create, modify, or improve the obstacle placement, level difficulty, pacing, special events (ramps, crowd zones, narrow gates, bonus sections), environment variety, how the game gets harder over time, procedural generation rules, wave/pattern design, or anything about making the race feel fun, fair, and replayable. Also trigger when the user says the game is too easy, too hard, too repetitive, too random, or that runs feel the same every time.
---

# Soapbox Obstacle & Level Design Skill

This skill is about **how the race feels** — the rhythm of challenge and relief, the surprise of a new obstacle combination, the thrill of a narrow escape, and the "just one more run" pull that makes endless runners addictive.

The racing engine skill provides the raw spawning mechanics and code. This skill provides the **design layer** on top: what to spawn, when, in what order, and why.

Read `difficulty-curve.md` for the complete difficulty progression system, speed ramps, spawn timing tables, and the wave/rest cycle.

Read `special-events.md` for the design of ramp sequences, crowd cheer zones, narrow gates, bonus coin sections, and boss patterns.

Read `variety-system.md` for the rules that prevent repetition, manage obstacle type rotation, environment zone pacing, and the procedural generation seed system.

## Design Philosophy

### 1. Every Death Must Feel Fair

The player should always be able to say "I could have dodged that." This means:

- At least one lane is ALWAYS clear in every obstacle row (enforced structurally by the pattern system, never left to random chance)
- When two rows spawn close together, the escape path from row 1 must be reachable before row 2 arrives
- Obstacles must be visible for at least 1.5 seconds before reaching the player
- No obstacle should appear from off-screen without warning
- New obstacle types are introduced gently (solo, centered, slow speed) before appearing in hard combinations

### 2. Difficulty Is a Wave, Not a Ramp

A straight line from easy to hard is exhausting. Instead, difficulty oscillates in waves. Each wave consists of:
- **Build phase** (4-6 obstacle rows): difficulty increases, patterns get tighter, doubles and sequences appear
- **Peak** (2-3 rows): the hardest moment in the wave, fast sequences
- **Rest valley** (2-4 rows): easier patterns, more coins, a chance to breathe

### 3. Teach Through Play

| Distance   | What the player learns                              |
|-----------|------------------------------------------------------|
| 0-100m    | Lane switching exists (single obstacles, wide gaps)  |
| 100-300m  | Timing matters (gaps get tighter)                    |
| 300-500m  | Two obstacles at once (doubles)                      |
| 500-800m  | Ramps exist (first ramp is alone, center lane)       |
| 800-1200m | Sequences require planned movement (zigzag, funnel)  |
| 1200m+    | Everything combines — mastery zone                   |

### 4. Reward Risk

- Coins cluster in lanes adjacent to obstacles (dodge toward them)
- Near-miss bonus for passing within 0.3m of an obstacle
- Ramps are obstacles you can choose to hit for a jump + invulnerability
- Narrow gates give massive style bonuses for threading through

### 5. No Two Runs Feel the Same

- Obstacle types rotate through a cooldown system (same type max 2x in a row)
- Pattern sequences are shuffled, not repeated in order
- Scenery zones shift at slightly randomized distances
- Special events appear at semi-random intervals within allowed ranges

## Pacing Structure

```
0m-----200m-----500m-----1000m-----1500m-----2000m-----2500m+
| INTRO | WARMUP |  RAMP   |   FLOW   |  MASTER  |  ENDGAME|
| Learn | Build  | Doubles | Waves of | Sequences| Max     |
| lanes | rhythm | appear  | tension  | dominate | density |
```

**INTRO (0-200m):** Single obstacles only, wide spacing (12m+), slow speed. Only cones and barrels.

**WARMUP (200-500m):** Spacing tightens to 10m. First doubles at ~350m but rare (20%). Speed building.

**RAMP (500-1000m):** Doubles common (50%). First sequences at ~700m. Medium obstacles appear. First ramp at ~600m solo in center lane.

**FLOW (1000-1500m):** Full wave pattern active. All obstacles unlocked. Speed at/near max. Special events begin.

**MASTER (1500-2000m):** Sequences dominate (60%+). Hard obstacles. Tighter gaps (6m). Narrow gates.

**ENDGAME (2000m+):** Maximum density. Row gap minimum (5m). Nearly all spawns are sequences. Survival mode.

## Obstacle Introduction Schedule

| Distance | New Types Unlocked                | Introduction Method                  |
|----------|-----------------------------------|--------------------------------------|
| 0m       | cone, barrel                      | Solo, center lane, max spacing       |
| 200m     | trash_can                         | Solo, any lane                       |
| 400m     | hay_bale, pothole                 | Solo first, then in easy doubles     |
| 600m     | ramp                              | Solo, center lane, with coin trail   |
| 800m     | tire_stack, barrier               | Solo first encounter, then mixed     |
| 1200m    | shopping_cart                     | Solo introduction                    |
| 1500m    | crowd_barrier                     | Solo, then paired with other types   |

```javascript
const OBSTACLE_UNLOCK_DISTANCE = {
  cone: 0, barrel: 0, trash_can: 200,
  hay_bale: 400, pothole: 400, ramp: 600,
  tire_stack: 800, barrier: 800,
  shopping_cart: 1200, crowd_barrier: 1500,
};
```

## Implementation Checklist

- [ ] Wave-based difficulty with build/peak/rest cycle
- [ ] 6-phase pacing structure
- [ ] Obstacle introduction schedule with solo first-encounter
- [ ] At least one lane always clear per row
- [ ] Coins placed in dodge-reward positions
- [ ] Near-miss scoring for close passes
- [ ] Obstacle type cooldown
- [ ] Pattern sequence shuffle
- [ ] Special events at appropriate distances
- [ ] Rest valleys include coin bonus sections
- [ ] Visibility time >= 1.5s for all obstacles
- [ ] Each run feels different from the last

## Test Prompts

1. "The game gets too hard too fast, adjust the difficulty curve"
2. "Every run feels the same, add more variety"
3. "Add ramp sequences where multiple ramps appear in a row"
4. "Create a bonus coin section that appears every 500 meters"
5. "The obstacles bunch up and it feels unfair, fix the spacing"
6. "Make the first 30 seconds easier for new players"
7. "Add crowd cheering sections that give a score bonus"
