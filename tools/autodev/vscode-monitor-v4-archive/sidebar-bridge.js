// sidebar-bridge.js — Canvas ↔ Extension Bridge for Neural Monitor Sidebar v1.0
(function () {
  'use strict';

  var vscode = acquireVsCodeApi();
  var SB = window.SidebarBridge;
  var NRM = window.NeuralRendererModule;
  if (!SB || !NRM) { console.error('[sidebar-bridge] Missing dependencies'); return; }

  var DataBridge = SB.DataBridge;
  var NeuralRenderer = NRM.NeuralRenderer;
  var NeuralLayout = NRM.NeuralLayout;
  var NSTATE = NRM.NSTATE;

  // ── STATE ──
  var renderer = new NeuralRenderer();
  var canvas = null;
  var ctx = null;
  var animFrame = null;
  var lastTime = 0;
  var _prevRosterHash = '';
  var _prevRosterNames = new Set();
  var _projectId = 'merlin'; // default, updated from extension

  // Category ordering & colors for layout
  var CAT_ORDER = ['gameplay', 'llm-lora', 'ui-ux', 'data', 'review', 'planning', 'general'];
  var CAT_COLORS = {
    'gameplay': '#ffb300', 'llm-lora': '#00ff41', 'ui-ux': '#00e5ff',
    'data': '#FF7900', 'review': '#44ff88', 'planning': '#aa44ff', 'general': '#66bbff'
  };

  // ── INIT ──
  function init() {
    canvas = document.getElementById('neuralCanvas');
    if (!canvas) { console.error('[sidebar-bridge] No canvas found'); return; }
    ctx = canvas.getContext('2d');

    // Resize observer
    var container = document.getElementById('galaxyContainer');
    if (container) {
      var ro = new ResizeObserver(function (entries) {
        for (var i = 0; i < entries.length; i++) {
          var rect = entries[i].contentRect;
          canvas.width = Math.floor(rect.width * (window.devicePixelRatio || 1));
          canvas.height = Math.floor(rect.height * (window.devicePixelRatio || 1));
          canvas.style.width = rect.width + 'px';
          canvas.style.height = rect.height + 'px';
          renderer.canvasW = canvas.width;
          renderer.canvasH = canvas.height;
        }
      });
      ro.observe(container);

      // Initial size
      canvas.width = Math.floor(container.clientWidth * (window.devicePixelRatio || 1));
      canvas.height = Math.floor(container.clientHeight * (window.devicePixelRatio || 1));
      canvas.style.width = container.clientWidth + 'px';
      canvas.style.height = container.clientHeight + 'px';
      renderer.canvasW = canvas.width;
      renderer.canvasH = canvas.height;
    }

    // Mouse events for camera control
    // Note: all coordinates use DPR-scaled canvas pixels for consistency
    canvas.addEventListener('mousedown', function (e) {
      var dpr = window.devicePixelRatio || 1;
      var px = e.offsetX * dpr;
      var py = e.offsetY * dpr;
      renderer.camera.startDrag(px, py);
      // Hit test for node pinning
      var hit = hitTestNode(px, py);
      if (hit) {
        renderer.pinnedNode = (renderer.pinnedNode === hit) ? null : hit;
      }
    });
    canvas.addEventListener('mousemove', function (e) {
      var dpr = window.devicePixelRatio || 1;
      var px = e.offsetX * dpr;
      var py = e.offsetY * dpr;
      renderer.camera.drag(px, py);
      // Hover detection
      var hit = hitTestNode(px, py);
      renderer.hoveredNode = hit;
    });
    canvas.addEventListener('mouseup', function () {
      renderer.camera.endDrag();
    });
    canvas.addEventListener('mouseleave', function () {
      renderer.camera.endDrag();
      renderer.hoveredNode = null;
    });

    // Start render loop
    lastTime = performance.now();
    animFrame = requestAnimationFrame(renderLoop);
  }

  function hitTestNode(px, py) {
    var nodes = renderer.nodes;
    var closest = null;
    var closestDist = 15; // hit radius in pixels
    for (var i = 0; i < nodes.length; i++) {
      var n = nodes[i];
      if (!n.isVisible()) continue;
      var dx = px - n.sx;
      var dy = py - n.sy;
      var d = Math.sqrt(dx * dx + dy * dy);
      if (d < closestDist) {
        closestDist = d;
        closest = n;
      }
    }
    return closest;
  }

  // ── RENDER LOOP ──
  function renderLoop(now) {
    animFrame = requestAnimationFrame(renderLoop);

    // Skip if hidden
    if (document.hidden) return;

    var dt = Math.min((now - lastTime) / 1000, 0.1); // cap at 100ms
    lastTime = now;

    if (!renderer.initialized || !ctx) return;

    // Advance renderer time (used by BubbleManager + impulse scheduling)
    renderer._time = (renderer._time || 0) + dt;

    // Update camera
    renderer.camera.update(dt);

    // Update all nodes
    for (var i = 0; i < renderer.nodes.length; i++) {
      renderer.nodes[i].update(dt);
    }

    // Project all nodes
    for (var pi = 0; pi < renderer.nodes.length; pi++) {
      var node = renderer.nodes[pi];
      var proj = renderer.camera.project(node.wx, node.wy, node.wz, renderer.canvasW, renderer.canvasH);
      if (proj) {
        node.sx = proj.x;
        node.sy = proj.y;
        node.sScale = proj.scale;
        node.depth = proj.depth;
      }
    }

    // Spawn impulses
    renderer._maybeSpawnImpulses();

    // Clear canvas
    ctx.clearRect(0, 0, renderer.canvasW, renderer.canvasH);

    // Background
    ctx.fillStyle = renderer.theme.void || '#020305';
    ctx.fillRect(0, 0, renderer.canvasW, renderer.canvasH);

    // Nebula glow
    var nebGrad = ctx.createRadialGradient(
      renderer.canvasW * 0.5, renderer.canvasH * 0.4, 10,
      renderer.canvasW * 0.5, renderer.canvasH * 0.4, renderer.canvasW * 0.6
    );
    nebGrad.addColorStop(0, renderer.theme.nebula || '#00ff41');
    nebGrad.addColorStop(1, 'transparent');
    ctx.save();
    ctx.globalAlpha = 0.04;
    ctx.fillStyle = nebGrad;
    ctx.fillRect(0, 0, renderer.canvasW, renderer.canvasH);
    ctx.restore();

    // Depth-sort nodes and connections
    var sortedNodes = renderer.nodes.slice().sort(function (a, b) { return b.depth - a.depth; });
    var sortedConns = renderer.connections.slice().sort(function (a, b) {
      var da = (a.a.depth + a.b.depth) * 0.5;
      var db = (b.a.depth + b.b.depth) * 0.5;
      return db - da;
    });

    // Draw ghost constellation (dormant nodes as faint points)
    ctx.save();
    ctx.globalAlpha = 0.08;
    for (var gi = 0; gi < sortedNodes.length; gi++) {
      var gn = sortedNodes[gi];
      if (gn.nstate === NSTATE.DORMANT && gn.sx && gn.sy) {
        ctx.fillStyle = gn.color;
        ctx.beginPath();
        ctx.arc(gn.sx, gn.sy, 1.5, 0, Math.PI * 2);
        ctx.fill();
      }
    }
    ctx.restore();

    // Draw ghost connections
    ctx.save();
    ctx.globalAlpha = 0.03;
    ctx.strokeStyle = '#ffffff';
    ctx.lineWidth = 0.3;
    for (var gci = 0; gci < sortedConns.length; gci++) {
      var gc = sortedConns[gci];
      ctx.beginPath();
      ctx.moveTo(gc.a.sx, gc.a.sy);
      ctx.lineTo(gc.b.sx, gc.b.sy);
      ctx.stroke();
    }
    ctx.restore();

    // Draw active connections + impulses
    for (var cci = 0; cci < sortedConns.length; cci++) {
      sortedConns[cci].draw(ctx, renderer.theme);
    }

    // Draw nodes
    for (var ni = 0; ni < sortedNodes.length; ni++) {
      sortedNodes[ni].draw(ctx, renderer.theme);
    }

    // Draw tooltip for hovered/pinned node
    var tooltipNode = renderer.pinnedNode || renderer.hoveredNode;
    if (tooltipNode && tooltipNode.isVisible()) {
      renderer._drawTooltip(ctx, tooltipNode, renderer.canvasW, renderer.canvasH);
    }

    // Update and draw bubbles (BubbleManager integration)
    // Use renderer._time (accumulated relative time) for consistent time basis
    var BM = NRM.BubbleManager;
    if (BM) {
      BM.update(renderer.nodes, dt, renderer._time);
      BM.draw(ctx, renderer.canvasW, renderer.canvasH, renderer._time);
    }

    // Footer
    var activeCount = 0;
    for (var fi = 0; fi < renderer.nodes.length; fi++) {
      if (renderer.nodes[fi].nstate === NSTATE.ACTIVE || renderer.nodes[fi].nstate === NSTATE.ACTIVATING) activeCount++;
    }
    renderer._drawFooter(ctx, activeCount, renderer.canvasW, renderer.canvasH);
  }

  // ── MESSAGE HANDLER ──
  window.addEventListener('message', function (event) {
    var msg = event.data;
    if (!msg || !msg.type) return;

    switch (msg.type) {
      case 'rosterData':
        handleRoster(msg.data, msg.projectId || _projectId);
        break;

      case 'statusData':
        if (DataBridge.initialized) {
          DataBridge.applyStatus(msg.data);
        }
        break;

      case 'liveAgents':
        if (DataBridge.initialized) {
          DataBridge.applyLiveActivity(msg.agents);
          // Relayout if new entities were created
          if (DataBridge._needsRelayout) {
            renderer.init(DataBridge.entities, CAT_ORDER, CAT_COLORS, _projectId);
            DataBridge._needsRelayout = false;
          }
        }
        break;

      case 'metricsData':
        if (DataBridge.initialized) {
          DataBridge.applyMetrics(msg.data);
        }
        break;

      case 'htmlUpdate':
        updateTextSections(msg.sections);
        break;

      case 'parentData':
        if (renderer.setParentMap) {
          renderer.setParentMap(msg.map);
        }
        break;

      case 'setProject':
        _projectId = msg.projectId || 'merlin';
        break;
    }
  });

  // ── ROSTER HANDLING ──
  function handleRoster(rosterData, projectId) {
    if (!rosterData) return;
    _projectId = projectId || _projectId;

    // Change detection — only re-init if roster content changed
    var hash = JSON.stringify(rosterData);
    if (hash === _prevRosterHash) return;

    // Diff for dynamic evolution
    var newNames = new Set();
    var projects = rosterData.projects || {};
    for (var pid in projects) {
      if (!projects.hasOwnProperty(pid)) continue;
      var agents = projects[pid] || [];
      for (var ai = 0; ai < agents.length; ai++) {
        newNames.add((agents[ai].name || '').toLowerCase());
      }
    }
    var common = rosterData.commonAgents || [];
    for (var ci = 0; ci < common.length; ci++) {
      newNames.add((common[ci].name || '').toLowerCase());
    }
    var skills = rosterData.skills || [];
    for (var si = 0; si < skills.length; si++) {
      newNames.add((skills[si].name || '').toLowerCase());
    }

    _prevRosterHash = hash;

    // Init DataBridge
    DataBridge.initFromRoster(rosterData);

    // Reset BubbleManager state on roster change (prevent stale singleton data)
    // Must be done BEFORE renderer.init() for defensive ordering
    var BM = NRM.BubbleManager;
    if (BM) {
      BM.bubbles = [];
      BM._activationTimes = {};
      BM.scaleFactor = 1.0;
    }

    // Init renderer with new entities
    renderer.init(DataBridge.entities, CAT_ORDER, CAT_COLORS, _projectId);

    // Animate newly added nodes (brief flash)
    if (_prevRosterNames.size > 0) {
      newNames.forEach(function (name) {
        if (!_prevRosterNames.has(name)) {
          var targetNode = renderer.nodeMap[name];
          if (targetNode) {
            // Briefly activate to show spawn animation
            targetNode.entity.isActive = true;
            targetNode.entity.state = SB.STATE.WORKING;
            (function (n) {
              setTimeout(function () {
                n.entity.isActive = false;
                n.entity.state = SB.STATE.IDLE;
              }, 2000);
            })(targetNode);
          }
        }
      });
    }

    _prevRosterNames = newNames;
  }

  // ── TEXT SECTION UPDATE ──
  function updateTextSections(sections) {
    if (!sections) return;
    // Update individual section divs without destroying the canvas
    var sectionIds = ['activity', 'agents', 'sessions', 'more'];
    for (var i = 0; i < sectionIds.length; i++) {
      var id = sectionIds[i];
      if (sections[id] !== undefined) {
        var el = document.getElementById('section-' + id);
        if (el) el.innerHTML = sections[id];
      }
    }
  }

  // ── WEBVIEW → EXTENSION MESSAGES ──
  window._sidebarSend = function (type, payload) {
    vscode.postMessage(Object.assign({ type: type }, payload || {}));
  };

  // ── INIT ON LOAD ──
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
