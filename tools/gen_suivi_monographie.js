// Generator: Suivi Monographie HTML
'use strict';
const fs = require('fs');
const path = require('path');

// Target path — edit as needed
const TARGET = process.argv[2] || 'C:\\Users\\PGNK2128\\Downloads\\Suivi Monographie.html';

// DROM classifier for ProPME agences
// Returns 'DROM' if agence is overseas, 'METRO' otherwise
const DROM_KEYWORDS = ['CARAIBES', 'REUNION', 'MAYOTTE', 'ANTILLES', 'GUYANE', 'MARTINIQUE', 'GUADELOUPE'];
// function isDROM(agence) — injected in JS

const HTML = `<!DOCTYPE html>
<html lang="fr">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Suivi Monographie</title>
<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/boosted@5.3.8/dist/css/boosted.min.css" crossorigin="anonymous">
<script src="https://cdn.plot.ly/plotly-2.35.2.min.js"></script>
<style>
:root{--o:#FF7900;--oa:#f16e00;--gr:#50BE87;--re:#cd3c14;--ye:#FFD200;--g9:#141414;--g7:#595959;--g4:#cccccc;--g2:#eeeeee;--g1:#f6f6f6;}
body{background:var(--g1);font-family:'HelvNeue OrangeT',Arial,sans-serif;font-size:.875rem;}
.ah{background:var(--g9);border-bottom:4px solid var(--o);padding:.6rem 1.25rem;display:flex;align-items:center;gap:.75rem;flex-wrap:wrap;}
.ao{color:var(--o);font-weight:700;font-size:1.15rem;} .as{color:#555;} .at{color:#fff;font-size:.85rem;} .ast{margin-left:auto;color:#888;font-size:.78rem;}
.bs{background:var(--o);color:#fff;border:none;border-radius:3px;padding:.28rem .85rem;font-size:.78rem;font-weight:600;cursor:pointer;transition:background .15s;}
.bs:hover{background:var(--oa);} .bs.saved{background:var(--gr);}
.nav-tabs{background:#fff;border-bottom:2px solid #dee2e6;padding:0 1rem;flex-wrap:nowrap;overflow-x:auto;}
.nav-tabs .nav-link{color:var(--g7);border:none;border-bottom:3px solid transparent;padding:.7rem .9rem;font-weight:500;font-size:.82rem;white-space:nowrap;}
.nav-tabs .nav-link:hover{color:var(--o);background:none;}
.nav-tabs .nav-link.active{color:var(--o);border-bottom:3px solid var(--o);background:none;}
.tb{background:var(--g2);color:var(--g7);border-radius:10px;font-size:.68rem;padding:1px 6px;margin-left:.3rem;font-weight:600;}
.nav-link.active .tb{background:rgba(255,121,0,.15);color:var(--o);}
.tab-content{padding:1.25rem;}
.kg{display:grid;gap:.75rem;grid-template-columns:repeat(auto-fit,minmax(130px,1fr));margin-bottom:1.25rem;}
.kc{background:#fff;border-radius:4px;padding:.9rem 1rem;box-shadow:0 1px 3px rgba(0,0,0,.07);border-top:3px solid var(--o);}
.kv{font-size:1.65rem;font-weight:700;line-height:1.1;color:var(--g9);}
.kl{font-size:.68rem;color:var(--g7);text-transform:uppercase;letter-spacing:.06em;margin-top:.15rem;}
.kc.kP .kv{color:var(--gr);} .kc.kN .kv{color:#a06b00;} .kc.kD .kv{color:var(--re);} .kc.kS .kv{color:var(--o);}
.cg{display:grid;gap:.75rem;grid-template-columns:1fr 1fr;margin-bottom:1rem;}
.cc{background:#fff;border-radius:4px;box-shadow:0 1px 3px rgba(0,0,0,.07);padding:.9rem;}
.cc h6{font-size:.72rem;text-transform:uppercase;letter-spacing:.05em;color:var(--g7);margin-bottom:.6rem;border-bottom:1px solid var(--g2);padding-bottom:.4rem;}
.cf{grid-column:1/-1;}
.sc{background:#fff;border-radius:4px;box-shadow:0 1px 3px rgba(0,0,0,.07);padding:.9rem;margin-bottom:.9rem;}
.sc h6{font-size:.72rem;text-transform:uppercase;letter-spacing:.05em;color:var(--g7);margin-bottom:.6rem;border-bottom:1px solid var(--g2);padding-bottom:.4rem;}
.bp{display:inline-block;padding:.2em .55em;border-radius:3px;font-size:.72rem;font-weight:600;}
.bP{background:var(--gr);color:#fff;} .bN{background:var(--ye);color:#333;} .bD{background:var(--re);color:#fff;}
.np{color:var(--gr);font-weight:700;} .nn{color:var(--re);font-weight:700;} .nz{color:#a06b00;font-weight:700;}
.dt thead th{font-size:.7rem;text-transform:uppercase;letter-spacing:.05em;color:var(--g7);background:var(--g1);cursor:pointer;white-space:nowrap;}
.dt thead th:hover{background:var(--g2);color:var(--o);} .dt td{vertical-align:middle;font-size:.8rem;}
.br{padding:.15rem .45rem;font-size:.72rem;}
.ht{font-size:.8rem;}
.h1r{font-weight:700;background:var(--g1);cursor:pointer;} .h1r:hover{background:var(--g2);}
.h1r td:first-child::before{content:'\\25B6 ';font-size:.65rem;color:var(--o);}
.h1r.open td:first-child::before{content:'\\25BC ';}
.h2r{font-weight:500;cursor:pointer;} .h2r td:first-child{padding-left:1.8rem;}
.h2r td:first-child::before{content:'\\25B6 ';font-size:.6rem;color:var(--g7);}
.h2r.open td:first-child::before{content:'\\25BC ';}
.h3r td:first-child{padding-left:3.2rem;color:var(--g7);font-size:.75rem;}
.ht-tot{font-weight:700;background:#eef0f2;}
.iz{border:2px dashed var(--g4);border-radius:4px;background:#fff;padding:1.25rem;}
.iz textarea{font-family:monospace;font-size:.75rem;}
.ipv{max-height:260px;overflow-y:auto;}
.dtb{background:#fff;border-radius:4px;box-shadow:0 1px 3px rgba(0,0,0,.07);padding:.65rem .9rem;margin-bottom:.75rem;display:flex;flex-wrap:wrap;gap:.5rem;align-items:center;}
.si{min-width:200px;font-size:.82rem;}
.pr{display:flex;align-items:center;justify-content:space-between;padding:.4rem 0;}
.pi{font-size:.78rem;color:var(--g7);}
.pagination .page-link{font-size:.78rem;color:var(--g7);}
.pagination .page-item.active .page-link{background:var(--o);border-color:var(--o);color:#fff;}
.toast-container{position:fixed;bottom:1.25rem;right:1.25rem;z-index:1100;}
.es{text-align:center;padding:2.5rem;color:var(--g7);}
.db{background:#fff;border-radius:4px;box-shadow:0 1px 3px rgba(0,0,0,.07);padding:.6rem .9rem;margin-bottom:.9rem;display:flex;gap:.5rem;align-items:center;flex-wrap:wrap;}
.db label{font-size:.78rem;font-weight:600;color:var(--g7);margin:0;}
.fil-btn{border:1.5px solid var(--g4);background:#fff;color:var(--g7);border-radius:3px;padding:.2rem .65rem;font-size:.78rem;cursor:pointer;transition:all .15s;}
.fil-btn:hover{border-color:var(--o);color:var(--o);}
.fil-btn.active{background:var(--o);border-color:var(--o);color:#fff;font-weight:600;}
.fil-btn.drom{} .fil-btn.drom.active{background:#0a6ebd;border-color:#0a6ebd;}
.tag-drom{background:#0a6ebd;color:#fff;border-radius:3px;font-size:.65rem;padding:.1em .4em;font-weight:700;margin-left:.3rem;}
.tag-metro{background:var(--g7);color:#fff;border-radius:3px;font-size:.65rem;padding:.1em .4em;font-weight:700;margin-left:.3rem;}
.dup-badge{background:#f0ad00;color:#333;border-radius:3px;font-size:.65rem;padding:.1em .4em;font-weight:700;margin-left:.3rem;}
.dup-row{background:#fff8e6 !important;}
@media(max-width:768px){.cg{grid-template-columns:1fr;}.kg{grid-template-columns:repeat(3,1fr);}}
</style>
</head>
<body>

<header class="ah">
  <span class="ao">Orange</span><span class="as">|</span>
  <span class="at">Suivi Monographie</span>
  <span class="ast" id="hd-stats">Aucune donn&eacute;e</span>
  <button class="bs" id="btnSave" onclick="manualSave()" title="Ctrl+S">&#128190; Sauvegarder</button>
</header>

<ul class="nav nav-tabs" role="tablist">
  <li class="nav-item"><button class="nav-link active" data-bs-toggle="tab" data-bs-target="#t-imp" type="button">Importer</button></li>
  <li class="nav-item"><button class="nav-link" data-bs-toggle="tab" data-bs-target="#t-dpm" type="button">Dashboard ProPME <span class="tb" id="cnt-pm">0</span></button></li>
  <li class="nav-item"><button class="nav-link" data-bs-toggle="tab" data-bs-target="#t-dent" type="button">Dashboard Entreprise <span class="tb" id="cnt-ent">0</span></button></li>
  <li class="nav-item"><button class="nav-link" data-bs-toggle="tab" data-bs-target="#t-tpm" type="button">Donn&eacute;es ProPME</button></li>
  <li class="nav-item"><button class="nav-link" data-bs-toggle="tab" data-bs-target="#t-tent" type="button">Donn&eacute;es Entreprise</button></li>
</ul>

<div class="tab-content">

<!-- IMPORT -->
<div class="tab-pane fade show active" id="t-imp" role="tabpanel">
  <div class="row g-3">
    <div class="col-lg-7">
      <div class="sc">
        <h6>Importer des donn&eacute;es</h6>
        <div class="mb-3">
          <span class="fw-semibold me-3" style="font-size:.82rem">Type :</span>
          <div class="form-check form-check-inline"><input class="form-check-input" type="radio" name="iT" id="rPM" value="propme" checked><label class="form-check-label" for="rPM">ProPME</label></div>
          <div class="form-check form-check-inline"><input class="form-check-input" type="radio" name="iT" id="rEnt" value="entreprise"><label class="form-check-label" for="rEnt">Entreprise</label></div>
        </div>
        <div class="mb-3">
          <span class="fw-semibold me-3" style="font-size:.82rem">Mode :</span>
          <div class="form-check form-check-inline"><input class="form-check-input" type="radio" name="iM" id="mAdd" value="add" checked><label class="form-check-label" for="mAdd">Ajouter (ignorer doublons)</label></div>
          <div class="form-check form-check-inline"><input class="form-check-input" type="radio" name="iM" id="mRep" value="replace"><label class="form-check-label" for="mRep">Remplacer tout</label></div>
        </div>
        <div class="iz mb-3">
          <label class="form-label fw-semibold" style="font-size:.82rem">Coller ici le tableau depuis le mail :</label>
          <textarea class="form-control" id="pasteArea" rows="11" placeholder="Collez ici le contenu copi&eacute; depuis le mail&hellip;"></textarea>
        </div>
        <div class="d-flex gap-2">
          <button class="btn btn-outline-secondary btn-sm" onclick="doPreview()">Analyser</button>
          <button class="btn btn-primary btn-sm" id="btnImp" disabled onclick="doImport()">Importer</button>
          <button class="btn btn-outline-secondary btn-sm" onclick="clrPaste()">Effacer</button>
        </div>
      </div>
    </div>
    <div class="col-lg-5">
      <div class="sc" id="pvCard" style="display:none">
        <h6>Pr&eacute;visualisation <span class="text-muted fw-normal" id="pvCnt" style="font-size:.78rem"></span></h6>
        <div id="pvWarn" style="display:none" class="alert alert-warning py-1 px-2 mb-2" style="font-size:.78rem"></div>
        <div class="ipv" id="pvCont"></div>
      </div>
      <div class="sc">
        <h6>Sauvegarde</h6>
        <p class="text-muted mb-2" style="font-size:.78rem">Sauvegarde automatique apr&egrave;s chaque modification. Export/Import pour partager.</p>
        <div class="d-flex flex-wrap gap-2">
          <button class="btn btn-primary btn-sm" onclick="manualSave()">&#128190; Sauvegarder</button>
          <button class="btn btn-outline-secondary btn-sm" onclick="expJSON()">Exporter JSON</button>
          <label class="btn btn-outline-secondary btn-sm mb-0" style="cursor:pointer">Importer JSON<input type="file" accept=".json" style="display:none" onchange="impJSON(this)"></label>
          <button class="btn btn-outline-danger btn-sm" onclick="resetAll()">R&eacute;initialiser tout</button>
        </div>
      </div>
      <div class="sc">
        <h6>Format attendu &amp; s&eacute;curit&eacute;</h6>
        <p class="mb-1" style="font-size:.75rem;color:var(--g7)"><strong>ProPME</strong> &mdash; Cl&eacute; unique : N&deg; questionnaire</p>
        <code style="font-size:.65rem;display:block;background:var(--g1);padding:.35rem .5rem;border-radius:3px;margin-bottom:.6rem;">N&deg; questionnaire | SIREN | Entreprise | Segment | Agence | mNPS | Profil | Lien | Date</code>
        <p class="mb-1" style="font-size:.75rem;color:var(--g7)"><strong>Entreprise</strong> &mdash; Cl&eacute; unique : SIREN + Date</p>
        <code style="font-size:.65rem;display:block;background:var(--g1);padding:.35rem .5rem;border-radius:3px;margin-bottom:.6rem;">SIREN | Entreprise | Segment | Dir Commerciale | mNPS | Connaissance VRC | Note Relation | Lien<br>Date (ligne suivante)</code>
        <div class="p-2" style="background:rgba(255,121,0,.07);border-left:3px solid var(--o);border-radius:0 3px 3px 0;font-size:.7rem;">
          <strong>DC &rarr; DE :</strong> AE CARAIBES &rarr; DE Antilles Guyane &bull; AE LA REUNION &rarr; DE R&eacute;union Mayotte &bull; Dir Ciale GNE &bull; GO &bull; GSE &bull; GSO &bull; IDF&hellip;
        </div>
      </div>
    </div>
  </div>
</div>

<!-- DASH PROPME -->
<div class="tab-pane fade" id="t-dpm" role="tabpanel">
  <!-- Filtre METRO / DROM / TOUT -->
  <div class="db">
    <label>P&eacute;rim&egrave;tre :</label>
    <button class="fil-btn active" id="f-all" onclick="setPMScope('all')">TOUT</button>
    <button class="fil-btn" id="f-metro" onclick="setPMScope('metro')">METRO</button>
    <button class="fil-btn drom" id="f-drom" onclick="setPMScope('drom')">DROM</button>
    <span id="pm-scope-info" class="text-muted" style="font-size:.75rem;margin-left:.5rem;"></span>
  </div>
  <div class="kg">
    <div class="kc"><div class="kv" id="pm-total">&mdash;</div><div class="kl">Total enqu&ecirc;tes</div></div>
    <div class="kc kS"><div class="kv" id="pm-mnps">&mdash;</div><div class="kl">mNPS moyen</div></div>
    <div class="kc kS"><div class="kv" id="pm-nps">&mdash;</div><div class="kl">NPS</div></div>
    <div class="kc kP"><div class="kv" id="pm-pp">&mdash;</div><div class="kl">% Promoteurs</div></div>
    <div class="kc kN"><div class="kv" id="pm-pn">&mdash;</div><div class="kl">% Neutres</div></div>
    <div class="kc kD"><div class="kv" id="pm-pd">&mdash;</div><div class="kl">% D&eacute;tracteurs</div></div>
  </div>
  <div id="pm-empty" class="es" style="display:none"><p>Aucune donn&eacute;e ProPME import&eacute;e.</p><button class="btn btn-primary btn-sm" onclick="goTab('t-imp')">Importer</button></div>
  <div id="pm-body">
    <div class="cg">
      <div class="cc"><h6>R&eacute;partition P / N / D</h6><div style="height:270px" id="c-pm-donut"></div></div>
      <div class="cc"><h6>Distribution notes (0&ndash;10)</h6><div style="height:270px" id="c-pm-notes"></div></div>
      <div class="cc cf"><h6>NPS par Agence ProPME</h6><div id="c-pm-ag" style="min-height:260px"></div></div>
    </div>
    <div class="sc"><h6>Volum&eacute;trie et NPS par Agence</h6>
      <div class="table-responsive"><table class="table table-sm table-hover">
        <thead><tr><th>Agence</th><th class="text-center">Zone</th><th class="text-center">Nb</th><th class="text-center">mNPS</th><th class="text-center">NPS</th><th class="text-center">Promoteurs</th><th class="text-center">Neutres</th><th class="text-center">D&eacute;tracteurs</th></tr></thead>
        <tbody id="pm-ag-body"></tbody><tfoot id="pm-ag-foot"></tfoot>
      </table></div>
    </div>
  </div>
</div>

<!-- DASH ENTREPRISE -->
<div class="tab-pane fade" id="t-dent" role="tabpanel">
  <div class="kg">
    <div class="kc"><div class="kv" id="ent-total">&mdash;</div><div class="kl">Total enqu&ecirc;tes</div></div>
    <div class="kc kS"><div class="kv" id="ent-mnps">&mdash;</div><div class="kl">mNPS moyen</div></div>
    <div class="kc kS"><div class="kv" id="ent-nps">&mdash;</div><div class="kl">NPS</div></div>
    <div class="kc kS"><div class="kv" id="ent-rel">&mdash;</div><div class="kl">Note Relation moy.</div></div>
    <div class="kc kP"><div class="kv" id="ent-pp">&mdash;</div><div class="kl">% Promoteurs</div></div>
    <div class="kc kN"><div class="kv" id="ent-pn">&mdash;</div><div class="kl">% Neutres</div></div>
    <div class="kc kD"><div class="kv" id="ent-pd">&mdash;</div><div class="kl">% D&eacute;tracteurs</div></div>
  </div>
  <div id="ent-empty" class="es" style="display:none"><p>Aucune donn&eacute;e Entreprise import&eacute;e.</p><button class="btn btn-primary btn-sm" onclick="goTab('t-imp')">Importer</button></div>
  <div id="ent-body">
    <div class="cg">
      <div class="cc"><h6>R&eacute;partition P / N / D</h6><div style="height:270px" id="c-ent-donut"></div></div>
      <div class="cc"><h6>Distribution notes (0&ndash;10)</h6><div style="height:270px" id="c-ent-notes"></div></div>
      <div class="cc cf"><h6>NPS par Direction Commerciale</h6><div id="c-ent-dir" style="min-height:260px"></div></div>
    </div>
    <div class="sc"><h6>Volum&eacute;trie DE &rarr; DC &rarr; Segment <small class="text-muted fw-normal">(cliquer pour d&eacute;plier)</small></h6>
      <div class="table-responsive"><table class="table table-sm ht">
        <thead><tr><th style="min-width:240px">Niveau</th><th class="text-center">Nb</th><th class="text-center">mNPS</th><th class="text-center">NPS</th><th class="text-center">Promoteurs</th><th class="text-center">Neutres</th><th class="text-center">D&eacute;tracteurs</th></tr></thead>
        <tbody id="ent-hier-body"></tbody>
      </table></div>
    </div>
    <div class="sc"><h6>R&eacute;partition par Segment</h6>
      <div class="table-responsive"><table class="table table-sm table-hover">
        <thead><tr><th>Segment</th><th class="text-center">Nb</th><th class="text-center">mNPS</th><th class="text-center">NPS</th><th class="text-center">% Promo</th><th class="text-center">% Neutre</th><th class="text-center">% D&eacute;tract</th></tr></thead>
        <tbody id="ent-seg-body"></tbody>
      </table></div>
    </div>
  </div>
</div>

<!-- TABLE PROPME -->
<div class="tab-pane fade" id="t-tpm" role="tabpanel">
  <div class="dtb">
    <input type="search" class="form-control form-control-sm si" id="pm-srch" placeholder="Rechercher&hellip;" oninput="filtPM()">
    <select class="form-select form-select-sm" style="width:auto" id="pm-fp" onchange="filtPM()">
      <option value="all">Tous profils</option><option value="Promoteur">Promoteurs</option><option value="Neutre">Neutres</option><option value="D\u00e9tracteur">D\u00e9tracteurs</option>
    </select>
    <select class="form-select form-select-sm" style="width:auto" id="pm-fa" onchange="filtPM()"><option value="all">Toutes les agences</option></select>
    <select class="form-select form-select-sm" style="width:auto" id="pm-fz" onchange="filtPM()">
      <option value="all">Toutes zones</option><option value="metro">METRO</option><option value="drom">DROM</option>
    </select>
    <span class="text-muted" style="font-size:.78rem" id="pm-fcnt"></span>
    <div class="ms-auto d-flex gap-2">
      <button class="btn btn-outline-secondary btn-sm" onclick="expCSV('propme')">Export CSV</button>
      <button class="btn btn-outline-danger btn-sm" id="pm-bulk" style="display:none" onclick="bulkDel('propme')">Supprimer s&eacute;lection</button>
    </div>
  </div>
  <div class="sc" style="padding:.5rem">
    <div class="table-responsive"><table class="table table-sm table-hover dt">
      <thead><tr>
        <th><input type="checkbox" id="pm-all" onchange="selAll('propme',this.checked)"></th>
        <th onclick="sortBy('propme','questionnaire')">N&deg; Quest.</th>
        <th onclick="sortBy('propme','entreprise')">Entreprise</th>
        <th onclick="sortBy('propme','siren')">SIREN</th>
        <th onclick="sortBy('propme','segment')">Segment</th>
        <th onclick="sortBy('propme','agence')">Agence</th>
        <th class="text-center">Zone</th>
        <th onclick="sortBy('propme','note')" class="text-center">Note</th>
        <th class="text-center">Profil</th>
        <th onclick="sortBy('propme','date')" class="text-center">Date</th>
        <th class="text-center">Actions</th>
      </tr></thead>
      <tbody id="pm-tbody"></tbody>
    </table></div>
    <div class="pr"><span class="pi" id="pm-pinfo"></span><ul class="pagination pagination-sm mb-0" id="pm-pages"></ul></div>
  </div>
</div>

<!-- TABLE ENTREPRISE -->
<div class="tab-pane fade" id="t-tent" role="tabpanel">
  <div class="dtb">
    <input type="search" class="form-control form-control-sm si" id="ent-srch" placeholder="Rechercher&hellip;" oninput="filtENT()">
    <select class="form-select form-select-sm" style="width:auto" id="ent-fp" onchange="filtENT()">
      <option value="all">Tous profils</option><option value="Promoteur">Promoteurs</option><option value="Neutre">Neutres</option><option value="D\u00e9tracteur">D\u00e9tracteurs</option>
    </select>
    <select class="form-select form-select-sm" style="width:auto" id="ent-fde" onchange="filtENT()"><option value="all">Toutes les DE</option></select>
    <select class="form-select form-select-sm" style="width:auto" id="ent-fdc" onchange="filtENT()"><option value="all">Toutes les DC</option></select>
    <span class="text-muted" style="font-size:.78rem" id="ent-fcnt"></span>
    <div class="ms-auto d-flex gap-2">
      <button class="btn btn-outline-secondary btn-sm" onclick="expCSV('entreprise')">Export CSV</button>
      <button class="btn btn-outline-danger btn-sm" id="ent-bulk" style="display:none" onclick="bulkDel('entreprise')">Supprimer s&eacute;lection</button>
    </div>
  </div>
  <div class="sc" style="padding:.5rem">
    <div class="table-responsive"><table class="table table-sm table-hover dt">
      <thead><tr>
        <th><input type="checkbox" id="ent-all" onchange="selAll('entreprise',this.checked)"></th>
        <th onclick="sortBy('entreprise','entreprise')">Entreprise</th>
        <th onclick="sortBy('entreprise','siren')">SIREN</th>
        <th onclick="sortBy('entreprise','segment')">Segment</th>
        <th onclick="sortBy('entreprise','directionEntreprise')">Dir. Entrep.</th>
        <th onclick="sortBy('entreprise','directionCommerciale')">Dir. Commerciale</th>
        <th onclick="sortBy('entreprise','note')" class="text-center">mNPS</th>
        <th class="text-center">Profil</th>
        <th onclick="sortBy('entreprise','noteRelation')" class="text-center">Note Rel.</th>
        <th>Connaissance VRC</th>
        <th onclick="sortBy('entreprise','date')" class="text-center">Date</th>
        <th class="text-center">Actions</th>
      </tr></thead>
      <tbody id="ent-tbody"></tbody>
    </table></div>
    <div class="pr"><span class="pi" id="ent-pinfo"></span><ul class="pagination pagination-sm mb-0" id="ent-pages"></ul></div>
  </div>
</div>

</div>

<!-- MODAL EDIT PROPME -->
<div class="modal fade" id="mEPM" tabindex="-1"><div class="modal-dialog"><div class="modal-content">
  <div class="modal-header py-2"><h5 class="modal-title" style="font-size:.95rem">Modifier &mdash; ProPME</h5><button type="button" class="btn-close" data-bs-dismiss="modal"></button></div>
  <div class="modal-body">
    <input type="hidden" id="ep-id">
    <div class="mb-2"><label class="form-label">N&deg; Questionnaire</label><input type="text" class="form-control form-control-sm" id="ep-q"></div>
    <div class="row g-2 mb-2"><div class="col-6"><label class="form-label">SIREN</label><input type="text" class="form-control form-control-sm" id="ep-sr"></div><div class="col-6"><label class="form-label">Date</label><input type="text" class="form-control form-control-sm" id="ep-dt" placeholder="JJ/MM"></div></div>
    <div class="mb-2"><label class="form-label">Entreprise</label><input type="text" class="form-control form-control-sm" id="ep-en"></div>
    <div class="row g-2 mb-2"><div class="col-6"><label class="form-label">Segment</label><input type="text" class="form-control form-control-sm" id="ep-sg"></div><div class="col-6"><label class="form-label">Agence</label><input type="text" class="form-control form-control-sm" id="ep-ag"></div></div>
    <div class="row g-2"><div class="col-4"><label class="form-label">Note (0&ndash;10)</label><input type="number" class="form-control form-control-sm" id="ep-no" min="0" max="10" oninput="aP('pm')"></div><div class="col-8"><label class="form-label">Profil (auto)</label><input type="text" class="form-control form-control-sm" id="ep-pr" readonly style="background:var(--g1)"></div></div>
  </div>
  <div class="modal-footer py-2"><button type="button" class="btn btn-secondary btn-sm" data-bs-dismiss="modal">Annuler</button><button type="button" class="btn btn-primary btn-sm" onclick="svPM()">Enregistrer</button></div>
</div></div></div>

<!-- MODAL EDIT ENT -->
<div class="modal fade" id="mEENT" tabindex="-1"><div class="modal-dialog modal-lg"><div class="modal-content">
  <div class="modal-header py-2"><h5 class="modal-title" style="font-size:.95rem">Modifier &mdash; Entreprise</h5><button type="button" class="btn-close" data-bs-dismiss="modal"></button></div>
  <div class="modal-body">
    <input type="hidden" id="ee-id">
    <div class="row g-2 mb-2"><div class="col-6"><label class="form-label">SIREN</label><input type="text" class="form-control form-control-sm" id="ee-sr"></div><div class="col-6"><label class="form-label">Date</label><input type="text" class="form-control form-control-sm" id="ee-dt" placeholder="JJ/MM"></div></div>
    <div class="mb-2"><label class="form-label">Entreprise</label><input type="text" class="form-control form-control-sm" id="ee-en"></div>
    <div class="row g-2 mb-2">
      <div class="col-4"><label class="form-label">Segment</label><input type="text" class="form-control form-control-sm" id="ee-sg"></div>
      <div class="col-8"><label class="form-label">Direction Commerciale</label>
        <select class="form-select form-select-sm" id="ee-dc" onchange="aDE()">
          <option value="">-- choisir --</option>
          <option>AE CARAIBES</option><option>AE LA REUNION</option>
          <option>Dir Ciale GNE GE</option><option>Dir Ciale GNE NDF</option>
          <option>Dir Ciale GO NC</option><option>Dir Ciale GO OA</option>
          <option>Dir Ciale GSE AURA</option><option>Dir Ciale GSE RM</option>
          <option>Dir Ciale GSO OC</option><option>Dir Ciale GSO SO</option>
          <option>Dir Ciale IDF HDM1</option><option>Dir Ciale IDF HDM2</option>
          <option>Dir Ciale IDF MDM</option><option>Dir Ciale IDF SPES</option>
        </select>
      </div>
    </div>
    <div class="row g-2 mb-2">
      <div class="col-4"><label class="form-label">Dir. Entrep. (auto)</label><input type="text" class="form-control form-control-sm" id="ee-de" readonly style="background:var(--g1)"></div>
      <div class="col-4"><label class="form-label">Note NPS (0&ndash;10)</label><input type="number" class="form-control form-control-sm" id="ee-no" min="0" max="10" oninput="aP('ent')"></div>
      <div class="col-4"><label class="form-label">Profil (auto)</label><input type="text" class="form-control form-control-sm" id="ee-pr" readonly style="background:var(--g1)"></div>
    </div>
    <div class="row g-2">
      <div class="col-4"><label class="form-label">Note Relation (0&ndash;10)</label><input type="number" class="form-control form-control-sm" id="ee-rl" min="0" max="10"></div>
      <div class="col-8"><label class="form-label">Connaissance VRC</label>
        <select class="form-select form-select-sm" id="ee-cn">
          <option value="">&mdash;</option><option>Oui, contacts r&eacute;guliers</option><option>Oui, peu de contacts</option><option>Non, ne le connais pas</option>
        </select>
      </div>
    </div>
  </div>
  <div class="modal-footer py-2"><button type="button" class="btn btn-secondary btn-sm" data-bs-dismiss="modal">Annuler</button><button type="button" class="btn btn-primary btn-sm" onclick="svENT()">Enregistrer</button></div>
</div></div></div>

<!-- MODAL DELETE -->
<div class="modal fade" id="mDel" tabindex="-1"><div class="modal-dialog modal-sm"><div class="modal-content">
  <div class="modal-header py-2"><h5 class="modal-title" style="font-size:.9rem">Confirmer la suppression</h5><button type="button" class="btn-close" data-bs-dismiss="modal"></button></div>
  <div class="modal-body"><p id="del-msg" class="mb-0"></p></div>
  <div class="modal-footer py-2"><button type="button" class="btn btn-secondary btn-sm" data-bs-dismiss="modal">Annuler</button><button type="button" class="btn btn-danger btn-sm" onclick="confDel()">Supprimer</button></div>
</div></div></div>

<div class="toast-container"><div id="appToast" class="toast align-items-center text-white border-0 bg-success" role="alert">
  <div class="d-flex"><div class="toast-body" id="toastMsg"></div><button type="button" class="btn-close btn-close-white me-2 m-auto" data-bs-dismiss="toast"></button></div>
</div></div>

<script src="https://cdn.jsdelivr.net/npm/boosted@5.3.8/dist/js/boosted.bundle.min.js" crossorigin="anonymous"></script>
<script>
'use strict';
// ── DC → DE mapping officiel ──────────────────────────────────────────
const DC_DE={
  'AE CARAIBES':'DE Antilles Guyane','AE LA REUNION':'DE R\\u00e9union Mayotte',
  'DIR CIALE GNE GE':'DE GNE','DIR CIALE GNE NDF':'DE GNE',
  'DIR CIALE GO NC':'DE GO','DIR CIALE GO OA':'DE GO',
  'DIR CIALE GSE AURA':'DE GSE','DIR CIALE GSE RM':'DE GSE',
  'DIR CIALE GSO OC':'DE GSO','DIR CIALE GSO SO':'DE GSO',
  'DIR CIALE IDF HDM1':'DE IDF','DIR CIALE IDF HDM2':'DE IDF',
  'DIR CIALE IDF MDM':'DE IDF','DIR CIALE IDF SPES':'DE IDF',
};
function dirE(dc){if(!dc)return'\\u2014';const k=dc.trim().toUpperCase();return DC_DE[k]||('\\u2014 ('+dc.trim()+')');}

// ── DROM classifier ───────────────────────────────────────────────────
const DROM_KW=['CARAIBES','REUNION','MAYOTTE','ANTILLES','GUYANE','MARTINIQUE','GUADELOUPE'];
function isDROM(agence){if(!agence)return false;const u=agence.toUpperCase();return DROM_KW.some(k=>u.includes(k))||u.startsWith('AE ');}
function zone(agence){return isDROM(agence)?'drom':'metro';}

// ── State ─────────────────────────────────────────────────────────────
const PS=50;
const PLY={responsive:true,displayModeBar:false};
const PLB={font:{family:'Arial,sans-serif',size:11},paper_bgcolor:'transparent',plot_bgcolor:'transparent',margin:{t:15,b:40,l:45,r:20}};
const S={pm:[],ent:[],ui:{
  pm: {q:'',p:'all',a:'all',z:'all',pg:1,sort:{c:'date',d:'desc'},scope:'all'},
  ent:{q:'',p:'all',de:'all',dc:'all',pg:1,sort:{c:'date',d:'desc'}},
}};
let _pv=[],_del=null;

// ── Utils ─────────────────────────────────────────────────────────────
const uid=()=>Math.random().toString(36).slice(2)+Date.now().toString(36);
const esc=s=>String(s||'').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');
const fmt=(n,d=1)=>(n==null||isNaN(n))?'\\u2014':Number(n).toFixed(d);
const fmtP=n=>(n==null||isNaN(n))?'\\u2014':Math.round(n)+'%';
function prof(note){const n=parseInt(note);return n>=9?'Promoteur':n>=7?'Neutre':'D\\u00e9tracteur';}
function nps(arr){
  if(!arr||!arr.length)return{nps:null,mnps:null,pP:0,pN:0,pD:0,nP:0,nN:0,nD:0,tot:0};
  const t=arr.length,nP=arr.filter(e=>e.note>=9).length,nN=arr.filter(e=>e.note>=7&&e.note<=8).length,nD=arr.filter(e=>e.note<=6).length;
  const pP=nP/t*100,pN=nN/t*100,pD=nD/t*100;
  return{nps:Math.round((pP-pD)*10)/10,mnps:Math.round(arr.reduce((s,e)=>s+e.note,0)/t*10)/10,pP,pN,pD,nP,nN,nD,tot:t};
}
const nhex=v=>v>0?'#50BE87':v<0?'#cd3c14':'#a06b00';
const ncls=v=>v>0?'np':v<0?'nn':'nz';
const badge=p=>'<span class="bp '+(p==='Promoteur'?'bP':p==='Neutre'?'bN':'bD')+'">'+esc(p)+'</span>';
const ztag=z=>'<span class="tag-'+(z||'metro')+'">'+(z==='drom'?'DROM':'METRO')+'</span>';
function grp(arr,k){const m=new Map();for(const x of arr){const v=(x[k]||'\\u2014').trim()||'\\u2014';if(!m.has(v))m.set(v,[]);m.get(v).push(x);}return m;}
function toast(msg,type='success'){const el=document.getElementById('appToast');el.className='toast align-items-center text-white border-0 bg-'+type;document.getElementById('toastMsg').textContent=msg;bootstrap.Toast.getOrCreateInstance(el,{delay:3500}).show();}
function goTab(id){document.querySelector('[data-bs-target="#'+id+'"]')?.click();}

// ── Dup keys ──────────────────────────────────────────────────────────
const pmKey=e=>String(e.questionnaire||'').trim();
const entKey=e=>String(e.siren||'').trim()+'|'+String(e.date||'').trim();

// ── Persistence ───────────────────────────────────────────────────────
function _write(){try{localStorage.setItem('sm_pm_v3',JSON.stringify(S.pm));localStorage.setItem('sm_ent_v3',JSON.stringify(S.ent));}catch(e){}}
function save(){_write();}
function manualSave(){_write();toast('Donn\\u00e9es sauvegard\\u00e9es.');const b=document.getElementById('btnSave');b.classList.add('saved');b.textContent='\\u2713 Sauvegard\\u00e9';setTimeout(()=>{b.classList.remove('saved');b.innerHTML='&#128190; Sauvegarder';},2000);}
function load(){
  try{
    S.pm=JSON.parse(localStorage.getItem('sm_pm_v3')||'[]');
    S.ent=JSON.parse(localStorage.getItem('sm_ent_v3')||'[]');
    S.pm=S.pm.map(e=>({...e,zone:zone(e.agence)}));
    S.ent=S.ent.map(e=>({...e,directionEntreprise:dirE(e.directionCommerciale)}));
  }catch(e){S.pm=[];S.ent=[];}
}
document.addEventListener('keydown',e=>{if((e.ctrlKey||e.metaKey)&&e.key==='s'){e.preventDefault();manualSave();}});

// ── Parsers ───────────────────────────────────────────────────────────
function parsePM(text){
  const out=[];
  for(const line of text.split('\\n').map(l=>l.trim()).filter(l=>l)){
    const p=line.split('\\t');if(p.length<6||!/^\\d{10,}/.test(p[0]))continue;
    const n=parseInt(p[5]);if(isNaN(n)||n<0||n>10)continue;
    const ag=p[4].trim();
    out.push({id:uid(),type:'propme',questionnaire:p[0].trim(),siren:p[1].trim(),entreprise:p[2].trim(),segment:p[3].trim(),agence:ag,note:n,profil:(p[6]||prof(n)).trim(),date:(p[8]||p[7]||'').trim(),zone:zone(ag)});
  }
  return out;
}
function parseENT(text){
  const raw=text.split('\\n').map(l=>l.trim());const merged=[];
  for(const line of raw){if(!line)continue;if(/^\\d{2}\\/\\d{2}$/.test(line)&&merged.length>0)merged[merged.length-1]+='\\t'+line;else merged.push(line);}
  const out=[];
  for(const line of merged){
    const p=line.split('\\t');if(p.length<5||!/^\\d{6,}/.test(p[0]))continue;
    const n=parseInt(p[4]);if(isNaN(n)||n<0||n>10)continue;
    const dc=p[3].trim();const nr=parseInt(p[6]);
    out.push({id:uid(),type:'entreprise',siren:p[0].trim(),entreprise:p[1].trim(),segment:p[2].trim(),directionCommerciale:dc,directionEntreprise:dirE(dc),note:n,profil:prof(n),connaissance:(p[5]||'').trim(),noteRelation:isNaN(nr)?null:nr,date:(p[8]||'').trim()});
  }
  return out;
}

// ── Import ────────────────────────────────────────────────────────────
function doPreview(){
  const text=document.getElementById('pasteArea').value.trim(),type=document.querySelector('input[name=iT]:checked').value;
  if(!text){toast('Veuillez coller des donn\\u00e9es.','danger');return;}
  _pv=type==='propme'?parsePM(text):parseENT(text);
  document.getElementById('pvCnt').textContent='('+_pv.length+' entr\\u00e9e'+(_pv.length!==1?'s':'')+' d\\u00e9tect\\u00e9e'+(_pv.length!==1?'s':'')+')';
  const warn=document.getElementById('pvWarn');
  if(!_pv.length){document.getElementById('pvCont').innerHTML='<p class="text-danger" style="font-size:.8rem">Aucune entr\\u00e9e valide.</p>';document.getElementById('btnImp').disabled=true;warn.style.display='none';}
  else{
    const keys=type==='propme'?new Set(S.pm.map(pmKey)):new Set(S.ent.map(entKey));
    const kf=type==='propme'?pmKey:entKey;
    const dup=_pv.filter(e=>keys.has(kf(e)));
    if(dup.length>0){warn.style.display='';warn.innerHTML='<strong>'+dup.length+' doublon'+(dup.length>1?'s':'')+' d\\u00e9tect\\u00e9'+(dup.length>1?'s':'')+' en base.</strong> Mode "Ajouter" : ignor\\u00e9s.';}else warn.style.display='none';
    const pv=_pv.slice(0,8),isDup=e=>keys.has(kf(e));
    if(type==='propme'){
      document.getElementById('pvCont').innerHTML='<table class="table table-sm" style="font-size:.73rem"><thead><tr><th>Entreprise</th><th>Agence</th><th>Zone</th><th>Note</th><th>Profil</th></tr></thead><tbody>'+
        pv.map(e=>'<tr'+(isDup(e)?' class="dup-row"':'')+'>'+
          '<td>'+esc(e.entreprise)+(isDup(e)?'<span class="dup-badge">DOUBLON</span>':'')+'</td>'+
          '<td>'+esc(e.agence)+'</td><td>'+ztag(e.zone)+'</td><td>'+e.note+'</td><td>'+badge(e.profil)+'</td></tr>').join('')+
        (_pv.length>8?'<tr><td colspan="5" class="text-muted">&hellip; et '+(_pv.length-8)+' autre(s)</td></tr>':'')+'</tbody></table>';
    }else{
      document.getElementById('pvCont').innerHTML='<table class="table table-sm" style="font-size:.73rem"><thead><tr><th>Entreprise</th><th>DC</th><th>DE</th><th>Note</th></tr></thead><tbody>'+
        pv.map(e=>'<tr'+(isDup(e)?' class="dup-row"':'')+'>'+
          '<td>'+esc(e.entreprise)+(isDup(e)?'<span class="dup-badge">DOUBLON</span>':'')+'</td>'+
          '<td><small>'+esc(e.directionCommerciale)+'</small></td><td><strong>'+esc(e.directionEntreprise)+'</strong></td><td>'+e.note+'</td></tr>').join('')+
        (_pv.length>8?'<tr><td colspan="4" class="text-muted">&hellip; et '+(_pv.length-8)+' autre(s)</td></tr>':'')+'</tbody></table>';
    }
    document.getElementById('btnImp').disabled=false;
  }
  document.getElementById('pvCard').style.display='';
}
function doImport(){
  if(!_pv.length)return;
  const type=document.querySelector('input[name=iT]:checked').value,mode=document.querySelector('input[name=iM]:checked').value,store=type==='propme'?'pm':'ent',kf=type==='propme'?pmKey:entKey;
  if(mode==='replace'){
    const seen=new Set(),deduped=_pv.filter(e=>{const k=kf(e);if(seen.has(k))return false;seen.add(k);return true;});
    S[store]=deduped;save();refresh();toast(deduped.length+' entr\\u00e9es import\\u00e9es (remplacement).');
  }else{
    const keys=type==='propme'?new Set(S.pm.map(pmKey)):new Set(S.ent.map(entKey));
    const seen=new Set(),newE=_pv.filter(e=>{const k=kf(e);if(keys.has(k)||seen.has(k))return false;seen.add(k);return true;});
    const dupes=_pv.length-newE.length;
    S[store]=[...S[store],...newE];save();refresh();
    toast(newE.length+' entr\\u00e9e(s) import\\u00e9e(s)'+(dupes>0?', '+dupes+' doublon(s) ignor\\u00e9(s)':'')+'.');
  }
  _pv=[];document.getElementById('pasteArea').value='';document.getElementById('pvCard').style.display='none';document.getElementById('btnImp').disabled=true;
}
function clrPaste(){document.getElementById('pasteArea').value='';document.getElementById('pvCard').style.display='none';document.getElementById('btnImp').disabled=true;_pv=[];}
function resetAll(){if(!confirm('Supprimer TOUTES les donn\\u00e9es ?'))return;S.pm=[];S.ent=[];save();refresh();toast('Donn\\u00e9es r\\u00e9initialis\\u00e9es.','secondary');}
function expJSON(){const b=new Blob([JSON.stringify({propme:S.pm,entreprise:S.ent,at:new Date().toISOString(),v:3},null,2)],{type:'application/json'});const a=document.createElement('a');a.href=URL.createObjectURL(b);a.download='suivi-monographie-'+new Date().toISOString().slice(0,10)+'.json';a.click();URL.revokeObjectURL(a.href);}
function impJSON(inp){const f=inp.files[0];if(!f)return;const r=new FileReader();r.onload=e=>{try{const d=JSON.parse(e.target.result);if(d.propme)S.pm=d.propme.map(en=>({...en,zone:zone(en.agence)}));if(d.entreprise)S.ent=d.entreprise.map(en=>({...en,directionEntreprise:dirE(en.directionCommerciale)}));save();refresh();toast('JSON import\\u00e9 : '+S.pm.length+' ProPME, '+S.ent.length+' Entreprise.');}catch{toast('Fichier JSON invalide.','danger');}};r.readAsText(f);inp.value='';}
function expCSV(type){
  const entries=type==='propme'?filtPM_all():filtENT_all();
  const q=v=>'"'+String(v??'').replace(/"/g,'""')+'"';
  let csv;
  if(type==='propme'){csv='N\\u00b0 Questionnaire;SIREN;Entreprise;Segment;Agence;Zone;Note;Profil;Date\\n';csv+=entries.map(e=>[e.questionnaire,e.siren,e.entreprise,e.segment,e.agence,e.zone==='drom'?'DROM':'METRO',e.note,e.profil,e.date].map(q).join(';')).join('\\n');}
  else{csv='SIREN;Entreprise;Segment;Dir. Entreprise;Dir. Commerciale;Note NPS;Profil;Note Relation;Connaissance VRC;Date\\n';csv+=entries.map(e=>[e.siren,e.entreprise,e.segment,e.directionEntreprise,e.directionCommerciale,e.note,e.profil,e.noteRelation,e.connaissance,e.date].map(q).join(';')).join('\\n');}
  const a=document.createElement('a');a.href=URL.createObjectURL(new Blob(['\\uFEFF'+csv],{type:'text/csv;charset=utf-8'}));a.download='export-'+type+'-'+new Date().toISOString().slice(0,10)+'.csv';a.click();URL.revokeObjectURL(a.href);
}

// ── Scope filter (METRO/DROM) ─────────────────────────────────────────
function setPMScope(scope){
  S.ui.pm.scope=scope;
  ['all','metro','drom'].forEach(s=>document.getElementById('f-'+s)?.classList.toggle('active',s===scope));
  const info=document.getElementById('pm-scope-info');
  const data=scopedPM();
  info.textContent=scope==='all'?'':'P\\u00e9rim\\u00e8tre '+scope.toUpperCase()+' : '+data.length+' enqu\\u00eate'+(data.length!==1?'s':'');
  dashPM();
}
function scopedPM(){
  const sc=S.ui.pm.scope;
  if(sc==='all')return S.pm;
  return S.pm.filter(e=>e.zone===sc);
}

// ── Dashboard ProPME ──────────────────────────────────────────────────
function dashPM(){
  const data=scopedPM(),n=nps(data);
  const empty=document.getElementById('pm-empty'),body=document.getElementById('pm-body');
  if(!data.length){empty.style.display='';body.style.display='none';['pm-total','pm-mnps','pm-nps','pm-pp','pm-pn','pm-pd'].forEach(id=>document.getElementById(id).textContent='\\u2014');return;}
  empty.style.display='none';body.style.display='';
  document.getElementById('pm-total').textContent=n.tot;document.getElementById('pm-mnps').textContent=fmt(n.mnps);document.getElementById('pm-nps').textContent=fmt(n.nps,1);document.getElementById('pm-pp').textContent=fmtP(n.pP);document.getElementById('pm-pn').textContent=fmtP(n.pN);document.getElementById('pm-pd').textContent=fmtP(n.pD);
  Plotly.react('c-pm-donut',[{type:'pie',hole:.5,values:[n.nP,n.nN,n.nD],labels:['Promoteurs','Neutres','D\\u00e9tracteurs'],marker:{colors:['#50BE87','#FFD200','#cd3c14']},texttemplate:'%{value}<br>%{percent:.1%}',textposition:'inside',insidetextfont:{size:11}}],{...PLB,margin:{t:10,b:10,l:10,r:10},height:270,showlegend:true,legend:{orientation:'h',y:-0.12}},PLY);
  const nd=Array.from({length:11},(_,i)=>({n:i,c:data.filter(e=>e.note===i).length}));
  Plotly.react('c-pm-notes',[{type:'bar',x:nd.map(d=>String(d.n)),y:nd.map(d=>d.c),marker:{color:nd.map(d=>d.n>=9?'#50BE87':d.n>=7?'#FFD200':'#cd3c14')},text:nd.map(d=>d.c>0?String(d.c):''),textposition:'outside'}],{...PLB,height:270,xaxis:{title:'Note',tickmode:'linear',dtick:1},yaxis:{title:'Nb'}},PLY);
  const byAg=grp(data,'agence');const agR=[];byAg.forEach((e,a)=>{const n2=nps(e);agR.push({a,z:e[0]?.zone,n2});agR[agR.length-1]={a,z:e[0]?.zone,...n2};});agR.sort((a,b)=>b.nps-a.nps);
  Plotly.react('c-pm-ag',[{type:'bar',orientation:'h',y:agR.map(r=>r.a),x:agR.map(r=>r.nps),marker:{color:agR.map(r=>nhex(r.nps))},text:agR.map(r=>'NPS: '+fmt(r.nps,1)+'  (n='+r.tot+')'),textposition:'outside'}],{...PLB,height:Math.max(260,agR.length*38+60),margin:{t:10,b:40,l:240,r:90},xaxis:{title:'NPS',zeroline:true,zerolinecolor:'#ccc'}},PLY);
  document.getElementById('pm-ag-body').innerHTML=agR.map(r=>'<tr><td>'+esc(r.a)+'</td><td class="text-center">'+ztag(r.z)+'</td><td class="text-center">'+r.tot+'</td><td class="text-center">'+fmt(r.mnps)+'</td><td class="text-center"><span class="'+ncls(r.nps)+'">'+fmt(r.nps,1)+'</span></td><td class="text-center">'+r.nP+' <small>('+fmtP(r.pP)+')</small></td><td class="text-center">'+r.nN+' <small>('+fmtP(r.pN)+')</small></td><td class="text-center">'+r.nD+' <small>('+fmtP(r.pD)+')</small></td></tr>').join('');
  document.getElementById('pm-ag-foot').innerHTML='<tr class="ht-tot"><td>TOTAL</td><td></td><td class="text-center">'+n.tot+'</td><td class="text-center">'+fmt(n.mnps)+'</td><td class="text-center"><span class="'+ncls(n.nps)+'">'+fmt(n.nps,1)+'</span></td><td class="text-center">'+n.nP+' <small>('+fmtP(n.pP)+')</small></td><td class="text-center">'+n.nN+' <small>('+fmtP(n.pN)+')</small></td><td class="text-center">'+n.nD+' <small>('+fmtP(n.pD)+')</small></td></tr>';
}

// ── Dashboard Entreprise ──────────────────────────────────────────────
function dashENT(){
  const data=S.ent,n=nps(data);
  const empty=document.getElementById('ent-empty'),body=document.getElementById('ent-body');
  if(!data.length){empty.style.display='';body.style.display='none';['ent-total','ent-mnps','ent-nps','ent-rel','ent-pp','ent-pn','ent-pd'].forEach(id=>document.getElementById(id).textContent='\\u2014');document.getElementById('ent-hier-body').innerHTML='';document.getElementById('ent-seg-body').innerHTML='';return;}
  empty.style.display='none';body.style.display='';
  const rv=data.filter(e=>e.noteRelation!=null);const mnRel=rv.length?Math.round(rv.reduce((s,e)=>s+e.noteRelation,0)/rv.length*10)/10:null;
  document.getElementById('ent-total').textContent=n.tot;document.getElementById('ent-mnps').textContent=fmt(n.mnps);document.getElementById('ent-nps').textContent=fmt(n.nps,1);document.getElementById('ent-rel').textContent=fmt(mnRel);document.getElementById('ent-pp').textContent=fmtP(n.pP);document.getElementById('ent-pn').textContent=fmtP(n.pN);document.getElementById('ent-pd').textContent=fmtP(n.pD);
  Plotly.react('c-ent-donut',[{type:'pie',hole:.5,values:[n.nP,n.nN,n.nD],labels:['Promoteurs','Neutres','D\\u00e9tracteurs'],marker:{colors:['#50BE87','#FFD200','#cd3c14']},texttemplate:'%{value}<br>%{percent:.1%}',textposition:'inside',insidetextfont:{size:11}}],{...PLB,margin:{t:10,b:10,l:10,r:10},height:270,showlegend:true,legend:{orientation:'h',y:-0.12}},PLY);
  const nd=Array.from({length:11},(_,i)=>({n:i,c:data.filter(e=>e.note===i).length}));
  Plotly.react('c-ent-notes',[{type:'bar',x:nd.map(d=>String(d.n)),y:nd.map(d=>d.c),marker:{color:nd.map(d=>d.n>=9?'#50BE87':d.n>=7?'#FFD200':'#cd3c14')},text:nd.map(d=>d.c>0?String(d.c):''),textposition:'outside'}],{...PLB,height:270,xaxis:{title:'Note',tickmode:'linear',dtick:1},yaxis:{title:'Nb'}},PLY);
  const byDC=grp(data,'directionCommerciale');const dcR=[];byDC.forEach((e,d)=>{const n2=nps(e);dcR.push({d,...n2});});dcR.sort((a,b)=>b.nps-a.nps);
  Plotly.react('c-ent-dir',[{type:'bar',orientation:'h',y:dcR.map(r=>r.d),x:dcR.map(r=>r.nps),marker:{color:dcR.map(r=>nhex(r.nps))},text:dcR.map(r=>'NPS: '+fmt(r.nps,1)+'  (n='+r.tot+')'),textposition:'outside'}],{...PLB,height:Math.max(260,dcR.length*38+60),margin:{t:10,b:40,l:240,r:90},xaxis:{title:'NPS',zeroline:true,zerolinecolor:'#ccc'}},PLY);
  const byDE=grp(data,'directionEntreprise');let rows='';
  for(const de of[...byDE.keys()].sort()){
    const deD=byDE.get(de),deN=nps(deD),dk='de_'+de.replace(/\\W/g,'_');
    rows+='<tr class="h1r" data-key="'+dk+'" onclick="t1(\\''+dk+'\\')"><td>'+esc(de)+'</td><td class="text-center">'+deN.tot+'</td><td class="text-center">'+fmt(deN.mnps)+'</td><td class="text-center"><span class="'+ncls(deN.nps)+'">'+fmt(deN.nps,1)+'</span></td><td class="text-center">'+deN.nP+' <small>('+fmtP(deN.pP)+')</small></td><td class="text-center">'+deN.nN+' <small>('+fmtP(deN.pN)+')</small></td><td class="text-center">'+deN.nD+' <small>('+fmtP(deN.pD)+')</small></td></tr>';
    for(const dc of[...grp(deD,'directionCommerciale').entries()].sort(([a],[b])=>a.localeCompare(b))){
      const[dcName,dcD]=dc,dcN=nps(dcD),ck=dk+'_'+dcName.replace(/\\W/g,'_');
      rows+='<tr class="h2r" data-parent="'+dk+'" data-key="'+ck+'" style="display:none" onclick="t2(\\''+ck+'\\')"><td>&#8627; '+esc(dcName)+'</td><td class="text-center">'+dcN.tot+'</td><td class="text-center">'+fmt(dcN.mnps)+'</td><td class="text-center"><span class="'+ncls(dcN.nps)+'">'+fmt(dcN.nps,1)+'</span></td><td class="text-center">'+dcN.nP+' <small>('+fmtP(dcN.pP)+')</small></td><td class="text-center">'+dcN.nN+' <small>('+fmtP(dcN.pN)+')</small></td><td class="text-center">'+dcN.nD+' <small>('+fmtP(dcN.pD)+')</small></td></tr>';
      grp(dcD,'segment').forEach((sD,seg)=>{const sN=nps(sD);rows+='<tr class="h3r" data-parent="'+ck+'" style="display:none"><td>'+esc(seg)+'</td><td class="text-center">'+sN.tot+'</td><td class="text-center">'+fmt(sN.mnps)+'</td><td class="text-center"><span class="'+ncls(sN.nps)+'">'+fmt(sN.nps,1)+'</span></td><td class="text-center">'+sN.nP+' <small>('+fmtP(sN.pP)+')</small></td><td class="text-center">'+sN.nN+' <small>('+fmtP(sN.pN)+')</small></td><td class="text-center">'+sN.nD+' <small>('+fmtP(sN.pD)+')</small></td></tr>';});
    }
  }
  rows+='<tr class="ht-tot"><td>TOTAL</td><td class="text-center">'+n.tot+'</td><td class="text-center">'+fmt(n.mnps)+'</td><td class="text-center"><span class="'+ncls(n.nps)+'">'+fmt(n.nps,1)+'</span></td><td class="text-center">'+n.nP+' <small>('+fmtP(n.pP)+')</small></td><td class="text-center">'+n.nN+' <small>('+fmtP(n.pN)+')</small></td><td class="text-center">'+n.nD+' <small>('+fmtP(n.pD)+')</small></td></tr>';
  document.getElementById('ent-hier-body').innerHTML=rows;
  const segR=[];grp(data,'segment').forEach((e,s)=>{const n2=nps(e);segR.push({s,...n2});});segR.sort((a,b)=>b.tot-a.tot);
  document.getElementById('ent-seg-body').innerHTML=segR.map(r=>'<tr><td><strong>'+esc(r.s)+'</strong></td><td class="text-center">'+r.tot+'</td><td class="text-center">'+fmt(r.mnps)+'</td><td class="text-center"><span class="'+ncls(r.nps)+'">'+fmt(r.nps,1)+'</span></td><td class="text-center">'+fmtP(r.pP)+'</td><td class="text-center">'+fmtP(r.pN)+'</td><td class="text-center">'+fmtP(r.pD)+'</td></tr>').join('');
}

function t1(k){const l=document.querySelector('[data-key="'+k+'"]'),o=l.classList.contains('open');document.querySelectorAll('[data-parent="'+k+'"]').forEach(r=>{r.style.display='none';r.classList.remove('open');const k2=r.dataset.key;if(k2)document.querySelectorAll('[data-parent="'+k2+'"]').forEach(r2=>r2.style.display='none');});if(!o){document.querySelectorAll('[data-parent="'+k+'"]').forEach(r=>r.style.display='');l.classList.add('open');}else l.classList.remove('open');}
function t2(k){const l=document.querySelector('[data-key="'+k+'"]'),o=l.classList.contains('open');document.querySelectorAll('[data-parent="'+k+'"]').forEach(r=>r.style.display=o?'none':'');l.classList.toggle('open',!o);}

// ── Data tables ───────────────────────────────────────────────────────
function filtPM_all(){
  const u=S.ui.pm,q=u.q.toLowerCase();
  return S.pm.filter(e=>{
    if(u.p!=='all'&&e.profil!==u.p)return false;
    if(u.a!=='all'&&e.agence!==u.a)return false;
    if(u.z!=='all'&&e.zone!==u.z)return false;
    if(q&&!(e.entreprise+' '+e.agence+' '+e.segment+' '+e.profil+' '+e.questionnaire+' '+e.siren).toLowerCase().includes(q))return false;
    return true;
  }).sort((a,b)=>{const{c,d}=u.sort;const va=a[c]??'',vb=b[c]??'';const cv=typeof va==='number'?va-vb:String(va).localeCompare(String(vb),'fr');return d==='asc'?cv:-cv;});
}
function filtPM(){return filtPM_all();}
function renderPM(){
  const u=S.ui.pm,filt=filtPM(),tot=filt.length;
  const pc=Math.max(1,Math.ceil(tot/PS));u.pg=Math.min(u.pg,pc);const pg=filt.slice((u.pg-1)*PS,u.pg*PS);
  document.getElementById('pm-fcnt').textContent=tot+' entr\\u00e9e'+(tot!==1?'s':'');
  document.getElementById('pm-tbody').innerHTML=pg.length===0?'<tr><td colspan="11" class="text-center text-muted py-4">Aucune donn\\u00e9e</td></tr>':
    pg.map(e=>'<tr><td><input type="checkbox" class="pm-chk" data-id="'+e.id+'" onchange="updBulk(\\'propme\\')"></td><td><small class="text-muted" style="font-size:.7rem">'+esc(e.questionnaire)+'</small></td><td><strong>'+esc(e.entreprise)+'</strong></td><td><small>'+esc(e.siren)+'</small></td><td>'+esc(e.segment)+'</td><td>'+esc(e.agence)+'</td><td class="text-center">'+ztag(e.zone)+'</td><td class="text-center"><strong>'+e.note+'</strong>/10</td><td class="text-center">'+badge(e.profil)+'</td><td class="text-center">'+esc(e.date)+'</td><td class="text-center" style="white-space:nowrap"><button class="btn btn-outline-secondary br" onclick="edPM(\\''+e.id+'\\')">Modifier</button> <button class="btn btn-outline-danger br" onclick="askDel(\\'propme\\',\\''+e.id+'\\',\\''+esc(e.entreprise)+'\\')">&#10005;</button></td></tr>').join('');
  renderPgs('propme',u.pg,pc,tot);
}
function filtPM(){const u=S.ui.pm;u.q=document.getElementById('pm-srch').value;u.p=document.getElementById('pm-fp').value;u.a=document.getElementById('pm-fa').value;u.z=document.getElementById('pm-fz').value;u.pg=1;renderPM();}

function filtENT_all(){
  const u=S.ui.ent,q=u.q.toLowerCase();
  return S.ent.filter(e=>{
    if(u.p!=='all'&&e.profil!==u.p)return false;
    if(u.de!=='all'&&e.directionEntreprise!==u.de)return false;
    if(u.dc!=='all'&&e.directionCommerciale!==u.dc)return false;
    if(q&&!(e.entreprise+' '+e.directionCommerciale+' '+e.directionEntreprise+' '+e.segment+' '+e.profil+' '+e.siren).toLowerCase().includes(q))return false;
    return true;
  }).sort((a,b)=>{const{c,d}=u.sort;const va=a[c]??'',vb=b[c]??'';const cv=typeof va==='number'?va-vb:String(va).localeCompare(String(vb),'fr');return d==='asc'?cv:-cv;});
}
function filtENT(){const u=S.ui.ent;u.q=document.getElementById('ent-srch').value;u.p=document.getElementById('ent-fp').value;u.de=document.getElementById('ent-fde').value;u.dc=document.getElementById('ent-fdc').value;u.pg=1;renderENT();}
function renderENT(){
  const u=S.ui.ent,filt=filtENT_all(),tot=filt.length;
  const pc=Math.max(1,Math.ceil(tot/PS));u.pg=Math.min(u.pg,pc);const pg=filt.slice((u.pg-1)*PS,u.pg*PS);
  document.getElementById('ent-fcnt').textContent=tot+' entr\\u00e9e'+(tot!==1?'s':'');
  document.getElementById('ent-tbody').innerHTML=pg.length===0?'<tr><td colspan="12" class="text-center text-muted py-4">Aucune donn\\u00e9e</td></tr>':
    pg.map(e=>'<tr><td><input type="checkbox" class="ent-chk" data-id="'+e.id+'" onchange="updBulk(\\'entreprise\\')"></td><td><strong>'+esc(e.entreprise)+'</strong></td><td><small>'+esc(e.siren)+'</small></td><td>'+esc(e.segment)+'</td><td><strong>'+esc(e.directionEntreprise)+'</strong></td><td><small>'+esc(e.directionCommerciale)+'</small></td><td class="text-center"><strong>'+e.note+'</strong>/10</td><td class="text-center">'+badge(e.profil)+'</td><td class="text-center">'+(e.noteRelation!=null?e.noteRelation:'\\u2014')+'</td><td><small>'+esc(e.connaissance)+'</small></td><td class="text-center">'+esc(e.date)+'</td><td class="text-center" style="white-space:nowrap"><button class="btn btn-outline-secondary br" onclick="edENT(\\''+e.id+'\\')">Modifier</button> <button class="btn btn-outline-danger br" onclick="askDel(\\'entreprise\\',\\''+e.id+'\\',\\''+esc(e.entreprise)+'\\')">&#10005;</button></td></tr>').join('');
  renderPgs('entreprise',u.pg,pc,tot);
}

// ── Sort / Pages ──────────────────────────────────────────────────────
function sortBy(type,col){const u=S.ui[type==='propme'?'pm':'ent'];u.sort.d=u.sort.c===col?(u.sort.d==='asc'?'desc':'asc'):'asc';u.sort.c=col;u.pg=1;type==='propme'?renderPM():renderENT();}
function renderPgs(type,pg,pc,tot){
  const pfx=type==='propme'?'pm':'ent';const s=Math.max(1,(pg-1)*PS+1),e=Math.min(pg*PS,tot);
  const inf=document.getElementById(pfx+'-pinfo'),pag=document.getElementById(pfx+'-pages');
  if(inf)inf.textContent=tot>0?s+'\\u2013'+e+' sur '+tot:'';
  if(!pag)return;if(pc<=1){pag.innerHTML='';return;}
  const arr=[];for(let i=1;i<=pc;i++)if(i===1||i===pc||(i>=pg-2&&i<=pg+2))arr.push(i);
  const wd=[];let prev=0;for(const p of arr){if(prev&&p-prev>1)wd.push('\\u2026');wd.push(p);prev=p;}
  pag.innerHTML='<li class="page-item '+(pg===1?'disabled':'')+'"><button class="page-link" onclick="goP(\\''+type+'\\','+(pg-1)+')">&#8249;</button></li>'+
    wd.map(p=>typeof p==='number'?'<li class="page-item '+(p===pg?'active':'')+'"><button class="page-link" onclick="goP(\\''+type+'\\','+p+')">'+p+'</button></li>':'<li class="page-item disabled"><span class="page-link">'+p+'</span></li>').join('')+
    '<li class="page-item '+(pg===pc?'disabled':'')+'"><button class="page-link" onclick="goP(\\''+type+'\\','+(pg+1)+')">&#8250;</button></li>';
}
function goP(type,pg){if(type==='propme'){S.ui.pm.pg=pg;renderPM();}else{S.ui.ent.pg=pg;renderENT();}}

// ── Bulk / Select ─────────────────────────────────────────────────────
function selAll(type,checked){document.querySelectorAll('.'+(type==='propme'?'pm':'ent')+'-chk').forEach(cb=>cb.checked=checked);updBulk(type);}
function updBulk(type){const pfx=type==='propme'?'pm':'ent';const cnt=document.querySelectorAll('.'+pfx+'-chk:checked').length;const btn=document.getElementById(pfx+'-bulk');if(btn){btn.style.display=cnt>0?'':'none';btn.textContent='Supprimer s\\u00e9lection ('+cnt+')';}}
function bulkDel(type){const pfx=type==='propme'?'pm':'ent';const ids=new Set([...document.querySelectorAll('.'+pfx+'-chk:checked')].map(cb=>cb.dataset.id));if(!ids.size)return;if(!confirm('Supprimer '+ids.size+' entr\\u00e9e(s) ?'))return;S[type==='propme'?'pm':'ent']=S[type==='propme'?'pm':'ent'].filter(e=>!ids.has(e.id));save();refresh();toast(ids.size+' entr\\u00e9e(s) supprim\\u00e9e(s).');}

// ── Edit ──────────────────────────────────────────────────────────────
function edPM(id){const e=S.pm.find(x=>x.id===id);if(!e)return;document.getElementById('ep-id').value=e.id;document.getElementById('ep-q').value=e.questionnaire||'';document.getElementById('ep-sr').value=e.siren||'';document.getElementById('ep-dt').value=e.date||'';document.getElementById('ep-en').value=e.entreprise||'';document.getElementById('ep-sg').value=e.segment||'';document.getElementById('ep-ag').value=e.agence||'';document.getElementById('ep-no').value=e.note;document.getElementById('ep-pr').value=e.profil||prof(e.note);bootstrap.Modal.getOrCreateInstance(document.getElementById('mEPM')).show();}
function svPM(){const id=document.getElementById('ep-id').value,idx=S.pm.findIndex(x=>x.id===id);if(idx<0)return;const n=parseInt(document.getElementById('ep-no').value),ag=document.getElementById('ep-ag').value;S.pm[idx]={...S.pm[idx],questionnaire:document.getElementById('ep-q').value,siren:document.getElementById('ep-sr').value,date:document.getElementById('ep-dt').value,entreprise:document.getElementById('ep-en').value,segment:document.getElementById('ep-sg').value,agence:ag,zone:zone(ag),note:isNaN(n)?S.pm[idx].note:n,profil:prof(isNaN(n)?S.pm[idx].note:n)};save();bootstrap.Modal.getOrCreateInstance(document.getElementById('mEPM')).hide();refresh();toast('Entr\\u00e9e modifi\\u00e9e.');}
function edENT(id){const e=S.ent.find(x=>x.id===id);if(!e)return;document.getElementById('ee-id').value=e.id;document.getElementById('ee-sr').value=e.siren||'';document.getElementById('ee-dt').value=e.date||'';document.getElementById('ee-en').value=e.entreprise||'';document.getElementById('ee-sg').value=e.segment||'';document.getElementById('ee-dc').value=e.directionCommerciale||'';document.getElementById('ee-de').value=e.directionEntreprise||'';document.getElementById('ee-no').value=e.note;document.getElementById('ee-pr').value=e.profil||prof(e.note);document.getElementById('ee-rl').value=e.noteRelation!=null?e.noteRelation:'';document.getElementById('ee-cn').value=e.connaissance||'';bootstrap.Modal.getOrCreateInstance(document.getElementById('mEENT')).show();}
function svENT(){const id=document.getElementById('ee-id').value,idx=S.ent.findIndex(x=>x.id===id);if(idx<0)return;const n=parseInt(document.getElementById('ee-no').value),nr=parseInt(document.getElementById('ee-rl').value),dc=document.getElementById('ee-dc').value;S.ent[idx]={...S.ent[idx],siren:document.getElementById('ee-sr').value,date:document.getElementById('ee-dt').value,entreprise:document.getElementById('ee-en').value,segment:document.getElementById('ee-sg').value,directionCommerciale:dc,directionEntreprise:dirE(dc),note:isNaN(n)?S.ent[idx].note:n,profil:prof(isNaN(n)?S.ent[idx].note:n),noteRelation:isNaN(nr)?null:nr,connaissance:document.getElementById('ee-cn').value};save();bootstrap.Modal.getOrCreateInstance(document.getElementById('mEENT')).hide();refresh();toast('Entr\\u00e9e modifi\\u00e9e.');}
function aP(pfx){const fld=pfx==='pm'?'ep':'ee';const n=parseInt(document.getElementById(fld+'-no').value);if(!isNaN(n))document.getElementById(fld+'-pr').value=prof(n);}
function aDE(){const dc=document.getElementById('ee-dc').value;document.getElementById('ee-de').value=dirE(dc);}

// ── Delete ────────────────────────────────────────────────────────────
function askDel(type,id,name){_del={type,id};document.getElementById('del-msg').textContent='Supprimer \\u00ab '+name+' \\u00bb ?';bootstrap.Modal.getOrCreateInstance(document.getElementById('mDel')).show();}
function confDel(){if(!_del)return;const{type,id}=_del;S[type==='propme'?'pm':'ent']=S[type==='propme'?'pm':'ent'].filter(e=>e.id!==id);save();bootstrap.Modal.getOrCreateInstance(document.getElementById('mDel')).hide();refresh();toast('Entr\\u00e9e supprim\\u00e9e.');_del=null;}

// ── Filters ───────────────────────────────────────────────────────────
function updFilters(){
  const agS=document.getElementById('pm-fa'),cAg=agS.value;
  const ags=[...new Set(S.pm.map(e=>e.agence).filter(Boolean))].sort();
  agS.innerHTML='<option value="all">Toutes les agences</option>'+ags.map(a=>'<option value="'+esc(a)+'">'+esc(a)+'</option>').join('');
  agS.value=ags.includes(cAg)?cAg:'all';
  const deS=document.getElementById('ent-fde'),cDE=deS.value;
  const des=[...new Set(S.ent.map(e=>e.directionEntreprise).filter(d=>d&&!d.startsWith('\\u2014')))].sort();
  deS.innerHTML='<option value="all">Toutes les DE</option>'+des.map(d=>'<option value="'+esc(d)+'">'+esc(d)+'</option>').join('');
  deS.value=des.includes(cDE)?cDE:'all';
  const dcS=document.getElementById('ent-fdc'),cDC=dcS.value;
  const dcs=[...new Set(S.ent.map(e=>e.directionCommerciale).filter(Boolean))].sort();
  dcS.innerHTML='<option value="all">Toutes les DC</option>'+dcs.map(d=>'<option value="'+esc(d)+'">'+esc(d)+'</option>').join('');
  dcS.value=dcs.includes(cDC)?cDC:'all';
}
function refresh(){
  document.getElementById('cnt-pm').textContent=S.pm.length;document.getElementById('cnt-ent').textContent=S.ent.length;
  document.getElementById('hd-stats').textContent='ProPME : '+S.pm.length+' | Entreprise : '+S.ent.length;
  updFilters();renderPM();renderENT();
  const act=document.querySelector('.tab-pane.show.active');
  if(act){if(act.id==='t-dpm')dashPM();if(act.id==='t-dent')dashENT();}
}
document.addEventListener('DOMContentLoaded',()=>{
  load();refresh();
  document.querySelectorAll('button[data-bs-toggle="tab"]').forEach(btn=>{
    btn.addEventListener('shown.bs.tab',e=>{
      const t=e.target.getAttribute('data-bs-target');
      if(t==='#t-dpm')dashPM();if(t==='#t-dent')dashENT();
      if(t==='#t-tpm')renderPM();if(t==='#t-tent')renderENT();
    });
  });
});
<\/script>
</body>
</html>`;

fs.writeFileSync(TARGET, HTML, 'utf8');
console.log('Written', HTML.length, 'chars to', TARGET);
