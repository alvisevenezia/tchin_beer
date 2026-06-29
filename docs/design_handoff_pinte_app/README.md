# Handoff : Le Million de Pintes (app mobile)

## Overview
App mobile sociale et ludique autour d'un défi collectif : une communauté boit ensemble pour atteindre **1 000 000 de pintes**. Les utilisateurs postent une photo de leur pinte, ce qui incrémente un compteur mondial en temps réel et alimente un fil commun. Une couche de compétition **ville contre ville** (avec régions et derbys) entretient l'engagement. Monétisation **sans publicité** (badge Fondateur, abonnement Pinte+, cosmétiques).

Le contexte produit complet est dans **`CONCEPT_SUMMARY.md`** (à lire en premier). Un deck de concept (`Le Million de Pintes.dc.html`) accompagne le prototype.

## About the Design Files
Les fichiers de ce bundle sont des **références de design réalisées en HTML** (prototypes montrant l'apparence et le comportement voulus) — **pas du code de production à copier tel quel**. Ils sont écrits comme « Design Components » (`.dc.html`) et dépendent de `support.js` / `deck-stage.js` pour s'afficher dans l'environnement d'origine.

La tâche est de **recréer ces designs dans l'environnement cible** (React Native, Flutter, Swift/SwiftUI, etc.) en suivant les patterns et librairies existants. Si aucun environnement n'existe encore, choisir le framework le plus adapté — pour une app mobile sociale temps réel, **React Native (Expo)** ou **Flutter** sont de bons choix, avec un backend temps réel (Supabase/Firebase) pour le compteur et le fil.

> Pour lire le code source de référence : ouvrir les `.dc.html` dans un navigateur (ils chargent `support.js`). La logique React de l'app est dans le bloc `<script data-dc-script>` en bas de `Pinte App Prototype.dc.html` (classe `Component`), et le markup dans `<x-dc>`.

## Fidelity
**Haute fidélité (hifi)** pour l'app (`Pinte App Prototype.dc.html`) : couleurs, typographie, espacements et interactions finaux. À recréer au pixel près avec les composants de la codebase cible. Le deck est un support de pitch, pas une UI à implémenter.

Cible : **mobile portrait**. Le cadre de référence du prototype simule un écran de **390 × 758 px** (zone d'écran utile, hors bezel).

---

## Design Tokens

### Couleurs
| Rôle | Hex |
|---|---|
| Fond app (crème) | `#FFF4E0` |
| Carte / surface claire (foam) | `#FFFBF2` |
| Encre / texte principal | `#2A1A0D` |
| Encre sur fond chaud | `#2A1206` |
| Brun profond (frame, slides sombres) | `#241308` |
| Ambre (primaire bière) | `#F4A722` |
| Corail / orange (accent principal, actif) | `#FF6A3D` |
| Orange intermédiaire | `#FF8A3D` |
| Bleu ciel (compétition) | `#1AA3D6` |
| Rouge live | `#FF3B30` |
| Texte atténué | `#9A865F`, `#7A6447`, `#4A3522` |
| Onglet inactif | `#B6A081` |
| Rail de progression / barre | `#ECDCBF` |
| Or (texte sur brun) | `#FFCB6B`, `#FFE3C2` |
| Chip corail clair | `#FFE3D6` |

Dégradés utilisés :
- CTA / barre de progression : `linear-gradient(90deg,#F4A722,#FF6A3D)`
- Fond chaud (capture succès, fonds de scène) : `radial-gradient(circle at 50% 30%, #FFD9A0, #FF8C4D)`
- Carte Fondateur : `linear-gradient(120deg,#2A1A0D,#5A3410)`
- Avatar : `radial-gradient(circle at 40% 35%,#FFC861,#FF6A3D)`
- Placeholder photo (vignette pinte), 3 teintes :
  - ambre `repeating-linear-gradient(45deg,#E9D8BC 0 16px,#F3E6CE 16px 32px)`
  - corail `repeating-linear-gradient(45deg,#F6D9BF 0 16px,#FCE7D4 16px 32px)`
  - ciel `repeating-linear-gradient(45deg,#CFE6F0 0 16px,#E1F0F7 16px 32px)`

### Typographie
- **Display / titres / chiffres** : **Bricolage Grotesque**, weights 700 & 800, letter-spacing −0.02 à −0.03em.
- **Corps / UI** : **Hanken Grotesk**, weights 400–700.
- Échelle (app) : compteur 66px/800 · titres d'écran 30px/800 · gros chiffres stat 26–30px/800 · corps 15–17px/500-700 · labels 11–13px/700 (uppercase, letter-spacing 0.1–0.18em).

### Rayons & ombres
- Frame téléphone : radius 56px ; écran : radius 44px.
- Cartes : 16–20px. Vignettes photo : 20px. Pills/chips : 100px (full round).
- Ombres : CTA corail `0 12px 26px rgba(255,106,61,0.34)` · bouton + flottant `0 10px 22px rgba(255,106,61,0.4)` · cartes `0 18px 44px rgba(42,18,6,0.10)`.

### Espacements
Padding d'écran : 20–24px horizontal. Gaps entre cartes : 10–12px. Marges entre items de fil : 20px.

---

## Screens / Views

L'app a **4 onglets** (Accueil, Fil, Villes, Profil) + **2 overlays plein écran** (Capture, Succès). Barre de navigation basse à 5 emplacements : Accueil · Fil · **(+) flottant** · Villes · Profil. Le bouton **+** central est un cercle corail surélevé (`translateY(-16px)`, 58px, `#FF6A3D`, texte « + » blanc).

### 1. Accueil
- **But** : voir la progression collective et ajouter une pinte.
- **Layout** : colonne, padding 24px.
  - Badge « EN DIRECT » : pastille rouge `#FF3B30` 11px (animation `pulse` 1.4s) + label corail uppercase 13px.
  - Sous-titre « Pintes bues par la communauté » (15px, `#9A865F`).
  - **Compteur** : `{totalStr}` en Bricolage 66px/800, encre. Formaté `fr-FR` (espaces fines comme séparateurs de milliers).
  - « / 1 000 000 — l'objectif » (17px/700, `#B89A6E`).
  - **Barre de progression** : hauteur 16px, rail `#ECDCBF`, remplissage dégradé ambre→corail, largeur = `total/1000000` en %.
  - Deux cartes stat (foam, radius 18) : `{myCount}` tes pintes (ambre) · `{streak} 🔥` jours d'affilée (corail).
  - Carte teaser ville (`#1AA3D6`, blanc) : « Ta ville cette semaine · 📍 Toulouse · 3ᵉ » + chevron `›`. **Tap → onglet Villes.**
  - **CTA** « 🍺 Ajoute ta pinte » (corail, radius 20) + sous-texte « +1 vers le million ». **Tap → overlay Capture.**

### 2. Fil
- **But** : voir toutes les pintes de la communauté, en direct ; réagir.
- **Layout** : header « Le fil » (30px/800) + chip total corail à droite. Liste verticale d'items.
- **Item de fil** :
  - Vignette photo : `width:100%`, `aspect-ratio:4/5`, radius 20, fond = dégradé rayé selon la teinte de l'item.
    - Chip ville en haut-gauche : fond `rgba(42,18,6,0.78)`, texte `#FFE3C2`, « 📍 {ville} ».
    - Numéro de pinte en bas-gauche : `#{num}` sur fond `rgba(255,251,242,0.82)`, Bricolage 20px/800.
  - Ligne sous la photo : avatar 38px (cercle couleur d'accent + initiale blanche) · nom (16px/700) + « vient de poser sa pinte » (13px, `#9A865F`) · **bouton like** (pill ♥ + compteur).
  - **Bouton like** : non-aimé = fond `#FFFBF2`, texte `#9A865F`, bordure `#ECDCBF` ; aimé = fond couleur d'accent, texte blanc. **Tap → toggle** (compteur ±1).

### 3. Villes (« La guerre des villes »)
- **But** : classement des villes, support de la compétition.
- **Layout** : titre 2 lignes 30px/800. Toggle **Aujourd'hui / Cette semaine** (2 pills ; actif = `#2A1A0D` blanc, inactif = foam). Liste de barres horizontales classées.
- **Ligne classement** : rang+médaille + nom + total à droite ; barre dessous (rail `#ECDCBF`, remplissage largeur proportionnelle). Top 3 colorés (ambre, orange, corail) ; au-delà en bleu ciel. La ville de l'utilisateur (Toulouse) porte un chip « ta ville » corail.
  - Données de réf. (semaine) : Toulouse 4 812 (100%), Lyon 4 530 (94%), Bordeaux 3 990 (83%), Lille 3 410 (71%), Rennes 2 875 (60%), Montpellier 2 240 (47%).
- Carte « ⚔️ Derby du week-end » (brun `#241308`, or) en bas.

### 4. Profil
- **But** : identité, fierté locale, accès monétisation.
- **Layout** : avatar 74px (dégradé) + nom 26px/800 + « 📍 Toulouse ». Rangée de 3 stats (pintes / jours / rang ville). Rangée de **badges** (cercles 56px colorés + « +8 »). **Carte Membre Fondateur N° 0457** (dégradé brun, or) — incarne la rareté. **Carte « Passer à Pinte+ » 2,99 €** (ambre).

### Overlay — Capture (plein écran, `#14110D`)
- Header : bouton ✕ (ferme) à gauche, « NOUVELLE PINTE » (or, uppercase) au centre.
- Centre : viseur 230×300, fond rayé sombre, **4 coins en équerre** or `#FFCB6B`, 🍺 au centre. Texte « Cadre ta pinte, puis appuie pour la valider. ».
- Bas : **déclencheur** = cercle blanc 84px (anneau `5px rgba(255,255,255,0.35)` + double box-shadow). **Tap → valide la pinte → overlay Succès.**

### Overlay — Succès (plein écran, radial sunset)
- 🍺 88px + « +1 » 62px/800 (animation `pop` 0.5s, en cascade). « Pinte n° {nextNum} validée ! » (24px/800). Message « Le compteur grimpe, et Toulouse gagne +1 dans la guerre des villes. »
- Bouton « Voir le fil » (brun, or) → ferme + onglet Fil. Lien « Continuer » → ferme (reste sur l'onglet courant).

---

## Interactions & Behavior
- **Navigation par onglets** : la barre basse change l'écran actif ; l'item actif passe en corail `#FF6A3D`, inactif `#B6A081`.
- **Compteur live** : un timer incrémente le total de **+1 à +3 toutes les 3,2 s** pour donner la sensation « temps réel » (à remplacer par un flux serveur réel en prod). Activable/désactivable.
- **Ajouter une pinte** : `+` (nav) ou CTA Accueil → Capture → déclencheur → le total **+1**, `myCount` **+1**, un nouvel item « Toi / Toulouse » (teinte corail) est **ajouté en tête du fil**, et l'écran Succès s'affiche avec le numéro de la nouvelle pinte.
- **Like** : toggle optimiste, compteur ±1, couleur d'accent.
- **Animations** : `pulse` (pastille live), `pop` (révélation succès), `shimmer` (déclaré, disponible pour skeletons). Transitions douces recommandées sur les changements d'onglet.

## State Management
État local (prototype — à remonter vers un store + backend en prod) :
- `tab` : `'accueil' | 'fil' | 'villes' | 'profil'`
- `total` : number (compteur mondial ; **source de vérité = serveur en prod**, push temps réel)
- `myCount` : number — pintes de l'utilisateur
- `streak` : number — jours consécutifs
- `sheet` : `null | 'capture' | 'success'`
- `nextNum` : string — numéro de la dernière pinte validée (formaté fr-FR)
- `feed` : `Array<{ id, name, city, num, tone:'amber'|'coral'|'sky', likes, liked }>`

Transitions clés : `confirmPhoto()` (total+1, myCount+1, prepend feed, sheet='success') · `toggleLike(id)` · `setTab(t)` · `openCapture()` / `closeSheet()` / `goFeed()`.

**Données à connecter (prod)** : compteur global temps réel (websocket/realtime DB), upload photo + modération/anti-triche, géoloc par ville déclarée, classements ville/région agrégés avec resets quotidien & hebdo (attention fuseaux horaires), profils + badges, achats in-app (Fondateur, Pinte+, cosmétiques).

## Assets
- **Polices** : Bricolage Grotesque & Hanken Grotesk (Google Fonts).
- **Icônes** : emoji système (🍺 🍻 🏠 🏆 👤 🔥 📍 ⚔️ ♥). En prod, remplacer par un set d'icônes cohérent du design system cible.
- **Images** : aucune réelle — les photos de pinte sont des **placeholders rayés**. À remplacer par les vraies photos uploadées par les utilisateurs.
- Aucune marque tierce : design original.

## Files
- `Pinte App Prototype.dc.html` — **prototype d'app interactif** (la référence hifi principale). Logique React dans la classe `Component` ; markup dans `<x-dc>`.
- `Le Million de Pintes.dc.html` — deck de concept (15 slides, pitch). Support narratif, pas une UI à livrer.
- `deck-stage.js`, `support.js` — runtime nécessaire pour afficher les `.dc.html` dans un navigateur (référence uniquement).
- `CONCEPT_SUMMARY.md` — résumé produit complet (à lire en premier).
