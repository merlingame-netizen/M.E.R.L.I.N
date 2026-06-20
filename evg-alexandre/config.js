/* =========================================================================
   CONFIG — EVG d'Alexandre @ Vallon-Pont-d'Arc / Ruoms (nuit du 18→19 juillet 2026)
   -------------------------------------------------------------------------
   👉 C'EST LE SEUL FICHIER À MODIFIER pour mettre la page à jour.
   Change les valeurs ci-dessous, sauvegarde, puis "commit + push".

   ▸ Compteur cagnotte  : montant_recolte
   ▸ Statut des dispos  : champ "statut" de chaque logement / activité
       "a_verifier"   → 🔍 Dispo à vérifier
       "dispo"        → ✅ Dispo vérifiée
       "option_posee" → ⏳ Option posée
       "complet"      → ❌ Complet (carte grisée, non sélectionnable)
   ▸ Prix              : prix_total (logement, pour le groupe, 1 nuit)
                         prix_par_personne (activité)
   Groupe : 5 personnes. Format : 1 nuit (sam 18 → dim 19 juillet).
   ========================================================================= */

const CAGNOTTE_CONFIG = {

  /* ---- LE COMPTEUR ----------------------------------------------------- */
  // ⚠️ Si sync.worker_url est renseigné (voir SETUP.md), ces valeurs servent
  //    seulement de SECOURS : le vrai montant/objectif vient du Worker.
  montant_recolte: 0,
  objectif: 750,               // estimation BASSE du budget (aligné sur OnParticipe)
  afficher_objectif: true,

  // Phrase affichée sous le titre de la page Cagnotte.
  cagnotte_description: "Cette cagnotte finance l'EVG d'Alexandre en Ardèche : "
    + "la location du logement, son cadeau et quelques activités (canoë dans les "
    + "gorges…). Le montant visé est une estimation basse du budget des deux jours "
    + "— chaque participation nous aide à tout couvrir 🛶🍻",

  // Synchro temps réel du montant (Cloudflare Worker). Vide = secours config.js.
  // Renseigne l'URL de ton Worker après déploiement (voir SETUP.md).
  sync: { worker_url: "" },


  /* ---- INFOS DE L'EVG -------------------------------------------------- */
  prenom_du_marie: "Alexandre",
  date: "Sam 18 → dim 19 juillet (1 nuit)",
  lieu: "Vallon-Pont-d'Arc · base Ruoms 🛶",


  /* ---- MESSAGE PERSO --------------------------------------------------- */
  message: "On est 5 pour l'EVG d'Alexandre en Ardèche ! Choisis ton logement "
    + "préféré et coche tes activités ci-dessous — le programme final sera calé "
    + "selon vos votes. Et n'oublie pas la cagnotte 🍻",


  /* ---- À QUOI SERT L'ARGENT ------------------------------------------- */
  depenses: [
    {
      titre: "Location du logement",
      description: "Un logement sympa pour héberger la bande la nuit du samedi.",
      icone: "🏡"
    },
    {
      titre: "Les cadeaux",
      description: "De quoi gâter Alexandre et lui offrir des surprises mémorables.",
      icone: "🎁"
    }
  ],


  /* ---- LE PROGRAMME (logements + activités) ---------------------------- */
  programme: {
    nb_personnes: 5,

    note_logement: "On est 5, 1 nuit (sam 18 → dim 19 juillet), base autour de "
      + "Ruoms / Vallon. Theo a déniché 2 Airbnb (5 voyageurs) — choisis ton "
      + "préféré, on bloque. Le bouton « Vérifier la dispo » ouvre l'annonce avec "
      + "dates (18→19) et 5 voyageurs déjà réglés ; prix & photos sur l'annonce.",

    logements: [
      {
        id: "airbnb-theo-1",
        nom: "Airbnb #1 — la sélection de Theo ⭐",
        emoji: "🏠",
        plateforme: "Airbnb · 5 voyageurs",
        couchages: 5,
        distance: "Secteur Vallon / Ruoms",
        prix_total: null,
        description: "Première proposition de Theo. Ouvre l'annonce pour le prix, "
          + "les photos et les dispos (dates 18→19 juillet, 5 voyageurs déjà réglés).",
        atouts: ["🛶 Proche des gorges", "👍 Repéré par Theo"],
        lien: "https://www.airbnb.fr/rooms/1488932443472820244?adults=5&check_in=2026-07-18&check_out=2026-07-19",
        statut: "a_verifier"
      },
      {
        id: "airbnb-theo-2",
        nom: "Airbnb #2 — la sélection de Theo",
        emoji: "🏡",
        plateforme: "Airbnb · 5 voyageurs",
        couchages: 5,
        distance: "Secteur Vallon / Ruoms",
        prix_total: null,
        description: "Deuxième proposition de Theo. Compare les deux annonces "
          + "(prix, piscine, distance) et vote pour ta préférée.",
        atouts: ["🛶 Proche des gorges", "👍 Repéré par Theo"],
        lien: "https://www.airbnb.fr/rooms/1362340652207876059?adults=5&check_in=2026-07-18&check_out=2026-07-19",
        statut: "a_verifier"
      }
    ],

    // Liens de recherche avec dates (18→19/07) et 5 voyageurs pré-remplis
    recherches_logement: [
      { nom: "Airbnb",  lien: "https://www.airbnb.fr/s/Vallon-Pont-d%27Arc--France/homes?checkin=2026-07-18&checkout=2026-07-19&adults=5" },
      { nom: "Booking", lien: "https://www.booking.com/searchresults.fr.html?ss=Vallon-Pont-d%27Arc&checkin=2026-07-18&checkout=2026-07-19&group_adults=5&no_rooms=2&group_children=0" },
      { nom: "Abritel", lien: "https://www.abritel.fr/search?destination=Vallon-Pont-d%27Arc%2C%20France&startDate=2026-07-18&endDate=2026-07-19&adults=5" },
      { nom: "Gîtes de France 07", lien: "https://www.gites-de-france-ardeche.com/recherche/locations-vacances-gites-vallon-pont-d-arc,type-g,insee-07330.html" }
    ],

    note_activites: "On est 5 — coche ce qui te tente, le budget /pers se calcule "
      + "en bas. Adresses repérées par Theo (téléphone cliquable 📞). Canoë : savoir "
      + "nager 25 m obligatoire (attestation pour tout le groupe).",

    activites: [
      /* ---- Canoë 🛶 ---- */
      {
        id: "canoe-integrale",
        categorie: "Canoë", cat_emoji: "🛶",
        nom: "Descente intégrale 32 km — Alain Bateaux ⭐",
        emoji: "🛶",
        duree: "~6h30 (départ 8h30)", lieu: "Vallon → Sauze",
        prix_par_personne: 42,
        description: "LE truc iconique : sous le Pont d'Arc + toute la réserve "
          + "naturelle, stops baignade et pique-nique sur l'eau. Alain Bateaux "
          + "(4,9★, parking gratuit, navette incluse). Canoës biplaces = plus drôle.",
        tel: "+33475371722",
        lien: "http://www.alainbateaux.com/",
        statut: "a_verifier"
      },
      {
        id: "canoe-24",
        categorie: "Canoë", cat_emoji: "🛶",
        nom: "Descente 24 km — la réserve",
        emoji: "🚣",
        duree: "5-6h", lieu: "Vallon → Sauze",
        prix_par_personne: 38,
        description: "La version un peu plus courte de la grande descente, toujours "
          + "dans la réserve. Bon compromis si on veut souffler un peu plus le soir.",
        tel: "+33475371722",
        lien: "http://www.alainbateaux.com/",
        statut: "a_verifier"
      },
      {
        id: "canoe-mini",
        categorie: "Canoë", cat_emoji: "🛶",
        nom: "Mini-descente 8 km — Pont d'Arc",
        emoji: "🌊",
        duree: "~2h", lieu: "Vallon → Châmes",
        prix_par_personne: 26,
        description: "Le passage mythique sous le Pont d'Arc en version courte. "
          + "Idéal en demi-journée tranquille si on préfère garder du temps à la maison.",
        tel: "+33475371722",
        lien: "http://www.alainbateaux.com/",
        statut: "a_verifier"
      },
      {
        id: "canoe-2j",
        categorie: "Canoë", cat_emoji: "🛶",
        nom: "Version aventure : 2 jours + bivouac",
        emoji: "⛺",
        duree: "Sam → dim, nuit dans les gorges", lieu: "32 km · bivouac Gaud/Gournier",
        prix_par_personne: 67,
        description: "L'option ultime : la nuit du 18 se passe au bivouac au cœur de "
          + "la réserve — ça REMPLACE le logement et le bar. ⚠️ Chaleur de juillet à "
          + "prévoir + tickets bivouac à réserver tout de suite pour 5 places.",
        lien: "https://www.canoe-ardeche.com/en/rates/",
        statut: "a_verifier"
      },

      /* ---- Rando & nature 🥾 ---- */
      {
        id: "rando-cirque-gens",
        categorie: "Rando & nature", cat_emoji: "🥾",
        nom: "Cirque de Gens — rando + baignade ⭐",
        emoji: "🏞️",
        duree: "Courte marche · ~2h", lieu: "Chauzon / Ruoms · 10 min",
        prix_par_personne: null, prix_label: "Gratuit 🎉",
        description: "Le remède au lendemain de veille (4,7★) : courte marche jusqu'à "
          + "une plage entre falaises, baignade dans l'Ardèche. Départ tôt (chaleur).",
        lien: "https://maps.google.com/?cid=16479928116418706446"
      },
      {
        id: "belvedere-serre-tourre",
        categorie: "Rando & nature", cat_emoji: "🥾",
        nom: "Belvédère du Serre de Tourre",
        emoji: "📸",
        duree: "Arrêt photo", lieu: "Route des Gorges",
        prix_par_personne: null, prix_label: "Gratuit 🎉",
        description: "Vue plongeante sur le premier méandre des gorges (4,8★). Arrêt "
          + "photo parfait sur la route du retour le dimanche.",
        lien: "https://maps.google.com/?cid=17676479393799058642"
      },
      {
        id: "rando-dent-rez",
        categorie: "Rando & nature", cat_emoji: "🥾",
        nom: "La Dent de Rez — panorama 360° (sportif)",
        emoji: "⛰️",
        duree: "13,5 km · ~5h20", lieu: "Gras · 25 min",
        prix_par_personne: null, prix_label: "Gratuit 🎉",
        description: "Pour les motivés : le sommet du Bas-Vivarais (719 m), vue gorges "
          + "+ Cévennes + Ventoux. Départ très tôt, 3 L d'eau/pers.",
        lien: "https://www.visorando.com/en/walk-la-dent-de-rez/"
      },

      /* ---- Restos & soirée 🍻 ---- */
      {
        id: "resto-remparts",
        categorie: "Restos & soirée", cat_emoji: "🍻",
        nom: "Dîner samedi — Les Remparts ⭐",
        emoji: "🍽️",
        duree: "20h30", lieu: "Ruoms",
        prix_par_personne: null, prix_label: "Repas 🍽️",
        description: "Les Remparts by la Chistera (4,9★) : planches ardéchoises, belle "
          + "terrasse. À réserver pour 5. Alternative : Sel & Poivre (4,9★).",
        tel: "+33475931552",
        statut: "a_verifier"
      },
      {
        id: "bar-la-plage",
        categorie: "Restos & soirée", cat_emoji: "🍻",
        nom: "La grosse soirée — La Plage",
        emoji: "🍹",
        duree: "Jusqu'à 2h", lieu: "Ruoms",
        prix_par_personne: null, prix_label: "Consos 🍹",
        description: "Bar festif (4,4★), musique et ambiance jusqu'à 2h le samedi. "
          + "C'est LA soirée du week-end → prévoir un SAM (Antoine ? 😉).",
        tel: "+33967175253"
      },
      {
        id: "guinguette-acacias",
        categorie: "Restos & soirée", cat_emoji: "🍻",
        nom: "Guinguette des Acacias",
        emoji: "🍕",
        duree: "Soir (ferme 22h30)", lieu: "Labeaume",
        prix_par_personne: null, prix_label: "Repas 🍕",
        description: "Guinguette champêtre au bord de l'eau (pizzas & rosé). Parfait "
          + "pour démarrer tranquille le soir de l'arrivée.",
        tel: "+33684261088"
      },
      {
        id: "resto-assiette",
        categorie: "Restos & soirée", cat_emoji: "🍻",
        nom: "Déjeuner dimanche — L'assiette gourmande",
        emoji: "🥗",
        duree: "13h", lieu: "Ruoms",
        prix_par_personne: null, prix_label: "Repas 🍽️",
        description: "Cuisine fraîche à Ruoms (4,7★) avant la route. Tél : "
          + "04 69 22 54 95 (réserver pour 5).",
        lien: "https://maps.google.com/?cid=1779969984596533270"
      },
      {
        id: "neovinum",
        categorie: "Restos & soirée", cat_emoji: "🍻",
        nom: "Œnoparcours & dégustation Néovinum",
        emoji: "🍷",
        duree: "1-2h (ouvert jusqu'à 19h)", lieu: "Ruoms",
        prix_par_personne: 10,
        description: "Vignerons Ardéchois : œnoparcours 5 € + atelier dégustation 10 €. "
          + "Sympa en fin d'aprem entre canoë et apéro.",
        tel: "+33475399808",
        lien: "https://www.vignerons-ardechois.com/fr/visiter"
      },

      /* ---- Sensations ✨ ---- */
      {
        id: "canyoning",
        categorie: "Sensations", cat_emoji: "✨",
        nom: "Canyoning — Face Sud",
        emoji: "💦",
        duree: "Demi-journée", lieu: "Canyons du Chassezac · 40 min",
        prix_par_personne: 48,
        description: "Sauts, toboggans naturels et rappels avec la référence locale "
          + "(+3 € location chaussons). Niveaux découverte → sportif.",
        lien: "https://www.face-sud.com/canyoning-ardeche-cevennes/",
        statut: "a_verifier"
      },
      {
        id: "speleoeno",
        categorie: "Sensations", cat_emoji: "✨",
        nom: "SpéléŒnologie — dégustation sous terre",
        emoji: "🍾",
        duree: "Demi-journée", lieu: "Grotte Saint-Marcel",
        prix_par_personne: 74,
        description: "L'activité la plus EVG du game : spéléo dans la grotte "
          + "Saint-Marcel PUIS dégustation de vin en cave souterraine. Inoubliable.",
        lien: "https://www.guides-speleo-ardeche.com/speleologie/speleologie-journee"
      },
      {
        id: "paddle",
        categorie: "Sensations", cat_emoji: "✨",
        nom: "Paddle — rapides du Pont d'Arc",
        emoji: "🏄",
        duree: "1h30-2h", lieu: "Les Mazes · Vallon",
        prix_par_personne: 48,
        description: "Descente des rapides en stand-up paddle avec passage sous le "
          + "Pont d'Arc (48 €) ou simple initiation (30 €). Fous rires garantis.",
        lien: "https://www.ardechepaddle.com/en/rentalteaching/"
      },
      {
        id: "accrobranche",
        categorie: "Sensations", cat_emoji: "✨",
        nom: "Accrobranche + tyroliennes géantes",
        emoji: "🌲",
        duree: "2-3h", lieu: "Les Mazes · Vallon",
        prix_par_personne: 14,
        description: "14 parcours, 1 600 m de tyroliennes, plage privée sur "
          + "l'Ardèche. Le bon plan pas cher entre deux baignades.",
        lien: "https://www.accrochetoiauxbranches.fr/parc-vallon-pont-darc/"
      },
      {
        id: "chauvet2",
        categorie: "Sensations", cat_emoji: "✨",
        nom: "Grotte Chauvet 2",
        emoji: "🖼️",
        duree: "~3h sur site", lieu: "Vallon",
        prix_par_personne: 18,
        description: "La réplique de la grotte aux 36 000 ans. Créneaux pris d'assaut "
          + "en juillet → réserver en ligne dès que possible.",
        lien: "https://grottechauvet2ardeche.tickeasy.com/",
        statut: "a_verifier"
      },
      {
        id: "orgnac",
        categorie: "Sensations", cat_emoji: "✨",
        nom: "Aven d'Orgnac — la sortie fraîcheur",
        emoji: "🕳️",
        duree: "2-3h", lieu: "Orgnac · 20 min",
        prix_par_personne: 16.5,
        description: "Grand Site de France : salles souterraines géantes à 12°C — LE "
          + "plan anti-canicule de l'après-midi (prendre un pull).",
        lien: "https://www.orgnac.com/en/infos-pratiques/opening-hours-and-rates"
      }
    ],

    // Trame indicative du week-end (s'affiche sous les activités)
    trame: [
      { jour: "Sam 18", plan: "Arrivée à Ruoms en matinée → canoë intégrale 32 km (Alain Bateaux, sous le Pont d'Arc) → récup' & apéro piscine → dîner aux Remparts → soirée à La Plage 🍹 (prévoir un SAM)" },
      { jour: "Dim 19", plan: "Cirque de Gens (rando courte + baignade entre falaises) → déj à L'assiette gourmande → arrêt photo au belvédère du Serre de Tourre → route du retour 🚗" }
    ]
  },


  /* ---- COORDONNÉES BANCAIRES (RIB) ------------------------------------ */
  rib: {
    titulaire: "Maxime Babonneau",
    iban: "FR76 1680 7004 0082 1663 3419 550",
    bic: "CCBPFRPPGRE",
    banque: "Banque Populaire — 17-19 Cours Charlemagne, 69002 Lyon",
    pdf: "rib-maxime-babonneau.pdf"
  },


  /* ---- CAGNOTTE EN LIGNE — OnParticipe (0 frais) ---------------------- */
  // 👉 POUR ACTIVER LE BOUTON « Participer à la cagnotte » :
  //   1. Va sur https://www.onparticipe.fr → « Créer une cagnotte » (gratuit)
  //   2. Titre : « EVG Alexandre » · renseigne TON IBAN pour le retrait (0 frais)
  //   3. Copie le lien de ta cagnotte et colle-le entre les guillemets ci-dessous
  //   → le bouton apparaît tout seul sur la page.
  // 💡 OnParticipe = 0 commission au retrait (modèle au pourboire VOLONTAIRE :
  //    au moment de payer, le don à la plateforme peut être mis à 0 €).
  // ⚠️ Tant que tu n'as pas créé TA cagnotte, le bouton pointe vers la page
  //    d'accueil OnParticipe. Remplace par l'URL de ta cagnotte dès que tu l'as.
  lien_cagnotte: "https://www.onparticipe.fr/c/3SWBzVUo",


  /* ---- WHATSAPP -------------------------------------------------------- */
  whatsapp: {
    message_annonce:
      "🍻 EVG d'Alexandre — Vallon-Pont-d'Arc, sam 18 → dim 19 juillet 🛶\n\n" +
      "C'est officiel : direction l'Ardèche, on est 5 ! 🎉\n\n" +
      "👉 Va sur la page choisir TON logement préféré et TES activités " +
      "(canoë, canyoning, guinguettes, dégustation sous terre…) — ton budget " +
      "se calcule tout seul :\n\n{url}\n\n" +
      "💸 Cagnotte SANS FRAIS : virement sur le RIB de la page (motif : EVG " +
      "Alexandre) ou via la cagnotte en ligne. Merci à tous ! 🤘"
  },


  /* ---- PARTICIPANTS — suivi manuel de qui a payé ---------------------- */
  // Ajoute une ligne quand quelqu'un a versé sa part (montant facultatif).
  participants: [
    // { nom: "Theo",   montant: 60 },
    // { nom: "Antoine", montant: 60 },
  ]
};

// (technique — ne pas toucher) rend la config accessible à la page
window.CAGNOTTE_CONFIG = CAGNOTTE_CONFIG;
