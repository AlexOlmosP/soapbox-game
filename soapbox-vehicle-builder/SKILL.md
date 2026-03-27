---
name: soapbox-vehicle-builder
description: Build an interactive 3D soapbox vehicle editor/customizer for a Red Bull Soapbox Race HTML game using Three.js and GLB assets. Use this skill whenever the user asks to create, modify, or improve the vehicle builder, car customizer, garage editor, or soapbox creator component. Also trigger when the user mentions vehicle parts (chassis, wheels, decorations, spoilers, paint, helmets), the build/customize screen, 3D preview, asset loading, or wants to change how players design their soapbox car. This skill covers the Three.js scene setup, GLB asset loading, part swapping, color picking, vehicle data model, and export for use in the racing game.
---

# Soapbox Vehicle Builder Skill (Three.js 3D)

Build an interactive 3D vehicle customizer where players assemble their soapbox racing vehicle from pre-made GLB assets before racing downhill. The builder is the creative heart of the game — where players express themselves and get invested.

## Context

- **Game**: Red Bull Soapbox Race — downhill gravity racer
- **Visual Style**: Subway Surfers / Fall Guys — chunky, colorful, bold low-poly 3D
- **Tech**: Single-file HTML artifact using Three.js (r128 via CDN)
- **Assets**: Pre-generated GLB files created with AI tools (NanoBanana → Tripo/Meshy → Blender → GLB)
- **Rendering**: WebGL via Three.js with GLTFLoader

Read `references/3d-asset-guide.md` for the full asset list, NanoBanana prompts, file naming convention, and Blender export checklist.
Read `references/part-stats.md` for how parts affect gameplay stats.
Read `references/rendering-guide.md` for scene setup, asset loading, camera, and animation code patterns.

## Vehicle Data Model

This JSON is the contract between builder and race engine. Both read and render from it.

```json
{
  "version": 2,
  "name": "My Soapbox",
  "chassis": {
    "type": "bathtub",
    "color": "#FF4444"
  },
  "wheels": {
    "type": "chunky",
    "color": "#333333"
  },
  "decorations": [
    { "type": "flag", "slot": "top", "enabled": true },
    { "type": "flame", "slot": "side", "enabled": true },
    { "type": "teeth", "slot": "front", "enabled": true },
    { "type": "jetpack", "slot": "back", "enabled": false }
  ],
  "driver": {
    "helmet": "classic",
    "helmetColor": "#2244FF"
  },
  "stats": {
    "speed": 3,
    "handling": 4,
    "style": 5
  }
}
```

## Part Catalog IDs

These IDs map directly to GLB filenames in the `assets/` directory:

**Chassis** (6): `bathtub`, `rocket`, `shoe`, `box`, `banana`, `couch`
**Wheels** (5): `chunky`, `skinny`, `monster`, `wagon`, `roller`
**Top deco** (5): `flag`, `antenna`, `propeller`, `crown`, `fin`
**Side deco** (5): `star`, `stripe`, `flame`, `number`, `lightning`
**Front deco** (5): `teeth`, `eyes`, `bumper`, `headlight`, `horn`
**Back deco** (4): `exhaust`, `parachute`, `tailflag`, `jetpack`
**Helmets** (5): `classic`, `openface`, `viking`, `mohawk`, `astronaut`

## Three.js Scene Hierarchy

```
Scene
├── AmbientLight (soft fill, intensity 0.6)
├── DirectionalLight (key light, intensity 0.8, top-right-front)
├── DirectionalLight (rim light, intensity 0.3, back-left)
├── VehicleGroup (turntable rotation)
│   ├── ChassisModel (GLB, color-tinted)
│   ├── WheelFL / WheelFR / WheelBL / WheelBR (GLB instances)
│   ├── DriverBody (GLB)
│   ├── HelmetModel (GLB, color-tinted)
│   └── DecoTop / DecoSide / DecoFront / DecoBack (GLB, optional)
├── FloorPlane (checkered garage floor)
└── PerspectiveCamera (simple orbit)
```

