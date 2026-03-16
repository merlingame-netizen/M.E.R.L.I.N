// robot-monitor-webview.js — VS Code webview side script (v2: themes + taskPanel)
// Receives postMessage from extension, drives RobotMonitor.Scene
(function () {
  'use strict';

  var canvas = document.getElementById('robotCanvas');
  var taskPanelEl = document.getElementById('taskPanel') || null;

  // Detect project theme from injected global
  var projectId = window.__ROBOT_PROJECT || 'merlin';

  // Set theme before creating scene
  if (window.RobotMonitor.setTheme) {
    window.RobotMonitor.setTheme(projectId);
  }

  var scene = new window.RobotMonitor.Scene(canvas, taskPanelEl);

  // Set render mode from injected global (default: neural)
  var renderMode = window.__RENDER_MODE || 'neural';
  scene.setRenderMode(renderMode);

  // Responsive resize
  function resize() {
    var container = document.getElementById('robotContainer');
    var w = container.clientWidth || 300;
    var h = container.clientHeight || 280;
    scene.resize(w, h);
  }

  var resizeObserver = new ResizeObserver(resize);
  resizeObserver.observe(document.getElementById('robotContainer'));
  resize();
  scene.start();

  // Load inline roster + metrics (injected in HTML — no race condition)
  if (window.__ROSTER) scene.setRoster(window.__ROSTER);
  if (window.__METRICS) scene.setMetrics(window.__METRICS);

  // Listen for status updates from extension
  window.addEventListener('message', function (event) {
    var msg = event.data;
    if (!msg) return;
    if (msg.type === 'statusUpdate') {
      scene.setData(msg.data);
    }
    if (msg.type === 'rosterData') {
      if (scene.setRoster) scene.setRoster(msg.data);
    }
    if (msg.type === 'metricsData') {
      if (scene.setMetrics) scene.setMetrics(msg.data);
    }
    if (msg.type === 'liveActivity') {
      if (scene.setLiveActivity) scene.setLiveActivity(msg.agents);
    }
    if (msg.type === 'trainData') {
      if (scene.setTrainData) scene.setTrainData(msg.data);
    }
    if (msg.type === 'setTheme') {
      if (window.RobotMonitor.setTheme) {
        window.RobotMonitor.setTheme(msg.theme);
      }
    }
    if (msg.type === 'setRenderMode') {
      scene.setRenderMode(msg.mode);
      // Update toggle button state
      var toggleBtn = document.getElementById('renderModeToggle');
      if (toggleBtn) {
        toggleBtn.textContent = msg.mode === 'neural' ? 'NEURAL' : 'VILLAGE';
      }
    }
  });

  // Tab switching (if tabs exist in webview HTML)
  var tabLive = document.getElementById('tabLive');
  var tabRoster = document.getElementById('tabRoster');
  var tabMetrics = document.getElementById('tabMetrics');
  var tabTrain = document.getElementById('tabTrain');
  if (tabLive && tabRoster) {
    var allTabs = [tabLive, tabRoster, tabMetrics, tabTrain].filter(Boolean);
    function activateTab(active, mode) {
      allTabs.forEach(function(t) { t.className = ''; });
      active.className = 'active';
      scene.setMode(mode);
    }
    tabLive.addEventListener('click', function() { activateTab(tabLive, 'live'); });
    tabRoster.addEventListener('click', function() { activateTab(tabRoster, 'roster'); });
    if (tabMetrics) tabMetrics.addEventListener('click', function() { activateTab(tabMetrics, 'metrics'); });
    if (tabTrain) tabTrain.addEventListener('click', function() { activateTab(tabTrain, 'train'); });
  }

  // Double-click on canvas: open agent file in VS Code (village mode)
  var _vscodeApi = (typeof acquireVsCodeApi === 'function') ? acquireVsCodeApi() : null;
  if (canvas) {
    canvas.addEventListener('dblclick', function () {
      var IM = window.RobotMonitor.InteractionManager;
      if (IM && IM.hoveredEntity && IM.hoveredEntity.name && _vscodeApi) {
        _vscodeApi.postMessage({ type: 'openAgentFile', name: IM.hoveredEntity.name });
      }
    });
  }

  // Train panel action callback → VS Code extension
  window._trainActionCallback = function(action, brain, opts) {
    if (_vscodeApi) {
      _vscodeApi.postMessage({ type: 'trainAction', action: action, brain: brain, opts: opts || {} });
    }
  };

  // Render mode toggle button
  var renderToggle = document.getElementById('renderModeToggle');
  if (renderToggle) {
    renderToggle.addEventListener('click', function () {
      var newMode = scene.renderMode === 'neural' ? 'village' : 'neural';
      scene.setRenderMode(newMode);
      renderToggle.textContent = newMode === 'neural' ? 'NEURAL' : 'VILLAGE';
      if (_vscodeApi) {
        _vscodeApi.postMessage({ type: 'renderModeChanged', mode: newMode });
      }
    });
  }

  // Neural mode mouse controls (orbit camera)
  if (canvas) {
    canvas.addEventListener('mousedown', function (e) {
      if (scene.renderMode !== 'neural' || !scene._neuralRenderer) return;
      var nr = scene._neuralRenderer;
      // Check if clicking a node first
      var hit = nr.hitTest(e.offsetX * (window.devicePixelRatio || 1), e.offsetY * (window.devicePixelRatio || 1));
      if (hit) {
        nr.pinnedNode = (nr.pinnedNode === hit) ? null : hit;
        return;
      }
      nr.camera.startDrag(e.clientX, e.clientY);
    });
    canvas.addEventListener('mousemove', function (e) {
      if (scene.renderMode !== 'neural' || !scene._neuralRenderer) return;
      var nr = scene._neuralRenderer;
      var dpr = window.devicePixelRatio || 1;
      if (!nr.camera.isDragging) {
        nr.hitTest(e.offsetX * dpr, e.offsetY * dpr);
      }
      nr.camera.drag(e.clientX, e.clientY);
    });
    canvas.addEventListener('mouseup', function () {
      if (scene.renderMode !== 'neural' || !scene._neuralRenderer) return;
      scene._neuralRenderer.camera.endDrag();
    });
    canvas.addEventListener('mouseleave', function () {
      if (scene.renderMode !== 'neural' || !scene._neuralRenderer) return;
      scene._neuralRenderer.camera.endDrag();
      scene._neuralRenderer.hoveredNode = null;
    });
  }

  // Search/filter agents
  var searchInput = document.getElementById('agentSearch');
  if (searchInput && scene.setSearchFilter) {
    var searchTimeout = null;
    searchInput.addEventListener('input', function () {
      clearTimeout(searchTimeout);
      var query = searchInput.value;
      searchTimeout = setTimeout(function () {
        scene.setSearchFilter(query);
      }, 150);
    });
  }

  // Visibility: pause when hidden
  document.addEventListener('visibilitychange', function () {
    if (document.hidden) {
      scene.stop();
    } else {
      scene.start();
    }
  });

  // Signal webview ready — extension waits for this before sending data
  if (_vscodeApi) {
    _vscodeApi.postMessage({ type: 'webviewReady' });
  }
})();
