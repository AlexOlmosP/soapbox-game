---
name: soapbox-art-style
description: Enforce the Subway Surfers cartoon art style across all 3D rendering in the Red Bull Soapbox Race HTML game. Use this skill whenever the user asks about the game's visual style, toon shading, cel shading, outlines, color palette, lighting, materials, how to make things look more cartoony, how to make GLB models match the game style, post-processing, visual consistency, or wants to fix anything that looks too realistic, too flat, too dark, or visually inconsistent. Also trigger when the user says the game "doesn't look right", wants to adjust the aesthetic, or mentions Subway Surfers style specifically. This skill is the single source of truth for all visual decisions in the game.
---

# Soapbox Art Style & Toon Shading Skill

This skill is the **visual bible** for the entire game. Every mesh, every
light, every color in the game passes through the rules defined here. The
other skills (vehicle builder, racing engine, game UI) all defer to this
skill for how things should look.

The goal: **make a browser game that feels like Subway Surfers** — vibrant,
chunky, bold, readable at a glance, and full of personality.

Read `toon-shading.md` for the complete Three.js material and outline
implementation, including the toonify pipeline for GLB models.

Read `color-and-lighting.md` for the master color palette, lighting rigs
for every scene type, environment color grading, and rules for visual
consistency.

## The Subway Surfers Aesthetic — Core Principles

### 1. Bold Outlines on Everything

Every 3D object has a visible black outline, like a cartoon cel drawing in
3D space. This is the single most defining visual trait — without outlines,
the game looks like a generic mobile game. With them, it looks like Subway
Surfers.

Implementation: the **inverted hull method** (a scaled-up back-face-only
black mesh behind every object). See `toon-shading.md` for the code.

Outline rules:
- Thickness scales with object importance: vehicles get 3–4% hull scale,
  small decorations get 2%, distant scenery gets 1.5%
- Outline color is always `#222222` (near-black, not pure black — softer)
- Outlines are NOT drawn on ground planes, skybox, or particle effects
- At far distances (>30m), outlines can be disabled for performance

### 2. Flat Color with Hard Shadow Steps

No smooth gradients on surfaces. Colors transition in 2–3 discrete steps:
full lit, half shadow, deep shadow. This is the "toon" or "cel" shading
look. Three.js achieves it with `MeshToonMaterial` and a custom gradient
map texture.

The gradient map has exactly 3 values:
- **Lit** (255): full color
- **Mid** (128): color × 0.7 (shadow edge)
- **Dark** (0): color × 0.4 (deep shadow)

### 3. Chunky Exaggerated Proportions

Nothing in this game is realistically proportioned. Wheels are oversized,
vehicles are stubby and wide, characters have big heads and short bodies,
obstacles are rounder and thicker than real life.

When generating assets with NanoBanana, always specify "chunky exaggerated
proportions" and "toy-like." When building placeholder geometry, round up
dimensions and make things squatter than realistic.

### 4. Vibrant Saturated Colors

The palette is punchy and loud. No pastels, no earth tones, no greys
(except for road and metal). Every object should pop against its neighbors.
See `color-and-lighting.md` for the full palette.

Color rules:
- Primary hues are fully saturated (S: 80–100% in HSL)
- White is used sparingly (highlights, lane markings, eyes)
- Black is only for outlines and deep shadows
- Adjacent objects should contrast in hue (not just brightness)
- The player's vehicle should always be the most colorful thing on screen

### 5. Minimal Texture Detail

Surfaces are mostly flat color. Textures, when present, are stylized
(plank lines on wood, tread blocks on tires) not photographic. If a GLB
model comes from NanoBanana with a detailed texture, the toonify pipeline
strips it and replaces it with a flat toon material using the dominant color.

### 6. Readable Silhouettes

Every object should be identifiable by its silhouette alone. This means:
- Obstacles need distinct shapes (barrel = cylinder, cone = cone, hay = rectangle)
- Chassis types must be visually different even at speed
- The player's vehicle must read clearly against the road
- The outline system helps enormously here

### 7. Consistent Scale

All objects exist in the same scale world. The coordinate system uses meters:
- A vehicle chassis is ~1.2–1.6m long
- A wheel is ~0.3–0.5m diameter
- The driver is ~0.8m tall (seated)
- A traffic cone is ~0.6m tall
- A tree is ~2.5m tall
- The road is ~7m wide (3 lanes at 1.8m spacing + margins)

When generating assets or building placeholders, respect these sizes. An
object that's too large or too small breaks the visual coherence.

## Material Decision Tree

When rendering any object, follow this logic:

```
Is it a ground plane or sky?
  YES → MeshBasicMaterial or MeshStandardMaterial (no toon)
  NO ↓

Is it a UI element (turntable, display platform)?
  YES → MeshStandardMaterial with subtle metallic sheen
  NO ↓

Is it a glow/particle effect (boost flames, coin sparkle)?
  YES → MeshBasicMaterial with additive blending
  NO ↓

Is it any game object (vehicle, obstacle, scenery, character)?
  YES → MeshToonMaterial + outline hull
  NO → Default to MeshToonMaterial
```

## Post-Processing (Optional Enhancement)

For extra visual polish, these post-processing effects can be added.
They are NOT required for the base game but elevate the look:

### FXAA Anti-Aliasing
Smooths jagged edges, especially visible on outlines. Use the
EffectComposer pattern (not available as CDN import in artifacts, but
can be implemented inline).

### Vignette
Subtle darkening at screen edges. Can be done purely in CSS:
```css
.vignette-overlay {
  position: absolute;
  inset: 0;
  pointer-events: none;
  background: radial-gradient(ellipse at center, transparent 60%, rgba(0,0,0,0.3) 100%);
  z-index: 4;
}
```

### Bloom on Collectibles
Coins and power-ups can have a subtle glow. In the absence of a bloom
post-process, fake it with a slightly transparent, scaled-up copy of the
mesh using additive blending:

```javascript
function addFakeBloom(mesh, color = 0xFFDD00) {
  mesh.traverse((child) => {
    if (child.isMesh) {
      const glow = child.clone();
      glow.material = new THREE.MeshBasicMaterial({
        color: color,
        transparent: true,
        opacity: 0.3,
        blending: THREE.AdditiveBlending,
        depthWrite: false,
      });
      glow.scale.multiplyScalar(1.15);
      child.parent.add(glow);
    }
  });
}
```

## Visual Debug Checklist

When reviewing any scene, check every item against this list:

- [ ] Does every game object have a visible dark outline?
- [ ] Are shadow transitions hard-stepped (not smooth gradients)?
- [ ] Is the color palette vibrant (no washed-out or muddy colors)?
- [ ] Can you identify every object by silhouette alone?
- [ ] Is the player's vehicle the most visually prominent thing?
- [ ] Are proportions chunky and exaggerated (not realistic)?
- [ ] Is the scene readable at a glance (not cluttered or noisy)?
- [ ] Do all objects feel like they belong in the same world?
- [ ] Are the lights warm and bright (not cold or dim)?
- [ ] Does the ground/road feel grounded (receiving shadows, not floating)?

## Test Prompts

1. "The game looks too realistic, make it more cartoony like Subway Surfers"
2. "The outlines aren't showing on the obstacles, fix it"
3. "These GLB models I imported look out of place, toonify them"
4. "The colors are too dull, make everything more vibrant"
5. "The lighting feels flat, can you improve it?"
6. "Make the coins glow and the obstacles feel more solid"
7. "The vehicle and the scenery look like they're from different games"
