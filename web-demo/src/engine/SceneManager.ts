// ═══════════════════════════════════════════════════════════════════════════════
// Scene Manager — Three.js scene lifecycle, renderer, lighting
// ═══════════════════════════════════════════════════════════════════════════════

import * as THREE from 'three';

export class SceneManager {
  readonly scene: THREE.Scene;
  readonly renderer: THREE.WebGLRenderer;
  readonly camera: THREE.PerspectiveCamera;
  private animationId = 0;
  private readonly callbacks: Array<(dt: number) => void> = [];
  private clock = new THREE.Clock();

  constructor(container: HTMLElement) {
    // Scene
    this.scene = new THREE.Scene();
    this.scene.background = new THREE.Color(0x1a2a3a);
    this.scene.fog = new THREE.FogExp2(0x1a2a3a, 0.015);

    // Camera
    this.camera = new THREE.PerspectiveCamera(
      55,
      container.clientWidth / container.clientHeight,
      0.1,
      500
    );
    this.camera.position.set(0, 3, 10);

    // Renderer
    this.renderer = new THREE.WebGLRenderer({
      antialias: true,
      alpha: false,
    });
    this.renderer.setSize(container.clientWidth, container.clientHeight);
    this.renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
    this.renderer.shadowMap.enabled = true;
    this.renderer.shadowMap.type = THREE.PCFSoftShadowMap;
    this.renderer.toneMapping = THREE.ACESFilmicToneMapping;
    this.renderer.toneMappingExposure = 0.9;
    container.appendChild(this.renderer.domElement);
    this.renderer.domElement.setAttribute('role', 'img');
    this.renderer.domElement.setAttribute('aria-label', 'Scène 3D — Chemin celtique de Merlin, paysage breton animé');

    // Lighting
    this.setupLighting();

    // Resize
    const onResize = () => {
      this.camera.aspect = container.clientWidth / container.clientHeight;
      this.camera.updateProjectionMatrix();
      this.renderer.setSize(container.clientWidth, container.clientHeight);
    };
    window.addEventListener('resize', onResize);
  }

  private setupLighting(): void {
    // Ambient
    const ambient = new THREE.AmbientLight(0x6688aa, 0.4);
    this.scene.add(ambient);

    // Hemisphere (sky/ground)
    const hemi = new THREE.HemisphereLight(0x87ceeb, 0x3a5f3a, 0.5);
    this.scene.add(hemi);

    // Directional (sun)
    const sun = new THREE.DirectionalLight(0xffeedd, 1.2);
    sun.position.set(20, 30, 15);
    sun.castShadow = true;
    sun.shadow.mapSize.width = 2048;
    sun.shadow.mapSize.height = 2048;
    sun.shadow.camera.near = 0.5;
    sun.shadow.camera.far = 100;
    sun.shadow.camera.left = -30;
    sun.shadow.camera.right = 30;
    sun.shadow.camera.top = 30;
    sun.shadow.camera.bottom = -30;
    this.scene.add(sun);
  }

  /** Register a callback to run every frame. */
  onUpdate(callback: (dt: number) => void): void {
    this.callbacks.push(callback);
  }

  /** Start the render loop. */
  start(): void {
    const animate = () => {
      this.animationId = requestAnimationFrame(animate);
      const dt = this.clock.getDelta();
      for (const cb of this.callbacks) {
        cb(dt);
      }
      this.renderer.render(this.scene, this.camera);
    };
    animate();
  }

  /** Stop the render loop. */
  stop(): void {
    cancelAnimationFrame(this.animationId);
  }

  dispose(): void {
    this.stop();
    this.renderer.dispose();
  }
}
