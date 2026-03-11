'use strict';

/**
 * Dictionnaire de traduction : nom de processus Windows → libellé français lisible.
 * Les clés sont en minuscules sans extension .exe.
 * Catégories : systeme, securite, navigateur, dev, office, orange, media, reseau, antivirus
 */
const PROCESS_DICTIONARY = {
  // ── Noyau Windows ──────────────────────────────────────────────
  'system': { label: 'Noyau Windows', category: 'systeme', desc: 'Processus système central NT' },
  'system idle process': { label: 'Processeur inactif', category: 'systeme', desc: 'Temps CPU non utilisé' },
  'registry': { label: 'Registre Windows', category: 'systeme', desc: 'Cache du registre système' },
  'smss': { label: 'Gestionnaire de sessions', category: 'systeme', desc: 'Session Manager Subsystem' },
  'csrss': { label: 'Sous-système client/serveur', category: 'systeme', desc: 'Client Server Runtime Process' },
  'wininit': { label: 'Initialisation Windows', category: 'systeme', desc: 'Windows Initialization Process' },
  'winlogon': { label: 'Ouverture de session', category: 'securite', desc: 'Gestion des ouvertures/fermetures de session' },
  'services': { label: 'Gestionnaire de services', category: 'systeme', desc: 'Service Control Manager' },
  'lsass': { label: 'Authentification Windows', category: 'securite', desc: 'Local Security Authority — gère les logins et tokens' },
  'lsaiso': { label: 'Isolation sécurité (LSA)', category: 'securite', desc: 'LSA Isolated — credential guard' },
  'svchost': { label: 'Hôte de services Windows', category: 'systeme', desc: 'Service Host — regroupe plusieurs services système' },
  'explorer': { label: 'Explorateur Windows', category: 'systeme', desc: 'Interface graphique du bureau + Explorateur de fichiers' },
  'dwm': { label: 'Gestionnaire de fenêtres', category: 'systeme', desc: 'Desktop Window Manager — rendu visuel des fenêtres' },
  'taskhostw': { label: 'Hôte de tâches', category: 'systeme', desc: 'Task Host Window — héberge les tâches planifiées' },
  'taskeng': { label: 'Planificateur de tâches', category: 'systeme', desc: 'Task Scheduler Engine' },
  'taskschd': { label: 'Planificateur de tâches', category: 'systeme', desc: 'Task Scheduler service' },
  'spoolsv': { label: 'Spoule d\'impression', category: 'systeme', desc: 'Print Spooler — file d\'attente imprimante' },
  'fontdrvhost': { label: 'Pilote de polices', category: 'systeme', desc: 'Font Driver Host Process' },
  'ctfmon': { label: 'Saisie de texte (CTF)', category: 'systeme', desc: 'Collaborative Translation Framework — IME, dictée vocale' },
  'conhost': { label: 'Hôte de console', category: 'systeme', desc: 'Console Window Host — fenêtres CMD/PowerShell' },
  'dllhost': { label: 'Hôte de composants COM', category: 'systeme', desc: 'DLL Host — héberge les composants COM+' },
  'rundll32': { label: 'Exécuteur DLL', category: 'systeme', desc: 'Exécute des fonctions dans des fichiers DLL' },
  'runtimebroker': { label: 'Courtier d\'applications', category: 'systeme', desc: 'Gère les permissions des apps Store (UWP)' },
  'sihost': { label: 'Hôte d\'interface shell', category: 'systeme', desc: 'Shell Infrastructure Host — fond d\'écran, Cortana' },
  'startmenuexperiencehost': { label: 'Menu Démarrer', category: 'systeme', desc: 'Interface du menu Démarrer Windows 11' },
  'searchhost': { label: 'Hôte de recherche', category: 'systeme', desc: 'Windows Search Host Process' },
  'searchapp': { label: 'Recherche Windows', category: 'systeme', desc: 'Interface de recherche Windows' },
  'searchindexer': { label: 'Indexeur de recherche', category: 'systeme', desc: 'Windows Search Indexer — indexe les fichiers locaux' },
  'searchprotocolhost': { label: 'Protocole de recherche', category: 'systeme', desc: 'Windows Search Protocol Host' },
  'searchfilterhost': { label: 'Filtre de recherche', category: 'systeme', desc: 'Windows Search Filter Host' },
  'wuauserv': { label: 'Windows Update', category: 'systeme', desc: 'Service de mises à jour automatiques Windows' },
  'tiworker': { label: 'Maintenance Windows', category: 'systeme', desc: 'Windows Modules Installer Worker — installe les MàJ' },
  'musnotification': { label: 'Notif. mises à jour', category: 'systeme', desc: 'Modern Update Notification' },
  'audiodg': { label: 'Moteur audio Windows', category: 'systeme', desc: 'Audio Device Graph Isolation — traitement audio' },
  'dashost': { label: 'Hôte appareils', category: 'systeme', desc: 'Device Association Framework Host — Bluetooth, etc.' },
  'wlanext': { label: 'Extension Wi-Fi', category: 'reseau', desc: 'Windows Wireless LAN 802.11 Extensibility Framework' },
  'wmpnscfg': { label: 'Partage média WMP', category: 'media', desc: 'Windows Media Player Network Sharing' },
  'msiexec': { label: 'Installateur Windows', category: 'systeme', desc: 'Windows Installer — installation de .msi' },
  'backgroundtaskhost': { label: 'Tâches d\'arrière-plan', category: 'systeme', desc: 'Background Task Host — tâches UWP en fond' },
  'applicationframehost': { label: 'Cadre d\'applications', category: 'systeme', desc: 'Application Frame Host — fenêtres UWP' },
  'securityhealthservice': { label: 'Sécurité Windows (santé)', category: 'securite', desc: 'Windows Security Health Service' },
  'securityhealthsystray': { label: 'Icône sécurité', category: 'securite', desc: 'Windows Security Taskbar Icon' },
  'smartscreen': { label: 'SmartScreen', category: 'securite', desc: 'Windows SmartScreen — analyse les téléchargements' },
  'vssvc': { label: 'Clichés instantanés', category: 'systeme', desc: 'Volume Shadow Copy Service' },
  'wbengine': { label: 'Sauvegarde Windows', category: 'systeme', desc: 'Block Level Backup Engine' },
  'onedrive': { label: 'OneDrive', category: 'office', desc: 'Synchronisation cloud Microsoft OneDrive' },
  'msedgewebview2': { label: 'WebView2 (Edge)', category: 'systeme', desc: 'Microsoft Edge WebView2 Runtime — composant navigateur intégré' },

  // ── Navigateurs ────────────────────────────────────────────────
  'chrome': { label: 'Google Chrome', category: 'navigateur', desc: 'Navigateur web Google Chrome' },
  'msedge': { label: 'Microsoft Edge', category: 'navigateur', desc: 'Navigateur web Microsoft Edge (Chromium)' },
  'firefox': { label: 'Mozilla Firefox', category: 'navigateur', desc: 'Navigateur web Mozilla Firefox' },
  'iexplore': { label: 'Internet Explorer', category: 'navigateur', desc: 'Navigateur web Internet Explorer (obsolète)' },
  'brave': { label: 'Brave Browser', category: 'navigateur', desc: 'Navigateur web Brave (privacy-first)' },
  'opera': { label: 'Opera Browser', category: 'navigateur', desc: 'Navigateur web Opera' },

  // ── Développement ──────────────────────────────────────────────
  'code': { label: 'Visual Studio Code', category: 'dev', desc: 'Éditeur de code VS Code (Microsoft)' },
  'code - insiders': { label: 'VS Code Insiders', category: 'dev', desc: 'Version preview de VS Code' },
  'node': { label: 'Node.js', category: 'dev', desc: 'Runtime JavaScript Node.js' },
  'nodemon': { label: 'Nodemon (Node.js)', category: 'dev', desc: 'Rechargement automatique Node.js' },
  'npm': { label: 'NPM', category: 'dev', desc: 'Node Package Manager' },
  'godot': { label: 'Godot Engine', category: 'dev', desc: 'Moteur de jeu Godot 4.x' },
  'git': { label: 'Git', category: 'dev', desc: 'Système de contrôle de version Git' },
  'python': { label: 'Python', category: 'dev', desc: 'Interpréteur Python' },
  'python3': { label: 'Python 3', category: 'dev', desc: 'Interpréteur Python 3' },
  'powershell': { label: 'PowerShell', category: 'dev', desc: 'Shell et langage de script PowerShell' },
  'pwsh': { label: 'PowerShell 7+', category: 'dev', desc: 'PowerShell Core cross-platform' },
  'cmd': { label: 'Invite de commandes', category: 'dev', desc: 'Command Prompt Windows (cmd.exe)' },
  'windowsterminal': { label: 'Terminal Windows', category: 'dev', desc: 'Windows Terminal — onglets multi-shell' },
  'wt': { label: 'Terminal Windows', category: 'dev', desc: 'Windows Terminal (raccourci)' },
  'devenv': { label: 'Visual Studio', category: 'dev', desc: 'IDE Visual Studio (Microsoft)' },
  'msbuildd': { label: 'MSBuild', category: 'dev', desc: 'Microsoft Build Engine' },
  'ollama': { label: 'Ollama (LLM local)', category: 'dev', desc: 'Serveur de modèles LLM locaux Ollama' },
  'docker': { label: 'Docker', category: 'dev', desc: 'Moteur de conteneurs Docker' },
  'dockerd': { label: 'Docker Daemon', category: 'dev', desc: 'Démon Docker (service principal)' },

  // ── Microsoft Office / Teams ───────────────────────────────────
  'winword': { label: 'Microsoft Word', category: 'office', desc: 'Traitement de texte Microsoft Word' },
  'excel': { label: 'Microsoft Excel', category: 'office', desc: 'Tableur Microsoft Excel' },
  'powerpnt': { label: 'Microsoft PowerPoint', category: 'office', desc: 'Présentation Microsoft PowerPoint' },
  'outlook': { label: 'Microsoft Outlook', category: 'office', desc: 'Client mail/calendrier Microsoft Outlook' },
  'teams': { label: 'Microsoft Teams', category: 'office', desc: 'Collaboration et réunions Microsoft Teams' },
  'ms-teams': { label: 'Microsoft Teams', category: 'office', desc: 'Microsoft Teams (nouvelle version)' },
  'onenote': { label: 'Microsoft OneNote', category: 'office', desc: 'Prise de notes Microsoft OneNote' },
  'msaccess': { label: 'Microsoft Access', category: 'office', desc: 'Base de données Microsoft Access' },
  'visio': { label: 'Microsoft Visio', category: 'office', desc: 'Diagrammes Microsoft Visio' },
  'lync': { label: 'Skype for Business', category: 'office', desc: 'Ancien client Skype For Business / Lync' },
  'officeclicktorun': { label: 'Office — Mises à jour', category: 'office', desc: 'Office Click-to-Run — mise à jour Office' },

  // ── Outils Orange / Enterprise ─────────────────────────────────
  'zscaler': { label: 'Zscaler (proxy sécurité)', category: 'orange', desc: 'Proxy sécurité cloud Orange/Zscaler' },
  'zscalertunnel': { label: 'Tunnel Zscaler', category: 'orange', desc: 'Tunnel VPN Zscaler' },
  'ciscojabber': { label: 'Cisco Jabber', category: 'orange', desc: 'Messagerie unifiée Cisco Jabber' },
  'cisco_umbrella_roaming': { label: 'Cisco Umbrella', category: 'orange', desc: 'Protection DNS Cisco Umbrella' },
  'intune': { label: 'Microsoft Intune (MDM)', category: 'orange', desc: 'Gestion d\'appareils mobiles Intune' },
  'intunemanagementextension': { label: 'Intune — Extension', category: 'orange', desc: 'Agent Intune Management Extension' },
  'sentinelagent': { label: 'SentinelOne (EDR)', category: 'securite', desc: 'Agent de sécurité endpoint SentinelOne' },
  'sentinelone': { label: 'SentinelOne (EDR)', category: 'securite', desc: 'Antivirus/EDR SentinelOne' },
  'crowdstrike': { label: 'CrowdStrike (EDR)', category: 'securite', desc: 'Agent de sécurité endpoint CrowdStrike' },
  'cscca': { label: 'Cisco AnyConnect', category: 'orange', desc: 'Client VPN Cisco AnyConnect' },
  'vpnui': { label: 'Cisco VPN (UI)', category: 'orange', desc: 'Interface graphique Cisco VPN' },
  'mcafeeframeworkservice': { label: 'McAfee Framework', category: 'securite', desc: 'Service framework McAfee' },
  'ibmpoweriam': { label: 'IBM Power IAM', category: 'orange', desc: 'Gestion identités IBM' },

  // ── Antivirus / Sécurité ───────────────────────────────────────
  'msmpeng': { label: 'Windows Defender (scan)', category: 'securite', desc: 'Microsoft Malware Protection Engine — scan antivirus' },
  'nissrv': { label: 'Windows Defender (réseau)', category: 'securite', desc: 'Network Inspection Service — détection intrusion' },
  'msseces': { label: 'Security Essentials', category: 'securite', desc: 'Microsoft Security Essentials' },
  'antivirussvc': { label: 'Service antivirus', category: 'securite', desc: 'Service antivirus générique' },

  // ── Multimedia ─────────────────────────────────────────────────
  'vlc': { label: 'VLC Media Player', category: 'media', desc: 'Lecteur multimédia VLC' },
  'spotify': { label: 'Spotify', category: 'media', desc: 'Application de streaming musical Spotify' },
  'itunes': { label: 'iTunes', category: 'media', desc: 'Lecteur audio/vidéo Apple iTunes' },
  'wmplayer': { label: 'Windows Media Player', category: 'media', desc: 'Lecteur multimédia Windows Media Player' },
  'obs64': { label: 'OBS Studio', category: 'media', desc: 'Logiciel d\'enregistrement/streaming OBS' },
  'obs32': { label: 'OBS Studio (32-bit)', category: 'media', desc: 'OBS Studio version 32-bit' },
  'discord': { label: 'Discord', category: 'media', desc: 'Application de communication Discord' },

  // ── Réseau / Système ───────────────────────────────────────────
  'svchost (netsvcs)': { label: 'Services réseau', category: 'reseau', desc: 'Groupe de services réseau Windows' },
  'vmware': { label: 'VMware', category: 'dev', desc: 'Machine virtuelle VMware' },
  'vmnat': { label: 'VMware NAT', category: 'dev', desc: 'Service NAT réseau VMware' },
  'vmnetdhcp': { label: 'VMware DHCP', category: 'dev', desc: 'Service DHCP virtuel VMware' },
};

/**
 * Résout le nom lisible d'un processus.
 * @param {string} rawName - Nom brut du processus (ex: "svchost#3", "CHROME.EXE")
 * @returns {{ label: string, category: string, desc: string }}
 */
function resolveProcess(rawName) {
  if (!rawName) return { label: rawName || '(inconnu)', category: 'autre', desc: '' };

  // Normaliser : minuscules, supprimer extension .exe, supprimer suffixe #N
  let name = rawName
    .toLowerCase()
    .replace(/\.exe$/i, '')
    .replace(/#\d+$/, '')
    .trim();

  if (PROCESS_DICTIONARY[name]) {
    return PROCESS_DICTIONARY[name];
  }

  // Fallback partiel : chercher si le nom contient un mot-clé connu (min 4 chars, unidirectionnel)
  for (const [key, val] of Object.entries(PROCESS_DICTIONARY)) {
    if (key.length >= 4 && name.includes(key)) {
      return val;
    }
  }

  // Inconnu : retourner le nom brut nettoyé avec première lettre en maj
  return {
    label: name.charAt(0).toUpperCase() + name.slice(1),
    category: 'autre',
    desc: `Processus non répertorié (${rawName})`
  };
}

module.exports = { PROCESS_DICTIONARY, resolveProcess };
