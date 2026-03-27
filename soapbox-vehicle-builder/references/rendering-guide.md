# Three.js Rendering Guide — Soapbox Race

How to set up, light, and render vehicles and game objects in Three.js r128
with a Subway Surfers cartoon art style.

## Table of Contents
1. [Scene & Renderer Setup](#scene--renderer-setup)
2. [Lighting Rig](#lighting-rig)
3. [Toon Shading Strategy](#toon-shading-strategy)
4. [Placeholder Geometry Library](#placeholder-geometry-library)
5. [GLB Asset Integration](#glb-asset-integration)
6. [Vehicle Assembly Pipeline](#vehicle-assembly-pipeline)
7. [Race View Camera & Rendering](#race-view-camera--rendering)
8. [Performance Budget](#performance-budget)

---

## Scene & Renderer Setup

```javascript
const renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true });
renderer.setSize(window.innerWidth, window.innerHeight);
renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
renderer.shadowMap.enabled = true;
renderer.shadowMap.type = THREE.PCFSoftShadowMap;
renderer.outputEncoding = THREE.sRGBEncoding;
renderer.toneMapping = THREE.ACESFilmicToneMapping;
renderer.toneMappingExposure = 1.2;

const scene = new THREE.Scene();
scene.background = new THREE.Color(0x87CEEB); // Sky blue
scene.fog = new THREE.Fog(0x87CEEB, 30, 80);  // Depth fog for race mode

const camera = new THREE.PerspectiveCamera(
  45, window.innerWidth / window.innerHeight, 0.1, 100
);
```

### Resize Handling
```javascript
window.addEventListener('resize', () => {
  camera.aspect = window.innerWidth / window.innerHeight;
  camera.updateProjectionMatrix();
  renderer.setSize(window.innerWidth, window.innerHeight);
});
```

---

## Lighting Rig

Three lights give the Subway Surfers bright, readable look:

```javascript
// 1. Ambient fill — prevents pure black shadows
const ambient = new THREE.AmbientLight(0xffffff, 0.5);
scene.add(ambient);

// 2. Key light — main directional, casts shadows
const keyLight = new THREE.DirectionalLight(0xffffff, 0.9);
keyLight.position.set(5, 8, 3);
keyLight.castShadow = true;
keyLight.shadow.mapSize.set(1024, 1024);
keyLight.shadow.camera.near = 0.5;
keyLight.shadow.camera.far = 30;
keyLight.shadow.camera.left = -5;
keyLight.shadow.camera.right = 5;
keyLight.shadow.camera.top = 5;
keyLight.shadow.camera.bottom = -5;
scene.add(keyLight);

// 3. Hemisphere — sky/ground color gradient for natural feel
const hemiLight = new THREE.HemisphereLight(0x87CEEB, 0xB97A20, 0.35);
scene.add(hemiLight);
```

For the **garage/builder** scene, use a warmer setup:
```javascript
scene.background = new THREE.Color(0x2a2a3e); // Dark interior
const garageFill = new THREE.AmbientLight(0xfff4e0, 0.4);
const spotLight = new THREE.SpotLight(0xffffff, 1.0, 10, Math.PI / 4, 0.5);
spotLight.position.set(0, 4, 2);
spotLight.castShadow = true;
```

---

## Toon Shading Strategy

The Subway Surfers look requires bold, flat colors with hard shadow edges.
Three.js r128 offers `MeshToonMaterial` which does exactly this:

```javascript
// Create a 3-step gradient map for toon shading
const gradientMap = new THREE.DataTexture(
  new Uint8Array([0, 0, 0, 128, 128, 128, 255, 255, 255]),
  3, 1, THREE.RGBFormat
);
gradientMap.minFilter = THREE.NearestFilter;
gradientMap.magFilter = THREE.NearestFilter;
gradientMap.needsUpdate = true;

function createToonMaterial(color) {
  return new THREE.MeshToonMaterial({
    color: color,
    gradientMap: gradientMap,
  });
}
```

### Outline Effect (Bold Cartoon Outlines)

Subway Surfers uses visible black outlines. Achieve this with the
**inverted hull method** — a slightly scaled-up copy of the mesh with
back-face rendering and a black material:

```javascript
function addOutline(mesh, thickness = 0.03) {
  const outlineMat = new THREE.MeshBasicMaterial({
    color: 0x222222,
    side: THREE.BackSide,
  });

  mesh.traverse((child) => {
    if (child.isMesh) {
      const outline = child.clone();
      outline.material = outlineMat;
      outline.scale.multiplyScalar(1 + thickness);
      outline.castShadow = false;
      outline.receiveShadow = false;
      child.parent.add(outline);
    }
  });
}
```

### Applying Toon Style to GLB Models

When loading GLB assets, their materials will be `MeshStandardMaterial`.
Convert them to toon style:

```javascript
function toonifyModel(model) {
  model.traverse((child) => {
    if (child.isMesh && child.material) {
      const origColor = child.material.color
        ? child.material.color.clone()
        : new THREE.Color(0xcccccc);
      child.material = createToonMaterial(origColor);
      child.castShadow = true;
      child.receiveShadow = true;
    }
  });
  addOutline(model);
}
```

---

## Placeholder Geometry Library

Use these when GLB assets aren't available yet. Each returns a `THREE.Group`.

### Chassis Dimensions
```javascript
const CHASSIS_DIMS = {
  bathtub:  { w: 1.2, h: 0.5, d: 0.7 },
  rocket:   { w: 1.6, h: 0.4, d: 0.5 },
  shoe:     { w: 1.3, h: 0.6, d: 0.7 },
  box:      { w: 1.0, h: 0.5, d: 0.6 },
  banana:   { w: 1.5, h: 0.5, d: 0.5 },
  couch:    { w: 1.1, h: 0.6, d: 0.7 },
};

const WHEEL_RADIUS = {
  chunky:  0.18,
  skinny:  0.22,
  monster: 0.28,
  wagon:   0.20,
  roller:  0.10,
};
```

### Placeholder Builders

```javascript
function buildPlaceholderChassis(type, color) {
  const d = CHASSIS_DIMS[type];
  const group = new THREE.Group();

  // Main body
  const bodyGeo = new THREE.BoxGeometry(d.w, d.h, d.d);
  const bodyMat = createToonMaterial(color);
  const body = new THREE.Mesh(bodyGeo, bodyMat);
  body.position.y = d.h / 2;
  body.castShadow = true;
  group.add(body);

  // Type-specific extras
  if (type === 'rocket') {
    // Nose cone
    const noseGeo = new THREE.ConeGeometry(d.d / 2, 0.4, 8);
    noseGeo.rotateZ(-Math.PI / 2);
    const nose = new THREE.Mesh(noseGeo, bodyMat);
    nose.position.set(-d.w / 2 - 0.2, d.h / 2, 0);
    group.add(nose);
  } else if (type === 'banana') {
    // Curve the box — scale it to look like a crescent
    body.scale.set(1, 0.7, 1);
    body.rotation.z = 0.15;
  }

  addOutline(group);
  return group;
}

function buildPlaceholderWheel(type, color) {
  const r = WHEEL_RADIUS[type];
  const group = new THREE.Group();

  // Tire
  const tireGeo = new THREE.CylinderGeometry(r, r, 0.12, 16);
  tireGeo.rotateZ(Math.PI / 2);
  const tire = new THREE.Mesh(tireGeo, createToonMaterial(color));
  group.add(tire);

  // Hub
  const hubGeo = new THREE.CylinderGeometry(r * 0.4, r * 0.4, 0.13, 12);
  hubGeo.rotateZ(Math.PI / 2);
  const hub = new THREE.Mesh(hubGeo, createToonMaterial(0xcccccc));
  group.add(hub);

  addOutline(group, 0.02);
  return group;
}

function buildPlaceholderDriver(helmetColor) {
  const group = new THREE.Group();

  // Body (cylinder torso)
  const bodyGeo = new THREE.CylinderGeometry(0.12, 0.15, 0.3, 8);
  const bodyMat = createToonMaterial(0x4488ff);
  const body = new THREE.Mesh(bodyGeo, bodyMat);
  body.position.y = 0.15;
  group.add(body);

  // Helmet (sphere)
  const helmetGeo = new THREE.SphereGeometry(0.14, 12, 8);
  const helmet = new THREE.Mesh(helmetGeo, createToonMaterial(helmetColor));
  helmet.position.y = 0.38;
  group.add(helmet);

  // Visor
  const visorGeo = new THREE.SphereGeometry(0.08, 8, 4, 0, Math.PI);
  const visor = new THREE.Mesh(visorGeo, createToonMaterial(0x222222));
  visor.position.set(0, 0.36, 0.1);
  group.add(visor);

  addOutline(group, 0.02);
  return group;
}

function buildPlaceholderDecoration(slot, type, color) {
  const group = new THREE.Group();
  const mat = createToonMaterial(color);

  if (type === 'flag' || type === 'tailflag') {
    const stickGeo = new THREE.CylinderGeometry(0.01, 0.01, 0.3, 4);
    group.add(new THREE.Mesh(stickGeo, createToonMaterial(0x666666)));
    const flagGeo = new THREE.BufferGeometry();
    const verts = new Float32Array([0,0.15,0, 0.15,0.1,0, 0,0.05,0]);
    flagGeo.setAttribute('position', new THREE.BufferAttribute(verts, 3));
    flagGeo.computeVertexNormals();
    const flag = new THREE.Mesh(flagGeo, mat);
    flag.material.side = THREE.DoubleSide;
    group.add(flag);
  } else if (type === 'crown') {
    const crownGeo = new THREE.CylinderGeometry(0.1, 0.12, 0.08, 3);
    group.add(new THREE.Mesh(crownGeo, mat));
  } else if (type === 'eyes') {
    [-0.06, 0.06].forEach(x => {
      const eyeGeo = new THREE.SphereGeometry(0.05, 8, 8);
      const eye = new THREE.Mesh(eyeGeo, createToonMaterial(0xffffff));
      eye.position.x = x;
      group.add(eye);
      const pupilGeo = new THREE.SphereGeometry(0.025, 6, 6);
      const pupil = new THREE.Mesh(pupilGeo, createToonMaterial(0x111111));
      pupil.position.set(x, 0, 0.04);
      group.add(pupil);
    });
  } else {
    const geo = new THREE.BoxGeometry(0.15, 0.1, 0.08);
    group.add(new THREE.Mesh(geo, mat));
  }

  addOutline(group, 0.02);
  return group;
}
```

---

## GLB Asset Integration

### Loading Pipeline

```javascript
// Minimal GLTFLoader approach for artifacts
async function loadGLB(url) {
  const response = await fetch(url);
  const buffer = await response.arrayBuffer();

  return new Promise((resolve) => {
    const loader = new THREE.GLTFLoader();
    loader.parse(buffer, '', (gltf) => {
      const model = gltf.scene;
      toonifyModel(model);  // Convert to cartoon style
      resolve(model);
    });
  });
}
```

### Asset Manager with Caching

```javascript
class AssetManager {
  constructor(basePath = 'assets/') {
    this.basePath = basePath;
    this.cache = new Map();
    this.loading = new Map();
  }

  async get(category, type) {
    const path = this.resolvePath(category, type);

    if (this.cache.has(path)) {
      return this.cache.get(path).clone();
    }

    if (this.loading.has(path)) {
      const model = await this.loading.get(path);
      return model.clone();
    }

    const promise = loadGLB(this.basePath + path);
    this.loading.set(path, promise);

    const model = await promise;
    this.cache.set(path, model);
    this.loading.delete(path);
    return model.clone();
  }

  resolvePath(category, type) {
    const paths = {
      chassis: `chassis/chassis_${type}.glb`,
      wheels:  `wheels/wheel_${type}.glb`,
      top:     `decorations/top/deco_top_${type}.glb`,
      side:    `decorations/side/deco_side_${type}.glb`,
      front:   `decorations/front/deco_front_${type}.glb`,
      back:    `decorations/back/deco_back_${type}.glb`,
      helmet:  `driver/helmet_${type}.glb`,
      driver:  `driver/driver_body.glb`,
      goggles: `driver/goggles.glb`,
    };
    return paths[category];
  }
}
```

---

## Vehicle Assembly Pipeline

Complete function to rebuild the vehicle from a data model:

```javascript
async function assembleVehicle(vehicleData, vehicleGroup, assets, usePlaceholders) {
  // Clear previous
  while (vehicleGroup.children.length) {
    vehicleGroup.remove(vehicleGroup.children[0]);
  }

  const chassisType = vehicleData.chassis.type;
  const points = ATTACHMENT_POINTS[chassisType];

  // 1. Chassis
  const chassis = usePlaceholders
    ? buildPlaceholderChassis(chassisType, vehicleData.chassis.color)
    : await assets.get('chassis', chassisType);
  if (!usePlaceholders) recolorMesh(chassis, vehicleData.chassis.color);
  chassis.name = 'chassis';
  vehicleGroup.add(chassis);

  // 2. Wheels (4 instances)
  const wheelPositions = ['wheelFL', 'wheelFR', 'wheelBL', 'wheelBR'];
  for (const pos of wheelPositions) {
    const wheel = usePlaceholders
      ? buildPlaceholderWheel(vehicleData.wheels.type, vehicleData.wheels.color)
      : await assets.get('wheels', vehicleData.wheels.type);
    if (!usePlaceholders) recolorMesh(wheel, vehicleData.wheels.color);
    wheel.name = pos;
    wheel.position.copy(points[pos]);
    if (pos.endsWith('R')) wheel.scale.x *= -1;
    vehicleGroup.add(wheel);
  }

  // 3. Driver
  const driver = usePlaceholders
    ? buildPlaceholderDriver(vehicleData.driver.helmetColor)
    : await assets.get('driver', 'body');
  driver.name = 'driver';
  driver.position.copy(points.driver);
  vehicleGroup.add(driver);

  // 4. Helmet on driver
  if (!usePlaceholders) {
    const helmet = await assets.get('helmet', vehicleData.driver.helmet);
    recolorMesh(helmet, vehicleData.driver.helmetColor);
    helmet.name = 'helmet';
    helmet.position.y = 0.28;
    driver.add(helmet);
  }

  // 5. Decorations
  for (const deco of vehicleData.decorations) {
    const decoMesh = usePlaceholders
      ? buildPlaceholderDecoration(deco.slot, deco.type, deco.color)
      : await assets.get(deco.slot, deco.type);
    if (!usePlaceholders) recolorMesh(decoMesh, deco.color);
    decoMesh.name = `deco_${deco.slot}`;
    decoMesh.position.copy(points[deco.slot]);
    vehicleGroup.add(decoMesh);
  }

  // 6. Ground shadow
  const shadowGeo = new THREE.CircleGeometry(0.7, 16);
  shadowGeo.rotateX(-Math.PI / 2);
  const shadowMat = new THREE.MeshBasicMaterial({
    color: 0x000000, transparent: true, opacity: 0.15,
  });
  const shadow = new THREE.Mesh(shadowGeo, shadowMat);
  shadow.position.y = 0.01;
  shadow.receiveShadow = false;
  vehicleGroup.add(shadow);
}

function recolorMesh(mesh, newColor) {
  mesh.traverse((child) => {
    if (child.isMesh && child.material) {
      child.material = child.material.clone();
      child.material.color.set(newColor);
    }
  });
}
```

---

## Race View Camera & Rendering

In race mode the camera is behind and above the vehicle (third-person chase):

```javascript
const CHASE_OFFSET = new THREE.Vector3(0, 2.5, 4);
const CHASE_LOOKAT = new THREE.Vector3(0, 0.5, -3);

function updateChaseCamera(camera, vehiclePosition) {
  const target = vehiclePosition.clone().add(CHASE_OFFSET);
  camera.position.lerp(target, 0.1);
  const lookTarget = vehiclePosition.clone().add(CHASE_LOOKAT);
  camera.lookAt(lookTarget);
}
```

In race mode, simplify rendering for performance:
- Disable outline pass on distant objects
- Use lower shadow map resolution (512×512)
- Cull objects beyond 60m
- Instance repeated scenery (trees, fences, crowd)

---

## Performance Budget

| Element          | Target     | Notes                                |
|------------------|------------|--------------------------------------|
| Total scene tris | < 50,000   | Includes track, vehicle, obstacles   |
| Vehicle          | < 10,000   | Chassis + wheels + decos + driver    |
| Single obstacle  | < 2,000    | Instanced where possible             |
| Scenery item     | < 1,500    | Trees, buildings, fences             |
| Draw calls       | < 80       | Merge static scenery into batches    |
| Texture memory   | < 32 MB    | Max 1024×1024 per asset              |
| Frame rate       | 60 FPS     | Target on mid-range mobile           |
| Load time        | < 3s       | Lazy-load non-critical assets        |

### Optimization Techniques
- Use `InstancedMesh` for repeated objects (coins, trees, crowd)
- Merge static scenery into `BufferGeometryUtils.mergeBufferGeometries()`
- LOD: swap to simpler geometry beyond 20m distance
- Texture atlasing: combine small decoration textures into one sheet
- Frustum culling is automatic in Three.js — just keep scene graph clean
