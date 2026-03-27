# Toon Shading Implementation Reference

Complete Three.js r128 implementation for the Subway Surfers cel-shaded
cartoon look: gradient maps, MeshToonMaterial, outline hulls, and the
GLB toonification pipeline.

## Table of Contents
1. [Gradient Map Setup](#gradient-map-setup)
2. [MeshToonMaterial Factory](#meshtoonmaterial-factory)
3. [Outline System (Inverted Hull)](#outline-system)
4. [GLB Toonification Pipeline](#glb-toonification-pipeline)
5. [Material Variants](#material-variants)
6. [Recoloring System](#recoloring-system)
7. [Distance-Based LOD for Outlines](#distance-lod)
8. [Common Pitfalls & Fixes](#common-pitfalls)

---

## Gradient Map Setup

The gradient map is a tiny 1D texture that controls how MeshToonMaterial
maps light intensity to discrete color steps. This is the core of the
cel-shading look.

### 3-Step Gradient (Standard — used for most objects)

Three bands: lit, mid-shadow, deep shadow. Produces the classic cartoon look.

```javascript
function createGradientMap3() {
  const data = new Uint8Array([
    0, 0, 0,         // Deep shadow (darkest)
    140, 140, 140,    // Mid shadow
    255, 255, 255,    // Full lit (brightest)
  ]);
  const texture = new THREE.DataTexture(data, 3, 1, THREE.RGBFormat);
  texture.minFilter = THREE.NearestFilter;
  texture.magFilter = THREE.NearestFilter;
  texture.needsUpdate = true;
  return texture;
}
```

### 2-Step Gradient (Hard — for dramatic/stylized objects)

Only two bands: lit and shadow. Creates a very stark, graphic novel look.
Use sparingly — good for obstacles and dramatic moments.

```javascript
function createGradientMap2() {
  const data = new Uint8Array([
    0, 0, 0,
    255, 255, 255,
  ]);
  const texture = new THREE.DataTexture(data, 2, 1, THREE.RGBFormat);
  texture.minFilter = THREE.NearestFilter;
  texture.magFilter = THREE.NearestFilter;
  texture.needsUpdate = true;
  return texture;
}
```

### 5-Step Gradient (Soft — for characters and vehicles)

Five bands for slightly smoother shading while staying cartoony. Use for
the player's vehicle and driver where you want a bit more visual depth.

```javascript
function createGradientMap5() {
  const data = new Uint8Array([
    0, 0, 0,
    64, 64, 64,
    128, 128, 128,
    192, 192, 192,
    255, 255, 255,
  ]);
  const texture = new THREE.DataTexture(data, 5, 1, THREE.RGBFormat);
  texture.minFilter = THREE.NearestFilter;
  texture.magFilter = THREE.NearestFilter;
  texture.needsUpdate = true;
  return texture;
}
```

### Critical: NearestFilter

The `minFilter` and `magFilter` **must** be `THREE.NearestFilter`. If you
use `LinearFilter`, the discrete steps blur together and the toon look
vanishes — the material reverts to standard smooth shading.

### Singleton Pattern

Create the gradient maps once and reuse them across all materials:

```javascript
const GRADIENT_MAPS = {
  standard: createGradientMap3(),
  hard: createGradientMap2(),
  soft: createGradientMap5(),
};
```

---

## MeshToonMaterial Factory

A factory function that creates properly configured toon materials:

```javascript
function createToonMaterial(color, options = {}) {
  const {
    gradientType = 'standard',  // 'standard' | 'hard' | 'soft'
    emissive = 0x000000,
    emissiveIntensity = 0,
    transparent = false,
    opacity = 1.0,
    side = THREE.FrontSide,
  } = options;

  return new THREE.MeshToonMaterial({
    color: new THREE.Color(color),
    gradientMap: GRADIENT_MAPS[gradientType],
    emissive: new THREE.Color(emissive),
    emissiveIntensity: emissiveIntensity,
    transparent: transparent,
    opacity: opacity,
    side: side,
  });
}
```

### Usage Examples

```javascript
// Standard vehicle body
const chassisMat = createToonMaterial('#FF4444');

// Dramatic obstacle
const obstacleMat = createToonMaterial('#FF8800', { gradientType: 'hard' });

// Softer character shading
const driverMat = createToonMaterial('#4488FF', { gradientType: 'soft' });

// Glowing coin (slight emissive)
const coinMat = createToonMaterial('#FFD700', {
  emissive: '#FFD700',
  emissiveIntensity: 0.2,
});

// Transparent window/visor
const visorMat = createToonMaterial('#88CCFF', {
  transparent: true,
  opacity: 0.5,
});
```

---

## Outline System

The inverted hull method creates bold cartoon outlines by rendering a
slightly enlarged copy of each mesh with its normals flipped (back-face only)
in a solid dark color.

### Core Implementation

```javascript
const OUTLINE_DEFAULTS = {
  color: 0x222222,
  thickness: 0.03,    // Scale multiplier (3%)
};

function addOutline(object, thickness, outlineColor) {
  const t = thickness !== undefined ? thickness : OUTLINE_DEFAULTS.thickness;
  const c = outlineColor !== undefined ? outlineColor : OUTLINE_DEFAULTS.color;

  const outlineMaterial = new THREE.MeshBasicMaterial({
    color: c,
    side: THREE.BackSide,
  });

  object.traverse((child) => {
    if (!child.isMesh) return;
    if (child.userData.isOutline) return;  // Don't outline an outline
    if (child.userData.noOutline) return;  // Opt-out flag

    const outline = child.clone();
    outline.material = outlineMaterial;
    outline.scale.multiplyScalar(1 + t);
    outline.castShadow = false;
    outline.receiveShadow = false;
    outline.userData.isOutline = true;
    outline.renderOrder = -1;  // Render before the main mesh

    // Add as sibling, not child (avoids compound scaling)
    if (child.parent) {
      child.parent.add(outline);
    }
  });
}
```

### Thickness Guidelines

| Object Type          | Thickness | Reason                                   |
|----------------------|-----------|------------------------------------------|
| Player vehicle       | 0.035     | Most prominent object, needs strong edge  |
| Driver/character     | 0.03      | Important but smaller                     |
| Obstacles            | 0.025     | Need to read clearly at speed             |
| Decorations          | 0.02      | Small parts, thinner outline              |
| Roadside scenery     | 0.02      | Background elements, less emphasis        |
| Distant buildings    | 0.015     | Far away, thin outline or none            |
| Collectibles (coins) | 0.02      | Small, spinning, needs definition         |
| Wheels               | 0.02      | Rounded shapes need less outline          |

### Removing Outlines

When recycling pooled objects or switching parts, clean up outlines:

```javascript
function removeOutlines(object) {
  const toRemove = [];
  object.traverse((child) => {
    if (child.userData.isOutline) toRemove.push(child);
  });
  toRemove.forEach(outline => {
    if (outline.parent) outline.parent.remove(outline);
    if (outline.geometry) outline.geometry.dispose();
    if (outline.material) outline.material.dispose();
  });
}
```

### Opting Out

Some meshes shouldn't have outlines (ground planes, shadows, particles):

```javascript
// Before calling addOutline on a group, flag exemptions:
groundPlane.userData.noOutline = true;
shadowDisc.userData.noOutline = true;
particleMesh.userData.noOutline = true;
```

---

## GLB Toonification Pipeline

When loading a GLB model from NanoBanana / image-to-3D, it arrives with
`MeshStandardMaterial` (PBR) materials that look realistic. The toonify
pipeline converts everything to match the game's cartoon style.

### Full Pipeline

```javascript
function toonifyModel(model, options = {}) {
  const {
    outlineThickness = OUTLINE_DEFAULTS.thickness,
    gradientType = 'standard',
    preserveColors = true,
    overrideColor = null,
  } = options;

  model.traverse((child) => {
    if (!child.isMesh) return;

    // 1. Extract color from original material
    let color;
    if (overrideColor) {
      color = new THREE.Color(overrideColor);
    } else if (preserveColors && child.material.color) {
      color = child.material.color.clone();
    } else if (preserveColors && child.material.map) {
      // If there's a texture but no flat color, sample the dominant color
      color = sampleDominantColor(child.material.map);
    } else {
      color = new THREE.Color(0xcccccc);
    }

    // 2. Dispose old material
    if (child.material.map) child.material.map.dispose();
    child.material.dispose();

    // 3. Create new toon material
    child.material = createToonMaterial(color, { gradientType });

    // 4. Enable shadows
    child.castShadow = true;
    child.receiveShadow = true;
  });

  // 5. Add outlines
  addOutline(model, outlineThickness);

  return model;
}
```

### Dominant Color Sampling

When a GLB has a texture map but the flat `material.color` is white (common
with textured models), extract the dominant color from the texture:

```javascript
function sampleDominantColor(texture) {
  // Create a temporary canvas to read pixel data
  const canvas = document.createElement('canvas');
  const size = 16; // Sample at low res for speed
  canvas.width = size;
  canvas.height = size;
  const ctx = canvas.getContext('2d');

  // Draw texture to canvas
  const img = texture.image;
  if (!img) return new THREE.Color(0xcccccc);
  ctx.drawImage(img, 0, 0, size, size);

  // Read all pixels
  const data = ctx.getImageData(0, 0, size, size).data;
  let r = 0, g = 0, b = 0, count = 0;

  for (let i = 0; i < data.length; i += 4) {
    // Skip near-white and near-black pixels (background/shadow)
    const brightness = (data[i] + data[i+1] + data[i+2]) / 3;
    if (brightness > 240 || brightness < 15) continue;

    r += data[i];
    g += data[i + 1];
    b += data[i + 2];
    count++;
  }

  if (count === 0) return new THREE.Color(0xcccccc);

  return new THREE.Color(
    Math.round(r / count) / 255,
    Math.round(g / count) / 255,
    Math.round(b / count) / 255
  );
}
```

### Toonify Presets

Different object types benefit from different toonify settings:

```javascript
const TOONIFY_PRESETS = {
  vehicle: {
    outlineThickness: 0.035,
    gradientType: 'soft',
    preserveColors: true,
  },
  obstacle: {
    outlineThickness: 0.025,
    gradientType: 'hard',
    preserveColors: true,
  },
  scenery: {
    outlineThickness: 0.02,
    gradientType: 'standard',
    preserveColors: true,
  },
  character: {
    outlineThickness: 0.03,
    gradientType: 'soft',
    preserveColors: true,
  },
  collectible: {
    outlineThickness: 0.02,
    gradientType: 'standard',
    preserveColors: true,
  },
};

// Usage:
const model = await loadGLB('assets/chassis/chassis_bathtub.glb');
toonifyModel(model, TOONIFY_PRESETS.vehicle);
```

### Batch Toonification

When loading many assets at init, process them efficiently:

```javascript
async function toonifyAssetBatch(assetPaths, preset) {
  const promises = assetPaths.map(async (path) => {
    const model = await loadGLB(path);
    toonifyModel(model, preset);
    return { path, model };
  });
  return Promise.all(promises);
}
```

---

## Material Variants

### Metallic Toon (Helmets, Chrome, Metal Parts)

Metal objects should still feel toon-shaded but have a slight reflective
quality. Achieve this with a lighter shadow step:

```javascript
function createMetallicToonMaterial(color) {
  // Custom gradient with higher shadow brightness (simulates reflection)
  const data = new Uint8Array([
    80, 80, 80,     // Shadow is lighter (metallic bounce)
    180, 180, 180,
    255, 255, 255,
  ]);
  const metalGradient = new THREE.DataTexture(data, 3, 1, THREE.RGBFormat);
  metalGradient.minFilter = THREE.NearestFilter;
  metalGradient.magFilter = THREE.NearestFilter;
  metalGradient.needsUpdate = true;

  return new THREE.MeshToonMaterial({
    color: new THREE.Color(color),
    gradientMap: metalGradient,
  });
}
```

### Emissive Toon (Headlights, Boost Flames, Glowing Items)

Objects that emit light but still look cartoony:

```javascript
function createEmissiveToonMaterial(color, glowIntensity = 0.4) {
  return createToonMaterial(color, {
    emissive: color,
    emissiveIntensity: glowIntensity,
    gradientType: 'standard',
  });
}
```

### Transparent Toon (Visors, Windows, Ghost Effects)

```javascript
function createTransparentToonMaterial(color, opacity = 0.5) {
  return createToonMaterial(color, {
    transparent: true,
    opacity: opacity,
    gradientType: 'standard',
    side: THREE.DoubleSide,
  });
}
```

### Flat / Unlit (Ground Markers, Lane Lines, Decals)

Some elements shouldn't respond to lighting at all:

```javascript
function createFlatMaterial(color) {
  return new THREE.MeshBasicMaterial({
    color: new THREE.Color(color),
  });
  // No outline on flat materials
}
```

---

## Recoloring System

The player can change colors on vehicle parts. This requires swapping
material colors without rebuilding the entire mesh.

### Single-Color Recolor

```javascript
function recolorMesh(object, newColor) {
  const color = new THREE.Color(newColor);

  object.traverse((child) => {
    if (!child.isMesh) return;
    if (child.userData.isOutline) return;  // Don't recolor outlines
    if (child.userData.noRecolor) return;  // Opt-out (e.g., hub caps stay silver)

    // Clone material to avoid shared references
    child.material = child.material.clone();
    child.material.color.copy(color);

    // Also update emissive if it was matching the base color
    if (child.material.emissiveIntensity > 0) {
      child.material.emissive.copy(color);
    }
  });
}
```

### Selective Recolor (by Mesh Name)

When a GLB has named sub-meshes, recolor only specific parts:

```javascript
function recolorNamedPart(object, meshName, newColor) {
  object.traverse((child) => {
    if (child.isMesh && child.name === meshName && !child.userData.isOutline) {
      child.material = child.material.clone();
      child.material.color.set(newColor);
    }
  });
}

// Example: recolor just the chassis body, not the frame
recolorNamedPart(vehicleGroup, 'body', '#FF4444');
```

### HSL Color Shifting

For subtle variations (e.g., giving each spectator a slightly different shirt),
shift hue while preserving saturation and lightness:

```javascript
function shiftHue(baseColor, hueOffset) {
  const color = new THREE.Color(baseColor);
  const hsl = {};
  color.getHSL(hsl);
  hsl.h = (hsl.h + hueOffset) % 1;
  color.setHSL(hsl.h, hsl.s, hsl.l);
  return color;
}

// Generate 5 crowd member colors from a base
const crowdColors = [0, 0.15, 0.35, 0.55, 0.75].map(offset =>
  shiftHue('#FF4444', offset)
);
```

---

## Distance-Based LOD for Outlines

At far distances, outlines waste polygons without being visible. Disable
them beyond a threshold:

```javascript
function updateOutlineVisibility(scene, cameraPosition) {
  const MAX_OUTLINE_DISTANCE = 30; // meters
  const SQ_DIST = MAX_OUTLINE_DISTANCE * MAX_OUTLINE_DISTANCE;

  scene.traverse((child) => {
    if (child.userData.isOutline) {
      const parent = child.parent;
      if (parent) {
        const dist = parent.position.distanceToSquared(cameraPosition);
        child.visible = dist < SQ_DIST;
      }
    }
  });
}

// Call once per frame in the render loop (not every frame — every 5th frame):
let frameCount = 0;
function onFrame() {
  frameCount++;
  if (frameCount % 5 === 0) {
    updateOutlineVisibility(scene, camera.position);
  }
}
```

---

## Common Pitfalls

### "The toon shading looks like smooth Phong shading"
**Cause**: `LinearFilter` on the gradient map texture.
**Fix**: Ensure `NearestFilter` on both `minFilter` and `magFilter`.

### "Outlines are inside-out / inverted"
**Cause**: The mesh has negative scale on one axis (common with mirrored
wheels). Negative scale flips the face winding.
**Fix**: Before adding outlines, check for negative scale:
```javascript
function fixNegativeScale(mesh) {
  mesh.traverse((child) => {
    if (child.isMesh) {
      const s = child.getWorldScale(new THREE.Vector3());
      if (s.x * s.y * s.z < 0) {
        child.geometry = child.geometry.clone();
        child.geometry.applyMatrix4(new THREE.Matrix4().makeScale(
          Math.sign(s.x), Math.sign(s.y), Math.sign(s.z)
        ));
      }
    }
  });
}
```

### "GLB model is all white after toonification"
**Cause**: The original material used a texture map with `color: #FFFFFF`.
The toonify pipeline reads the color (white) instead of sampling the texture.
**Fix**: Set `preserveColors: false` and provide an `overrideColor`, or
improve the `sampleDominantColor` function to handle this case.

### "Outlines flicker (z-fighting) on thin geometry"
**Cause**: The outline mesh is too close to the original at thin edges.
**Fix**: Increase outline thickness slightly, or add a small depth bias:
```javascript
outline.renderOrder = -1;
outline.material.depthWrite = true;
outline.material.polygonOffset = true;
outline.material.polygonOffsetFactor = 1;
outline.material.polygonOffsetUnits = 1;
```

### "Performance drops with many outlined objects"
**Cause**: Each outline doubles the draw call count.
**Fix**: Use the distance-based LOD system above. Also consider merging
static outlined geometry using `BufferGeometryUtils.mergeBufferGeometries()`
for scenery that doesn't move or change color.

### "Colors look different on mobile vs desktop"
**Cause**: Different `outputEncoding` or `toneMapping` settings, or the
device has a different color gamut.
**Fix**: Always set these on the renderer:
```javascript
renderer.outputEncoding = THREE.sRGBEncoding;
renderer.toneMapping = THREE.ACESFilmicToneMapping;
renderer.toneMappingExposure = 1.2;
```
