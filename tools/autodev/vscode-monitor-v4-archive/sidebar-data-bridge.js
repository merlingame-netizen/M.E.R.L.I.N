// sidebar-data-bridge.js — Extracted DataBridge for Neural Monitor Sidebar v1.0
(function() {
  'use strict';

  // ── FONT (3x5 bitmap) ──────────────────────────────────────────────
  var FONT = {
    'A':[7,5,7,5,5],'B':[6,5,6,5,6],'C':[7,4,4,4,7],'D':[6,5,5,5,6],
    'E':[7,4,6,4,7],'F':[7,4,6,4,4],'G':[7,4,5,5,7],'H':[5,5,7,5,5],
    'I':[7,2,2,2,7],'J':[3,1,1,5,7],'K':[5,5,6,5,5],'L':[4,4,4,4,7],
    'M':[5,7,7,5,5],'N':[5,7,7,7,5],'O':[7,5,5,5,7],'P':[7,5,7,4,4],
    'Q':[7,5,5,7,1],'R':[7,5,7,6,5],'S':[7,4,7,1,7],'T':[7,2,2,2,2],
    'U':[5,5,5,5,7],'V':[5,5,5,5,2],'W':[5,5,7,7,5],'X':[5,5,2,5,5],
    'Y':[5,5,2,2,2],'Z':[7,1,2,4,7],
    '0':[7,5,5,5,7],'1':[2,6,2,2,7],'2':[7,1,7,4,7],'3':[7,1,7,1,7],
    '4':[5,5,7,1,1],'5':[7,4,7,1,7],'6':[7,4,7,5,7],'7':[7,1,1,1,1],
    '8':[7,5,7,5,7],'9':[7,5,7,1,7],
    '.':[0,0,0,0,2],':':[0,2,0,2,0],'-':[0,0,7,0,0],'_':[0,0,0,0,7],
    '/':[1,1,2,4,4],'%':[5,1,2,4,5],' ':[0,0,0,0,0],'!':[2,2,2,0,2],
    '?':[7,1,2,0,2],'+':[0,2,7,2,0],'>':[4,2,1,2,4]
  };

  // ── drawText ────────────────────────────────────────────────────────
  function drawText(ctx, text, x, y, color, scale) {
    scale = scale || 1;
    ctx.fillStyle = color || '#b0c8b0';
    var str = String(text).toUpperCase();
    var cx = x;
    for (var i = 0; i < str.length; i++) {
      var ch = FONT[str[i]];
      if (ch) {
        for (var r = 0; r < 5; r++) {
          for (var c = 0; c < 3; c++) {
            if (ch[r] & (1 << (2 - c))) {
              ctx.fillRect(cx + c * scale, y + r * scale, scale, scale);
            }
          }
        }
      }
      cx += 4 * scale;
    }
    return cx - x;
  }

  // ── textWidth ───────────────────────────────────────────────────────
  function textWidth(text, scale) {
    return String(text).length * 4 * (scale || 1) - (scale || 1);
  }

  // ── STATE enum ──────────────────────────────────────────────────────
  var STATE = { IDLE: 0, WORKING: 1, WAITING: 2, DONE: 3, ERROR: 4 };

  // ── AgentEntity ─────────────────────────────────────────────────────
  function AgentEntity(data) {
    this.name = data.name || 'unnamed';
    this.category = data.category || 'general';
    this.project = data.project || 'unknown';
    this.type = data.type || 'agent';
    this.description = data.description || '';
    this.state = STATE.IDLE;
    this.isActive = false;
    this.currentTask = '';
    this.progress = 0;
    this.error = '';
    this.invocationCount = 0;
    this.score = data.score || 0;
    this.collaborationGroup = null;
    this._liveTs = 0;
  }

  // ── DataBridge ──────────────────────────────────────────────────────
  var DataBridge = {
    entities: [],
    entityMap: {},
    initialized: false,
    _needsRelayout: false,

    initFromRoster: function(rosterData) {
      if (!rosterData) return;
      this.entities = [];
      this.entityMap = {};

      var projects = rosterData.projects || {};
      for (var pid in projects) {
        if (!projects.hasOwnProperty(pid)) continue;
        var agents = projects[pid] || [];
        for (var ai = 0; ai < agents.length; ai++) {
          var ag = agents[ai];
          var entity = new AgentEntity({ name: ag.name || 'unnamed', category: ag.category || 'general', project: pid, type: 'agent', description: ag.description || '' });
          this.entities.push(entity);
          this.entityMap[this._normalizeKey(entity.name)] = entity;
        }
      }

      var common = rosterData.commonAgents || [];
      for (var ci = 0; ci < common.length; ci++) {
        var ca = common[ci];
        var cEntity = new AgentEntity({ name: ca.name || 'unnamed', category: ca.category || 'general', project: 'common', type: 'agent', description: ca.description || '' });
        this.entities.push(cEntity);
        this.entityMap[this._normalizeKey(cEntity.name)] = cEntity;
      }

      var skills = rosterData.skills || [];
      for (var si = 0; si < skills.length; si++) {
        var sk = skills[si];
        var sEntity = new AgentEntity({ name: sk.name || 'unnamed-skill', category: 'general', project: 'all', type: 'skill', score: sk.score || 0 });
        this.entities.push(sEntity);
        this.entityMap[this._normalizeKey(sEntity.name)] = sEntity;
      }

      this.initialized = true;
      this._needsRelayout = true;
    },

    applyStatus: function(statusData) {
      if (!statusData || !this.initialized) return;
      var activatedNames = {};
      var workers = statusData.workers || [];

      for (var wi = 0; wi < workers.length; wi++) {
        var w = workers[wi];
        var domain = w.domain || w.name || '';
        if (!domain) continue;
        var entity = this._findEntity(domain);

        if (!entity) {
          entity = new AgentEntity({ name: domain, category: 'general', project: 'unknown', type: 'agent' });
          this.entities.push(entity);
          this.entityMap[this._normalizeKey(domain)] = entity;
          this._needsRelayout = true;
        }

        entity.currentTask = w.current_task || '';
        entity.progress = w.progress || 0;
        entity.error = w.error || '';
        var s = String(w.status || 'pending').toLowerCase();
        if (s === 'in_progress' || s === 'running') { entity.state = STATE.WORKING; entity.isActive = true; }
        else if (s === 'done' || s === 'completed' || s === 'merged') { entity.state = STATE.DONE; entity.isActive = true; }
        else if (s === 'error' || s === 'failed') { entity.state = STATE.ERROR; entity.isActive = true; }
        else { entity.state = STATE.IDLE; entity.isActive = false; }
        activatedNames[this._normalizeKey(domain)] = true;
      }

      for (var ei = 0; ei < this.entities.length; ei++) {
        var ent = this.entities[ei];
        var key = this._normalizeKey(ent.name);
        if (ent.isActive && !activatedNames[key]) {
          ent.isActive = false;
          ent.state = STATE.IDLE;
          ent.currentTask = '';
          ent.progress = 0;
          ent.collaborationGroup = null;
        }
      }
    },

    applyMetrics: function(metricsData) {
      if (!metricsData || !this.initialized) return;
      var topAgents = metricsData.topAgents || [];
      for (var ai = 0; ai < topAgents.length; ai++) {
        var ag = topAgents[ai];
        var entity = this._findEntity(ag.name || '');
        if (entity) entity.invocationCount = ag.count || 0;
      }
      var topSkills = metricsData.topSkills || [];
      for (var si = 0; si < topSkills.length; si++) {
        var sk = topSkills[si];
        var sEntity = this._findEntity(sk.name || '');
        if (sEntity) sEntity.invocationCount = sk.count || 0;
      }
    },

    applyLiveActivity: function(agents) {
      if (!agents || !this.initialized) return;
      var now = Date.now();
      var activeNames = {};

      for (var i = 0; i < agents.length; i++) {
        var a = agents[i];
        var name = a.name || '';
        if (!name) continue;
        var entity = this._findEntity(name);
        if (!entity) entity = this._findEntityByKeywords(name, a.description || '');
        if (!entity) {
          entity = new AgentEntity({ name: name, category: this._guessCategory(name), project: a.project || 'common', type: 'agent', description: a.description || '' });
          this.entities.push(entity);
          this.entityMap[this._normalizeKey(name)] = entity;
          this._needsRelayout = true;
        }
        if (!entity.isActive) {
          entity.state = STATE.WORKING;
          entity.isActive = true;
        }
        entity.currentTask = a.description || 'active';
        entity._liveTs = now;
        activeNames[this._normalizeKey(name)] = true;
      }

      for (var ei = 0; ei < this.entities.length; ei++) {
        var ent = this.entities[ei];
        if (ent._liveTs && !activeNames[this._normalizeKey(ent.name)] && (now - ent._liveTs) > 60000) {
          ent.isActive = false;
          ent.state = STATE.IDLE;
          ent.currentTask = '';
          ent._liveTs = 0;
        }
      }
    },

    getActiveEntities: function() {
      var result = [];
      for (var i = 0; i < this.entities.length; i++) {
        if (this.entities[i].isActive) result.push(this.entities[i]);
      }
      return result;
    },

    _findEntity: function(name) {
      if (!name) return null;
      return this.entityMap[this._normalizeKey(name)] || null;
    },

    _findEntityByKeywords: function(name, desc) {
      var combined = (name + ' ' + desc).toLowerCase();
      var tokens = combined.split(/[\s_-]+/);
      var best = null, bestScore = 0;
      for (var i = 0; i < this.entities.length; i++) {
        var ent = this.entities[i];
        var eName = ent.name.toLowerCase();
        var score = 0;
        for (var t = 0; t < tokens.length; t++) {
          if (tokens[t].length > 2 && eName.indexOf(tokens[t]) >= 0) score++;
        }
        if (score > bestScore) { bestScore = score; best = ent; }
      }
      return bestScore >= 2 ? best : null;
    },

    _normalizeKey: function(name) {
      return String(name || '').toLowerCase().trim();
    },

    _guessCategory: function(name) {
      var n = String(name).toLowerCase();
      if (/game|godot|gdscript|scene/.test(n)) return 'gameplay';
      if (/ui|ux|visual|css|html/.test(n)) return 'ui-ux';
      if (/llm|lora|ai|brain|swarm/.test(n)) return 'llm-lora';
      if (/data|query|sql|bigquery|hive|qlik|powerbi/.test(n)) return 'data';
      if (/test|review|security/.test(n)) return 'review';
      if (/doc|plan/.test(n)) return 'planning';
      return 'general';
    }
  };

  // ── Exports ─────────────────────────────────────────────────────────
  window.SidebarBridge = {
    FONT: FONT,
    drawText: drawText,
    textWidth: textWidth,
    AgentEntity: AgentEntity,
    DataBridge: DataBridge,
    STATE: STATE
  };

  window.RobotMonitor = {
    drawText: drawText,
    textWidth: textWidth
  };
})();
