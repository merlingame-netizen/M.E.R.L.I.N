/* =========================================================================
   CONFIG — Cagnotte EVG d'Alexandre
   -------------------------------------------------------------------------
   👉 C'EST LE SEUL FICHIER À MODIFIER pour mettre la page à jour.
   Change les valeurs ci-dessous, sauvegarde, puis "commit + push".
   La page se met à jour toute seule au prochain chargement.
   ========================================================================= */

const CAGNOTTE_CONFIG = {

  /* ---- LE COMPTEUR ----------------------------------------------------- */
  // Montant déjà récolté (en euros). Mets à jour ce chiffre régulièrement.
  montant_recolte: 0,

  // Objectif de la cagnotte (en euros). 👉 Tu m'as dit me donner la jauge
  // plus tard : remplace ce chiffre par ton objectif quand tu l'auras.
  objectif: 500,

  // Affiche la barre de progression + l'objectif ? (true) ou juste le
  // montant qui monte sans objectif ? (false)
  afficher_objectif: true,


  /* ---- INFOS DE L'EVG -------------------------------------------------- */
  prenom_du_marie: "Alexandre",
  date: "À définir",          // ex: "Samedi 12 septembre 2026"
  lieu: "À définir",          // ex: "Annecy"


  /* ---- MESSAGE PERSO --------------------------------------------------- */
  // Le petit mot affiché en haut. Modifie-le comme tu veux.
  message: "On organise un EVG de folie pour Alexandre ! Pour que tout soit "
    + "parfait, on met en commun pour le logement et les cadeaux. "
    + "Chaque participation compte — merci à vous 🍻",


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


  /* ---- COORDONNÉES BANCAIRES (RIB) ------------------------------------ */
  rib: {
    titulaire: "Maxime Babonneau",
    iban: "FR76 1680 7004 0082 1663 3419 550",
    bic: "CCBPFRPPGRE",
    banque: "Banque Populaire — 17-19 Cours Charlemagne, 69002 Lyon",
    // Fichier PDF du RIB placé à côté de cette page.
    pdf: "rib-maxime-babonneau.pdf"
  },


  /* ---- LIEN CAGNOTTE EN LIGNE (optionnel) ----------------------------- */
  // Si tu crées un jour une cagnotte Leetchi/Lydia/Le Pot Commun, colle le
  // lien ici (ex: "https://www.leetchi.com/c/..."). Laisse "" pour cacher.
  lien_cagnotte: "",


  /* ---- PARTICIPANTS ---------------------------------------------------- */
  // Ajoute / retire des lignes au fur et à mesure des participations.
  // Mets "montant: null" si tu ne veux pas afficher la somme de chacun.
  participants: [
    // { nom: "Thomas", montant: 50 },
    // { nom: "Julie",  montant: 30 },
  ]
};

// (technique — ne pas toucher) rend la config accessible à la page
window.CAGNOTTE_CONFIG = CAGNOTTE_CONFIG;
