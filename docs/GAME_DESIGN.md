# London Turf Wars: Design Brief

A multiplayer turf-war strategy shooter set in a stylized, fictional London.
Rival crews capture and hold districts on a map that works like a board game.
The tone is competitive and playful, with British humour.

## Art style (updated)
The game should **look realistic and high-spec**. This replaces the earlier "cartoonish, chunky" style.
- Use Future lighting, Atmosphere, PBR materials (SurfaceAppearance) and detailed models.
- Turn on StreamingEnabled and offer a graphics-quality fallback so it still runs on phones and low-end PCs.
- Realistic visuals do NOT relax the content rules: still no gore or blood, KO instead of death,
  and fictional weapon designs only (no real brands or models).
- Realistic weapons and violence can raise the content maturity label. Answer the questionnaire honestly.

## Working style
- The developer is a beginner at Roblox Studio and Luau. Explain things in plain English.
- Work in small steps and stop after each one for testing in Studio.
- Give exact Studio click-by-click instructions for anything built in Studio (the 3D map).
- Comment code so it teaches Luau.

## Content rules
- Follow Roblox Community Standards at all times.
- No gore, blood, dismemberment or realistic injury.
- Weapons are fictional designs (they may look realistic). No real gun brands or models.
- At 0 health a player is "knocked out" and respawns after a short delay. No graphic death animations.
- No real-world gang names, postcodes, symbols or references. All crews are fictional.
- No real transport logos (no Tube roundel). Use original names and colours.
- Fill in the content maturity questionnaire honestly when publishing.
- Include an easy way for players to report problems.

## Crews
Launch with 2 crews and expand to 4 later.
| Crew | Theme | Perk (~5%) |
|---|---|---|
| Mudlark Mob | river, wet-look gear, scavenger | +5% faster respawn |
| Black Cab Brawlers | taxi-yellow & black, fast | +5% move speed between districts (not in combat) |
| Barrow Boys | old-school market trader | +5% income from held districts |
| Tower Block Terrors | concrete grey & orange, high-rise | +5% cheaper defences |

Each crew has a colour, an outfit, one small perk, a hideout base and a spawn point.
Friendly fire is off. All perk values live in `src/shared/CrewConfig.luau`.

## Fairness (high priority)
- Same standard weapons, health and speed for every crew. Weapons differ by role, not by crew;
  crew signature weapons are sidegrades in the same class.
- One perk per crew, equal strength, each in a different area. All perks live in one config table.
- Symmetrical map: same number of starting districts, similar income, similar distance from the centre.
- Crew size is capped. New players join the smaller crew, and balancing also considers rank.
- Catch-up: losing crews get cheaper defences and faster respawns. Districts get easier to retake
  the longer one crew holds them.
- Weekly war resets everyone to an equal… *(brief was cut off here; to be completed)*

## Core loop additions (requested later)
- **PvP arena**: crews fight each other directly (friendly fire still off).
- **Jobs for money**: players earn cash by doing jobs such as **heists** and **missions**.
  Keep heists fictional, in the caper style of a heist film
  (e.g. "nick the Crown Jewels replica from a fictional museum"), with no realistic crime instructions.
  Payouts are equal for every crew. Only the Barrow Boys' +5% district-income perk differs,
  and it applies to district income, not job payouts.
