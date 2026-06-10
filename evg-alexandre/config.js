/* =========================================================================
   CONFIG — EVG d'Alexandre @ Vallon-Pont-d'Arc (nuit du 18 au 19 juillet 2026)
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
   Recherches faites le 10 juin 2026 — prix = estimations à confirmer à la résa.
   ========================================================================= */

const CAGNOTTE_CONFIG = {

  /* ---- LE COMPTEUR ----------------------------------------------------- */
  montant_recolte: 100,
  objectif: 0,                 // pas d'objectif fixe (dépendra location + cadeaux)
  afficher_objectif: false,


  /* ---- INFOS DE L'EVG -------------------------------------------------- */
  prenom_du_marie: "Alexandre",
  date: "Sam 18 → dim 19 juillet (1 nuit)",
  lieu: "Vallon-Pont-d'Arc 🛶",


  /* ---- MESSAGE PERSO --------------------------------------------------- */
  message: "Destination actée : Vallon-Pont-d'Arc ! Choisis ton logement "
    + "préféré et coche tes activités ci-dessous — le programme final sera "
    + "calé selon vos votes. Et n'oublie pas la cagnotte 🍻",


  /* ---- À QUOI SERT L'ARGENT ------------------------------------------- */
  depenses: [
    {
      titre: "Location du logement",
      description: "Un grand logement pour héberger toute la bande le temps du week-end.",
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
    nb_personnes: 10,

    note_logement: "Pour 10 personnes, 1 nuit (sam 18 → dim 19 juillet). "
      + "⚠️ Mi-juillet beaucoup de gîtes ne louent qu'à la semaine, et 1 nuit "
      + "sèche est rare : prix estimés POUR LA NUIT, à confirmer à l'appel "
      + "(certains exigeront 2 nuits minimum — on avisera). Choisis ta préférée, "
      + "on appelle pour bloquer.",

    logements: [
      {
        id: "trois-eaux",
        nom: "Les Trois Eaux — Domaine de Lastic ⭐",
        emoji: "🏞️",
        plateforme: "En direct",
        couchages: 14,
        distance: "Vagnas · 10 min de Vallon",
        prix_total: 600,
        description: "Ferme du XIIe rénovée (235 m²). Week-ends « sur demande » et "
          + "groupes d'amis bienvenus : la meilleure piste pour une nuit sèche "
          + "mi-juillet. Tél : 06 60 51 20 65.",
        atouts: ["🏊 Piscine chauffée", "🎱 Billard & ping-pong", "🍕 Four à pizza", "🎯 Pétanque"],
        lien: "https://www.domaine-lastic.fr/",
        statut: "a_verifier"
      },
      {
        id: "azure",
        nom: "Gîte L'Azuré — Saint-Remèze",
        emoji: "💆",
        plateforme: "En direct",
        couchages: 15,
        distance: "15-18 min de Vallon",
        prix_total: 550,
        description: "220 m² en plein village (boulangerie à pied), draps et ménage "
          + "inclus. Demander si une nuit est acceptée en juillet (sinon semaine). "
          + "Contact : Nadège, 06 10 62 62 31 (WhatsApp ok).",
        atouts: ["🏊 Piscine + spa", "🥖 Village à pied", "⚽ Baby-foot & pétanque", "🍖 BBQ"],
        lien: "https://www.gite-azure.com/",
        statut: "a_verifier"
      },
      {
        id: "villa-jaulet",
        nom: "Villa Jaulet — Rives de l'Ardèche",
        emoji: "🏊",
        plateforme: "Abritel",
        couchages: 10,
        distance: "5 min du centre · rivière à 500 m",
        prix_total: 450,
        description: "5 chambres, piscine privée 10×4 m + équipements du domaine "
          + "(tennis, multisports). 421 €/nuit vérifié mi-juillet. ⚠️ Minimum "
          + "7 nuits affiché en juillet — à négocier en direct (trou de planning).",
        atouts: ["🏊 Piscine privée", "❄️ Clim (4 ch.)", "🎾 Tennis du domaine"],
        lien: "https://www.abritel.fr/location-vacances/p8471550a",
        statut: "a_verifier"
      },
      {
        id: "villa-julie",
        nom: "Villa Julie — Rives de l'Ardèche",
        emoji: "🌳",
        plateforme: "Abritel",
        couchages: 10,
        distance: "5 min du centre · rivière à 500 m",
        prix_total: 400,
        description: "La jumelle de la Jaulet : 5 chambres, piscine privée, terrasse "
          + "couverte. Même réserve sur le minimum 7 nuits en juillet — sa sœur "
          + "« Bonne Vie » (piscine chauffée) est une alternative dans le même parc.",
        atouts: ["🏊 Piscine privée", "🌳 Terrasse couverte", "🏞️ Rivière à 500 m"],
        lien: "https://www.abritel.fr/location-vacances/p8471564a",
        statut: "a_verifier"
      },
      {
        id: "villa-luxe",
        nom: "Villa grand luxe — piscine 15 m",
        emoji: "🤑",
        plateforme: "Airbnb",
        couchages: 14,
        distance: "Commune de Vallon-Pont-d'Arc",
        prix_total: 1000,
        description: "L'option « gros budget » : piscine chauffée de 15 m, jacuzzi "
          + "privé, sauna, salle de fitness, 4 ha d'oliviers au calme absolu.",
        atouts: ["🏊 Piscine chauffée 15 m", "🛁 Jacuzzi + sauna", "💪 Salle de fitness"],
        lien: "https://www.airbnb.fr/rooms/632867871701836416",
        statut: "a_verifier"
      },
      {
        id: "bastide",
        nom: "La Bastide Saint Martin (plan B semaine)",
        emoji: "🏰",
        plateforme: "En direct",
        couchages: 18,
        distance: "800 m du centre — tout à pied !",
        prix_total: null,
        description: "Bastide XVIIIe 4★, piscine couverte chauffée à 30°C. En juillet : "
          + "semaine uniquement, 3 300 € (≈ 330 €/pers à 10). Le plan B si l'EVG "
          + "devient une semaine — zéro voiture le soir.",
        atouts: ["🏊 Piscine couverte 30°C", "🚶 Centre à pied", "🛏️ 9 chambres"],
        lien: "https://www.gitebastidesaintmartin.com/",
        statut: "a_verifier"
      },
      {
        id: "grand-gite-vallon",
        nom: "Le Grand Gîte de Vallon",
        emoji: "😢",
        plateforme: "En direct",
        couchages: 12,
        distance: "Vallon-Pont-d'Arc",
        prix_total: null,
        description: "Le candidat idéal sur le papier… déjà réservé du 11 au 25 "
          + "juillet (vérifié le 10 juin). On le laisse ici pour mémoire.",
        atouts: [],
        lien: "",
        statut: "complet"
      }
    ],

    // Liens de recherche avec dates (17→19/07) et 10 voyageurs pré-remplis
    recherches_logement: [
      { nom: "Airbnb",  lien: "https://www.airbnb.fr/s/Vallon-Pont-d%27Arc--France/homes?checkin=2026-07-18&checkout=2026-07-19&adults=10" },
      { nom: "Booking", lien: "https://www.booking.com/searchresults.fr.html?ss=Vallon-Pont-d%27Arc&checkin=2026-07-18&checkout=2026-07-19&group_adults=10&no_rooms=4&group_children=0" },
      { nom: "Abritel", lien: "https://www.abritel.fr/search?destination=Vallon-Pont-d%27Arc%2C%20France&startDate=2026-07-18&endDate=2026-07-19&adults=10" },
      { nom: "Gîtes de France 07", lien: "https://www.gites-de-france-ardeche.com/recherche/locations-vacances-gites-vallon-pont-d-arc,type-g,insee-07330.html" }
    ],

    note_activites: "Coche tout ce qui te tente — le programme final sera calé "
      + "selon les votes. Prix 2026 vérifiés chez les opérateurs (à confirmer à la résa). "
      + "Canoë : savoir nager 25 m obligatoire (attestation pour tout le groupe).",

    activites: [
      /* ---- Canoë 🛶 ---- */
      {
        id: "canoe-mini",
        categorie: "Canoë", cat_emoji: "🛶",
        nom: "Mini-descente 8 km — Pont d'Arc",
        emoji: "🛶",
        duree: "~2h", lieu: "Vallon → Châmes",
        prix_par_personne: 26,
        description: "Le passage mythique sous le Pont d'Arc, pauses baignade. "
          + "Tarif groupe 10+ chez Loulou Bateaux. Idéal en demi-journée tranquille.",
        lien: "https://louloubateaux.com/tarifs/",
        statut: "a_verifier"
      },
      {
        id: "canoe-24",
        categorie: "Canoë", cat_emoji: "🛶",
        nom: "Descente 24 km — la classique ⭐",
        emoji: "🚣",
        duree: "6-7h (départ le matin)", lieu: "Vallon → Sauze",
        prix_par_personne: 38,
        description: "LA traversée des Gorges en réserve naturelle, navette retour "
          + "incluse. 38 € (grille 10-19 pers Loulou Bateaux) ou ~35 € chez "
          + "Aventure Canoës (-10 % dès 10). Canoës biplaces = plus drôle en EVG.",
        lien: "https://aventure-canoes.fr/tarifs/",
        statut: "a_verifier"
      },
      {
        id: "canoe-2j",
        categorie: "Canoë", cat_emoji: "🛶",
        nom: "Descente 2 jours + nuit en bivouac",
        emoji: "⛺",
        duree: "Sam matin → dim après-midi", lieu: "32 km dans les Gorges",
        prix_par_personne: 67,
        description: "L'aventure totale sam → dim : la nuit du 18 se passe au "
          + "bivouac au cœur de la réserve (Gaud ou Gournier) — ça peut REMPLACER "
          + "le gîte ! ⚠️ Tickets bivouac à réserver TOUT DE SUITE pour 10 places — "
          + "le pack de la Base Nautique du Pont d'Arc (+3 €) gère la résa.",
        lien: "https://www.canoe-ardeche.com/en/rates/",
        statut: "a_verifier"
      },

      /* ---- Rando 🥾 ---- */
      {
        id: "rando-cirque-gens",
        categorie: "Rando", cat_emoji: "🥾",
        nom: "Cirque des Gens",
        emoji: "🥾",
        duree: "7 km · ~2h30", lieu: "Chauzon / Ruoms · 10 min",
        prix_par_personne: null, prix_label: "Gratuit 🎉",
        description: "Méandre spectaculaire au-dessus des falaises, belvédères "
          + "plongeants et baignade en bas. Départ tôt le matin (chaleur de juillet).",
        lien: "https://www.visorando.com/randonnee-vallon-pont-d-arc.html"
      },
      {
        id: "rando-dent-rez",
        categorie: "Rando", cat_emoji: "🥾",
        nom: "La Dent de Rez — panorama 360°",
        emoji: "⛰️",
        duree: "13,5 km · ~5h20", lieu: "Gras · 25 min",
        prix_par_personne: null, prix_label: "Gratuit 🎉",
        description: "Le sommet du Bas-Vivarais (719 m) : vue sur les gorges, les "
          + "Cévennes et le Ventoux. La « grosse rando » du week-end — départ très tôt, 3 L d'eau/pers.",
        lien: "https://www.visorando.com/en/walk-la-dent-de-rez/"
      },

      /* ---- Soirée & terroir 🍻 ---- */
      {
        id: "guinguette",
        categorie: "Soirée & terroir", cat_emoji: "🍻",
        nom: "Guinguettes au bord de l'Ardèche",
        emoji: "🍻",
        duree: "Soir", lieu: "Saint-Martin-d'Ardèche",
        prix_par_personne: null, prix_label: "Consos 🍺",
        description: "Chez Patou (terrasse au-dessus de la rivière) ou la Guinguette "
          + "du Moulin (120 places, barbecue, moules-frites) — parfait après le canoë "
          + "qui finit juste à côté.",
        lien: "https://en.gorges-ardeche-pontdarc.fr/restauration/la-guinguette-du-moulin-saint-martin-dardeche/"
      },
      {
        id: "cab07",
        categorie: "Soirée & terroir", cat_emoji: "🍻",
        nom: "Soirée CAB07 — cabaret + night-club",
        emoji: "🪩",
        duree: "Dîner-spectacle puis club 23h30-3h", lieu: "Vallon",
        prix_par_personne: null, prix_label: "Consos 🍸",
        description: "Le QG d'EVG local : blind test, DJ, dîner-spectacle puis "
          + "night-club C07 le samedi. Privatisation possible, navettes ~5 €/pers. "
          + "Tél : 06 77 61 94 74.",
        lien: "https://www.lecab07.fr/ambiance-club/"
      },
      {
        id: "neovinum",
        categorie: "Soirée & terroir", cat_emoji: "🍻",
        nom: "Œnoparcours & dégustation Néovinum",
        emoji: "🍷",
        duree: "1-2h (ouvert jusqu'à 19h)", lieu: "Ruoms · 10 min",
        prix_par_personne: 10,
        description: "Vignerons Ardéchois : œnoparcours 5 € + atelier dégustation "
          + "10 €. Alternative : Domaine de Vigier à Lagorce (7,50 €, réserver au "
          + "04 75 88 01 18).",
        lien: "https://www.vignerons-ardechois.com/fr/visiter"
      },

      /* ---- Sensations & bonus ✨ ---- */
      {
        id: "canyoning",
        categorie: "Sensations & bonus", cat_emoji: "✨",
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
        categorie: "Sensations & bonus", cat_emoji: "✨",
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
        categorie: "Sensations & bonus", cat_emoji: "✨",
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
        categorie: "Sensations & bonus", cat_emoji: "✨",
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
        categorie: "Sensations & bonus", cat_emoji: "✨",
        nom: "Grotte Chauvet 2",
        emoji: "🖼️",
        duree: "~3h sur site", lieu: "Vallon",
        prix_par_personne: 18,
        description: "La réplique de la grotte aux 36 000 ans. Créneaux pris "
          + "d'assaut en juillet → réserver en ligne dès que possible.",
        lien: "https://grottechauvet2ardeche.tickeasy.com/",
        statut: "a_verifier"
      },
      {
        id: "orgnac",
        categorie: "Sensations & bonus", cat_emoji: "✨",
        nom: "Aven d'Orgnac — la sortie fraîcheur",
        emoji: "🕳️",
        duree: "2-3h", lieu: "Orgnac · 20 min",
        prix_par_personne: 16.5,
        description: "Grand Site de France : salles souterraines géantes à 12°C — "
          + "LE plan anti-canicule de l'après-midi (prendre un pull).",
        lien: "https://www.orgnac.com/en/infos-pratiques/opening-hours-and-rates"
      },
      {
        id: "adventure-camp",
        categorie: "Sensations & bonus", cat_emoji: "✨",
        nom: "Pack EVG Adventure Camp",
        emoji: "🎯",
        duree: "Demi-journée à journée", lieu: "Grospierres · 15 min",
        prix_par_personne: 55,
        description: "Packs EVG 50-64 €/pers (paintball, archery tag, laser game, "
          + "via ferrata…) — le futur marié est GRATUIT dès 11 participants avec "
          + "2 activités.",
        lien: "https://www.adventurecamp.fr/groupes/evg-evjf-wei/"
      }
    ],

    // Trame indicative du week-end (s'affiche sous les activités)
    trame: [
      { jour: "Sam 18", plan: "Arrivée le matin → canoë (mini 8 km ou 24 km) → baignade au Pont d'Arc → check-in & apéro piscine → dîner → soirée CAB07 ou Bar La Plage à Ruoms 🪩" },
      { jour: "Dim 19", plan: "Rando tôt (Cirque des Gens) ou sensation (canyoning / spéléŒno / paddle) → guinguette au bord de l'eau à Saint-Martin avant la route 🍻" }
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


  /* ---- LIEN CAGNOTTE EN LIGNE (optionnel) ----------------------------- */
  lien_cagnotte: "",


  /* ---- WHATSAPP -------------------------------------------------------- */
  whatsapp: {
    message_annonce:
      "🍻 EVG d'Alexandre — Vallon-Pont-d'Arc, sam 18 → dim 19 juillet 🛶\n\n" +
      "C'est officiel : direction l'Ardèche ! 🎉\n\n" +
      "👉 Va sur la page choisir TON logement préféré et TES activités " +
      "(canoë, canyoning, guinguettes, dégustation sous terre…) — ton budget " +
      "se calcule tout seul :\n\n{url}\n\n" +
      "💸 Et pense à la cagnotte (RIB sur la page, motif : EVG Alexandre). " +
      "Merci à tous ! 🤘"
  },


  /* ---- PARTICIPANTS ---------------------------------------------------- */
  participants: [
    // { nom: "Thomas", montant: 50 },
  ]
};

// (technique — ne pas toucher) rend la config accessible à la page
window.CAGNOTTE_CONFIG = CAGNOTTE_CONFIG;
