# Les Mers Libres — Archipel 0.2

Un prototype Roblox d'aventure pirate inspiré de l'esprit de One Piece : liberté, exploration, maîtrise des armes et force de la volonté. Les lieux, personnages, constructions et effets de cette version sont originaux. L'objectif est de permettre un parcours complet avec les poings, le sabre et le Haki, sans obligation de prendre un fruit.

Cette livraison relie le combat existant à quatre îles, des ennemis, des quêtes et une progression. Les contrôles automatisés ne remplacent pas un essai dans Roblox Studio ; le rendu, les sensations de combat et le multijoueur restent à valider dans le moteur.

## Lancer dans ton projet

1. Laisse l'ancien `auto-dev.bat` récupérer la mise à jour, puis ferme les deux fenêtres Auto Sync et Rojo. Relance `auto-dev.bat` depuis le dossier habituel.
2. Dans Studio, connecte le plugin Rojo au serveur local comme auparavant et accepte la synchronisation.
3. Lance **Play**. La carte est construite au démarrage du serveur : elle n'apparaît pas encore dans l'éditeur lorsque Play est arrêté.
4. Sur la place, parle à **Alma avec E** pour prendre la première quête. Les pillards sont au nord-est ; le dojo et son dummy se trouvent à l'ouest. Le passeur attend au bout de la jetée au sud.

Le script suit désormais la branche Git ouverte (`main` ou `feature/observation-qte`) et ne force aucune fusion. S'il signale des modifications locales ou une divergence, il garde les fichiers en place et affiche la cause.

## Le contenu

| Île | Accès par passeur | Rencontres | Quêtes et déblocages |
| --- | --- | --- | --- |
| Port Brise-Azur | Niveau 1 | 5 pillards, Brisecoque, dummy du dojo | Sabre puis Armement |
| Futaie des Épaves | Niveau 5 | 5 écumeurs, Gardien des racines | Pistolet puis Observation ; fruit facultatif auprès d'Ena |
| Citadelle Écarlate | Niveau 12 | 5 fusiliers, Commandant Varek | Briser le blocus, affronter le commandant |
| Crête du Tonnerre | Niveau 20 | 5 ronins, Amiral de la tempête | Ascension puis duel au sanctuaire |

- 24 ennemis actifs, dont 4 boss, plus un dummy qui poursuit et attaque dans le dojo. Les ennemis réapparaissent et peuvent contourner les obstacles par pathfinding.
- 8 quêtes répétables avec validation auprès du PNJ, XP, pièces, niveaux 1 à 30 et maîtrise des styles. Les récompenses sont calculées côté serveur.
- Poings : combo de quatre coups conservé, dégâts de base 5 / 5 / 6 / 9. Sabre : portée supérieure et attaque lourde. Pistolet : tir bloqué par les obstacles, six munitions, recharge.
- Observation : signal de réaction de 250 ms, trois charges, recharge de base de sept secondes. Essai limité au dojo avant son déblocage permanent par quête. La maîtrise peut réduire la recharge.
- Armement : concentration pour renforcer les dégâts, garde pour les réduire, consommation d'énergie continue. Il faut gérer la réserve.
- Fruit des Braises facultatif : **projectile, zone, rempart ou propulsion**. L'atelier règle puissance, taille et portée sur trois paliers, avec coût et statistiques prévisualisés. Une technique équipée à la fois.
- Carte, journal, barres de vie/XP/énergie, indicateurs de dégâts, styles et dialogues. PvP désactivé par défaut ; les deux joueurs doivent l'activer et quitter les zones d'arrivée protégées.

## Commandes PC

| Touche | Action |
| --- | --- |
| Clic gauche | Attaque du style équipé |
| R | Attaque lourde ; recharge avec le pistolet |
| 1 / 2 / 3 | Poings / sabre / pistolet, après déblocage |
| Maj gauche | Sprint |
| Q | Dash ; un dash aérien avant de toucher le sol |
| F au signal | Esquive d'Observation |
| H | Armement : concentration → garde → désactivé |
| E près d'un PNJ | Parler ou voyager |
| M / B / T | Carte / styles / atelier des techniques |
| Z | Technique du fruit équipée |

Des boutons tactiles de combat sont présents. L'ergonomie mobile complète et la navigation à la manette restent à travailler.

## Sauvegarde et limites de cette version

En **Studio**, la progression est volontairement limitée à la session et repart de zéro à chaque Play. Dans une expérience publiée, le serveur utilise `ArchipelagoProfiles_v1` avec acquisition de session, sauvegarde périodique et libération au départ. Si le chargement échoue, le HUD l'indique et cette session n'écrit pas de nouveau profil par-dessus la sauvegarde existante. Le service réel doit encore être testé sur une expérience de test publiée.

Les traversées utilisent pour l'instant le **passeur avec déplacement instantané**. Les voiliers sont décoratifs ; ni pilotage ni nage ne sont livrés. Une chute dans l'eau ramène au port avec perte de vie, plus importante avec un fruit.

Les attaques fonctionnent avec des effets visuels, mais les animations corporelles R15 de combat et les sons ne sont pas encore intégrés. Les points d'entrée pour de vraies animations sont conservés ; voir [ASSET_SOURCES.md](ASSET_SOURCES.md). Les boss partagent encore des patterns simples ; Haki des Rois, attaques avancées, autres fruits, équipages et navigation libre restent à développer.

## Vérification et reprise du développement

- [Scénarios de test Studio et contrôles automatisés](docs/TESTING.md)
- [État du projet et prochaines étapes](docs/PROJECT_STATE.md)

Les définitions d'îles, quêtes, ennemis et styles sont dans `src/shared/Config.lua`. La carte est dans `WorldService`, la progression dans `ProgressionService`, le combat dans `CombatService` et la sauvegarde dans `DataService`. Le client gère l'affichage et les entrées ; les récompenses, dégâts, coûts, munitions et déblocages sont validés par le serveur.
