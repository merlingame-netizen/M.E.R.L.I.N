// neural-renderer.js — 3D Neural Network Visualization for Robot Monitor v5
// Dark void by default. Nodes illuminate when agents/skills activate.
// Pseudo-3D projection on Canvas 2D. No external dependencies.
(function () {
  'use strict';

  // ── NEURAL STATES ──
  var NSTATE = {
    DORMANT: 0,     // invisible
    ACTIVATING: 1,  // fading in (0.5s)
    ACTIVE: 2,      // full glow, pulsing
    COMPLETING: 3,  // burst, fade out (1.5s)
    AFTERGLOW: 4,   // dim (5s then dormant)
    ERROR: 5        // red pulse, jitter
  };

  // ── NEURAL CAMERA ──
  function NeuralCamera() {
    this.azimuth = 0;
    this.elevation = 0.3;
    this.distance = 400;
    this.focalLength = 300;
    this.autoRotateSpeed = 0.08; // rad/s
    this.isDragging = false;
    this.dragStartAz = 0;
    this.dragStartEl = 0;
    this.dragStartX = 0;
    this.dragStartY = 0;
    this.targetAzimuth = null; // for smooth return after drag
    this.returnTimer = 0;
    this._cosA = 1; this._sinA = 0;
    this._cosE = Math.cos(0.3); this._sinE = Math.sin(0.3);
  }

  NeuralCamera.prototype.update = function (dt) {
    if (this.isDragging) {
      this.returnTimer = 0;
    } else if (this.returnTimer > 0) {
      this.returnTimer -= dt;
      // don't auto-rotate while returning
    } else {
      this.azimuth += this.autoRotateSpeed * dt;
    }
    this._cosA = Math.cos(this.azimuth);
    this._sinA = Math.sin(this.azimuth);
    this._cosE = Math.cos(this.elevation);
    this._sinE = Math.sin(this.elevation);
  };

  NeuralCamera.prototype.project = function (wx, wy, wz, canvasW, canvasH) {
    var rx = wx * this._cosA - wz * this._sinA;
    var rz = wx * this._sinA + wz * this._cosA;
    var ry = wy * this._cosE - rz * this._sinE;
    rz = wy * this._sinE + rz * this._cosE;

    var z = rz + this.distance;
    if (z < 1) return null;

    var scale = this.focalLength / z;
    return {
      x: canvasW * 0.5 + rx * scale,
      y: canvasH * 0.45 - ry * scale,
      scale: scale,
      depth: z
    };
  };

  NeuralCamera.prototype.startDrag = function (mx, my) {
    this.isDragging = true;
    this.dragStartAz = this.azimuth;
    this.dragStartEl = this.elevation;
    this.dragStartX = mx;
    this.dragStartY = my;
  };

  NeuralCamera.prototype.drag = function (mx, my) {
    if (!this.isDragging) return;
    this.azimuth = this.dragStartAz + (mx - this.dragStartX) * 0.01;
    this.elevation = this.dragStartEl + (my - this.dragStartY) * 0.005;
    if (this.elevation < -0.5) this.elevation = -0.5;
    if (this.elevation > 0.8) this.elevation = 0.8;
  };

  NeuralCamera.prototype.endDrag = function () {
    this.isDragging = false;
    this.returnTimer = 3.0; // 3s pause before auto-rotate resumes
  };

  // ── NEURAL NODE ──
  function NeuralNode(entity) {
    this.entity = entity;
    this.wx = 0; this.wy = 0; this.wz = 0; // 3D world position
    this.sx = 0; this.sy = 0; this.sScale = 1; this.depth = 0; // projected
    this.nstate = NSTATE.DORMANT;
    this.opacity = 0;
    this.targetOpacity = 0;
    this.glowRadius = 0;
    this.pulsePhase = Math.random() * Math.PI * 2;
    this.activateTimer = 0;
    this.afterglowTimer = 0;
    this.burstParticles = [];
    this.jitterX = 0; this.jitterY = 0;
    this.baseRadius = entity.type === 'skill' ? 2.5 : 4;
    this.color = '#00ff41';
    this.isSkill = entity.type === 'skill';
    this._prevEntityState = null;
    this._impulsesSpawned = false; // one-shot flag per activation
    this.sparkles = [];        // continuous scintillation particles
    this._sparkleTimer = 0.15 + Math.random() * 0.1; // initial cooldown before first sparkle
    this._nextImpulseTime = Math.random() * 2.0; // stagger periodic impulses across nodes
  }

  NeuralNode.prototype.setColor = function (color) {
    this.color = color;
  };

  NeuralNode.prototype.update = function (dt) {
    // Detect entity state changes
    var entityActive = this.entity.isActive;
    var entityState = this.entity.state; // 0=IDLE,1=WORKING,3=DONE,4=ERROR

    if (entityActive && (this.nstate === NSTATE.DORMANT || this.nstate === NSTATE.AFTERGLOW || this.nstate === NSTATE.COMPLETING)) {
      // Activate (or re-activate from fading states)
      this.nstate = (entityState === 4) ? NSTATE.ERROR : NSTATE.ACTIVATING;
      this.activateTimer = 0;
      this.targetOpacity = 1;
      this._impulsesSpawned = false;
    } else if (!entityActive && (this.nstate === NSTATE.ACTIVE || this.nstate === NSTATE.ERROR)) {
      // Deactivate
      this.nstate = NSTATE.COMPLETING;
      this.activateTimer = 0;
      this.targetOpacity = 0.3;
      this.sparkles = []; // clear sparkles — burst takes over
      this._spawnBurst();
    } else if (entityActive && entityState === 4 && this.nstate !== NSTATE.ERROR) {
      this.nstate = NSTATE.ERROR;
    } else if (entityActive && entityState !== 4 && this.nstate === NSTATE.ERROR) {
      this.nstate = NSTATE.ACTIVE;
    }

    // State machine
    switch (this.nstate) {
      case NSTATE.DORMANT:
        this.opacity = Math.max(0, this.opacity - dt * 2);
        break;

      case NSTATE.ACTIVATING:
        this.activateTimer += dt;
        this.opacity = Math.min(1, this.activateTimer / 0.5);
        this.glowRadius = this.activateTimer * 40;
        if (this.activateTimer >= 0.5) {
          this.nstate = NSTATE.ACTIVE;
          this.opacity = 1;
        }
        break;

      case NSTATE.ACTIVE:
        this.opacity = 1;
        this.pulsePhase += dt * 8; // 2.5x faster pulse (1.27 Hz)
        this.glowRadius = 0;
        // Spawn sparkle particles continuously while active
        this._sparkleTimer -= dt;
        if (this._sparkleTimer <= 0) {
          this._spawnSparkle();
          this._sparkleTimer = 0.15 + Math.random() * 0.1; // 4-7 sparkles/s
        }
        break;

      case NSTATE.COMPLETING:
        this.activateTimer += dt;
        this.opacity = 1 - (this.activateTimer / 1.5) * 0.7;
        if (this.activateTimer >= 1.5) {
          this.nstate = NSTATE.AFTERGLOW;
          this.afterglowTimer = 5;
          this.opacity = 0.3;
        }
        break;

      case NSTATE.AFTERGLOW:
        this.afterglowTimer -= dt;
        if (this.afterglowTimer <= 0) {
          this.nstate = NSTATE.DORMANT;
          this.opacity = 0.3;
          this.targetOpacity = 0;
        } else if (this.afterglowTimer < 1) {
          this.opacity = 0.3 * this.afterglowTimer;
        }
        break;

      case NSTATE.ERROR:
        this.opacity = 1;
        this.pulsePhase += dt * 6;
        this.jitterX = (Math.random() - 0.5) * 2;
        this.jitterY = (Math.random() - 0.5) * 2;
        break;
    }

    // Update burst particles
    for (var bi = this.burstParticles.length - 1; bi >= 0; bi--) {
      var bp = this.burstParticles[bi];
      bp.life -= dt;
      bp.x += bp.vx * dt;
      bp.y += bp.vy * dt;
      if (bp.life <= 0) this.burstParticles.splice(bi, 1);
    }

    // Update sparkles (continuous scintillation)
    for (var si = this.sparkles.length - 1; si >= 0; si--) {
      var sp = this.sparkles[si];
      sp.life -= dt;
      sp.x += sp.vx * dt;
      sp.y += sp.vy * dt;
      sp.vx *= 0.95; // friction
      sp.vy *= 0.95;
      if (sp.life <= 0) this.sparkles.splice(si, 1);
    }
  };

  NeuralNode.prototype._spawnBurst = function () {
    if (this.burstParticles.length > 16) return; // cap burst particles
    for (var i = 0; i < 8; i++) {
      var angle = (i / 8) * Math.PI * 2;
      this.burstParticles.push({
        x: 0, y: 0,
        vx: Math.cos(angle) * 30,
        vy: Math.sin(angle) * 30,
        life: 0.6
      });
    }
  };

  NeuralNode.prototype._spawnSparkle = function () {
    if (this.sparkles.length >= 6) return; // cap concurrent sparkles
    var angle = Math.random() * Math.PI * 2;
    var speed = 12 + Math.random() * 18;
    var lifetime = 0.4 + Math.random() * 0.3;
    this.sparkles.push({
      x: 0, y: 0,
      vx: Math.cos(angle) * speed,
      vy: Math.sin(angle) * speed,
      life: lifetime,
      maxLife: lifetime,
      size: 0.6 + Math.random() * 1.0,
      phase: Math.random() * Math.PI * 2 // independent flicker phase
    });
  };

  NeuralNode.prototype.isVisible = function () {
    return this.opacity > 0.01;
  };

  NeuralNode.prototype.draw = function (ctx, neuralTheme) {
    if (!this.isVisible()) return;

    var x = this.sx + this.jitterX;
    var y = this.sy + this.jitterY;
    var r = this.baseRadius * this.sScale;
    var alpha = this.opacity;
    var color = this.nstate === NSTATE.ERROR ? '#ff3333' : this.color;

    // Outer glow — boosted when ACTIVE
    var glowAlpha = 0.15;
    var glowMult = 4;
    if (this.nstate === NSTATE.ACTIVE) {
      glowAlpha = 0.25 + 0.1 * Math.sin(this.pulsePhase * 0.7); // pulsating glow
      glowMult = 5;
    }
    ctx.save();
    ctx.globalAlpha = alpha * glowAlpha;
    var glowR = r * glowMult;
    var grad = ctx.createRadialGradient(x, y, r * 0.5, x, y, glowR);
    grad.addColorStop(0, color);
    grad.addColorStop(1, 'transparent');
    ctx.fillStyle = grad;
    ctx.beginPath();
    ctx.arc(x, y, glowR, 0, Math.PI * 2);
    ctx.fill();
    ctx.restore();

    // Activating ring
    if (this.nstate === NSTATE.ACTIVATING && this.glowRadius > 0) {
      ctx.save();
      ctx.globalAlpha = alpha * 0.3 * (1 - this.activateTimer / 0.5);
      ctx.strokeStyle = color;
      ctx.lineWidth = 1.5;
      ctx.beginPath();
      ctx.arc(x, y, this.glowRadius * this.sScale, 0, Math.PI * 2);
      ctx.stroke();
      ctx.restore();
    }

    // Active pulse rings (double, dephased)
    if (this.nstate === NSTATE.ACTIVE) {
      // Ring 1 — primary, boosted amplitude
      var pulseR = r * (1.8 + 0.7 * Math.sin(this.pulsePhase));
      ctx.save();
      ctx.globalAlpha = alpha * 0.25;
      ctx.strokeStyle = color;
      ctx.lineWidth = 1.2;
      ctx.beginPath();
      ctx.arc(x, y, pulseR, 0, Math.PI * 2);
      ctx.stroke();
      ctx.restore();

      // Ring 2 — secondary, dephased, larger
      var pulseR2 = r * (2.2 + 0.5 * Math.sin(this.pulsePhase + Math.PI));
      ctx.save();
      ctx.globalAlpha = alpha * 0.12;
      ctx.strokeStyle = color;
      ctx.lineWidth = 0.7;
      ctx.beginPath();
      ctx.arc(x, y, pulseR2, 0, Math.PI * 2);
      ctx.stroke();
      ctx.restore();
    }

    // Core shape
    ctx.save();
    ctx.globalAlpha = alpha * 0.9;
    ctx.fillStyle = color;
    if (this.isSkill) {
      // Diamond shape for skills
      ctx.beginPath();
      ctx.moveTo(x, y - r);
      ctx.lineTo(x + r, y);
      ctx.lineTo(x, y + r);
      ctx.lineTo(x - r, y);
      ctx.closePath();
      ctx.fill();
    } else {
      // Circle for agents
      ctx.beginPath();
      ctx.arc(x, y, r, 0, Math.PI * 2);
      ctx.fill();
    }
    ctx.restore();

    // Inner bright spot
    ctx.save();
    ctx.globalAlpha = alpha * 0.8;
    ctx.fillStyle = '#ffffff';
    ctx.beginPath();
    ctx.arc(x, y, r * 0.35, 0, Math.PI * 2);
    ctx.fill();
    ctx.restore();

    // Burst particles
    for (var bi = 0; bi < this.burstParticles.length; bi++) {
      var bp = this.burstParticles[bi];
      ctx.save();
      ctx.globalAlpha = bp.life * 0.8;
      ctx.fillStyle = color;
      ctx.beginPath();
      ctx.arc(x + bp.x, y + bp.y, 1.5 * this.sScale, 0, Math.PI * 2);
      ctx.fill();
      ctx.restore();
    }

    // Sparkle particles (continuous scintillation while active)
    if (this.sparkles.length > 0) {
      ctx.save();
      ctx.fillStyle = '#ffffff';
      for (var si = 0; si < this.sparkles.length; si++) {
        var sp = this.sparkles[si];
        var sparkleAlpha = (sp.life / sp.maxLife);
        // Twinkle effect: flicker with per-particle phase offset
        sparkleAlpha *= 0.5 + 0.5 * Math.sin(sp.life * 20 + sp.phase);
        ctx.globalAlpha = Math.max(0, sparkleAlpha * 0.9);
        ctx.beginPath();
        ctx.arc(x + sp.x, y + sp.y, sp.size * this.sScale, 0, Math.PI * 2);
        ctx.fill();
      }
      ctx.restore();
    }
  };

  NeuralNode.prototype.hitTest = function (mx, my) {
    var dx = mx - this.sx;
    var dy = my - this.sy;
    var hitR = Math.max(8, this.baseRadius * this.sScale * 2);
    return dx * dx + dy * dy < hitR * hitR;
  };

  // ── NEURAL CONNECTION ──
  function NeuralConnection(nodeA, nodeB) {
    this.a = nodeA;
    this.b = nodeB;
    this.impulses = [];
  }

  NeuralConnection.prototype.isVisible = function () {
    return this.a.isVisible() && this.b.isVisible();
  };

  NeuralConnection.prototype.spawnImpulse = function (fromNode) {
    if (this.impulses.length >= 3) return; // max per connection
    this.impulses.push({
      progress: 0,
      speed: 1.2,
      forward: fromNode === this.a
    });
  };

  NeuralConnection.prototype.update = function (dt) {
    for (var i = this.impulses.length - 1; i >= 0; i--) {
      this.impulses[i].progress += this.impulses[i].speed * dt;
      if (this.impulses[i].progress >= 1) this.impulses.splice(i, 1);
    }
  };

  NeuralConnection.prototype.draw = function (ctx, neuralTheme) {
    if (!this.isVisible()) return;

    var alphaA = this.a.opacity;
    var alphaB = this.b.opacity;
    var lineAlpha = Math.min(alphaA, alphaB) * 0.25;

    // Depth fade: farther connections dimmer
    var avgDepth = (this.a.depth + this.b.depth) * 0.5;
    var depthFade = Math.max(0.3, 1 - (avgDepth - 300) / 400);
    lineAlpha *= depthFade;

    // Connection line
    ctx.save();
    ctx.globalAlpha = lineAlpha;
    ctx.strokeStyle = neuralTheme.impulse || '#00e5ff';
    ctx.lineWidth = 0.5;
    ctx.beginPath();
    ctx.moveTo(this.a.sx, this.a.sy);
    ctx.lineTo(this.b.sx, this.b.sy);
    ctx.stroke();
    ctx.restore();

    // Draw impulses
    for (var i = 0; i < this.impulses.length; i++) {
      var imp = this.impulses[i];
      var t = imp.forward ? imp.progress : 1 - imp.progress;
      var ix = this.a.sx + (this.b.sx - this.a.sx) * t;
      var iy = this.a.sy + (this.b.sy - this.a.sy) * t;

      // Main dot
      ctx.save();
      ctx.globalAlpha = (1 - imp.progress) * 0.9 * depthFade;
      ctx.fillStyle = neuralTheme.impulse || '#00e5ff';
      ctx.beginPath();
      ctx.arc(ix, iy, 2, 0, Math.PI * 2);
      ctx.fill();

      // Trail (3 dots)
      for (var ti = 1; ti <= 3; ti++) {
        var tt = t - ti * 0.05 * (imp.forward ? 1 : -1);
        if (tt < 0 || tt > 1) continue;
        var tx = this.a.sx + (this.b.sx - this.a.sx) * tt;
        var ty = this.a.sy + (this.b.sy - this.a.sy) * tt;
        ctx.globalAlpha = (1 - imp.progress) * 0.3 * (1 - ti * 0.25) * depthFade;
        ctx.beginPath();
        ctx.arc(tx, ty, 1.2, 0, Math.PI * 2);
        ctx.fill();
      }
      ctx.restore();
    }
  };

  // ── NEURAL LAYOUT ──
  var NeuralLayout = {
    // Fibonacci sphere distribution
    fibonacciSphere: function (n, radius) {
      var points = [];
      var goldenAngle = Math.PI * (3 - Math.sqrt(5));
      for (var i = 0; i < n; i++) {
        var theta = Math.acos(1 - 2 * (i + 0.5) / n);
        var phi = goldenAngle * i;
        points.push({
          x: radius * Math.sin(theta) * Math.cos(phi),
          y: radius * Math.sin(theta) * Math.sin(phi) * 0.6, // compress Y for sidebar
          z: radius * Math.cos(theta)
        });
      }
      return points;
    },

    compute: function (nodes, catOrder, catColors) {
      // Separate agents and skills
      var catGroups = {};
      var skillNodes = [];
      for (var i = 0; i < nodes.length; i++) {
        var n = nodes[i];
        if (n.isSkill) {
          skillNodes.push(n);
        } else {
          var cat = n.entity.category || 'general';
          if (!catGroups[cat]) catGroups[cat] = [];
          catGroups[cat].push(n);
        }
      }

      // Active categories
      var activeCats = [];
      for (var ci = 0; ci < catOrder.length; ci++) {
        if (catGroups[catOrder[ci]] && catGroups[catOrder[ci]].length > 0) {
          activeCats.push(catOrder[ci]);
        }
      }

      // Place category centroids on Fibonacci sphere
      var clusterR = 120;
      var catCenters = this.fibonacciSphere(activeCats.length, clusterR);

      // Place agents within each category cluster
      var agentR = 25;
      for (var gi = 0; gi < activeCats.length; gi++) {
        var catName = activeCats[gi];
        var group = catGroups[catName];
        var center = catCenters[gi];
        var color = catColors[catName] || '#00ff41';

        if (group.length === 1) {
          group[0].wx = center.x;
          group[0].wy = center.y;
          group[0].wz = center.z;
          group[0].setColor(color);
        } else {
          var subPoints = this.fibonacciSphere(group.length, agentR);
          for (var ai = 0; ai < group.length; ai++) {
            group[ai].wx = center.x + subPoints[ai].x;
            group[ai].wy = center.y + subPoints[ai].y;
            group[ai].wz = center.z + subPoints[ai].z;
            group[ai].setColor(color);
          }
        }
      }

      // Place skills on outer orbital ring
      var skillR = 170;
      if (skillNodes.length > 0) {
        var skillPoints = this.fibonacciSphere(skillNodes.length, skillR);
        for (var si = 0; si < skillNodes.length; si++) {
          skillNodes[si].wx = skillPoints[si].x;
          skillNodes[si].wy = skillPoints[si].y;
          skillNodes[si].wz = skillPoints[si].z;
          skillNodes[si].setColor('#66bbff');
        }
      }

      return { activeCats: activeCats, catCenters: catCenters, catGroups: catGroups, skillNodes: skillNodes };
    }
  };

  // ── NEURAL THEMES ──
  var NEURAL_THEMES = {
    merlin: { void: '#020305', glow: '#00ff41', impulse: '#00e5ff', burst: '#ffb300', nebula: '#00ff41' },
    data:   { void: '#050200', glow: '#FF7900', impulse: '#ffb300', burst: '#ff3333', nebula: '#FF7900' },
    cours:  { void: '#020208', glow: '#4488ff', impulse: '#66bbff', burst: '#aa44ff', nebula: '#4488ff' }
  };

  // ── NEURAL RENDERER (main class) ──
  function NeuralRenderer() {
    this.camera = new NeuralCamera();
    this.nodes = [];
    this.connections = [];
    this.nodeMap = {}; // name → NeuralNode
    this.initialized = false;
    this.canvasW = 300;
    this.canvasH = 600;
    this.theme = NEURAL_THEMES.merlin;
    this.hoveredNode = null;
    this.pinnedNode = null;
    this._layoutData = null;
    this._totalImpulses = 0;
    this._time = 0;
    this._sortedNodes = [];  // pre-allocated sort buffer
    this._sortedConns = [];  // pre-allocated sort buffer
  }

  NeuralRenderer.prototype.init = function (entities, catOrder, catColors, projectId) {
    this.nodes = [];
    this.connections = [];
    this.nodeMap = {};

    this.theme = NEURAL_THEMES[projectId] || NEURAL_THEMES.merlin;

    // Create NeuralNodes wrapping DataBridge entities.
    // IMPORTANT: NeuralNode holds a direct reference to each entity object.
    // DataBridge must mutate entities in place (not replace them) for state sync to work.
    for (var i = 0; i < entities.length; i++) {
      var node = new NeuralNode(entities[i]);
      this.nodes.push(node);
      this.nodeMap[entities[i].name] = node;
    }

    // Compute 3D layout
    this._layoutData = NeuralLayout.compute(this.nodes, catOrder, catColors);

    // Build connections
    this._buildConnections();

    // Pre-allocate sort buffers
    this._sortedNodes = this.nodes.slice();
    this._sortedConns = this.connections.slice();

    this.initialized = true;
  };

  NeuralRenderer.prototype._buildConnections = function () {
    this.connections = [];
    var ld = this._layoutData;
    if (!ld) return;

    // Intra-category connections (all agents in same category connect to first agent as hub)
    for (var ci = 0; ci < ld.activeCats.length; ci++) {
      var catName = ld.activeCats[ci];
      var group = ld.catGroups[catName];
      if (!group || group.length < 2) continue;
      var hub = group[0];
      for (var ai = 1; ai < group.length; ai++) {
        this.connections.push(new NeuralConnection(hub, group[ai]));
      }
    }

    // Inter-category connections (nearest category pairs)
    for (var i = 0; i < ld.activeCats.length; i++) {
      var catA = ld.catGroups[ld.activeCats[i]];
      if (!catA || catA.length === 0) continue;
      var nodeA = catA[0];

      // Connect to next category (ring topology)
      var nextIdx = (i + 1) % ld.activeCats.length;
      var catB = ld.catGroups[ld.activeCats[nextIdx]];
      if (catB && catB.length > 0) {
        this.connections.push(new NeuralConnection(nodeA, catB[0]));
      }
    }

    // Skills connect to 1-2 related agent categories (simplified: connect to nearest agent)
    for (var si = 0; si < ld.skillNodes.length; si++) {
      var skill = ld.skillNodes[si];
      var nearestDist = Infinity;
      var nearestAgent = null;
      for (var ni = 0; ni < this.nodes.length; ni++) {
        if (this.nodes[ni].isSkill) continue;
        var dx = skill.wx - this.nodes[ni].wx;
        var dy = skill.wy - this.nodes[ni].wy;
        var dz = skill.wz - this.nodes[ni].wz;
        var dist = dx * dx + dy * dy + dz * dz;
        if (dist < nearestDist) {
          nearestDist = dist;
          nearestAgent = this.nodes[ni];
        }
      }
      if (nearestAgent) {
        this.connections.push(new NeuralConnection(skill, nearestAgent));
      }
    }
  };

  NeuralRenderer.prototype.resize = function (w, h) {
    this.canvasW = w;
    this.canvasH = h;
  };

  NeuralRenderer.prototype.setTheme = function (projectId) {
    this.theme = NEURAL_THEMES[projectId] || NEURAL_THEMES.merlin;
  };

  NeuralRenderer.prototype.hitTest = function (mx, my) {
    // Test visible nodes first (near to far for priority)
    var best = null;
    var bestDist = Infinity;
    for (var i = 0; i < this.nodes.length; i++) {
      var n = this.nodes[i];
      if (!n.hitTest(mx, my)) continue;
      // Ghost hit: allow hitting dormant nodes (will show ghost)
      if (n.depth < bestDist) {
        bestDist = n.depth;
        best = n;
      }
    }
    this.hoveredNode = best;
    return best;
  };

  NeuralRenderer.prototype.tick = function (ctx, dt) {
    if (!this.initialized) return;

    this._time += dt;
    var w = this.canvasW;
    var h = this.canvasH;
    var theme = this.theme;

    // Update camera
    this.camera.update(dt);

    // Project all nodes
    for (var i = 0; i < this.nodes.length; i++) {
      var n = this.nodes[i];
      n.update(dt);
      var p = this.camera.project(n.wx, n.wy, n.wz, w, h);
      if (p) {
        n.sx = p.x;
        n.sy = p.y;
        n.sScale = p.scale;
        n.depth = p.depth;
      }
    }

    // Update connections
    this._totalImpulses = 0;
    for (var ci = 0; ci < this.connections.length; ci++) {
      this.connections[ci].update(dt);
      this._totalImpulses += this.connections[ci].impulses.length;
    }

    // Spawn impulses when nodes activate (check periodically)
    this._maybeSpawnImpulses();

    // ── RENDER LAYERS ──

    // 1. Background void
    ctx.fillStyle = theme.void;
    ctx.fillRect(0, 0, w, h);

    // 2. Nebula (subtle center glow)
    ctx.save();
    ctx.globalAlpha = 0.12;
    var nebGrad = ctx.createRadialGradient(w * 0.5, h * 0.45, 0, w * 0.5, h * 0.45, w * 0.6);
    nebGrad.addColorStop(0, theme.nebula);
    nebGrad.addColorStop(1, 'transparent');
    ctx.fillStyle = nebGrad;
    ctx.fillRect(0, 0, w, h);
    ctx.restore();

    // 2.5. Ghost constellation — all dormant nodes as faint points
    ctx.save();
    for (var gi = 0; gi < this._sortedNodes.length; gi++) {
      var gn = this._sortedNodes[gi];
      if (gn.isVisible()) continue; // skip visible nodes (drawn later with full glow)
      var gr = gn.baseRadius * gn.sScale * 0.6;
      if (gr < 0.3) continue;
      ctx.globalAlpha = gn.isSkill ? 0.12 : 0.18;
      ctx.fillStyle = gn.color;
      if (gn.isSkill) {
        ctx.beginPath();
        ctx.moveTo(gn.sx, gn.sy - gr);
        ctx.lineTo(gn.sx + gr, gn.sy);
        ctx.lineTo(gn.sx, gn.sy + gr);
        ctx.lineTo(gn.sx - gr, gn.sy);
        ctx.closePath();
        ctx.fill();
      } else {
        ctx.beginPath();
        ctx.arc(gn.sx, gn.sy, gr, 0, Math.PI * 2);
        ctx.fill();
      }
    }
    ctx.restore();

    // 2.6. Ghost connections — faint lines between dormant nodes
    ctx.save();
    ctx.globalAlpha = 0.06;
    ctx.strokeStyle = theme.impulse;
    ctx.lineWidth = 0.5;
    for (var gci = 0; gci < this.connections.length; gci++) {
      var gc = this.connections[gci];
      if (gc.isVisible()) continue; // skip visible connections (drawn later)
      ctx.beginPath();
      ctx.moveTo(gc.a.sx, gc.a.sy);
      ctx.lineTo(gc.b.sx, gc.b.sy);
      ctx.stroke();
    }
    ctx.restore();

    // 3. Connections (depth-sorted, reuse pre-allocated buffer)
    this._sortedConns.sort(function (a, b) {
      return (b.a.depth + b.b.depth) - (a.a.depth + a.b.depth);
    });
    for (var di = 0; di < this._sortedConns.length; di++) {
      this._sortedConns[di].draw(ctx, theme);
    }

    // 4. Nodes (depth-sorted: far to near, reuse pre-allocated buffer)
    this._sortedNodes.sort(function (a, b) {
      return b.depth - a.depth;
    });
    for (var ni = 0; ni < this._sortedNodes.length; ni++) {
      this._sortedNodes[ni].draw(ctx, theme);
    }

    // 5. Ghost outline for hovered dormant node
    if (this.hoveredNode && !this.hoveredNode.isVisible()) {
      var gn = this.hoveredNode;
      var gr = gn.baseRadius * gn.sScale;
      ctx.save();
      ctx.globalAlpha = 0.15;
      ctx.strokeStyle = gn.color;
      ctx.lineWidth = 0.5;
      ctx.beginPath();
      if (gn.isSkill) {
        ctx.moveTo(gn.sx, gn.sy - gr);
        ctx.lineTo(gn.sx + gr, gn.sy);
        ctx.lineTo(gn.sx, gn.sy + gr);
        ctx.lineTo(gn.sx - gr, gn.sy);
        ctx.closePath();
      } else {
        ctx.arc(gn.sx, gn.sy, gr, 0, Math.PI * 2);
      }
      ctx.stroke();
      ctx.restore();
    }

    // 6. Tooltip for hovered/pinned node
    var tooltipNode = this.pinnedNode || this.hoveredNode;
    if (tooltipNode) {
      this._drawTooltip(ctx, tooltipNode, w, h);
    }

    // 7. Footer: active count
    var activeCount = 0;
    for (var ai = 0; ai < this.nodes.length; ai++) {
      if (this.nodes[ai].isVisible()) activeCount++;
    }
    this._drawFooter(ctx, activeCount, w, h);
  };

  NeuralRenderer.prototype._spawnNodeImpulses = function (node) {
    for (var ci = 0; ci < this.connections.length; ci++) {
      var conn = this.connections[ci];
      if (conn.a === node || conn.b === node) {
        var other = conn.a === node ? conn.b : conn.a;
        if (other.isVisible() && conn.impulses.length < 3) { // check cap before spawning
          conn.spawnImpulse(node);
          this._totalImpulses++;
          if (this._totalImpulses >= 30) return;
        }
      }
    }
  };

  NeuralRenderer.prototype._maybeSpawnImpulses = function () {
    if (this._totalImpulses >= 30) return; // cap raised 20→30

    for (var i = 0; i < this.nodes.length; i++) {
      var n = this.nodes[i];

      // One-shot impulses on activation (existing behavior)
      if (n.nstate === NSTATE.ACTIVATING && !n._impulsesSpawned) {
        n._impulsesSpawned = true;
        this._spawnNodeImpulses(n);
      }

      // Periodic impulses while ACTIVE (continuous network activity)
      if (n.nstate === NSTATE.ACTIVE && this._time >= n._nextImpulseTime) {
        this._spawnNodeImpulses(n);
        n._nextImpulseTime = this._time + 1.5 + Math.random(); // 1.5-2.5s interval
      }

      if (this._totalImpulses >= 30) return;
    }
  };

  NeuralRenderer.prototype._drawTooltip = function (ctx, node, canvasW, canvasH) {
    var e = node.entity;
    var name = (e.name || 'unknown').toUpperCase();
    var type = node.isSkill ? 'SKILL' : (e.category || 'AGENT').toUpperCase();
    var task = e.currentTask ? e.currentTask.substring(0, 40).toUpperCase() : '';
    var state = node.nstate === NSTATE.ACTIVE ? 'ACTIVE' :
                node.nstate === NSTATE.ERROR ? 'ERROR' :
                node.nstate === NSTATE.ACTIVATING ? 'ACTIVATING' :
                node.nstate === NSTATE.COMPLETING ? 'COMPLETING' :
                node.nstate === NSTATE.AFTERGLOW ? 'FADING' : 'DORMANT';

    // Use the pixel font from RobotMonitor
    var drawTextFn = window.RobotMonitor ? window.RobotMonitor.drawText : null;
    var textWidthFn = window.RobotMonitor ? window.RobotMonitor.textWidth : null;
    if (!drawTextFn || !textWidthFn) return;

    var s = 1; // font scale
    var lineH = 7;
    var lines = [name, type + ' | ' + state];
    if (task) lines.push(task);
    if (e.progress > 0) lines.push('PROGRESS: ' + e.progress + '%');
    if (e.invocationCount > 0) lines.push('INVOCATIONS: ' + e.invocationCount);

    var maxW = 0;
    for (var li = 0; li < lines.length; li++) {
      var lw = textWidthFn(lines[li], s);
      if (lw > maxW) maxW = lw;
    }

    var padX = 6, padY = 4;
    var boxW = maxW + padX * 2;
    var boxH = lines.length * lineH + padY * 2;

    // Position: above node, clamped to canvas
    var bx = Math.max(2, Math.min(canvasW - boxW - 2, node.sx - boxW * 0.5));
    var by = node.sy - boxH - 12;
    if (by < 2) by = node.sy + 12;

    // Background panel
    ctx.save();
    ctx.globalAlpha = 0.85;
    ctx.fillStyle = '#0a0a0a';
    ctx.fillRect(bx, by, boxW, boxH);

    // Border glow
    ctx.globalAlpha = 0.6;
    ctx.strokeStyle = node.color;
    ctx.lineWidth = 1;
    ctx.strokeRect(bx, by, boxW, boxH);
    ctx.restore();

    // Text lines
    for (var ti = 0; ti < lines.length; ti++) {
      var tColor = ti === 0 ? node.color : (ti === 1 ? '#888888' : '#666666');
      drawTextFn(ctx, lines[ti], bx + padX, by + padY + ti * lineH, tColor, s);
    }
  };

  NeuralRenderer.prototype._drawFooter = function (ctx, activeCount, w, h) {
    var drawTextFn = window.RobotMonitor ? window.RobotMonitor.drawText : null;
    if (!drawTextFn) return;

    var label = this.nodes.length + ' NODES';
    if (activeCount > 0) {
      label += ' | ' + activeCount + ' ACTIVE';
    } else {
      label += ' | AWAITING ACTIVITY...';
    }
    label += ' | NEURAL';

    drawTextFn(ctx, label, 4, h - 8, '#444444', 1);
  };

  // ── BUBBLE MANAGER ──
  // Enriched info bubbles that appear above active nodes
  var BubbleManager = {
    bubbles: [],       // { node, opacity, targetOpacity, startTime }
    scaleFactor: 1.0,  // 1.0 → 0.6 based on bubble count
    _activationTimes: {}, // name → timestamp of activation

    update: function (nodes, dt, time) {
      var activeNodes = [];
      for (var i = 0; i < nodes.length; i++) {
        var n = nodes[i];
        if (n.nstate === NSTATE.ACTIVE || n.nstate === NSTATE.ACTIVATING || n.nstate === NSTATE.ERROR) {
          activeNodes.push(n);
          // Track activation time
          var key = n.entity.name;
          if (!this._activationTimes[key]) {
            this._activationTimes[key] = time;
          }
        }
      }

      // Clean up deactivated entries
      var activeNames = {};
      for (var ai = 0; ai < activeNodes.length; ai++) {
        activeNames[activeNodes[ai].entity.name] = true;
      }
      for (var name in this._activationTimes) {
        if (!activeNames[name]) delete this._activationTimes[name];
      }

      // Compute scale factor: shrink bubbles when many active
      var count = activeNodes.length;
      this.scaleFactor = count <= 3 ? 1.0 : Math.max(0.6, 1.0 - (count - 3) * 0.08);

      // Sync bubble list with active nodes
      var bubbleMap = {};
      for (var bi = 0; bi < this.bubbles.length; bi++) {
        bubbleMap[this.bubbles[bi].node.entity.name] = this.bubbles[bi];
      }

      var newBubbles = [];
      for (var ni = 0; ni < activeNodes.length; ni++) {
        var node = activeNodes[ni];
        var existing = bubbleMap[node.entity.name];
        if (existing) {
          existing.targetOpacity = 1;
          existing.opacity = Math.min(1, existing.opacity + dt * 3.3); // 0.3s fade-in
          newBubbles.push(existing);
        } else {
          newBubbles.push({ node: node, opacity: 0, targetOpacity: 1 });
        }
      }

      // Fade out removed bubbles
      for (var ri = 0; ri < this.bubbles.length; ri++) {
        var b = this.bubbles[ri];
        if (!activeNames[b.node.entity.name]) {
          b.targetOpacity = 0;
          b.opacity = Math.max(0, b.opacity - dt * 2); // 0.5s fade-out
          if (b.opacity > 0.01) newBubbles.push(b);
        }
      }

      this.bubbles = newBubbles;
    },

    draw: function (ctx, canvasW, canvasH, time) {
      var drawTextFn = window.RobotMonitor ? window.RobotMonitor.drawText : null;
      var textWidthFn = window.RobotMonitor ? window.RobotMonitor.textWidth : null;
      if (!drawTextFn || !textWidthFn) return;

      var s = this.scaleFactor;
      var fontScale = Math.max(1, Math.round(s));

      // Collect bubble rects for collision avoidance
      var rects = [];

      for (var i = 0; i < this.bubbles.length; i++) {
        var b = this.bubbles[i];
        var node = b.node;
        var e = node.entity;
        if (b.opacity < 0.01) continue;

        var name = (e.name || '?').toUpperCase();
        if (name.length > 18) name = name.substring(0, 16) + '..';
        var task = e.currentTask ? e.currentTask.substring(0, 25).toUpperCase() : '';
        var durStr = '';
        var actTime = this._activationTimes[e.name];
        if (actTime) {
          var elapsed = Math.round(time - actTime);
          durStr = elapsed < 60 ? elapsed + 'S' : Math.round(elapsed / 60) + 'M';
        }
        var invocStr = e.invocationCount > 0 ? 'X' + e.invocationCount : '';
        var line3 = (durStr && invocStr) ? durStr + ' | ' + invocStr : durStr + invocStr;

        // Compute size
        var lineH = 7 * s;
        var lines = [name];
        if (task) lines.push(task);
        if (line3) lines.push(line3);

        var maxW = 0;
        for (var li = 0; li < lines.length; li++) {
          var lw = textWidthFn(lines[li], fontScale);
          if (lw > maxW) maxW = lw;
        }

        var padX = 5 * s;
        var padY = 3 * s;
        var boxW = Math.min(140 * s, maxW + padX * 2);
        var boxH = lines.length * lineH + padY * 2;

        // Position: above node, clamped to canvas
        var bx = Math.max(2, Math.min(canvasW - boxW - 2, node.sx - boxW * 0.5));
        var by = node.sy - boxH - 14 * s;
        if (by < 2) by = node.sy + 14 * s;

        // Collision avoidance: push up/down if overlapping
        for (var ri = 0; ri < rects.length; ri++) {
          var r = rects[ri];
          if (bx < r.x + r.w && bx + boxW > r.x && by < r.y + r.h && by + boxH > r.y) {
            by = r.y - boxH - 2; // push above
            if (by < 2) by = r.y + r.h + 2; // push below if off-screen
          }
        }
        rects.push({ x: bx, y: by, w: boxW, h: boxH });

        // Draw bubble background
        ctx.save();
        ctx.globalAlpha = b.opacity * 0.85;
        ctx.fillStyle = '#0a0a0a';
        ctx.fillRect(bx, by, boxW, boxH);

        // Border glow (node color)
        ctx.globalAlpha = b.opacity * 0.7;
        ctx.strokeStyle = node.color;
        ctx.lineWidth = s;
        ctx.strokeRect(bx, by, boxW, boxH);

        // Connecting line from bubble to node
        ctx.globalAlpha = b.opacity * 0.3;
        ctx.beginPath();
        ctx.moveTo(bx + boxW * 0.5, by + boxH);
        ctx.lineTo(node.sx, node.sy);
        ctx.stroke();
        ctx.restore();

        // Text lines
        ctx.save();
        ctx.globalAlpha = b.opacity;
        for (var ti = 0; ti < lines.length; ti++) {
          var tColor = ti === 0 ? node.color : (ti === 1 ? '#888888' : '#555555');
          drawTextFn(ctx, lines[ti], bx + padX, by + padY + ti * lineH, tColor, fontScale);
        }
        ctx.restore();
      }
    }
  };

  // ── DELEGATION CONNECTIONS (Parent → Child traces) ──
  NeuralRenderer.prototype.setParentMap = function (map) {
    if (!this.initialized || !map) return;
    this._parentMap = map;

    // Create or update ephemeral delegation connections
    // Remove old delegation connections
    var kept = [];
    for (var ci = 0; ci < this.connections.length; ci++) {
      if (!this.connections[ci]._isDelegation) {
        kept.push(this.connections[ci]);
      }
    }
    this.connections = kept;

    // Add new delegation connections for active parent→child pairs
    for (var childName in map) {
      if (!map.hasOwnProperty(childName)) continue;
      var parentName = map[childName];
      var childNode = this.nodeMap[childName];
      var parentNode = this.nodeMap[parentName];
      if (!childNode || !parentNode) continue;
      // Only show when at least one is active
      if (!childNode.isVisible() && !parentNode.isVisible()) continue;

      var conn = new NeuralConnection(parentNode, childNode);
      conn._isDelegation = true;
      conn._delegationBright = true;
      this.connections.push(conn);

      // Spawn bright impulse from parent to child
      if (childNode.nstate === NSTATE.ACTIVE || childNode.nstate === NSTATE.ACTIVATING) {
        conn.spawnImpulse(parentNode);
      }
    }

    // Update sort buffers
    this._sortedConns = this.connections.slice();
  };

  // Override connection draw for delegation connections (brighter)
  var _origConnDraw = NeuralConnection.prototype.draw;
  NeuralConnection.prototype.draw = function (ctx, neuralTheme) {
    if (this._isDelegation) {
      // Brighter line for delegation
      var aVis = this.a.isVisible();
      var bVis = this.b.isVisible();
      if (!aVis && !bVis) return;
      var depthFade = 1.0; // no depth fade for delegation
      ctx.save();
      ctx.globalAlpha = 0.5;
      ctx.strokeStyle = neuralTheme.burst || '#ffb300';
      ctx.lineWidth = 1.2;
      ctx.beginPath();
      ctx.moveTo(this.a.sx, this.a.sy);
      ctx.lineTo(this.b.sx, this.b.sy);
      ctx.stroke();
      // Draw impulses with burst color
      for (var ii = 0; ii < this.impulses.length; ii++) {
        var imp = this.impulses[ii];
        var t = imp.forward ? imp.progress : (1 - imp.progress);
        var ix = this.a.sx + (this.b.sx - this.a.sx) * t;
        var iy = this.a.sy + (this.b.sy - this.a.sy) * t;
        ctx.globalAlpha = (1 - imp.progress) * 0.9;
        ctx.fillStyle = neuralTheme.burst || '#ffb300';
        ctx.beginPath();
        ctx.arc(ix, iy, 3, 0, Math.PI * 2);
        ctx.fill();
      }
      ctx.restore();
    } else {
      _origConnDraw.call(this, ctx, neuralTheme);
    }
  };

  // ── INTEGRATE BUBBLES INTO TICK ──
  var _origTick = NeuralRenderer.prototype.tick;
  NeuralRenderer.prototype.tick = function (ctx, dt) {
    _origTick.call(this, ctx, dt);
    if (!this.initialized) return;
    // Update and draw bubbles after everything else
    BubbleManager.update(this.nodes, dt, this._time);
    BubbleManager.draw(ctx, this.canvasW, this.canvasH, this._time);
  };

  // ── EXPORT ──
  window.NeuralRenderer = NeuralRenderer;
  window.NeuralRendererModule = {
    NeuralRenderer: NeuralRenderer,
    NeuralCamera: NeuralCamera,
    NeuralNode: NeuralNode,
    NeuralConnection: NeuralConnection,
    NeuralLayout: NeuralLayout,
    NSTATE: NSTATE,
    NEURAL_THEMES: NEURAL_THEMES,
    BubbleManager: BubbleManager
  };
})();
