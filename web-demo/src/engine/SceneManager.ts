// ═══════════════════════════════════════════════════════════════════════════════
// Scene Manager — Three.js scene lifecycle, renderer, lighting
// ═══════════════════════════════════════════════════════════════════════════════

import { ACESFilmicToneMapping, AmbientLight, Clock, Color, DirectionalLight, FogExp2, HemisphereLight, PCFSoftShadowMap, PerspectiveCamera, Scene, WebGLRenderer } from 'three';

export class SceneManager {
  readonly scene: Scene;
  readonly renderer: WebGLRenderer;
  readonly camera: PerspectiveCamera;
  private animationId = 0;
  private running = false; // C126/VIS-01: guards start() against double-invoke from visibilitychange
  private readonly callbacks: Array<(dt: number) => void> = [];
  private clock = new Clock();
  // C81-01: stored so dispose() can remove it (window.resize leaks per run without this)
  private readonly onResize: () => void;
  // C126/VIS-01: pause RAF when tab hidden — stops GPU/CPU burn during inactive sessions
  private readonly onVisibilityChange: () => void;

  constructor(container: HTMLElement) {
    // Scene
    this.scene = new Scene();
    this.scene.background = new Color(0x1a2a3a);
    this.scene.fog = new FogExp2(0x1a2a3a, 0.015);

    // Camera
    this.camera = new PerspectiveCamera(
      55,
      container.clientWidth / container.clientHeight,
      0.1,
      500
    );
    this.camera.position.set(0, 3, 10);

    // Renderer
    this.renderer = new WebGLRenderer({
      antialias: true,
      alpha: false,
    });
    this.renderer.setSize(container.clientWidth, container.clientHeight);
    this.renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
    this.renderer.shadowMap.enabled = true;
    this.renderer.shadowMap.type = PCFSoftShadowMap;
    this.renderer.toneMapping = ACESFilmicToneMapping;
    this.renderer.toneMappingExposure = 0.9;
    container.appendChild(this.renderer.domElement);
    this.renderer.domElement.setAttribute('role', 'img');
    this.renderer.domElement.setAttribute('aria-label', 'Scène 3D — Chemin celtique de Merlin, paysage breton animé');

    // Lighting
    this.setupLighting();

    // Resize — stored as instance field so dispose() can remove it
    this.onResize = () => {
      this.camera.aspect = container.clientWidth / container.clientHeight;
      this.camera.updateProjectionMatrix();
      this.renderer.setSize(container.clientWidth, container.clientHeight);
    };
    window.addEventListener('resize', this.onResize);

    // C126/VIS-01: pause render loop when tab is hidden, resume when visible.
    // Prevents GPU/CPU burn (rAF still fires at ~4fps in background tabs in Chrome).
    this.onVisibilityChange = () => {
      if (document.hidden) { this.stop(); } else { this.start(); }
    };
    document.addEventListener('visibilitychange', this.onVisibilityChange);
  }

  private setupLighting(): void {
    // Ambient
    const ambient = new AmbientLight(0x6688aa, 0.4);
    this.scene.add(ambient);

    // Hemisphere (sky/ground)
    const hemi = new HemisphereLight(0x87ceeb, 0x3a5f3a, 0.5);
    this.scene.add(hemi);

    // Directional (sun)
    const sun = new DirectionalLight(0xffeedd, 1.2);
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

  /** Start the render loop. No-op if already running (safe to call from visibilitychange). */
  start(): void {
    if (this.running) return; // C126/VIS-01: prevent double-loop on rapid visibility events
    this.running = true;
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
    this.running = false;
    cancelAnimationFrame(this.animationId);
  }

  dispose(): void {
    this.stop();
    window.removeEventListener('resize', this.onResize);
    document.removeEventListener('visibilitychange', this.onVisibilityChange); // C126/VIS-01
    this.renderer.dispose();
  }
}
