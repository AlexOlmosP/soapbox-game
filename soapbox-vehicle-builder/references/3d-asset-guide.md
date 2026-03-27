# Soapbox Race — 3D Asset Generation Guide

Complete asset list for the Red Bull Soapbox Race game. Every item listed here
needs to be generated as a 3D model and exported as `.glb` (preferred) or `.gltf`.

> **Pipeline:** NanoBanana prompt → reference image → Image-to-3D service
> (Tripo / Meshy / Rodin) → GLB export → load in Three.js

---

## Table of Contents

1. [Output Requirements](#output-requirements)
2. [Vehicle Parts — Chassis](#chassis-bodies)
3. [Vehicle Parts — Wheels](#wheels)
4. [Vehicle Parts — Decorations (Top)](#top-decorations)
5. [Vehicle Parts — Decorations (Side)](#side-decorations)
6. [Vehicle Parts — Decorations (Front)](#front-decorations)
7. [Vehicle Parts — Decorations (Back)](#back-decorations)
8. [Driver / Character](#driver)
9. [Obstacles](#obstacles)
10. [Environment / Track](#environment--track)
11. [Collectibles & Power-ups](#collectibles--power-ups)
12. [UI Props](#ui-props)
13. [Prompt Template](#master-prompt-template)
14. [File Naming Convention](#file-naming-convention)

---

## Output Requirements

Every asset must meet these specs so Three.js can load and render them
consistently:

| Property             | Requirement                                    |
|----------------------|------------------------------------------------|
| Format               | `.glb` (binary glTF)                           |
| Polygon count        | 500–3,000 tris per part, 8,000 max for chassis |
| Textures             | Embedded in GLB, max 1024×1024 px              |
| Origin point         | Centered at base (bottom-center of object)     |
| Scale                | 1 unit = 1 meter in real-world scale           |
| Up axis              | Y-up                                           |
| Style                | Subway Surfers / stylized cartoon: bold colors, |
|                      | chunky proportions, slight cel-shading look,   |
|                      | no photorealism                                |
| Background           | Pure white or transparent for clean extraction  |
| Orientation          | Front of vehicle faces -Z (Three.js convention) |

### NanoBanana Image Tips for Clean 3D Conversion

- Always request **white background, centered object, single item only**
- Use **3/4 front view** (slightly above, slightly to the side) — this gives
  the image-to-3D converter the most geometry information
- Say **"low-poly stylized cartoon"** to keep mesh complexity reasonable
- Add **"no text, no watermarks, no floor shadows"** to keep it clean
- For game assets, specify **"game asset, isometric view"** for best results

---

## Chassis Bodies

These are the main vehicle bodies. Each is roughly 1.5m long × 0.8m wide × 0.6m tall.

### 1. `chassis_bathtub.glb`
Classic soapbox: a porcelain bathtub mounted on a wooden frame with visible axle mounts.

**Prompt:**
> Low-poly stylized cartoon bathtub soapbox race car, white porcelain bathtub
> body mounted on a simple wooden plank frame, chunky exaggerated proportions,
> bold colors, Subway Surfers art style, 3/4 front view, white background,
> game asset, no text, no shadows, single object centered

### 2. `chassis_rocket.glb`
Retro rocket ship shape — pointed nose cone, cylindrical body, tail fins.

**Prompt:**
> Low-poly stylized cartoon rocket-shaped soapbox race car, retro 1950s rocket
> ship body with pointed nose cone and small tail fins, bright red and silver,
> chunky toy-like proportions, Subway Surfers art style, 3/4 front view, white
> background, game asset, no text, no shadows, single object centered

### 3. `chassis_shoe.glb`
Giant sneaker/trainer with an open top where the driver sits inside.

**Prompt:**
> Low-poly stylized cartoon giant sneaker soapbox race car, oversized colorful
> running shoe with lace holes, thick rubber sole, open top for driver seating,
> chunky proportions, Subway Surfers art style, 3/4 front view, white
> background, game asset, no text, no shadows, single object centered

### 4. `chassis_box.glb`
Wooden crate/shipping box with visible plank seams and nail heads.

**Prompt:**
> Low-poly stylized cartoon wooden crate soapbox race car, simple wooden box
> with visible plank lines and metal nails, rustic homemade feel, chunky
> proportions, Subway Surfers art style, 3/4 front view, white background,
> game asset, no text, no shadows, single object centered

### 5. `chassis_banana.glb`
A giant banana with the driver sitting in the curved middle.

**Prompt:**
> Low-poly stylized cartoon giant banana soapbox race car, oversized bright
> yellow banana shape as vehicle body, curved crescent form, comically large,
> Subway Surfers art style, 3/4 front view, white background, game asset,
> no text, no shadows, single object centered

### 6. `chassis_couch.glb`
A living room sofa with wheels — cushions, armrests, and all.

**Prompt:**
> Low-poly stylized cartoon sofa couch soapbox race car, colorful living room
> couch with puffy cushions and armrests mounted on a frame, chunky cartoon
> proportions, Subway Surfers art style, 3/4 front view, white background,
> game asset, no text, no shadows, single object centered

---

## Wheels

Each wheel set contains 4 identical wheels. Generate one wheel model and it will
be instanced 4 times in-game. Each wheel is roughly 0.3–0.5m diameter.

### 1. `wheel_chunky.glb`
Thick, round cartoon tire with visible tread blocks.

**Prompt:**
> Low-poly stylized cartoon chunky tire wheel, thick rubber tire with blocky
> tread pattern and silver hub cap, toy-like proportions, single wheel,
> side view, white background, game asset, no text, no shadows

### 2. `wheel_skinny.glb`
Tall and narrow bicycle-style wheel with thin spokes.

**Prompt:**
> Low-poly stylized cartoon tall skinny bicycle wheel, thin spokes with small
> hub, narrow tire, elegant and minimal, side view, white background, game
> asset, no text, no shadows

### 3. `wheel_monster.glb`
Oversized monster truck tire with aggressive knobby tread.

**Prompt:**
> Low-poly stylized cartoon monster truck wheel, oversized tire with aggressive
> knobby tread and chrome rim, exaggerated large proportions, side view, white
> background, game asset, no text, no shadows

### 4. `wheel_wagon.glb`
Old-fashioned wooden wagon wheel with thick spokes.

**Prompt:**
> Low-poly stylized cartoon wooden wagon wheel, old fashioned wood and iron
> construction with thick spokes, rustic pioneer style, side view, white
> background, game asset, no text, no shadows

### 5. `wheel_roller.glb`
Small inline skate wheel — compact and colorful.

**Prompt:**
> Low-poly stylized cartoon inline skate wheel, small compact roller wheel
> with colored urethane and metal bearing center, tiny and sporty, side view,
> white background, game asset, no text, no shadows

---

## Top Decorations

Mounted on top of the chassis. Each roughly 0.2–0.4m.

| # | File                     | Description          | Prompt Key Phrases                                           |
|---|--------------------------|----------------------|--------------------------------------------------------------|
| 1 | `deco_top_flag.glb`      | Small racing flag    | "small triangular racing flag on a stick, colorful pennant"  |
| 2 | `deco_top_antenna.glb`   | Bouncy ball antenna  | "car antenna with bouncy ball on top, springy flexible rod"  |
| 3 | `deco_top_propeller.glb` | Toy propeller        | "toy helicopter propeller beanie cap spinner, two blades"    |
| 4 | `deco_top_crown.glb`     | Golden crown         | "small golden king crown, cartoon royal crown, three points" |
| 5 | `deco_top_fin.glb`       | Shark dorsal fin     | "shark dorsal fin, grey and smooth, curved triangular shape" |

**Full prompt wrapper for each:**
> Low-poly stylized cartoon [KEY PHRASES], Subway Surfers art style, chunky
> proportions, 3/4 view, white background, game asset, no text, no shadows,
> single object centered

---

## Side Decorations

Mounted on the lateral surface of the chassis. Flat or semi-flat objects.

| # | File                        | Description            | Prompt Key Phrases                                          |
|---|-----------------------------|------------------------|-------------------------------------------------------------|
| 1 | `deco_side_sticker.glb`     | Round number sticker   | "round racing number sticker decal, bold number, flat disc"  |
| 2 | `deco_side_stripe.glb`      | Racing stripe          | "horizontal racing stripe, thick band of color, elongated"   |
| 3 | `deco_side_flame.glb`       | Flame paintjob shape   | "hot rod flame shape, stylized fire silhouette, orange red"  |
| 4 | `deco_side_number.glb`      | Large race number      | "large bold race number in a circle, competition number"     |
| 5 | `deco_side_lightning.glb`   | Lightning bolt         | "lightning bolt shape, zigzag electrical bolt, bright yellow" |

---

## Front Decorations

Mounted on the front-facing surface. These give the vehicle personality.

| # | File                        | Description            | Prompt Key Phrases                                           |
|---|-----------------------------|------------------------|--------------------------------------------------------------|
| 1 | `deco_front_bumper.glb`     | Chunky bumper bar      | "thick cartoon bumper bar, chrome or painted, protective bar" |
| 2 | `deco_front_teeth.glb`      | Monster teeth grille   | "row of cartoon monster teeth, zigzag smile, white teeth"    |
| 3 | `deco_front_eyes.glb`       | Cartoon eyeballs       | "pair of cartoon googly eyes, big round eyes with pupils"    |
| 4 | `deco_front_headlight.glb`  | Round vintage headlight| "vintage round car headlight, single round lamp, chrome rim" |
| 5 | `deco_front_horn.glb`       | Bull horn              | "cartoon bull horn, single curved horn, ivory colored"       |

---

## Back Decorations

Mounted on the rear. Visible during the race (behind-view camera).

| # | File                        | Description            | Prompt Key Phrases                                            |
|---|-----------------------------|------------------------|---------------------------------------------------------------|
| 1 | `deco_back_exhaust.glb`     | Dual exhaust pipes     | "dual exhaust pipes, two chrome pipe openings, car exhaust"   |
| 2 | `deco_back_parachute.glb`   | Drag chute (cosmetic)  | "small drag racing parachute, folded fabric chute with cords" |
| 3 | `deco_back_tailflag.glb`    | Small fluttering flag  | "small flag on flexible pole, pennant waving, rear mounted"   |
| 4 | `deco_back_jetpack.glb`     | Cosmetic jetpack       | "cartoon jetpack, two cylinders with orange flame coming out"  |

---

## Driver

The player character who sits in/on the vehicle. Generated in a modular way so
helmet and goggles can be swapped. Roughly 0.8m tall (seated/crouching pose).

### 1. `driver_body.glb`
The base driver body in a seated racing pose, arms forward gripping an
imaginary steering bar. **No head** — the helmet goes on top.

**Prompt:**
> Low-poly stylized cartoon character body in seated racing pose, arms reaching
> forward gripping steering wheel, wearing colorful racing jumpsuit, headless
> mannequin style (no head), chunky Subway Surfers proportions, 3/4 front view,
> white background, game asset, no text, no shadows

### 2. `helmet_classic.glb`
Round classic racing helmet with visor slot.

**Prompt:**
> Low-poly stylized cartoon classic racing helmet, round dome shape with
> visor opening, solid color, chunky proportions, front view, white background,
> game asset, no text, no shadows

### 3. `helmet_viking.glb`
Viking helmet with small horns.

**Prompt:**
> Low-poly stylized cartoon viking helmet with two small curved horns, metal
> look, chunky proportions, front view, white background, game asset

### 4. `helmet_astronaut.glb`
Space helmet with bubble visor.

**Prompt:**
> Low-poly stylized cartoon astronaut space helmet, round bubble visor,
> white with gold visor tint, chunky proportions, front view, white background,
> game asset

### 5. `goggles.glb`
Aviator goggles that attach to any helmet.

**Prompt:**
> Low-poly stylized cartoon aviator goggles, round lenses with leather strap,
> steampunk pilot style, front view, white background, game asset

---

## Obstacles

Objects that appear on the track during the race. The player must dodge these
by switching lanes. Roughly 0.5–1.5m in size.

| #  | File                     | Description                 | Size (approx) | Prompt Key Phrases                                                  |
|----|--------------------------|-----------------------------|----------------|----------------------------------------------------------------------|
| 1  | `obs_barrel.glb`         | Red/orange oil barrel       | 0.8m tall      | "oil barrel drum, red orange metal barrel, industrial"               |
| 2  | `obs_cone.glb`           | Traffic cone                | 0.6m tall      | "orange traffic cone with white stripes"                             |
| 3  | `obs_hay_bale.glb`       | Hay bale stack              | 1.0m           | "rectangular hay bale, golden straw, farm hay block"                 |
| 4  | `obs_tire_stack.glb`     | Stacked tires               | 1.0m tall      | "stack of three black rubber tires, piled up"                        |
| 5  | `obs_barrier.glb`        | Road barrier/barricade      | 1.2m wide      | "road construction barrier, orange and white striped barricade"      |
| 6  | `obs_trash_can.glb`      | Overturned trash can        | 0.7m           | "tipped over metal trash can with lid, garbage can on its side"      |
| 7  | `obs_shopping_cart.glb`  | Abandoned shopping cart     | 1.0m           | "abandoned shopping cart, metal grocery cart, slightly tilted"        |
| 8  | `obs_ramp.glb`           | Small jump ramp             | 0.5m tall      | "small wooden jump ramp, skateboard ramp shape, wedge"               |
| 9  | `obs_pothole.glb`        | Road pothole (flat decal)   | 1.0m wide      | "road pothole crack, broken asphalt patch, flat ground damage"       |
| 10 | `obs_crowd_barrier.glb`  | Metal crowd barrier/fence   | 1.5m wide      | "metal crowd control barrier fence, silver steel railing"            |

**Full prompt wrapper for each:**
> Low-poly stylized cartoon [KEY PHRASES], Subway Surfers art style, chunky
> exaggerated proportions, vibrant colors, 3/4 view, white background, game
> asset, no text, no shadows, single object centered

---

## Environment / Track

Larger set pieces that form the downhill track and scenery.

### Track Segments

| # | File                       | Description                      | Prompt Key Phrases                                          |
|---|----------------------------|----------------------------------|-------------------------------------------------------------|
| 1 | `track_straight.glb`       | Straight road segment (10m)      | "straight asphalt road section with painted lane dividers"  |
| 2 | `track_start_gate.glb`     | Starting ramp/gate               | "race start gate with banner and countdown lights"          |
| 3 | `track_finish_arch.glb`    | Finish line arch                 | "race finish line inflatable arch, checkered pattern"       |

### Roadside Scenery (placed along the track edges)

| # | File                       | Description                      | Prompt Key Phrases                                          |
|---|----------------------------|----------------------------------|-------------------------------------------------------------|
| 1 | `scene_tree.glb`           | Cartoon tree                     | "round cartoon tree, puffy green canopy, brown trunk"       |
| 2 | `scene_bush.glb`           | Small hedge bush                 | "round cartoon bush hedge, bright green, puffy sphere"      |
| 3 | `scene_crowd_person.glb`   | Cheering spectator (3 variants)  | "cartoon person cheering, arms up, excited spectator"       |
| 4 | `scene_flag_banner.glb`    | Triangular pennant string        | "string of colorful triangular pennant flags, bunting"      |
| 5 | `scene_lamppost.glb`       | Street lamp                      | "cartoon street lamp post, vintage style, single light"     |
| 6 | `scene_building_a.glb`     | Small colorful house             | "small cartoon colorful house, simple architecture"         |
| 7 | `scene_building_b.glb`     | Apartment block                  | "cartoon apartment building, 3 stories, colorful facade"    |
| 8 | `scene_fence.glb`          | Wooden fence section             | "wooden picket fence section, white painted, 4 posts"       |

---

## Collectibles & Power-ups

Items the player can collect during the race for bonus points.

| # | File                     | Description               | Size     | Prompt Key Phrases                                          |
|---|--------------------------|---------------------------|----------|-------------------------------------------------------------|
| 1 | `item_coin.glb`          | Spinning golden coin      | 0.3m     | "golden coin, shiny gold disc with star embossed"           |
| 2 | `item_star.glb`          | Star power-up             | 0.3m     | "golden five-pointed star, glowing cartoon star"            |
| 3 | `item_wrench.glb`        | Wrench (style bonus)      | 0.3m     | "cartoon wrench tool, chrome silver spanner"                |
| 4 | `item_boost.glb`         | Speed boost arrow          | 0.3m     | "glowing speed boost arrow, neon forward arrow shape"       |

---

## UI Props

3D objects used in menus or the vehicle builder scene (garage background, etc).

| # | File                     | Description                      | Prompt Key Phrases                                          |
|---|--------------------------|----------------------------------|-------------------------------------------------------------|
| 1 | `ui_turntable.glb`       | Rotating display platform        | "circular display turntable platform, showroom pedestal"    |
| 2 | `ui_garage_bg.glb`       | Cartoon garage interior          | "cartoon garage workshop interior, tools on walls, workbench"|
| 3 | `ui_trophy.glb`          | Winner trophy                    | "golden cartoon winner trophy cup, first place award"       |

---

## Master Prompt Template

Use this base template for ALL assets. Replace `[OBJECT DESCRIPTION]` with the
specific key phrases from the tables above:

```
Low-poly stylized cartoon [OBJECT DESCRIPTION], Subway Surfers art style,
chunky exaggerated proportions, vibrant saturated colors, bold simple shapes,
3/4 front view, white background, game asset, no text, no watermarks,
no shadows, single object centered, clean silhouette
```

### Post-Generation Checklist (Image-to-3D conversion)

After generating each NanoBanana image:
1. Check the image has a clean white background and clear silhouette
2. Upload to Tripo/Meshy/Rodin for 3D conversion
3. Select "game asset" or "low-poly" preset if available
4. Export as `.glb` with embedded textures
5. In Blender (optional cleanup):
   - Verify Y-up orientation
   - Check origin is at bottom-center
   - Run "Merge by Distance" to clean up duplicate verts
   - Decimate if over the poly budget
   - Re-export as `.glb`

---

## File Naming Convention

```
assets/
├── chassis/
│   ├── chassis_bathtub.glb
│   ├── chassis_rocket.glb
│   ├── chassis_shoe.glb
│   ├── chassis_box.glb
│   ├── chassis_banana.glb
│   └── chassis_couch.glb
├── wheels/
│   ├── wheel_chunky.glb
│   ├── wheel_skinny.glb
│   ├── wheel_monster.glb
│   ├── wheel_wagon.glb
│   └── wheel_roller.glb
├── decorations/
│   ├── top/
│   │   ├── deco_top_flag.glb
│   │   ├── deco_top_antenna.glb
│   │   ├── deco_top_propeller.glb
│   │   ├── deco_top_crown.glb
│   │   └── deco_top_fin.glb
│   ├── side/
│   │   ├── deco_side_sticker.glb
│   │   ├── deco_side_stripe.glb
│   │   ├── deco_side_flame.glb
│   │   ├── deco_side_number.glb
│   │   └── deco_side_lightning.glb
│   ├── front/
│   │   ├── deco_front_bumper.glb
│   │   ├── deco_front_teeth.glb
│   │   ├── deco_front_eyes.glb
│   │   ├── deco_front_headlight.glb
│   │   └── deco_front_horn.glb
│   └── back/
│       ├── deco_back_exhaust.glb
│       ├── deco_back_parachute.glb
│       ├── deco_back_tailflag.glb
│       └── deco_back_jetpack.glb
├── driver/
│   ├── driver_body.glb
│   ├── helmet_classic.glb
│   ├── helmet_viking.glb
│   ├── helmet_astronaut.glb
│   └── goggles.glb
├── obstacles/
│   ├── obs_barrel.glb
│   ├── obs_cone.glb
│   ├── obs_hay_bale.glb
│   ├── obs_tire_stack.glb
│   ├── obs_barrier.glb
│   ├── obs_trash_can.glb
│   ├── obs_shopping_cart.glb
│   ├── obs_ramp.glb
│   ├── obs_pothole.glb
│   └── obs_crowd_barrier.glb
├── environment/
│   ├── track_straight.glb
│   ├── track_start_gate.glb
│   ├── track_finish_arch.glb
│   ├── scene_tree.glb
│   ├── scene_bush.glb
│   ├── scene_crowd_person.glb
│   ├── scene_flag_banner.glb
│   ├── scene_lamppost.glb
│   ├── scene_building_a.glb
│   ├── scene_building_b.glb
│   └── scene_fence.glb
├── items/
│   ├── item_coin.glb
│   ├── item_star.glb
│   ├── item_wrench.glb
│   └── item_boost.glb
└── ui/
    ├── ui_turntable.glb
    ├── ui_garage_bg.glb
    └── ui_trophy.glb
```

**Total asset count: 55 GLB files**

---

## Asset Priority (build order)

If you want to get a playable prototype fast, generate these first:

**Phase 1 — Minimum Viable Game (12 assets):**
- 2 chassis (bathtub, rocket)
- 2 wheels (chunky, monster)
- 1 driver body + 1 helmet
- 3 obstacles (barrel, cone, hay bale)
- 1 track segment + 1 coin + 1 turntable

**Phase 2 — Full Vehicle Builder (add 20 assets):**
- Remaining 4 chassis, 3 wheels
- 8 decorations (2 per slot)
- 2 more helmets + goggles
- Additional obstacles

**Phase 3 — Polish (remaining 23 assets):**
- All remaining decorations
- Full environment set
- All collectibles and UI props