## Editor UI Layout

Two layers: Three.js canvas (background) + HTML overlay for controls.

```
┌─────────────────────────────────────────────────┐
│  [Vehicle Name Input]                           │
│         ┌───────────────────────┐               │
│         │   3D PREVIEW CANVAS   │  ┌──────────┐ │
│         │   (Three.js WebGL)    │  │ PART     │ │
│         │   ← drag to orbit →   │  │ PICKER   │ │
│         │                       │  │ [tabs]   │ │
│         └───────────────────────┘  │ [grid]   │ │
│  ┌──────────────────────────────┐  │ COLOR    │ │
│  │ SPD ████░░  HDL ███░░░       │  │ [●●●●]  │ │
│  │ STY █████░                   │  └──────────┘ │
│  └──────────────────────────────┘               │
│              [ 🏁 RACE! ]                        │
└─────────────────────────────────────────────────┘
```

### Part Picker
- Tab bar: **Chassis** | **Wheels** | **Top** | **Side** | **Front** | **Back** | **Helmet**
- Grid of clickable thumbnails (emoji icons or small preview images)
- Selecting a part: unloads current GLB → loads new → attaches at mount point → tints
- Decoration tabs include a "None" option to remove

### Color Picker
- 12-16 bold color swatches
- Only active on Chassis and Helmet tabs
- Calls `tintModel()` and updates vehicleData

### Stats Bars
- SPD / HDL / STY horizontal bars (1-5 scale)
- Recalculated on every part change using `references/part-stats.md`
- Animated via CSS `transition: width 0.3s`

### RACE! Button
- Large, bottom-center, pulsing glow animation
- Saves vehicle to storage and signals race mode

## Color Tinting Strategy

Chassis and helmets are generated as **white/light gray** assets. Apply player color at runtime:

```javascript
function tintModel(model, hexColor) {
  const color = new THREE.Color(hexColor);
  model.traverse((child) => {
    if (child.isMesh) {
      child.material.color.copy(color);
    }
  });
}
```

Decorations keep their baked textures/colors — players don't recolor those.

## Placeholder Fallback (No Assets Mode)

If GLB files aren't available yet, render placeholder primitives so the builder is still functional and testable:

- **Chassis**: `BoxGeometry(2, 0.6, 1)` with `MeshToonMaterial`
- **Wheels**: `CylinderGeometry(0.25, 0.25, 0.15, 16)` rotated 90°
- **Decorations**: small `SphereGeometry` or `ConeGeometry` at anchor points
- **Driver**: `SphereGeometry(0.2)` for head + `CylinderGeometry` for body

This ensures the editor works before any assets exist. Placeholder mode should be automatic — if a GLB fails to load, fall back to the primitive.

## Persistence

```javascript
// Auto-save on every change
await window.storage.set('soapbox-vehicle-v2', JSON.stringify(vehicleData));

// Load on init
const saved = await window.storage.get('soapbox-vehicle-v2');

// Export for race
await window.storage.set('currentVehicle', JSON.stringify(vehicleData));
```

## Implementation Checklist

- [ ] Three.js scene with 3-point lighting
- [ ] GLTFLoader for GLB assets with caching
- [ ] Vehicle group hierarchy (chassis → wheels → driver → decos)
- [ ] Wheel mount positions adapting to chassis type
- [ ] Decoration anchor points per slot (top/side/front/back)
- [ ] Color tinting on chassis and helmet meshes
- [ ] Mouse/touch orbit camera with auto-turntable
- [ ] Wheel spin + decoration animations (propeller, flag wave)
- [ ] Part picker tabs for all 7 categories
- [ ] Color palette active for chassis/helmet only
- [ ] Stats bars updating on every part change
- [ ] Vehicle name input
- [ ] Persistent storage save/load
- [ ] RACE! button exporting vehicle data
- [ ] Placeholder primitives when GLBs unavailable
- [ ] Responsive canvas + mobile-friendly UI
- [ ] Loading spinner while assets fetch
