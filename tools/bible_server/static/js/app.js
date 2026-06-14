/**
 * Bible Server SPA — tab router, renderers, search.
 */
(function () {
  'use strict';

  let bibleData = null;

  // ── Boot ──────────────────────────────────────────────────────────────

  document.addEventListener('DOMContentLoaded', init);

  async function init() {
    showLoader();
    try {
      bibleData = await API.bible();
      buildTabs(bibleData.tabs);
      renderAll(bibleData);
      activateTab(bibleData.tabs[0].id);
      setStatus('ok');
    } catch (err) {
      document.querySelector('.main').innerHTML =
        `<div class="loader" style="color:var(--violet)">${esc(err.message)}</div>`;
      setStatus('error');
    }
  }

  function showLoader() {
    document.querySelector('.main').innerHTML = '<div class="loader">Invocation du grimoire...</div>';
  }

  function setStatus(state) {
    const el = document.querySelector('.header .status');
    el.className = 'status ' + state;
    el.textContent = state === 'ok' ? 'Connecte' : 'Erreur';
  }

  // ── Tabs ──────────────────────────────────────────────────────────────

  function buildTabs(tabs) {
    const bar = document.querySelector('.tab-bar');
    bar.innerHTML = '';
    tabs.forEach(t => {
      const btn = document.createElement('button');
      btn.textContent = t.label;
      btn.dataset.tab = t.id;
      btn.addEventListener('click', () => activateTab(t.id));
      bar.appendChild(btn);
    });
  }

  var _lazyCallbacks = {};

  function activateTab(id) {
    ensureTabRendered(id);
    document.querySelectorAll('.tab-bar button').forEach(b =>
      b.classList.toggle('active', b.dataset.tab === id));
    document.querySelectorAll('.tab-panel').forEach(p =>
      p.classList.toggle('active', p.id === 'tab-' + id));
    if (_lazyCallbacks[id]) {
      _lazyCallbacks[id]();
      delete _lazyCallbacks[id];
    }
  }

  // ── Render all ────────────────────────────────────────────────────────

  var _tabRenderers = {};
  var _renderedTabs = {};

  function renderAll(d) {
    const main = document.querySelector('.main');
    main.innerHTML = '';
    _tabRenderers = {
      overview:      renderOverview,
      scenes:        renderScenes,
      cards:         renderCards,
      mechanics:     renderMechanics,
      gauges:        renderGauges,
      llm:           renderLLM,
      assets:        renderAssets,
      visual:        renderVisual,
      lore:          renderLore,
      audio:         renderAudio,
      progression:   renderProgression,
      architecture:  renderArchitecture,
      journal:       renderJournal,
      formulas:      renderFormulas,
    };
    _renderedTabs = {};
    d.tabs.forEach(t => {
      const panel = document.createElement('div');
      panel.className = 'tab-panel';
      panel.id = 'tab-' + t.id;
      main.appendChild(panel);
    });
  }

  function ensureTabRendered(id) {
    if (_renderedTabs[id]) return;
    _renderedTabs[id] = true;
    var panel = document.getElementById('tab-' + id);
    if (!panel) return;
    var fn = _tabRenderers[id];
    if (fn) fn(panel, bibleData);
    else panel.innerHTML = '<p style="color:var(--dim-warm)">Onglet — contenu a venir.</p>';
  }

  // ── Helpers ───────────────────────────────────────────────────────────

  function esc(s) {
    const d = document.createElement('div');
    d.textContent = String(s);
    return d.innerHTML;
  }

  function h(tag, attrs, ...children) {
    const el = document.createElement(tag);
    if (attrs) Object.entries(attrs).forEach(([k, v]) => {
      if (k === 'className') el.className = v;
      else if (k.startsWith('on')) el.addEventListener(k.slice(2).toLowerCase(), v);
      else el.setAttribute(k, v);
    });
    children.forEach(c => {
      if (typeof c === 'string') el.appendChild(document.createTextNode(c));
      else if (c) el.appendChild(c);
    });
    return el;
  }

  function section(title) {
    return h('h2', { style: 'color:var(--gold);margin:24px 0 12px;font-size:16px;' }, title);
  }

  // ── Tab renderers ─────────────────────────────────────────────────────

  function renderOverview(panel, d) {
    const m = d.meta || {};
    panel.appendChild(section('Projet'));
    const info = [
      ['Nom', m.name],
      ['Scene principale', m.main_scene],
      ['Viewport', `${m.viewport_w} x ${m.viewport_h}`],
      ['FPS max', m.max_fps],
      ['Scenes', d.scenes?.length],
      ['Scripts', d.scripts?.length],
      ['Regles', d.rules?.length],
      ['Addons', d.addons?.join(', ')],
    ];
    const tbl = h('table', null,
      h('thead', null, h('tr', null, h('th', null, 'Cle'), h('th', null, 'Valeur'))),
      h('tbody', null, ...info.map(([k, v]) =>
        h('tr', null, h('td', null, k), h('td', null, String(v || '-')))
      ))
    );
    panel.appendChild(tbl);

    if (d.svg_scene_flow) {
      panel.appendChild(section('Flow des scenes'));
      const svgDiv = h('div', { className: 'scene-flow-svg' });
      svgDiv.innerHTML = d.svg_scene_flow;
      panel.appendChild(svgDiv);
    }
  }

  function renderScenes(panel, d) {
    panel.appendChild(section('Scenes (.tscn)'));
    if (d.svg_scene_flow) {
      const svgDiv = h('div', { className: 'scene-flow-svg' });
      svgDiv.innerHTML = d.svg_scene_flow;
      panel.appendChild(svgDiv);
    }
    const grid = h('div', { className: 'card-grid' });
    (d.scenes || []).forEach(s => {
      grid.appendChild(h('div', { className: 'card' },
        h('h3', null, s.name),
        h('p', null, s.path)
      ));
    });
    panel.appendChild(grid);

    panel.appendChild(section('Arbre de nodes (parse .tscn + GDScript)'));
    var mockupArea = h('div', { className: 'scene-mockup-area' });
    mockupArea.innerHTML = '<p style="color:var(--dim-warm)">Chargement des mockups...</p>';
    panel.appendChild(mockupArea);

    _lazyCallbacks['scenes'] = function () {
      API.scenes().then(function (scenes) {
        mockupArea.innerHTML = '';
        if (!scenes || scenes.length === 0) {
          mockupArea.innerHTML = '<p style="color:var(--dim-warm)">Aucune scene trouvee.</p>';
          return;
        }
        scenes.forEach(function (scene) {
          var card = h('div', { className: 'card', style: 'margin-bottom:24px;padding:16px' });
          SceneMockup.render(card, scene);
          mockupArea.appendChild(card);
        });
      }).catch(function (err) {
        mockupArea.innerHTML = '<p style="color:var(--violet)">Erreur : ' + esc(err.message) + '</p>';
      });
    };
  }

  // ── SVG Glyph system (mirrors GDScript MerlinGlyph._draw) ──────────────

  var GLYPH_SVG = {
    eye: '<circle cx="20" cy="20" r="10.2" fill="none" stroke="STC" stroke-width="SW"/><circle cx="20" cy="20" r="3.1" fill="STC"/>',
    sword: '<line x1="20" y1="9.8" x2="20" y2="26.6" stroke="STC" stroke-width="SW" stroke-linecap="round"/><line x1="14.4" y1="15.7" x2="25.6" y2="15.7" stroke="STC" stroke-width="SW" stroke-linecap="round"/><polyline points="18.4,9.8 20,7 21.6,9.8" fill="none" stroke="STC" stroke-width="SW" stroke-linecap="round" stroke-linejoin="round"/><line x1="20" y1="26.6" x2="20" y2="30.2" stroke="STC" stroke-width="2.6" stroke-linecap="round"/>',
    spiral: '<path d="M20,20 C20,20 20.4,19.2 21.2,18.8 C22.8,18 24.4,19.2 24,21.2 C23.2,24.8 18,26.4 15.6,22.4 C13.2,18 16.4,13.2 21.2,12.4 C27.6,11.2 31.6,17.2 29.6,23.2 C27.2,30 18,32 13.6,27.6" fill="none" stroke="STC" stroke-width="SW" stroke-linecap="round"/>',
    crescent: '<path d="M24.2,10.8 A10.2,10.2 0 1,1 24.2,29.2" fill="none" stroke="STC" stroke-width="SW" stroke-linecap="round"/>',
    sun: '<circle cx="20" cy="20" r="6.1" fill="none" stroke="STC" stroke-width="SW"/><line x1="20" y1="8" x2="20" y2="11.3" stroke="STC" stroke-width="SW" stroke-linecap="round"/><line x1="20" y1="28.7" x2="20" y2="32" stroke="STC" stroke-width="SW" stroke-linecap="round"/><line x1="8" y1="20" x2="11.3" y2="20" stroke="STC" stroke-width="SW" stroke-linecap="round"/><line x1="28.7" y1="20" x2="32" y2="20" stroke="STC" stroke-width="SW" stroke-linecap="round"/><line x1="11.5" y1="11.5" x2="13.8" y2="13.8" stroke="STC" stroke-width="SW" stroke-linecap="round"/><line x1="26.2" y1="26.2" x2="28.5" y2="28.5" stroke="STC" stroke-width="SW" stroke-linecap="round"/><line x1="11.5" y1="28.5" x2="13.8" y2="26.2" stroke="STC" stroke-width="SW" stroke-linecap="round"/><line x1="26.2" y1="13.8" x2="28.5" y2="11.5" stroke="STC" stroke-width="SW" stroke-linecap="round"/>',
    rift: '<circle cx="20" cy="20" r="10.2" fill="none" stroke="STC" stroke-width="SW"/><polyline points="18.4,9.8 21.2,16.7 18.6,20.6 21.8,30.2" fill="none" stroke="STC" stroke-width="SW" stroke-linecap="round" stroke-linejoin="round"/>',
    spark: '<polygon points="20,9.8 22.5,17.5 30.2,20 22.5,22.5 20,30.2 17.5,22.5 9.8,20 17.5,17.5" fill="none" stroke="STC" stroke-width="SW" stroke-linejoin="round"/>',
    book: '<polyline points="9.8,14.4 9.8,25.1 20,21.2 20,15.4 9.8,14.4" fill="none" stroke="STC" stroke-width="SW" stroke-linejoin="round"/><polyline points="30.2,14.4 30.2,25.1 20,21.2 20,15.4" fill="none" stroke="STC" stroke-width="SW" stroke-linejoin="round"/>',
    target: '<circle cx="20" cy="20" r="10.2" fill="none" stroke="STC" stroke-width="SW"/><circle cx="20" cy="20" r="5.1" fill="none" stroke="STC" stroke-width="SW"/><circle cx="20" cy="20" r="1.2" fill="STC"/><line x1="20" y1="7.9" x2="20" y2="12" stroke="STC" stroke-width="SW"/><line x1="20" y1="28" x2="20" y2="32.1" stroke="STC" stroke-width="SW"/><line x1="7.9" y1="20" x2="12" y2="20" stroke="STC" stroke-width="SW"/><line x1="28" y1="20" x2="32.1" y2="20" stroke="STC" stroke-width="SW"/>',
    leaf: '<line x1="20" y1="30.2" x2="20" y2="18" stroke="STC" stroke-width="SW" stroke-linecap="round"/><path d="M15.2,20 A5.1,5.1 0 0,1 20,15" fill="none" stroke="STC" stroke-width="SW" stroke-linecap="round"/><path d="M25,17.4 A5.1,5.1 0 0,1 20,22" fill="none" stroke="STC" stroke-width="SW" stroke-linecap="round"/>',
    tree: '<line x1="20" y1="30.2" x2="20" y2="9.8" stroke="STC" stroke-width="SW" stroke-linecap="round"/><line x1="20" y1="21.5" x2="13.9" y2="14.9" stroke="STC" stroke-width="SW" stroke-linecap="round"/><line x1="20" y1="18.5" x2="26.1" y2="13.9" stroke="STC" stroke-width="SW" stroke-linecap="round"/><line x1="20" y1="15.4" x2="15.9" y2="10.3" stroke="STC" stroke-width="SW" stroke-linecap="round"/>',
    crown: '<polyline points="9.8,25.1 9.8,17.4 14.9,21.1 20,14.4 25.1,21.1 30.2,17.4 30.2,25.1 9.8,25.1" fill="none" stroke="STC" stroke-width="SW" stroke-linejoin="round"/>',
    compass: '<polygon points="20,9.8 21.6,18.4 20,20 18.4,18.4" fill="STC"/><polygon points="30.2,20 21.6,21.6 20,20 21.6,18.4" fill="STC"/><polygon points="20,30.2 18.4,21.6 20,20 21.6,21.6" fill="STC"/><polygon points="9.8,20 18.4,18.4 20,20 18.4,21.6" fill="STC"/>',
    triskele: '<path d="M20,15.7 A4.3,4.3 0 1,1 15.7,20" fill="none" stroke="STC" stroke-width="SW" stroke-linecap="round"/><path d="M24.3,20 A4.3,4.3 0 1,1 20,24.3" fill="none" stroke="STC" stroke-width="SW" stroke-linecap="round"/><path d="M15.7,24.3 A4.3,4.3 0 1,1 24.3,15.7" fill="none" stroke="STC" stroke-width="SW" stroke-linecap="round"/>',
    rune: '<line x1="20" y1="9.8" x2="20" y2="30.2" stroke="STC" stroke-width="SW" stroke-linecap="round"/><line x1="20" y1="14.2" x2="25.1" y2="12.8" stroke="STC" stroke-width="SW" stroke-linecap="round"/><line x1="20" y1="19.8" x2="25.1" y2="18.4" stroke="STC" stroke-width="SW" stroke-linecap="round"/><line x1="20" y1="25.4" x2="25.1" y2="24" stroke="STC" stroke-width="SW" stroke-linecap="round"/>',
    wind: '<path d="M12,14.9 Q20,12 28,14.9" fill="none" stroke="STC" stroke-width="SW" stroke-linecap="round"/><path d="M12,20 Q20,17 27,20" fill="none" stroke="STC" stroke-width="SW" stroke-linecap="round"/><path d="M12,25.1 Q20,22 26,25.1" fill="none" stroke="STC" stroke-width="SW" stroke-linecap="round"/>',
    heart: '<path d="M20,28 L10,18 A5,5 0 0,1 20,14 A5,5 0 0,1 30,18 Z" fill="none" stroke="STC" stroke-width="SW" stroke-linejoin="round"/>',
    speech: '<circle cx="20" cy="18" r="8.7" fill="none" stroke="STC" stroke-width="SW"/><polyline points="17,25.5 14.4,31.2 21,26.3" fill="none" stroke="STC" stroke-width="SW" stroke-linejoin="round"/>',
    knot: '<path d="M17,14.4 A5.6,5.6 0 1,0 17,25.6" fill="none" stroke="STC" stroke-width="SW" stroke-linecap="round"/><path d="M23,25.6 A5.6,5.6 0 1,0 23,14.4" fill="none" stroke="STC" stroke-width="SW" stroke-linecap="round"/>',
    flame: '<path d="M20,30.2 L14.4,23.1 L17.6,17.6 L20,9.8 L23.1,18 L25.6,23.6 Z" fill="none" stroke="STC" stroke-width="SW" stroke-linejoin="round"/><circle cx="20" cy="23.6" r="3.1" fill="none" stroke="STC" stroke-width="SW"/>',
    balance: '<line x1="20" y1="9.8" x2="20" y2="26.1" stroke="STC" stroke-width="SW" stroke-linecap="round"/><line x1="9.8" y1="13.4" x2="30.2" y2="13.4" stroke="STC" stroke-width="SW" stroke-linecap="round"/><path d="M5.7,17.5 A4.1,4.1 0 0,0 13.9,17.5" fill="none" stroke="STC" stroke-width="SW"/><path d="M26.1,17.5 A4.1,4.1 0 0,0 34.3,17.5" fill="none" stroke="STC" stroke-width="SW"/><line x1="15.4" y1="26.1" x2="24.6" y2="26.1" stroke="STC" stroke-width="SW" stroke-linecap="round"/>',
    void: '<path d="M20,9.8 A10.2,10.2 0 0,1 28.2,13.4" fill="none" stroke="STC" stroke-width="SW"/><path d="M30.2,20 A10.2,10.2 0 0,1 25.6,28.8" fill="none" stroke="STC" stroke-width="SW"/><path d="M17.2,29.6 A10.2,10.2 0 0,1 10,22" fill="none" stroke="STC" stroke-width="SW"/>',
    ash: '<path d="M13.6,14.9 A5.6,5.6 0 0,1 26.4,14.9" fill="none" stroke="STC" stroke-width="SW"/><circle cx="12" cy="22" r="1.5" fill="STC"/><circle cx="16" cy="26" r="1.5" fill="STC"/><circle cx="20" cy="23" r="1.5" fill="STC"/><circle cx="24" cy="28" r="1.5" fill="STC"/><circle cx="28" cy="24" r="1.5" fill="STC"/>',
    waves: '<path d="M11,15 A6,6 0 0,1 11,25" fill="none" stroke="STC" stroke-width="SW" stroke-linecap="round"/><path d="M14.3,13 A9.3,9.3 0 0,1 14.3,27" fill="none" stroke="STC" stroke-width="SW" stroke-linecap="round"/><path d="M17.5,11 A12.5,12.5 0 0,1 17.5,29" fill="none" stroke="STC" stroke-width="SW" stroke-linecap="round"/>',
    chain: '<circle cx="16.4" cy="20" r="4.3" fill="none" stroke="STC" stroke-width="SW"/><circle cx="23.6" cy="20" r="4.3" fill="none" stroke="STC" stroke-width="SW"/>',
  };

  var TAG_TO_GLYPH = {
    sens:'eye', savoir:'book', memoire:'spiral', vigilance:'target',
    force:'sword', agilite:'wind', endurance:'tree', finesse:'compass',
    empathie:'heart', verbe:'speech', ruse:'knot', autorite:'crown', franchise:'sun',
    instinct:'spark', nature:'leaf', vision:'crescent',
    rituel:'triskele', sacrifice:'flame', equilibre:'balance', mystere:'rune',
    vide:'void', glitch:'rift', dissolution:'ash', murmure:'waves', emprise:'chain',
  };

  var FAMILY_COLORS = {
    Perception:'#C9A24B', Corps:'#A8703E', Parole:'#B5C04F',
    Intuition:'#4F6B3E', Monde:'#7FA6C9', Corrompu:'#7B4FA3',
  };

  var TAG_FAMILIES = {
    Perception:['sens','savoir','memoire','vigilance'],
    Corps:['force','agilite','endurance','finesse'],
    Parole:['empathie','verbe','ruse','autorite','franchise'],
    Intuition:['instinct','nature','vision'],
    Monde:['rituel','sacrifice','equilibre','mystere'],
    Corrompu:['vide','glitch','dissolution','murmure','emprise'],
  };

  var RARITY_CSS = { Commune:'commune', Rare:'rare', 'Épique':'epique', Mythique:'mythique' };

  var RARITY_HEX = { Commune:'#4A3B28', Rare:'#5A7A8C', 'Épique':'#9A4FA8', Mythique:'#C9A24B' };

  var EFFECT_ICONS = { HEAL:{col:'#5E7A42',icon:'♥'}, PURGE:{col:'#6B4E8A',icon:'✦'}, DRAW:{col:'#3F5A6A',icon:'✚'} };

  function tagNormalize(t) {
    return String(t).toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g, '').replace(/[^a-z]/g, '');
  }

  function tagFamily(t) {
    var n = tagNormalize(t);
    for (var fam in TAG_FAMILIES) {
      if (TAG_FAMILIES[fam].indexOf(n) !== -1) return fam;
    }
    return '';
  }

  function tagColor(t) {
    var fam = tagFamily(t);
    return fam ? FAMILY_COLORS[fam] : '#9C8C6A';
  }

  function glyphSVG(tag, color) {
    var n = tagNormalize(tag);
    var g = TAG_TO_GLYPH[n] || 'eye';
    var raw = GLYPH_SVG[g] || GLYPH_SVG.eye;
    var c = color || '#2A2018';
    var svg = raw.replace(/STC/g, c).replace(/SW/g, '1.5');
    return '<svg viewBox="0 0 40 40" xmlns="http://www.w3.org/2000/svg">' + svg + '</svg>';
  }

  function buildMerlinCard(c, idx) {
    var rar = c.rarity || 'Commune';
    var rarClass = RARITY_CSS[rar] || 'commune';
    var isCorrupted = (c.corruption || 0) >= 3;

    var el = document.createElement('div');
    el.className = 'merlin-card merlin-card--' + rarClass + (isCorrupted ? ' merlin-card--corrupted' : '');
    el.setAttribute('data-deal', '');
    el.style.animationDelay = (idx * 0.05) + 's';

    // Gem (top-left): rarity color + corruption cost
    var gemHex = RARITY_HEX[rar] || '#4A3B28';
    var gem = document.createElement('div');
    gem.className = 'merlin-card__gem';
    gem.style.background = gemHex;
    if ((c.corruption || 0) > 0) gem.textContent = String(c.corruption);
    el.appendChild(gem);

    // Effect badge (top-right)
    if (c.effect_type && EFFECT_ICONS[c.effect_type]) {
      var est = EFFECT_ICONS[c.effect_type];
      var badge = document.createElement('div');
      badge.className = 'merlin-card__badge';
      badge.style.background = est.col;
      badge.textContent = est.icon + ' ' + (c.effect_type || '');
      el.appendChild(badge);
    }

    // Name
    var name = document.createElement('div');
    name.className = 'merlin-card__name';
    name.textContent = c.name || '?';
    el.appendChild(name);

    // Glyph (SVG, based on primary tag)
    var primaryTag = (c.tags && c.tags.length > 0) ? c.tags[0] : '';
    var glyphDiv = document.createElement('div');
    glyphDiv.className = 'merlin-card__glyph';
    glyphDiv.innerHTML = glyphSVG(primaryTag);
    el.appendChild(glyphDiv);

    // Tags (max 2, with family colors)
    if (c.tags && c.tags.length > 0) {
      var tagsDiv = document.createElement('div');
      tagsDiv.className = 'merlin-card__tags';
      var shown = 0;
      c.tags.forEach(function (t) {
        if (shown >= 2) return;
        var chip = document.createElement('span');
        chip.className = 'merlin-card__tag';
        chip.style.color = tagColor(t);
        chip.textContent = String(t).toUpperCase();
        tagsDiv.appendChild(chip);
        shown++;
      });
      el.appendChild(tagsDiv);
    }

    // Evocation (flavor text)
    if (c.evocation) {
      var evo = document.createElement('div');
      evo.className = 'merlin-card__evocation';
      evo.textContent = c.evocation;
      el.appendChild(evo);
    }

    return el;
  }

  function renderCards(panel, d) {
    var cards = d.cards || {};
    ['starter', 'enriched'].forEach(function (pool) {
      var list = cards[pool] || [];
      if (!list.length) return;
      panel.appendChild(section(pool === 'starter' ? 'Cartes de depart (' + list.length + ')' : 'Cartes enrichies (' + list.length + ')'));
      var grid = document.createElement('div');
      grid.className = 'merlin-card-grid';
      list.forEach(function (c, i) {
        grid.appendChild(buildMerlinCard(c, i));
      });
      panel.appendChild(grid);
    });
  }

  function renderMechanics(panel, d) {
    panel.appendChild(section('Resolution — Roue des degres'));
    var res = d.resolution || {};

    // Visual resolution wheel
    if (res.deltas) {
      var degreeColors = { eclatante:'#4F6B3E', reussite:'#7FA65C', partiel:'#C9A24B', echec:'#7B4FA3' };
      var degreeLabels = { eclatante:'Eclatante', reussite:'Reussite', partiel:'Partiel', echec:'Echec' };
      var wheel = h('div', { className: 'resolution-wheel' });
      Object.entries(res.deltas).forEach(function (entry) {
        var k = entry[0], v = entry[1];
        var color = degreeColors[k] || 'var(--dim-warm)';
        var label = degreeLabels[k] || k;
        var band = (res.die_bands && res.die_bands[k]) ? res.die_bands[k] : null;
        var rangeStr = band ? (Array.isArray(band) ? band.join('-') : String(band)) : '';
        var seg = h('div', { className: 'resolution-segment' },
          h('div', { className: 'resolution-segment__label', style: 'color:' + color }, label),
          h('div', { className: 'resolution-segment__delta', style: 'color:' + color }, (v > 0 ? '+' : '') + String(v)),
          rangeStr ? h('div', { className: 'resolution-segment__range' }, 'De : ' + rangeStr) : h('span')
        );
        wheel.appendChild(seg);
      });
      panel.appendChild(wheel);
    }

    // Detailed table below
    panel.appendChild(section('Detail des deltas'));
    if (res.deltas) {
      var tbl = h('table', null,
        h('thead', null, h('tr', null, h('th', null, 'Degre'), h('th', null, 'Delta Integrite'), h('th', null, 'Plage de'))),
        h('tbody', null, ...Object.entries(res.deltas).map(function (entry) {
          var k = entry[0], v = entry[1];
          var band = (res.die_bands && res.die_bands[k]) ? res.die_bands[k] : '-';
          return h('tr', null,
            h('td', null, k),
            h('td', { style: v > 0 ? 'color:var(--green)' : v < 0 ? 'color:var(--violet)' : '' }, (v > 0 ? '+' : '') + String(v)),
            h('td', null, Array.isArray(band) ? band.join('-') : String(band))
          );
        }))
      );
      panel.appendChild(tbl);
    }

    // Combo system description
    panel.appendChild(section('Systeme de combinaison'));
    panel.appendChild(h('div', { style: 'display:flex;gap:12px;align-items:center;padding:12px;background:var(--surface);border-radius:6px;border:1px solid var(--border-brun);flex-wrap:wrap;justify-content:center;' },
      h('div', { style: 'text-align:center;padding:8px 16px;' },
        h('div', { style: 'font-size:32px;' }, '🃏'),
        h('div', { style: 'font-size:11px;color:var(--dim-warm);margin-top:4px;' }, '1 Principale')
      ),
      h('div', { style: 'font-size:20px;color:var(--gold);' }, '+'),
      h('div', { style: 'text-align:center;padding:8px 16px;' },
        h('div', { style: 'font-size:24px;' }, '🃏🃏'),
        h('div', { style: 'font-size:11px;color:var(--dim-warm);margin-top:4px;' }, '1-2 Modificateurs')
      ),
      h('div', { style: 'font-size:20px;color:var(--gold);' }, '→'),
      h('div', { style: 'text-align:center;padding:8px 16px;' },
        h('div', { style: 'font-size:14px;color:var(--gold);' }, 'Tags couverts = degre'),
        h('div', { style: 'font-size:11px;color:var(--dim-warm);margin-top:4px;' }, 'Code applique, Gemma narre')
      )
    ));
  }

  function renderGauges(panel, d) {
    panel.appendChild(section('Jauges — Apercu visuel'));

    // Integrity gauge (0-10, starts at 7)
    var intBar = h('div', { className: 'gauge-bar', style: 'max-width:500px;' });
    var intFill = h('div', { className: 'gauge-bar__fill', style: 'width:70%;background:linear-gradient(90deg,#4F6B3E,#7FA65C);' }, '7/10');
    var intLabel = h('div', { className: 'gauge-bar__label' }, 'Integrite');
    intBar.appendChild(intLabel);
    intBar.appendChild(intFill);
    panel.appendChild(h('div', { style: 'margin:16px 0;' },
      h('div', { style: 'font-size:12px;color:var(--dim-warm);margin-bottom:4px;' }, 'Integrite — 0 a 10 (depart 7). Mort narrative a 0.'),
      intBar
    ));

    // Corruption gauge (seuil /5, paliers glitch)
    var corBar = h('div', { className: 'gauge-bar', style: 'max-width:500px;' });
    var corFill = h('div', { className: 'gauge-bar__fill', style: 'width:30%;background:linear-gradient(90deg,#7B4FA3,#9A4FA8);' }, '6');
    var corLabel = h('div', { className: 'gauge-bar__label' }, 'Corruption');
    corBar.appendChild(corLabel);
    corBar.appendChild(corFill);
    panel.appendChild(h('div', { style: 'margin:16px 0;' },
      h('div', { style: 'font-size:12px;color:var(--dim-warm);margin-bottom:4px;' }, 'Corruption — seuil tous les 5 pts. Plafond ~15-20 = fin corrompue.'),
      corBar
    ));

    // Corruption paliers (glitch R75)
    panel.appendChild(section('Paliers de corruption (R75)'));
    var paliers = [
      { seuil: '0-4', nom: 'Sain', desc: 'Pas de glitch visuel', col: '#7FA65C' },
      { seuil: '5-9', nom: 'Trouble', desc: 'Legers artefacts visuels, scanlines', col: '#C9A24B' },
      { seuil: '10-14', nom: 'Emprise', desc: 'Glitch prononce, couleurs alterees', col: '#9A4FA8' },
      { seuil: '15+', nom: 'Dissolution', desc: 'Distorsion max, fin corrompue imminente', col: '#7B4FA3' },
    ];
    var palierGrid = h('div', { className: 'resolution-wheel' });
    paliers.forEach(function (p) {
      palierGrid.appendChild(h('div', { className: 'resolution-segment', style: 'border-color:' + p.col + ';' },
        h('div', { className: 'resolution-segment__label', style: 'color:' + p.col }, p.nom),
        h('div', { className: 'resolution-segment__delta', style: 'color:' + p.col + ';font-size:16px;' }, p.seuil),
        h('div', { className: 'resolution-segment__range' }, p.desc)
      ));
    });
    panel.appendChild(palierGrid);

    // Table detail
    panel.appendChild(section('Detail'));
    var res = d.resolution || {};
    var items = [
      ['Integrite', '0-10, depart 7, mort narrative a 0 (jugee par Gemma R65)'],
      ['Corruption', 'cout 0-3 par carte risquee, seuil /5 → evenement + carte corrompue'],
      ['Prix partiel', String(res.partiel_price != null ? res.partiel_price : '-')],
    ];
    var tbl = h('table', null,
      h('thead', null, h('tr', null, h('th', null, 'Jauge'), h('th', null, 'Detail'))),
      h('tbody', null, ...items.map(function (row) {
        return h('tr', null, h('td', null, row[0]), h('td', null, row[1]));
      }))
    );
    panel.appendChild(tbl);
  }

  function renderLLM(panel, d) {
    panel.appendChild(section('LLM / Gemma 4'));
    panel.appendChild(h('p', { style: 'color:var(--dim-warm);margin-bottom:16px' },
      'Gemma 4 E2B natif via GDExtension (addons/merlin_llm/). GBNF grammar, streaming, 100% local.'));
    const autoloads = d.autoloads || [];
    if (autoloads.length) {
      panel.appendChild(section('Autoloads'));
      const tbl = h('table', null,
        h('thead', null, h('tr', null, h('th', null, 'Nom'), h('th', null, 'Chemin'))),
        h('tbody', null, ...autoloads.map(a =>
          h('tr', null, h('td', null, a.name), h('td', null, a.path))
        ))
      );
      panel.appendChild(tbl);
    }
  }

  function renderAssets(panel, d) {
    panel.appendChild(section('Assets par categorie'));

    let currentPage = 1;
    let debounceTimer = null;
    const PAGE_LIMIT = 20;

    const searchBar = h('div', { className: 'search-bar' });
    const searchInput = h('input', { type: 'text', placeholder: 'Rechercher un asset...' });
    const catSelect = h('select', null, h('option', { value: '' }, 'Toutes les categories'));
    searchBar.appendChild(searchInput);
    searchBar.appendChild(catSelect);
    panel.appendChild(searchBar);

    const statsDiv = h('div', { style: 'color:var(--ink-dim);font-size:12px;margin:8px 0;' });
    panel.appendChild(statsDiv);

    const grid = h('div', { className: 'asset-grid' });
    panel.appendChild(grid);

    const pager = h('div', { style: 'display:flex;gap:8px;justify-content:center;margin:16px 0;' });
    panel.appendChild(pager);

    async function loadAssets(page) {
      currentPage = page;
      grid.innerHTML = '<p style="color:var(--dim-warm);padding:24px;grid-column:1/-1">Chargement...</p>';
      pager.innerHTML = '';
      const params = { page: page, limit: PAGE_LIMIT };
      if (catSelect.value) params.category = catSelect.value;
      if (searchInput.value.trim()) params.search = searchInput.value.trim();

      try {
        const result = await API.assets(params);
        const files = result.files || [];
        const total = result.total || 0;
        const pages = result.pages || 1;

        if (result.categories) {
          const opts = catSelect.querySelectorAll('option');
          if (opts.length <= 1) {
            Object.entries(result.categories).sort().forEach(([cat, count]) => {
              catSelect.appendChild(h('option', { value: cat }, cat + ' (' + count + ')'));
            });
          }
        }

        statsDiv.textContent = total + ' assets' + (catSelect.value ? ' dans ' + catSelect.value : '') +
          (searchInput.value.trim() ? ' — recherche: "' + searchInput.value.trim() + '"' : '') +
          ' — page ' + page + '/' + pages;

        grid.innerHTML = '';
        if (!files.length) {
          grid.appendChild(h('p', { style: 'color:var(--ink-dim);padding:24px;grid-column:1/-1' }, 'Aucun asset trouve.'));
          return;
        }

        files.forEach(function (f) {
          var isImage = ['.png', '.jpg', '.jpeg', '.svg', '.webp', '.bmp', '.tga'].indexOf(f.ext) !== -1;
          var isAudio = ['.wav', '.ogg', '.mp3', '.flac'].indexOf(f.ext) !== -1;
          var sizeStr = f.size_bytes > 1048576 ? (f.size_bytes / 1048576).toFixed(1) + ' MB'
            : f.size_bytes > 1024 ? Math.round(f.size_bytes / 1024) + ' KB'
            : f.size_bytes + ' B';

          var tile = h('div', { className: 'asset-tile', onClick: function () { openAssetModal(f); } },
            h('div', { className: 'thumb' },
              isImage
                ? h('img', { src: API.thumb(f.path), alt: f.name, loading: 'lazy' })
                : h('span', { className: 'icon' }, extIcon(f.ext.replace('.', '')))
            ),
            h('div', { className: 'info' },
              h('div', { className: 'name', title: f.path }, f.name),
              h('div', { className: 'size' }, sizeStr + ' — ' + f.category)
            )
          );
          if (isAudio) {
            tile.appendChild(h('audio', { controls: '', preload: 'none', style: 'width:100%;height:24px;margin-top:4px;' },
              h('source', { src: '/api/asset/' + encodeURI(f.path) })
            ));
          }
          grid.appendChild(tile);
        });

        pager.innerHTML = '';
        if (pages > 1) {
          if (page > 1) pager.appendChild(h('button', { className: 'btn btn--gold', onClick: function () { loadAssets(page - 1); } }, 'Precedent'));
          pager.appendChild(h('span', { style: 'color:var(--dim-warm);align-self:center;font-size:12px;' }, page + ' / ' + pages));
          if (page < pages) pager.appendChild(h('button', { className: 'btn btn--gold', onClick: function () { loadAssets(page + 1); } }, 'Suivant'));
        }
      } catch (err) {
        grid.innerHTML = '';
        grid.appendChild(h('p', { style: 'color:var(--violet);padding:24px;grid-column:1/-1' }, 'Erreur: ' + esc(err.message)));
      }
    }

    searchInput.addEventListener('input', function () {
      clearTimeout(debounceTimer);
      debounceTimer = setTimeout(function () { loadAssets(1); }, 400);
    });
    catSelect.addEventListener('change', function () { loadAssets(1); });

    _lazyCallbacks['assets'] = function () { loadAssets(1); };
  }

  var TAG_PRESETS = [
    { key: 'validated', label: 'Valide', icon: '✓' },
    { key: 'replace',   label: 'A remplacer', icon: '⚠' },
    { key: 'wip',       label: 'WIP', icon: '🔄' },
    { key: 'delete',    label: 'A supprimer', icon: '✕' },
  ];

  function openAssetModal(f) {
    var modal = document.getElementById('modal');
    var content = document.getElementById('modal-content');
    content.innerHTML = '';

    var isImage = ['.png', '.jpg', '.jpeg', '.svg', '.webp', '.bmp', '.tga'].indexOf(f.ext) !== -1;
    var isAudio = ['.wav', '.ogg', '.mp3', '.flac'].indexOf(f.ext) !== -1;
    var isShader = ['.gdshader', '.shader'].indexOf(f.ext) !== -1;

    content.appendChild(h('h2', { style: 'color:var(--gold);margin-bottom:12px;font-size:16px;' }, f.name));
    content.appendChild(h('p', { style: 'color:var(--ink-dim);font-size:12px;margin-bottom:16px;' }, f.path));

    if (isImage) {
      content.appendChild(h('img', { src: '/api/asset/' + encodeURI(f.path), style: 'max-width:100%;max-height:50vh;border-radius:4px;border:1px solid var(--border-brun);' }));
    } else if (isAudio) {
      content.appendChild(h('audio', { controls: '', preload: 'metadata', style: 'width:100%;margin:16px 0;' },
        h('source', { src: '/api/asset/' + encodeURI(f.path) })
      ));
    } else if (isShader) {
      var pre = h('pre', { style: 'background:var(--surface);padding:12px;border-radius:4px;max-height:40vh;overflow:auto;font-size:12px;color:var(--cream);' }, 'Chargement...');
      content.appendChild(pre);
      fetch('/api/asset/' + encodeURI(f.path)).then(function (r) { return r.text(); }).then(function (text) { pre.textContent = text; });
    }

    var tagBar = h('div', { style: 'display:flex;gap:6px;margin-top:12px;flex-wrap:wrap;' });
    content.appendChild(tagBar);

    var noteArea = h('textarea', {
      placeholder: 'Note sur cet asset...',
      style: 'width:100%;height:60px;margin-top:8px;padding:8px;background:var(--surface);color:var(--cream);border:1px solid var(--border-brun);border-radius:4px;font-size:12px;resize:vertical;'
    });
    content.appendChild(noteArea);

    var currentTags = [];

    function renderTags(tags) {
      currentTags = tags || [];
      tagBar.innerHTML = '';
      TAG_PRESETS.forEach(function (preset) {
        var active = currentTags.indexOf(preset.key) !== -1;
        var btn = h('button', {
          className: 'tag ' + (active ? 'tag--active' : 'tag--wip'),
          style: 'cursor:pointer;' + (active ? 'background:var(--gold);color:var(--ink);' : ''),
          onClick: function () {
            var idx = currentTags.indexOf(preset.key);
            if (idx !== -1) currentTags.splice(idx, 1);
            else currentTags.push(preset.key);
            API.annotate(f.path, { tags: currentTags, note: noteArea.value });
            renderTags(currentTags);
          }
        }, preset.icon + ' ' + preset.label);
        tagBar.appendChild(btn);
      });
    }

    API.annotations().then(function (all) {
      var ann = all[f.path] || {};
      renderTags(ann.tags || []);
      noteArea.value = ann.note || '';
    });

    var saveTimer = null;
    noteArea.addEventListener('input', function () {
      clearTimeout(saveTimer);
      saveTimer = setTimeout(function () {
        API.annotate(f.path, { tags: currentTags, note: noteArea.value });
      }, 800);
    });

    var actions = h('div', { style: 'display:flex;gap:8px;margin-top:12px;' });
    actions.appendChild(h('button', { className: 'btn btn--danger', onClick: function () {
      if (confirm('Supprimer ' + f.name + ' ?')) {
        API.deleteAsset(f.path).then(function () { modal.classList.remove('open'); location.reload(); });
      }
    } }, 'Supprimer'));
    actions.appendChild(h('button', { className: 'btn btn--gold', onClick: function () {
      var prompt = 'Remplace l\'asset "' + f.path + '" par : [description du nouvel asset]';
      API.clipboard({ text: prompt }).then(function () {
        alert('Prompt copie dans le presse-papiers.');
      }).catch(function () {
        navigator.clipboard.writeText(prompt).then(function () { alert('Prompt copie (fallback navigateur).'); });
      });
    } }, 'Modifier (clipboard)'));
    content.appendChild(actions);

    modal.classList.add('open');
  }

  function extIcon(ext) {
    const icons = {
      wav: '♫', ogg: '♫', mp3: '♫',
      gdshader: '✨', shader: '✨',
      glb: '◆', gltf: '◆', obj: '◆',
      ttf: 'Aa', otf: 'Aa', woff: 'Aa',
      tres: '⚙', tscn: '⚙',
      gd: '⚙',
    };
    return icons[ext] || '□';
  }

  function renderVisual(panel, d) {
    panel.appendChild(section('Palette canonique'));
    const palette = d.palette || {};
    const grid = h('div', { style: 'display:grid;grid-template-columns:repeat(auto-fill,minmax(180px,1fr));gap:8px;' });
    Object.entries(palette).forEach(([name, info]) => {
      const hex = info.hex || '888888';
      const swatch = h('div', {
        style: 'display:flex;align-items:center;gap:8px;padding:8px;background:var(--surface);border:1px solid var(--border-brun);border-radius:4px;'
      },
        h('div', { style: `width:32px;height:32px;border-radius:4px;background:#${hex};border:1px solid var(--border-brun);flex-shrink:0;` }),
        h('div', null,
          h('div', { style: 'font-size:12px;color:var(--cream);' }, name),
          h('div', { style: 'font-size:11px;color:var(--ink-dim);' }, `#${hex} — ${info.desc || ''}`)
        )
      );
      grid.appendChild(swatch);
    });
    panel.appendChild(grid);

    if (d.font_sizes && Object.keys(d.font_sizes).length) {
      panel.appendChild(section('Tailles de police'));
      const tbl = h('table', null,
        h('thead', null, h('tr', null, h('th', null, 'Constante'), h('th', null, 'px'))),
        h('tbody', null, ...Object.entries(d.font_sizes).map(([k, v]) =>
          h('tr', null, h('td', null, k), h('td', null, String(v)))
        ))
      );
      panel.appendChild(tbl);
    }

    if (d.card_styles) {
      panel.appendChild(section('Styles de cartes'));
      Object.entries(d.card_styles).forEach(([group, styles]) => {
        panel.appendChild(h('h3', { style: 'color:var(--dim-warm);margin:12px 0 6px;font-size:13px;' }, group));
        const tbl = h('table', null,
          h('thead', null, h('tr', null, h('th', null, 'Cle'), h('th', null, 'Couleur'), h('th', null, 'Apercu'))),
          h('tbody', null, ...Object.entries(styles).map(([k, v]) => {
            const color = typeof v === 'object' ? (v.color || v.hex || '') : String(v);
            return h('tr', null,
              h('td', null, k),
              h('td', null, color),
              h('td', null, h('div', { style: `width:24px;height:14px;border-radius:3px;background:${color.startsWith('#') ? color : '#' + color};` }))
            );
          }))
        );
        panel.appendChild(tbl);
      });
    }
  }

  function renderLore(panel, d) {
    panel.appendChild(section('Sections BIBLE.md'));
    (d.bible_sections || []).forEach(s => {
      panel.appendChild(h('details', { style: 'margin-bottom:8px;' },
        h('summary', { style: 'cursor:pointer;color:var(--gold);font-size:13px;padding:6px 0;' }, s.title),
        h('div', { style: 'padding:8px 16px;color:var(--dim-warm);font-size:12px;line-height:1.6;white-space:pre-wrap;' }, s.body || '')
      ));
    });
  }

  function renderAudio(panel, d) {
    panel.appendChild(section('Audio'));
    panel.appendChild(h('p', { style: 'color:var(--dim-warm);margin-bottom:16px;' },
      'Theme menu MusicGen. SFX/stingers = roadmap v10.16 (BIBLE S22).'));

    var container = h('div');
    panel.appendChild(container);

    _lazyCallbacks['audio'] = function () {
    API.assets({ category: 'Audio', limit: 200 }).then(function (result) {
      var files = result.files || [];
      container.innerHTML = '';
      if (!files.length) {
        container.appendChild(h('p', { style: 'color:var(--ink-dim)' }, 'Aucun fichier audio trouve.'));
        return;
      }
      container.appendChild(section('Fichiers audio (' + files.length + '/' + result.total + ')'));
      files.forEach(function (f) {
        var sizeStr = f.size_bytes > 1024 ? Math.round(f.size_bytes / 1024) + ' KB' : f.size_bytes + ' B';
        container.appendChild(h('div', { style: 'margin-bottom:12px;padding:8px;background:var(--surface);border-radius:4px;border:1px solid var(--border-brun);' },
          h('div', { style: 'display:flex;justify-content:space-between;margin-bottom:4px;' },
            h('span', { style: 'font-size:12px;color:var(--cream);' }, f.name),
            h('span', { style: 'font-size:11px;color:var(--ink-dim);' }, sizeStr)
          ),
          h('div', { style: 'font-size:10px;color:var(--ink-dim);margin-bottom:4px;' }, f.path),
          h('audio', { controls: '', preload: 'none', style: 'height:28px;width:100%;max-width:500px;' },
            h('source', { src: '/api/asset/' + encodeURI(f.path) })
          )
        ));
      });
    });
    };
  }

  function renderProgression(panel, d) {
    panel.appendChild(section('Progression & Meta'));
    panel.appendChild(h('p', { style: 'color:var(--dim-warm);line-height:1.6;' },
      'Quetes v10.14+ : chaine 2-3 quetes de 2-5 beats. De pre-tire par rarete. Ramification conditionnelle. Meta cross-run : fragments du Graal, codex, PNJ a memoire.'));
    if (d.tags) {
      panel.appendChild(section('Familles de tags'));
      const families = d.tags.families || {};
      Object.entries(families).forEach(([fam, tags]) => {
        panel.appendChild(h('div', { style: 'margin-bottom:8px;' },
          h('span', { style: 'color:var(--gold);font-size:13px;margin-right:8px;' }, fam + ':'),
          ...tags.map(t => h('span', { className: 'tag tag--wip' }, t))
        ));
      });
    }
  }

  function renderArchitecture(panel, d) {
    panel.appendChild(section('Scripts'));
    const scripts = d.scripts || [];
    if (scripts.length) {
      const tbl = h('table', null,
        h('thead', null, h('tr', null, h('th', null, 'Fichier'), h('th', null, 'Lignes'), h('th', null, 'Couche'))),
        h('tbody', null, ...scripts.map(s =>
          h('tr', null,
            h('td', null, s.name),
            h('td', null, String(s.lines)),
            h('td', null, s.layer || '-')
          )
        ))
      );
      panel.appendChild(tbl);
    }
    if (d.addons && d.addons.length) {
      panel.appendChild(section('Addons'));
      panel.appendChild(h('ul', { style: 'padding-left:20px;' },
        ...d.addons.map(a => h('li', { style: 'color:var(--dim-warm);font-size:13px;margin:4px 0;' }, a))
      ));
    }
  }

  function renderJournal(panel, d) {
    panel.appendChild(section('Regles (R-numerotees)'));
    const searchBar = h('div', { className: 'search-bar' });
    const input = h('input', { type: 'text', placeholder: 'Rechercher une regle...' });
    searchBar.appendChild(input);
    panel.appendChild(searchBar);

    const container = h('div');
    panel.appendChild(container);

    function render(filter) {
      container.innerHTML = '';
      const lf = (filter || '').toLowerCase();
      (d.rules || []).forEach(r => {
        const text = `R${r.num} ${r.title} ${r.desc}`.toLowerCase();
        if (lf && !text.includes(lf)) return;
        container.appendChild(h('div', { className: 'card', style: 'margin-bottom:8px;' },
          h('h3', null, `R${r.num} — ${r.title}`),
          h('p', null, r.desc || '')
        ));
      });
    }

    input.addEventListener('input', () => render(input.value));
    render('');
  }

  function renderFormulas(panel, d) {
    panel.appendChild(section('Vocabulaire d\'animation — Demos interactives'));
    panel.appendChild(h('p', { style: 'color:var(--dim-warm);font-size:12px;margin-bottom:12px;' },
      'Cliquez sur une constante pour jouer son animation. Timings identiques au GDScript (MerlinVisual).'));

    if (d.anim_vocab && d.anim_vocab.length) {
      var animDefs = {
        DUR_TAP_DOWN:  { dur: 0.06, css: 'transform:scale(0.97)', desc: 'Press bouton' },
        DUR_TAP_UP:    { dur: 0.10, css: 'transform:scale(1.0)', desc: 'Relache bouton' },
        DUR_FAST:      { dur: 0.12, css: 'transform:scale(1.06)', desc: 'Hover carte' },
        DUR_UI:        { dur: 0.22, css: 'transform:translateY(-18px)', desc: 'Vol carte' },
        DUR_DEAL:      { dur: 0.28, css: 'transform:translateY(0) scale(1)', from: 'transform:translateY(40px) scale(0.8)', desc: 'Distribution' },
        DUR_DISCARD:   { dur: 0.25, css: 'transform:translateX(-40px) rotate(-6deg);opacity:0', desc: 'Defausse' },
        DUR_VEIL_IN:   { dur: 0.20, css: 'opacity:0.7;background:var(--bg-deep)', desc: 'Voile entree' },
        DUR_VEIL_OUT:  { dur: 0.25, css: 'opacity:0', desc: 'Voile sortie' },
        STAGGER:       { dur: 0.05, css: 'transform:translateY(-4px)', desc: 'Decalage groupe' },
        DUR_SLIDE_UP:  { dur: 0.35, css: 'transform:translateY(-20px)', desc: 'Slide situation' },
        DUR_BREATHE:   { dur: 3.0,  css: 'transform:scale(1.02);opacity:0.85', desc: 'Respiration titre', loop: true },
        DUR_IMPACT_FREEZE: { dur: 0.08, css: 'transform:scale(1.15)', desc: 'Gel impact' },
        DUR_FLASH:     { dur: 0.12, css: 'background:var(--gold);opacity:0.8', desc: 'Flash' },
        DUR_INK_WIPE:  { dur: 0.65, css: 'clip-path:inset(0 0 0 0)', from: 'clip-path:inset(0 100% 0 0)', desc: 'Encre wipe' },
        DUR_MOTE_FADE: { dur: 0.30, css: 'opacity:0;transform:translateY(-10px)', desc: 'Mote disparition' },
        DUR_WORLD_REACT: { dur: 1.50, css: 'filter:brightness(1.3) saturate(1.2)', desc: 'Reaction monde' },
      };

      var grid = h('div', { className: 'anim-demo-grid' });
      d.anim_vocab.forEach(function (a) {
        var def = animDefs[a.name];
        var preview = h('div', { className: 'anim-demo__preview' });
        var demo = h('div', { className: 'anim-demo', onClick: function () {
          if (!def) return;
          var dur = parseFloat(a.value) || def.dur;
          if (def.from) {
            preview.style.cssText = 'width:48px;height:48px;margin:0 auto 8px;background:var(--gold);border-radius:6px;transition:none;' + def.from;
            requestAnimationFrame(function () {
              preview.style.transition = 'all ' + dur + 's cubic-bezier(0.34, 1.56, 0.64, 1)';
              preview.style.cssText = 'width:48px;height:48px;margin:0 auto 8px;background:var(--gold);border-radius:6px;transition:all ' + dur + 's cubic-bezier(0.34, 1.56, 0.64, 1);' + def.css;
            });
          } else {
            preview.style.transition = 'all ' + dur + 's cubic-bezier(0.34, 1.56, 0.64, 1)';
            preview.style.cssText += ';' + def.css;
            setTimeout(function () {
              preview.style.cssText = 'width:48px;height:48px;margin:0 auto 8px;background:var(--gold);border-radius:6px;transition:all ' + dur + 's ease;';
            }, dur * 1000 + 100);
          }
        } },
          preview,
          h('div', { className: 'anim-demo__name' }, a.name),
          h('div', { className: 'anim-demo__value' }, a.value + 's'),
          h('div', { className: 'anim-demo__note' }, def ? def.desc : (a.comment || ''))
        );
        grid.appendChild(demo);
      });
      panel.appendChild(grid);

      // Reference table below
      panel.appendChild(section('Reference complete'));
      var tbl = h('table', null,
        h('thead', null, h('tr', null, h('th', null, 'Constante'), h('th', null, 'Valeur'), h('th', null, 'Easing'), h('th', null, 'Note'))),
        h('tbody', null, ...d.anim_vocab.map(function (a) {
          var def = animDefs[a.name];
          return h('tr', null,
            h('td', { style: 'color:var(--gold);' }, a.name),
            h('td', null, a.value),
            h('td', null, a.name.indexOf('DEAL') !== -1 ? 'BACK out' : a.name.indexOf('BREATHE') !== -1 ? 'sine in-out' : 'cubic-bezier'),
            h('td', null, a.comment || (def ? def.desc : ''))
          );
        }))
      );
      panel.appendChild(tbl);
    }
  }
})();
