# Provenance des éléments visuels

## Intégrés dans Archipel 0.2

| Élément | Origine | Utilisation |
| --- | --- | --- |
| Îles, maisons, phares, quais, arbres, armes, bateaux et PNJ de dialogue | Géométrie originale produite par `Builders.lua` et `WorldService.lua` | Pièces Roblox natives, sans scripts de modèles tiers |
| Effets de coups, tirs, Haki et Braises | Code original du projet | Effets locaux ; le rempart physique est créé par le serveur |
| Rig des ennemis | API Roblox `Players:CreateHumanoidModelFromDescriptionAsync` | R15 ; rig R6 local de secours si la création échoue |
| Marche des ennemis R15 | Animation Roblox par défaut `rbxassetid://507777826` | Identifiant cité dans la [documentation officielle de l'éditeur de graphes](https://github.com/Roblox/creator-docs/blob/main/content/en-us/animation/graph-editor.md) ; disponibilité dans l'expérience à vérifier dans Studio |

Aucun pack d'animations de combat tiers n'est importé. Aucun mouvement de combat artificiel n'est appliqué aux Motor6D. Ceux du rig de secours servent uniquement à assembler le squelette.

## Animations de combat à sélectionner

Le client reconnaît des objets `Animation` dans `ReplicatedStorage.CombatAnimations` :

- `M1_1`, `M1_2`, `M1_3`, `M1_4` pour les poings ;
- `Sword_1`, `Sword_2`, `Sword_3`, `Sword_4` pour le sabre ;
- `Gun_1` pour le tir ;
- `ObservationDodgeRight` pour l'esquive actuelle.

La sélection doit se faire après visionnage sur un rig R15 et vérification des droits d'utilisation et des permissions de l'expérience. Importer uniquement les animations retenues, sans les scripts des packs. Tester leur durée par rapport au temps d'anticipation défini dans `Config.Styles`. Les anciennes pistes de packs gratuits étaient non vérifiées ; elles ne constituent pas des animations choisies ni une garantie de qualité.

Le projet vise un hommage avec ses propres îles et personnages. Il ne contient ni carte extraite d'un autre jeu, ni musique, modèle ou animation extrait de One Piece.
