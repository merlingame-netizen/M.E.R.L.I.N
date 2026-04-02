// ═══════════════════════════════════════════════════════════════════════════════
// Camera Rail — Spline-based auto-walk camera for 3D biome traversal
// ═══════════════════════════════════════════════════════════════════════════════

import * as THREE from 'three';

// T063 bob-head constants — 2 Hz frequency, 0.04 amplitude
const BOB_FREQUENCY = 2.0;  // Hz
const BOB_AMPLITUDE = 0.04; // world units vertical

export class CameraRail {
  private readonly curve: THREE.CatmullRomCurve3;
  private progress = 0;
  private speed = 0.008; // Progress per second (0-1 range)
  private paused = false;
  private readonly lookOffset = new THREE.Vector3(0, 0.3, 0);
  private elapsedMoving = 0; // accumulated time while not paused (for bob)

  constructor(points: THREE.Vector3[]) {
    this.curve = new THREE.CatmullRomCurve3(points, false, 'catmullrom', 0.5);
  }

  /** Create a default coastal rail path. */
  static createCoastalPath(): CameraRail {
    return new CameraRail([
      new THREE.Vector3(0, 2, 20),
      new THREE.Vector3(5, 2.5, 15),
      new THREE.Vector3(8, 3, 8),
      new THREE.Vector3(5, 3.5, 2),
      new THREE.Vector3(0, 3, -5),
      new THREE.Vector3(-5, 2.5, -12),
      new THREE.Vector3(-8, 2, -20),
      new THREE.Vector3(-3, 2.5, -28),
      new THREE.Vector3(2, 3, -35),
    ]);
  }

  /** Create a default forest rail path. */
  static createForestPath(): CameraRail {
    return new CameraRail([
      new THREE.Vector3(0, 1.8, 25),
      new THREE.Vector3(3, 2, 18),
      new THREE.Vector3(-2, 2.2, 10),
      new THREE.Vector3(4, 2.5, 3),
      new THREE.Vector3(0, 2.3, -5),
      new THREE.Vector3(-4, 2, -13),
      new THREE.Vector3(2, 2.2, -22),
      new THREE.Vector3(0, 2.5, -30),
    ]);
  }

  setSpeed(speed: number): void {
    this.speed = speed;
  }

  pause(): void {
    this.paused = true;
  }

  resume(): void {
    this.paused = false;
  }

  isPaused(): boolean {
    return this.paused;
  }

  getProgress(): number {
    return this.progress;
  }

  /** Returns true if the camera has reached the end of the path. */
  isComplete(): boolean {
    return this.progress >= 1;
  }

  /** Reset progress to start. */
  reset(): void {
    this.progress = 0;
    this.paused = false;
    this.elapsedMoving = 0;
  }

  /** Update camera position along the spline. T063: bob-head Y offset applied. */
  update(camera: THREE.PerspectiveCamera, dt: number): void {
    if (this.paused || this.progress >= 1) return;

    this.elapsedMoving += dt;
    // Velocity fade-in: ramp from 50% to 100% speed over first 3 seconds
    const velocityScale = Math.min(1, 0.5 + this.elapsedMoving / 6);
    this.progress = Math.min(1, this.progress + this.speed * dt * velocityScale);

    const position = this.curve.getPointAt(this.progress);

    // T063: Bob-head — sinusoidal Y offset simulating walking motion
    const bob = Math.sin(this.elapsedMoving * BOB_FREQUENCY * Math.PI * 2) * BOB_AMPLITUDE;
    position.y += bob;

    camera.position.copy(position);

    // Look ahead on the curve — 0.08 lookahead avoids upward tilt at rail start
    const lookProgress = Math.min(1, this.progress + 0.08);
    const lookAt = this.curve.getPointAt(lookProgress);
    lookAt.add(this.lookOffset);
    camera.lookAt(lookAt);
  }

  /** Get a debug visualization of the path. */
  createDebugLine(): THREE.Line {
    const points = this.curve.getPoints(100);
    const geometry = new THREE.BufferGeometry().setFromPoints(points);
    const material = new THREE.LineBasicMaterial({ color: 0xff8800, opacity: 0.5, transparent: true });
    return new THREE.Line(geometry, material);
  }
}
