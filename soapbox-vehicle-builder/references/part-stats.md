# Part Stats Reference

All stats range from 1-5. The final vehicle stats are calculated as:
`finalStat = clamp(chassisBase + wheelModifier + decorationBonuses, 1, 5)`

## Chassis Base Stats

| Type     | Speed | Handling | Style | Design Notes                          |
|----------|-------|----------|-------|---------------------------------------|
| bathtub  | 3     | 3        | 3     | Balanced all-rounder                  |
| rocket   | 5     | 2        | 4     | Fast but hard to steer                |
| shoe     | 2     | 4        | 5     | Slow but stylish and maneuverable     |
| box      | 3     | 4        | 1     | Reliable but boring                   |
| banana   | 4     | 2        | 5     | Fast, wild, maximum style points      |
| couch    | 2     | 3        | 4     | Comfy cruiser with flair              |

## Wheel Modifiers

Wheel modifiers are added to the chassis base stats.

| Type     | Speed | Handling | Style | Design Notes                          |
|----------|-------|----------|-------|---------------------------------------|
| chunky   | 0     | 0        | 0     | No modification — default choice      |
| skinny   | +1    | +1       | 0     | Faster and nimbler, looks basic       |
| monster  | -1    | -1       | +1    | Slower, harder to steer, looks wild   |
| wagon    | 0     | +1       | +1    | Charming and handles well             |
| roller   | +1    | 0        | -1    | Quick but looks silly                 |

## Decoration Stat Nudges

Each decoration gives a small ±1 bonus to one stat. Multiple decorations stack, but final stats are always clamped to 1-5.

### Top Slot
| Type      | Stat Effect  | Notes                      |
|-----------|-------------|----------------------------|
| flag      | Style +1    | Classic soapbox spirit      |
| antenna   | Handling +1 | Better "aerodynamic sensing" |
| propeller | Speed +1    | Spin power!                 |
| crown     | Style +1    | Royal flair                 |
| fin       | Speed +1    | Aerodynamic                 |

### Side Slot
| Type      | Stat Effect  | Notes                      |
|-----------|-------------|----------------------------|
| sticker   | Style +1    | Sponsors = style            |
| stripe    | Speed +1    | Racing stripes make it fast |
| flame     | Speed +1    | Fire = speed, obviously     |
| number    | Handling +1 | Pro racers handle better    |
| lightning | Style +1    | Electric energy             |

### Front Slot
| Type      | Stat Effect   | Notes                      |
|-----------|--------------|----------------------------|
| bumper    | Handling +1  | Better crash protection     |
| teeth     | Style +1     | Intimidation factor         |
| eyes      | Style +1     | Personality boost           |
| headlight | Handling +1  | See the road better         |
| horn      | Speed +1     | Bull horns = charging power |

### Back Slot
| Type       | Stat Effect  | Notes                      |
|------------|-------------|----------------------------|
| exhaust    | Speed +1    | Imaginary turbo boost       |
| parachute  | Handling +1 | Drag = control at speed     |
| tail_flag  | Style +1    | Flair from behind           |
| jetpack    | Speed +1    | Rocket propulsion aesthetic |

## Stat Calculation Example

A **shoe** chassis + **wagon** wheels + **crown** (top) + **flame** (side):

| Stat     | Chassis | Wheels | Crown | Flame | Total | Clamped |
|----------|---------|--------|-------|-------|-------|---------|
| Speed    | 2       | 0      | 0     | +1    | 3     | 3       |
| Handling | 4       | +1     | 0     | 0     | 5     | 5       |
| Style    | 5       | +1     | +1    | 0     | 7     | 5       |

Result: Speed 3, Handling 5, Style 5 — a nimble showboat!

## Stat Effects in Race Mode

These stats translate to gameplay as follows:
- **Speed 1-5**: Max velocity ranges from 3.0 to 5.0 units/frame
- **Handling 1-5**: Lane switch duration ranges from 400ms (slow) to 150ms (snappy)
- **Style 1-5**: Score multiplier ranges from 1.0x to 2.0x
