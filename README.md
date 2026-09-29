# Prototype pirate Roblox

Le dépôt contient le déplacement, un combo M1 de quatre coups avec dégâts côté serveur, un compteur de dégâts dans le HUD et un prototype du Haki de l’Observation.

## Tester dans Roblox Studio

1. Synchroniser la branche de test avec Rojo et lancer **Play** dans Studio. Un dummy R15 apparaît près du joueur, le suit et attaque quand il est assez proche. Il réapparaît après sa mort.
2. Se laisser approcher par le dummy : « F • ESQUIVE » apparaît avant l’impact. Un test avec deux joueurs reste aussi possible.
3. Appuyer sur F pendant l’affichage : le serveur annule le dégât, applique une esquive latérale et retire une charge.
4. Tester F trop tôt, trop tard, sans attaque et avec zéro charge : ces entrées ne doivent pas annuler les dégâts.
5. Attendre environ sept secondes pour récupérer une charge, puis tester le respawn.

L’Observation est activée automatiquement **uniquement dans Studio**. En jeu publié, `ObservationUnlocked` reste faux jusqu’à ce qu’une future quête l’attribue depuis le serveur. Ce déblocage n’est pas encore sauvegardé.

Le dummy existe uniquement dans Studio. Il n’utilise aucune animation M1 tant que les animations R15 du projet ne sont pas importées.

Les animations R15 `M1_1` à `M1_4` restent à sélectionner et importer dans `ReplicatedStorage.CombatAnimations`. Le code ne remplace pas une animation absente par un mouvement artificiel. Les candidats et précautions sont listés dans `ASSET_SOURCES.md`.
