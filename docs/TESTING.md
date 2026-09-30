# Vérifier Archipel 0.2.1

## Contrôles hors Roblox

Depuis la racine du dépôt, avec les exécutables officiels [Luau](https://github.com/luau-lang/luau) et [Rojo](https://github.com/rojo-rbx/rojo) disponibles :

```sh
# Après une modification de Builders, WorldService ou des définitions de carte :
python tools/bake_world.py --luau /chemin/luau --rojo /chemin/rojo
python tools/check.py --luau /chemin/luau --compiler /chemin/luau-compile
python tools/preview_world.py --luau /chemin/luau --out /tmp/archipelago-world.json
python tools/check_place.py --rojo /chemin/rojo
git diff --check
```

`check.py` compile les scripts, teste XP, limites des recettes, prérequis, progression et attribution des quêtes. Il vérifie aussi les échecs du démarrage (module manquant, erreur de module, erreur de carte), le message répliqué et la reprise de l'apparition des personnages. Il teste les refus d'écriture de sauvegarde après échec de chargement ou perte de session. `preview_world.py` exécute le constructeur de la carte avec un hôte géométrique pour vérifier les quatre points d'arrivée et 24 positions d'ennemis. Il exporte des volumes, pas une capture Roblox ; son calcul de sol ne remplace pas la physique et le pathfinding du moteur.

`check_place.py` construit le vrai fichier Rojo puis vérifie les quatre îles, les pièces, la taille de l'océan, les points d'apparition, les interactions, la version du modèle et la présence et le contenu exact des 14 scripts/modules, notamment Config et Rules dans ArchipelagoShared. Il valide le fichier produit, sans lancer le moteur Roblox.

## Premier Play dans Studio — à effectuer

| Parcours | Résultat attendu |
| --- | --- |
| Synchroniser hors Play | `Workspace/Archipelago` contient quatre îles ; décor visible avant le lancement |
| Modules après synchronisation | `ReplicatedStorage/ArchipelagoShared` contient Config et Rules, tous deux ModuleScripts |
| Play, ouverture de Output | Aucune erreur ; arrivée à Port Brise-Azur, HUD lisible, quatre îles générées |
| Marcher sur la place, le quai, les marches et entrer dans une maison | Pas de blocage du personnage ni d'apparition dans un volume |
| Parler à Alma avec E, accepter la quête | Objectif 0/4, journal mis à jour |
| Vaincre quatre pillards, revenir à Alma, réclamer | Objectif suit les bonnes éliminations ; XP/pièces et sabre attribués une seule fois |
| Réclamer de nouveau sans nouvelle quête ; réclamer de loin | Aucune récompense supplémentaire |
| Refaire les quêtes pour atteindre le niveau 3, battre Brisecoque | Armement débloqué ; H alterne concentration/garde/arrêt et consomme l'énergie |
| Entrer au dojo et approcher le dummy | Le dummy poursuit et attaque ; il ne peut pas achever le joueur |
| F au signal, trop tôt, trop tard, puis à zéro charge | Seule l'entrée valide esquive ; charges limitées et recharge visible |
| Quitter le dojo avant la quête d'Observation | L'Observation d'entraînement n'est plus disponible |
| Mourir ou réinitialiser pendant une attaque/dash/recharge | Réapparition sur la dernière île, interface conservée, aucun ancien dash ou tir affectant le nouveau personnage |
| Atteindre niveau 5, aller au passeur, rejoindre la Futaie | Arrivée sûre ; traversées supérieures refusées sous le niveau requis |
| Finir la quête des écumeurs, équiper 3, tirer et recharger | Six tirs puis recharge, obstacle solide bloquant les tirs, dégâts attribués par le serveur |
| Finir la quête du Gardien | Observation permanente ; continuer sans fruit reste possible |
| Choisir les Braises auprès d'Ena, ouvrir T | Quatre formes, trois réglages ; coût/statistiques cohérents, recette enregistrée puis utilisée avec Z |
| Tester projectile, zone, rempart, propulsion | Effets cohérents, rempart bloquant les tirs, une seule propulsion aérienne avant retour au sol |
| Tomber à la mer avant/après acquisition du fruit | Retour au port ; pénalité de vie plus forte avec fruit |
| Continuer sur les deux dernières îles | Quêtes, morts et réapparitions des ennemis fonctionnent ; pas de blocage des boss dans le décor |

La progression Studio est remise à zéro à chaque nouvelle session. Pendant les essais, répéter les quêtes pour atteindre les paliers ; aucun bouton de récompense arbitraire n'est exposé au client.

## Multijoueur Studio — à effectuer

- Lancer un serveur et deux clients. Vérifier les effets chez les deux joueurs et l'absence de double récompense d'une même quête.
- Combattre le même ennemi : chaque contributeur actif et suffisamment proche reçoit l'XP après sa mort. Rester spectateur n'accorde rien.
- PvP désactivé par défaut, protégé aux arrivées. Avec PvP activé chez les deux joueurs hors zone sûre, vérifier dégâts, QTE et impossibilité de désactiver le PvP pendant le combat.
- Avec latence simulée, contrôler la fenêtre visible de 250 ms, la petite marge serveur et les avertissements d'attaques simultanées.
- Répéter acceptation et validation rapidement, changer de style pendant un coup, modifier la recette en vol : pas de récompense dupliquée, de tir gratuit ou de changement rétroactif des paramètres lancés.

## Sauvegarde réelle — à effectuer dans une expérience de test publiée

1. Gagner XP/pièces, valider un déblocage, enregistrer une technique et changer d'île. Quitter puis rejoindre : retrouver le profil.
2. Garder une partie ouverte plus d'une minute, puis tester l'arrêt du serveur et la reconnexion.
3. Vérifier le refus temporaire d'une session concurrente et la libération au départ.
4. Simuler une indisponibilité du stockage dans une copie de test : HUD explicite, aucune écriture d'un profil vide par-dessus le profil existant.

Ne pas activer de faux succès pour contourner un service indisponible. Studio reste isolé du stockage live même si son accès aux API est activé.
