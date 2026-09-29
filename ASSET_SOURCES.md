# Free asset shortlist for the project

Goal: keep the game pirate/anime themed, R15 compatible, and avoid ripped copyrighted assets.

## Combat animations (priority)

1. R15 Fighting Animations Pack Combo Moveset
   - Creator Store asset: 112293652257087
   - Free model
   - Intended use: M1 combo, melee stance, dodge candidates.

2. Combat Animations R15 Fighting Punch Kick
   - Creator Store asset: 72490332630186
   - Free model
   - Tags explicitly include dodge / evade / weave; useful for future Observation Haki QTE.

3. R15 Fighting Animations Pack Combo Punch Kick
   - Creator Store asset: 70925948463185
   - Free model
   - Backup candidate if the first two do not fit the style.

## Pirate / adventure identity

4. Pirate Animation Package
   - Creator Store asset: 8175508596
   - Free model, 27 animations.
   - Test rig compatibility before use; candidate for pirate idle/emotes/locomotion.

5. Sword Animations by Fancy Cat Games
   - Creator Store asset: 77935648543779
   - Free model, highly rated on the Creator Store.
   - Candidate for the future swordsman fighting style.

## VFX

6. slash effect
   - Creator Store asset: 9931893913
   - Free model, highly rated.

7. Aura Open Source Particle
   - Creator Store asset: 10205305332
   - Free to use / open source according to its listing.
   - Candidate for Haki aura prototypes.

8. VFX Studio plugin
   - Creator Store asset: 135581141962270
   - Free plugin, highly rated.
   - Use to inspect/adapt VFX instead of building every effect manually.

## Rules before importing any free model

- Prefer R15 assets.
- Inspect and remove every Script/LocalScript/ModuleScript that is not required.
- Never run external EXE "Roblox modpacks" or launchers.
- Avoid assets ripped directly from copyrighted games/anime.
- Import only the animation/VFX/model parts we actually need, not entire systems blindly.
- Keep damage, hitboxes, cooldowns and progression in our own server-authoritative code.

## Expected animation names in ReplicatedStorage.CombatAnimations

The current Combat client automatically uses Animation objects with these names when present:

- M1_1
- M1_2
- M1_3
- M1_4

Reserved for the future Observation Haki system:

- ObservationDodgeLeft
- ObservationDodgeRight

After testing a free pack, copy/rename only the selected Animation objects into ReplicatedStorage > CombatAnimations.
