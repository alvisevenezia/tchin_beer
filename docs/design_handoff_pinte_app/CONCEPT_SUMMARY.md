# Le Million de Pintes — Résumé du concept

> Ce document résume la réflexion produit issue de la discussion. Il accompagne le deck de concept (`Le Million de Pintes.dc.html`) et le prototype d'app (`Pinte App Prototype.dc.html`).

## Le point de départ (réel)
Un groupe d'amis sur WhatsApp s'est lancé un défi : **boire 1 000 000 de pintes ensemble**. Chaque pinte est prise en photo, numérotée, et postée sur le groupe. Le groupe compte **1 023 membres** — et WhatsApp plafonne à 1 024. **Le groupe est plein.** C'est le déclic : le mouvement a un plafond de verre et a besoin d'une vraie app pour grandir.

## L'idée
Une app où **chaque pinte = +1 vers le million**. Trois piliers :
1. **Une photo** — l'utilisateur prend sa pinte en photo (sa preuve, son +1).
2. **Un compteur mondial** — un total qui grimpe en temps réel vers 1 000 000. C'est le **cœur émotionnel** : une œuvre collective. Chaque jalon (500 000ᵉ, 999 999ᵉ pinte…) devient un évènement.
3. **Un fil commun** — toutes les pintes de la communauté, en direct (le remplaçant de WhatsApp, sans plafond et avec du jeu).

## Le moteur d'engagement : la guerre des villes
- **Géolocalisation** par ville (déclarée à l'inscription — plus fiable et moins « flicage » que le GPS).
- **Classement des villes** en temps réel, **remis à zéro chaque jour ET chaque semaine** (le reset crée une nouvelle chance de gagner → on revient chaque jour).
- **Régions** comme 2ᵉ niveau : une petite ville ne battra jamais Paris au volume, mais sa région oui — personne n'est laissé de côté.
- **Derbys** : duels programmés entre deux villes le temps d'un week-end (ranime les rivalités).
- **Profil & fierté locale** : total perso, série de jours (streak), badges, couleurs de la ville.

## Public cible
**Les étudiants.** Connectés (réflexe photo déjà acquis), joueurs (classements/séries/défis = leur langage), fiers de leur ville (les rivalités entre villes étudiantes existent déjà). Ton **estival, fun, léger**.

## Monétisation — SANS PUBLICITÉ
La pub casse l'expérience et est exclue. Avec une communauté passionnée, quelques fonctionnalités payantes sympas suffisent à dépasser les coûts d'hébergement. Trois leviers :

1. **Membre Fondateur (la rareté)** — badge **numéroté et introuvable**. Les 1 023 OG l'ont gratuitement ; les nouveaux veulent le leur (badge « Vérifié / Early » payant, mais jamais le numéro de fondateur). Achat unique.
2. **Pinte+ (abonnement, ≈ 2,99 €/mois)** — stats détaillées, historique complet, badges exclusifs, avatar custom, droit de représenter sa ville aux évènements. Revenu récurrent.
3. **Cosmétiques (dès 0,99 €)** — cadres de photo thématiques, couleurs de ville, verres animés. Marge élevée, zéro impact sur l'expérience des autres.

Bonus envisagés : **boost de pinte** (mise en avant 1h), **capitaine de ville** (rôle premium), **offrir Pinte+ à un pote** (acquisition virale).

## Vision internationale
**France d'abord**, mais architecture pensée pour scaler dès le jour 1 : **Villes → Régions → Pays**. La même mécanique se rejoue à chaque échelle ; pour s'étendre, il suffira d'ajouter des pays.

## Roadmap esquissée
1. MVP → 2. Beta avec les 1 023 membres existants → 3. Lancement public.

## Points ouverts à trancher
- **Anti-triche** : la photo est obligatoire pour garder le compteur crédible. Niveau de validation à définir (réactions de la commu, vérification légère, contrôle photo).
- Granularité exacte des régions, gestion des fuseaux pour les resets quotidiens à l'international.
