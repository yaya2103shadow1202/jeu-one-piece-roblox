# État du projet — 29 septembre 2026

## Direction retenue

Construire un jeu Roblox d'aventure pirate inspiré de One Piece, avec une progression sérieuse sans fruit, un Haki exigeant, des armes distinctes et des fruits dont le joueur compose les techniques. Priorité à une boucle jouable, puis aux sensations et à la qualité visuelle.

## Livré dans le code

Archipel 0.2 relie quatre îles originales aux combats et aux huit quêtes. Il ajoute 24 ennemis dont quatre boss, un dummy d'entraînement, niveaux/XP/pièces, maîtrise, deux Hakis, trois styles de combat, un premier fruit configurable, interface et sauvegarde serveur. La progression part des pillards du port et va jusqu'à l'Amiral de la tempête. Les styles sans fruit gardent accès à toutes les quêtes.

Les déplacements conservés : caméra classique à distance 7–26, marche 16, sprint 25, dash au sol 70 et aérien 62, combo poings de quatre coups. Aucun remplacement par des poses corporelles bricolées. Les animations de combat restent à importer après sélection.

Le précédent dépôt ne contenait pas de service d'XP persistant identifiable. Cette version met en place un profil versionné ; aucune migration d'un autre système d'XP non fourni n'a été inventée.

## Vérifié / restant à vérifier

Les tests CLI exécutent les règles pures, les vrais gestionnaires de quêtes et de sauvegarde dans des hôtes de test, et le constructeur de carte dans un hôte géométrique. La compilation Luau et la construction Rojo sont vérifiées. Ces contrôles n'exécutent ni la physique, ni la réplication, ni le rendu Roblox.

Il reste à lancer les scénarios de [TESTING.md](TESTING.md) dans Studio, puis à tester la sauvegarde dans une expérience publiée de test. Ne pas annoncer le jeu comme testé dans Studio avant cet essai.

## Prochain travail concret

1. Corriger les retours du premier Play : apparition, trajet Alma → pillards → dojo → boss, erreurs Output, collisions des quais et des îles.
2. Sélectionner et intégrer de vraies animations R15 de poings, sabre, tir et esquive, puis ajuster anticipation, impact et enchaînements. Donner aux boss des attaques lisibles et distinctes.
3. Remplacer les traversées instantanées par de vrais bateaux pilotables et développer la nage, avec faiblesse des utilisateurs de fruit.
4. Étendre Haki et armes : parades, précision, maîtrise, spécialisation et contre-jeu. Équilibrer le parcours sans fruit par des parties réelles.
5. Développer plusieurs emplacements de techniques, de nouvelles interactions de fruit, effets et sons. L'atelier actuel compose une forme et trois paramètres ; ce n'est pas encore un éditeur libre de mécaniques.
6. Enrichir les quêtes au-delà de l'élimination, la vie des villages, l'exploration et les récompenses. Les pièces s'accumulent mais aucun magasin n'est livré.

## Synchronisation

Le dépôt est `yaya2103shadow1202/jeu-one-piece-roblox`. `auto-dev.bat` sert Rojo et suit la branche locale ouverte, avec fusion en avance rapide uniquement. La carte est générée au lancement du serveur. Les fichiers du dépôt sont la source du code ; ne pas annoncer une modification de la session Studio du joueur sans l'avoir observée.
