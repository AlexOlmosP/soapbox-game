# Color & Lighting Reference

The master color palette, lighting rigs for every scene, environment color
grading, and rules for visual consistency across the entire game.

## Table of Contents
1. [Master Color Palette](#master-color-palette)
2. [Color Usage Rules](#color-usage-rules)
3. [Lighting Rig: Garage / Builder](#lighting-rig-garage)
4. [Lighting Rig: Race / Outdoor](#lighting-rig-race)
5. [Lighting Rig: Title Screen](#lighting-rig-title)
6. [Environment Color Zones](#environment-color-zones)
7. [Sky & Fog System](#sky--fog-system)
8. [Shadow Configuration](#shadow-configuration)
9. [Color Accessibility](#color-accessibility)

---

## Master Color Palette

These are the official game colors. All code should reference these values.
The palette is designed for maximum vibrancy and contrast on both OLED and
LCD screens.

### Primary Palette (Vehicle & UI)

```javascript
const PALETTE = {
  // Warm
  red:        '#FF3344',
  orange:     '#FF8800',
  yellow:     '#FFD700',
  coral:      '#FF6B6B',
  hotPink:    '#FF44AA',

  // Cool
  blue:       '#4488FF',
  cyan:       '#00DDEE',
  teal:       '#20B2AA',
  purple:     '#AA44FF',
  green:      '#44DD66',
  lime:       '#88DD00',

  // Neutral
  white:      '#FFFFFF',
  silver:     '#C0C0C0',
  grey:       '#888888',
  darkGrey:   '#444444',
  nearBlack:  '#222222',
  black:      '#111111',

  // Metallic
  gold:       '#FFB347',
  chrome:     '#CCCCCC',
  bronze:     '#CD7F32',
};
```

### Vehicle Color Picker Palette

The 16 colors offered to the player in the vehicle builder. Curated so
every combination looks good:

```javascript
const VEHICLE_COLORS = [
  '#FF3344', // Red
  '#FF8800', // Orange
  '#FFD700', // Yellow
  '#88DD00', // Lime
  '#44DD66', // Green
  '#00DDEE', // Cyan
  '#4488FF', // Blue
  '#AA44FF', // Purple
  '#FF44AA', // Pink
  '#FFFFFF', // White
  '#222222', // Black
  '#FFB347', // Gold
  '#C0C0C0', // Silver
  '#FF6B6B', // Coral
  '#20B2AA', // Teal
  '#CD7F32', // Bronze
];
```

### Environment Palette

Colors for road, ground, sky, and scenery elements:

```javascript
const ENV_COLORS = {
  // Sky
  skyTop:        '#4A90D9',
  skyBottom:     '#87CEEB',
  skyHorizon:    '#B0D4F1',

  // Ground
  grass:         '#88AA55',
  grassDark:     '#6E8E3E',
  dirt:          '#B99B6B',
  sand:          '#E8D5A3',

  // Road
  asphalt:       '#555566',
  asphaltDark:   '#444455',
  laneMarking:   '#FFFFFF',
  curb:          '#CC3333',
  curbWhite:     '#EEEEEE',

  // Buildings
  buildingWarm:  '#DDBB88',
  buildingCool:  '#AABBCC',
  buildingBrick: '#BB7755',
  buildingPink:  '#EEBB99',
  roofRed:       '#CC4444',
  roofBlue:      '#5577AA',

  // Trees
  foliage:       '#44AA44',
  foliageDark:   '#338833',
  trunk:         '#8B6914',

  // Fences
  woodFence:     '#EEDDCC',
  metalFence:    '#999999',
};
```

---

## Color Usage Rules

### 1. The 60-30-10 Rule

For any single scene or object, distribute color as:
- **60%** dominant color (sky, road, or vehicle body)
- **30%** secondary color (scenery, UI, complementary accents)
- **10%** accent color (highlights, decorations, collectibles)

### 2. Contrast Requirements

- Adjacent lane obstacles must differ in hue by at least 60° on the color wheel
- The player's vehicle must contrast against the road surface (grey)
- Collectibles (gold) must contrast against every background zone
- HUD text (white) must have a dark shadow or backdrop for readability

### 3. Color Temperature

The game leans **warm**:
- Sunlight: warm white (`#FFF4E0`) not cool blue
- Shadows: warm grey (`#5A5A6E`) not cold grey
- Sky: saturated blue with warm highlights at horizon
- Ground: warm greens and yellows, not cold blue-greens

### 4. Saturation by Depth

Closer objects are more saturated. Distant objects are slightly desaturated
(fog handles this naturally, but reinforce it in material choices):

```
Near (0-10m):   Full saturation
Mid (10-30m):   ~85% saturation
Far (30-60m):   ~65% saturation (fog blend)
Very far (60m+): Fades into fog color
```

### 5. No Pure Black, No Pure White

- Outlines use `#222222` (not `#000000`)
- Highlights use `#FAFAFA` or `#F0F0F0` (not `#FFFFFF`)
- Exception: lane markings CAN be `#FFFFFF` for maximum visibility

---

## Lighting Rig: Garage

The vehicle builder takes place in a warm, dramatic indoor space — like
a cool workshop where you build your masterpiece.

```javascript
function setupGarageLighting(scene) {
  // Remove any existing lights
  clearLights(scene);

  // Background
  scene.background = new THREE.Color(0x1E1E2E);
  scene.fog = null; // No fog indoors

  // 1. Warm ambient fill
  const ambient = new THREE.AmbientLight(0xFFF4E0, 0.35);
  scene.add(ambient);

  // 2. Key spotlight — dramatic top-down on the vehicle
  const keySpot = new THREE.SpotLight(0xFFFFFF, 1.0, 12, Math.PI / 4, 0.4, 1);
  keySpot.position.set(0, 5, 2);
  keySpot.target.position.set(0, 0, 0);
  keySpot.castShadow = true;
  keySpot.shadow.mapSize.set(1024, 1024);
  keySpot.shadow.bias = -0.001;
  scene.add(keySpot);
  scene.add(keySpot.target);

  // 3. Fill light — softer, from the side
  const fill = new THREE.PointLight(0x88AAFF, 0.3, 10);
  fill.position.set(-3, 3, -1);
  scene.add(fill);

  // 4. Rim light — subtle backlight for edge definition
  const rim = new THREE.PointLight(0xFF8844, 0.25, 8);
  rim.position.set(2, 2, -3);
  scene.add(rim);

  // 5. Ground bounce (simulated with hemisphere)
  const hemi = new THREE.HemisphereLight(0x2A2A3E, 0x1A1A2E, 0.15);
  scene.add(hemi);
}
```

### Garage Floor

A reflective-looking dark floor sells the "showroom" feel:

```javascript
function createGarageFloor() {
  const geo = new THREE.CircleGeometry(6, 32);
  geo.rotateX(-Math.PI / 2);
  const mat = new THREE.MeshStandardMaterial({
    color: 0x2A2A3E,
    roughness: 0.3,
    metalness: 0.2,
  });
  // Note: using MeshStandardMaterial for the floor (not toon)
  // because a slightly reflective floor looks better in the garage
  const floor = new THREE.Mesh(geo, mat);
  floor.receiveShadow = true;
  floor.userData.noOutline = true;
  return floor;
}
```

---

## Lighting Rig: Race

Outdoor, sunny, energetic. The road should feel bright and the obstacles
should be clearly visible.

```javascript
function setupRaceLighting(scene) {
  clearLights(scene);

  // Background: gradient sky
  scene.background = new THREE.Color(0x87CEEB);
  scene.fog = new THREE.Fog(0x87CEEB, 25, 65);

  // 1. Ambient — warm, strong enough to prevent dark areas
  const ambient = new THREE.AmbientLight(0xFFF4E0, 0.5);
  scene.add(ambient);

  // 2. Sun — warm directional, top-right-front
  const sun = new THREE.DirectionalLight(0xFFF4E0, 0.9);
  sun.position.set(4, 10, 5);
  sun.castShadow = true;
  sun.shadow.mapSize.set(1024, 1024);
  sun.shadow.camera.near = 1;
  sun.shadow.camera.far = 40;
  sun.shadow.camera.left = -8;
  sun.shadow.camera.right = 8;
  sun.shadow.camera.top = 15;
  sun.shadow.camera.bottom = -5;
  sun.shadow.bias = -0.001;
  scene.add(sun);

  // 3. Hemisphere — sky blue top, warm ground bottom
  const hemi = new THREE.HemisphereLight(0x87CEEB, 0xB97A20, 0.35);
  scene.add(hemi);

  // 4. Subtle fill from the left (prevents harsh one-side lighting)
  const fill = new THREE.DirectionalLight(0x88BBFF, 0.15);
  fill.position.set(-3, 5, 2);
  scene.add(fill);

  return { sun }; // Return sun reference so it can follow the player
}
```

### Sun Following

In race mode, the sun's shadow camera should follow the player's Z position
so shadows remain sharp near the vehicle:

```javascript
function updateSunPosition(sun, playerZ) {
  sun.position.z = playerZ + 5;
  sun.target.position.z = playerZ - 5;
  sun.target.updateMatrixWorld();
}
// In the race loop, playerZ is always 0 (the world scrolls),
// so this is only needed if the camera or player actually moves.
```

---

## Lighting Rig: Title Screen

A cinematic hero-shot setup. More dramatic than the race, less moody than
the garage:

```javascript
function setupTitleLighting(scene) {
  clearLights(scene);

  // Background: slightly darker sky for drama
  scene.background = new THREE.Color(0x3A6EA5);
  scene.fog = new THREE.Fog(0x3A6EA5, 8, 25);

  // 1. Warm ambient
  const ambient = new THREE.AmbientLight(0xFFF4E0, 0.4);
  scene.add(ambient);

  // 2. Key light — slightly warmer and more angled than race
  const key = new THREE.DirectionalLight(0xFFE0B0, 0.8);
  key.position.set(3, 6, 4);
  key.castShadow = true;
  key.shadow.mapSize.set(1024, 1024);
  scene.add(key);

  // 3. Back rim light — creates a heroic silhouette edge
  const rim = new THREE.DirectionalLight(0xFF8844, 0.4);
  rim.position.set(-2, 3, -4);
  scene.add(rim);

  // 4. Hemisphere
  const hemi = new THREE.HemisphereLight(0x3A6EA5, 0x8B6914, 0.25);
  scene.add(hemi);
}
```

---

## Environment Color Zones

As the player races further, the environment shifts to keep things fresh.
Each zone has its own road color, ground color, sky tint, and fog color.

```javascript
const ENVIRONMENT_ZONES = [
  {
    name: 'suburban',
    distance: [0, 500],
    road: 0x555566,
    ground: 0x88AA55,
    sky: 0x87CEEB,
    fog: 0x87CEEB,
    fogNear: 25,
    fogFar: 65,
    sunColor: 0xFFF4E0,
    sunIntensity: 0.9,
    ambientIntensity: 0.5,
  },
  {
    name: 'urban',
    distance: [500, 1000],
    road: 0x444455,
    ground: 0x888888,
    sky: 0x7ABFDD,
    fog: 0x7ABFDD,
    fogNear: 20,
    fogFar: 55,
    sunColor: 0xFFEEDD,
    sunIntensity: 0.85,
    ambientIntensity: 0.45,
  },
  {
    name: 'park',
    distance: [1000, 1500],
    road: 0x556655,
    ground: 0x66AA44,
    sky: 0x8AD4E8,
    fog: 0x8AD4E8,
    fogNear: 28,
    fogFar: 70,
    sunColor: 0xFFFFDD,
    sunIntensity: 0.95,
    ambientIntensity: 0.55,
  },
  {
    name: 'industrial',
    distance: [1500, 2000],
    road: 0x555555,
    ground: 0x999977,
    sky: 0x7799AA,
    fog: 0x7799AA,
    fogNear: 18,
    fogFar: 50,
    sunColor: 0xFFDDCC,
    sunIntensity: 0.8,
    ambientIntensity: 0.4,
  },
  {
    name: 'sunset',
    distance: [2000, 3000],
    road: 0x554455,
    ground: 0x887755,
    sky: 0xE88844,
    fog: 0xDD7744,
    fogNear: 20,
    fogFar: 55,
    sunColor: 0xFFAA66,
    sunIntensity: 0.85,
    ambientIntensity: 0.4,
  },
];
```

### Zone Transition

Blend smoothly between zones over ~100m to avoid jarring color pops:

```javascript
function getZoneBlend(distance) {
  for (let i = 0; i < ENVIRONMENT_ZONES.length; i++) {
    const zone = ENVIRONMENT_ZONES[i];
    const [start, end] = zone.distance;

    if (distance < start) continue;
    if (distance > end) continue;

    // Check if we're in the transition region (last 100m of zone)
    const transitionStart = end - 100;
    if (distance > transitionStart && i < ENVIRONMENT_ZONES.length - 1) {
      const t = (distance - transitionStart) / 100;
      const nextZone = ENVIRONMENT_ZONES[i + 1];
      return blendZones(zone, nextZone, t);
    }

    return zone;
  }

  // Past all zones — cycle randomly
  return ENVIRONMENT_ZONES[Math.floor(Math.random() * ENVIRONMENT_ZONES.length)];
}

function blendZones(zoneA, zoneB, t) {
  const colorA = new THREE.Color();
  const colorB = new THREE.Color();

  return {
    road: colorA.set(zoneA.road).lerp(colorB.set(zoneB.road), t).getHex(),
    ground: colorA.set(zoneA.ground).lerp(colorB.set(zoneB.ground), t).getHex(),
    sky: colorA.set(zoneA.sky).lerp(colorB.set(zoneB.sky), t).getHex(),
    fog: colorA.set(zoneA.fog).lerp(colorB.set(zoneB.fog), t).getHex(),
    fogNear: zoneA.fogNear + (zoneB.fogNear - zoneA.fogNear) * t,
    fogFar: zoneA.fogFar + (zoneB.fogFar - zoneA.fogFar) * t,
    sunColor: colorA.set(zoneA.sunColor).lerp(colorB.set(zoneB.sunColor), t).getHex(),
    sunIntensity: zoneA.sunIntensity + (zoneB.sunIntensity - zoneA.sunIntensity) * t,
    ambientIntensity: zoneA.ambientIntensity + (zoneB.ambientIntensity - zoneA.ambientIntensity) * t,
  };
}

// Apply zone to scene (call every few frames):
function applyZoneToScene(scene, zone, sun, ambient) {
  scene.background.set(zone.sky);
  scene.fog.color.set(zone.fog);
  scene.fog.near = zone.fogNear;
  scene.fog.far = zone.fogFar;
  sun.color.set(zone.sunColor);
  sun.intensity = zone.sunIntensity;
  ambient.intensity = zone.ambientIntensity;
}
```

---

## Sky & Fog System

### Sky Gradient

Three.js doesn't have a built-in sky gradient. Options:

**Option A — Flat color (simplest):**
```javascript
scene.background = new THREE.Color(0x87CEEB);
```

**Option B — Vertical gradient via shader (better):**
```javascript
function createSkyGradient(topColor, bottomColor) {
  const canvas = document.createElement('canvas');
  canvas.width = 2;
  canvas.height = 256;
  const ctx = canvas.getContext('2d');
  const gradient = ctx.createLinearGradient(0, 0, 0, 256);
  gradient.addColorStop(0, topColor);
  gradient.addColorStop(1, bottomColor);
  ctx.fillStyle = gradient;
  ctx.fillRect(0, 0, 2, 256);

  const texture = new THREE.CanvasTexture(canvas);
  texture.minFilter = THREE.LinearFilter;
  texture.magFilter = THREE.LinearFilter;
  scene.background = texture;
}

createSkyGradient('#4A90D9', '#B0D4F1');
```

### Fog

Fog serves two purposes: hides track pop-in at the far end, and creates
depth/atmosphere. Always match fog color to sky color:

```javascript
scene.fog = new THREE.Fog(
  0x87CEEB,  // Same as sky — objects fade into sky seamlessly
  25,        // Start fading at 25m
  65         // Fully hidden at 65m
);
```

---

## Shadow Configuration

### Shadow Map Quality

```javascript
// Renderer setup
renderer.shadowMap.enabled = true;
renderer.shadowMap.type = THREE.PCFSoftShadowMap;

// Directional light (sun) shadow
sun.castShadow = true;
sun.shadow.mapSize.set(1024, 1024); // 1K for mobile, 2K for desktop
sun.shadow.camera.near = 1;
sun.shadow.camera.far = 40;
sun.shadow.camera.left = -8;
sun.shadow.camera.right = 8;
sun.shadow.camera.top = 15;
sun.shadow.camera.bottom = -5;
sun.shadow.bias = -0.001;     // Prevents shadow acne
sun.shadow.normalBias = 0.02; // Prevents peter-panning
```

### What Casts Shadows

- Player vehicle: YES
- Obstacles: YES
- Scenery trees/buildings: YES (but only near ones, <20m)
- Collectibles: NO (too small, not worth the cost)
- Lane markings: NO
- Outlines: NO (disabled via `outline.castShadow = false`)

### What Receives Shadows

- Road surface: YES
- Ground/grass planes: YES
- Curbs: YES
- Other objects: NO (toon shading makes received shadows look weird
  on non-flat surfaces — the toon material's own shading is enough)

### Contact Shadows (Fake)

For objects that don't cast proper shadows (collectibles, small decorations),
place a small dark ellipse under them as a "contact shadow":

```javascript
function createContactShadow(radius = 0.3) {
  const geo = new THREE.CircleGeometry(radius, 12);
  geo.rotateX(-Math.PI / 2);
  const mat = new THREE.MeshBasicMaterial({
    color: 0x000000,
    transparent: true,
    opacity: 0.15,
    depthWrite: false,
  });
  const shadow = new THREE.Mesh(geo, mat);
  shadow.position.y = 0.01; // Just above ground to prevent z-fighting
  shadow.userData.noOutline = true;
  shadow.userData.noRecolor = true;
  return shadow;
}
```

---

## Color Accessibility

### Color Blind Considerations

The game relies on color to distinguish objects, but obstacles must also be
distinguishable by shape. The silhouette rule (every object identifiable by
shape alone) serves double duty as an accessibility feature.

Additional guidelines:
- Don't rely solely on red/green distinction for gameplay-critical info
- Coins (gold) and obstacles (varied colors) differ in both color AND
  behavior (coins spin and bob, obstacles are static)
- The HUD uses icons (🏁 ⭐ 🪙) alongside numbers, not color alone
- Near-miss text ("CLOSE!") uses pink (#FF44AA) which reads well for
  most forms of color blindness

### Contrast Ratios

HUD text over the game viewport must maintain readability:
- White text with dark text-shadow: sufficient on all backgrounds
- The HUD top bar has a gradient backdrop (`rgba(0,0,0,0.5)`) ensuring
  minimum 4.5:1 contrast ratio even over bright sky sections
