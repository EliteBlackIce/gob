# Goblin Delivery Co.

You are a goblin. Your boss doesn't care. The parcels are screaming. Deliver them anyway.

A slapstick delivery RPG for **Godot 4.4** (GL Compatibility renderer, pure GDScript).
Everything - models, terrain, textures, sounds, music - is generated procedurally, so the repo contains no binary assets.

## Run it

1. Install [Godot 4.4+](https://godotengine.org/download) (standard build, no .NET needed).
2. Open this folder as a project (or `godot --path .`) and press **F5**.

## Controls

| Key | Action |
| --- | --- |
| WASD / Mouse | Move / look (first person) |
| ESC | Game menu (resume, options, quit to title) |
| Space | Jump |
| **LMB** | Attack with your weapon (3-hit combo, the third hit is heavy) |
| **RMB** (hold) | Block. Tap it right before a hit lands to **parry** and stun the attacker |
| **Shift** | Dodge roll (invulnerable for a moment) |
| F | Kick |
| Q | Throw a bottle (AoE damage + stun) |
| R | Drink grog (heal) |
| Z | Holler (stuns and shoves everything near you, 18 s cooldown) |
| E | Interact: chests, shrines, doors, portals, shops, scrap |
| **V** | **Scan ping**: tags scrap, chests, shrines, exits and bosses through walls for a few seconds |
| Tab / I | Backpack, equipment, compare gear |
| G | Toss the parcel (island routes only) |
| C | Open your saved clips folder |

## The loop

1. **Pick a contract** on the board in the tavern: one safe island route, plus three **procedurally generated dungeons**
   (new layout, monsters, loot and modifiers every single time, five themes unlocked by beating bosses).
2. **Fight through the dungeon.** Rooms are random shapes (rect, cross, round, pillared, L), joined by corridors.
   Combat rooms lock their doors until every wave is dead. Along the way: treasure rooms (and mimics), shrines with
   blessings, campfires, a wandering peddler, spike-trap gauntlets, lava and poison pools, powder kegs, elites with
   affixes (Swift, Armored, Vampiric, Volatile, Flaming, Gigantic) and a fog-of-war minimap.
3. **Beat the boss, deliver the parcel.** Four bosses with phases and telegraphed attacks: **The Auditor** (crypt),
   **The Mimic King** (sewers), **The Landlord** (caves / ice), **The Overdue Dragon** (foundry; he can be talked down
   by handing him the parcel, because it was *his*). Take the stairs for deeper, harder floors, or portal home.
4. **Loot and level.** Gear comes in five rarities (Common, Uncommon, Rare, Epic, Legendary) with rolled affixes, funny names
   and 12 hand-made Legendary effects (shockwave swings, coin-burst kills, chain lightning, a haunted pigeon, a revive-once duck...).
   Seven weapon types swing differently (stab, slash, overhead, slam, ranged staples). XP gives levels, levels give skill points
   (6 branches, 23 skills).
5. **Spend it.** Gruk the blacksmith buys, sells and enhances (+5). Your stash lives by the fire. Ms. Deed sells six homes, from a
   Cardboard Box to **The Castle**, each with stash space, HP, grog and XP perks. Buying the Castle is the ending.
6. **Hit Grubnik's quota (friend-slop mode).** Dungeons are littered with goofy **scrap** (Rubber Ducks, Whoopee Cushions, Cursed
   Teapots, a Golden Toilet Brush...). Grab it with E, haul it home (a full sack slows you down), and sell it at the **Quota Desk**
   in the tavern. Grubnik wants a set amount of copper every four days; scrap counts 20% extra. Meet the quota for a bonus and a rare
   gear drop, miss it and he "adjusts" your wages. Die and the scrap from that trip is gone. Press **V** to scan for loot, and keep an
   eye out: the dungeon flickers, whispers and occasionally something tall stands at the edge of your torchlight. Don't stare.
   The whole game runs through a camcorder filter (chunky pixels, dither, REC tag) you can toggle in Options.
7. **Dying costs you.** The funeral is billed and the dungeon keeps whatever you looted that run. Gear you already own is safe.

The old island route is still there as a quick, parcel-in-arms delivery with crows, inspector slimes and the Customer Service Ogre.

## Viral moments

Big events (ogre launches, crow heists, potato detonations, perfect deliveries, deaths) fire a slow-mo
caption banner and **save a screenshot** to `user://clips/` (press **C** in game to open the folder).

## Project layout

```
scripts/rpg/      items (ItemDB loot generator, ItemModels voxel weapons/armour + icons), Stats
scripts/dungeon/  DungeonGen (pure-data layouts), DungeonBuilder (voxel meshes), Dungeon (the run), props, NPCs, scrap, ambience (spooky events)
scripts/mobs/     Mob AI, MobDB, MobModels, 4 bosses, training dummy
scripts/combat/   projectiles, FX, damage numbers, loot drops, scanner (V ping)
scripts/gfx/      atmosphere, camcorder filter layer
scripts/hud/      combat HUD (HP/XP/hotbar/boss bar/minimap)
scripts/          game.gd (state/skills/contracts/houses), player.gd, viewmodel.gd, tavern.gd, island.gd, ui.gd, menus.gd
tests/            rpg.gd, smoke.gd, flow.gd (headless), dshot.gd / shot.gd / gallery.gd (screenshots)
```

## Art pipeline (voxel / blocky, Minecraft Dungeons style)

Everything is built from coloured blocks in code - no imported models or textures:

```
shaders/voxel.gdshader       blocky surface: Lambert light, per-block colour jitter, pixel-grid texture noise, vertex alpha = glow
shaders/voxel_alpha.gdshader translucent version (slime jelly, glass)
shaders/water.gdshader       pixelated sea: depth-aware turquoise shallows, foam pixels, caustic sparkles, square sun glitter
scripts/vox/vox.gd           sparse voxel model + mesher: hidden faces culled, per-corner ambient occlusion baked into vertex colours
scripts/vox/terrain.gd       the island as half-metre block columns: height table, chunked meshes, HeightMap collider
scripts/vox/props.gd         palms, bushes, grass, rocks, barrels, crates, torches, lanterns, parcels, furniture
scripts/vox/creatures.gd     crow, slime (translucent cube), ogre
scripts/vox/buildings.gd     tavern inn, hut, lighthouse, tavern interior shell
scripts/goblin_model.gd      the goblin (reference-style: big eyes, fangs, tongue, vest, backpack) with a procedural rig
scripts/viewmodel.gd         first-person arms, carried parcel, bottle throw, kick boot
scripts/gfx/atmos.gd         sky, sun, fog, bloom, floating light motes; Forward+ GI (see below)
```

**About the "ray traced" look.** Godot has no hardware ray tracing. On the **Forward+** renderer (Vulkan, the
project default) the game turns on its closest equivalents: SDFGI (real-time bounced light), SSAO + SSIL and
volumetric fog (sun shafts). Machines without Vulkan fall back automatically to the Compatibility renderer, where
baked per-block ambient occlusion, hard sun shadows, bloom and fog carry the look instead.

## Asset sheets

`art/` has screenshots rendered from the engine: `dungeon_*` (combat, loot beams, HUD), `mobs_g*`, `boss_*`, `weapons.png`,
`ui_*` (inventory, shop, contracts, skills) and `tavern_*` (`tests/dshot.tscn`). `art/01..07` are the older contact sheets.

## Tests

```bash
# headless gameplay smoke test + end-to-end scene flow
godot --headless --fixed-fps 60 --path . res://tests/rpg.tscn    # loot, stats, 120 random dungeons, every mob, boss and room type
godot --headless --fixed-fps 60 --path . res://tests/smoke.tscn
godot --headless --fixed-fps 60 --path . res://tests/flow.tscn

# render a scenario to PNG (needs a display, e.g. xvfb-run)
xvfb-run -a godot --path . --rendering-driver opengl3 res://tests/shot.tscn -- island_wide out.png
```

## Look and feel

* **Minecraft-menu UI**: a fully procedural bitmap pixel font (`scripts/pixel_font.gd`), stone-grey bevelled buttons and panels, a dirt-tile
  backdrop, a title screen with a logo and yellow splash text over a slow pan of the tavern, a Game Menu, and an Options screen
  (master / music / SFX volume, FOV, mouse sensitivity, camcorder filter; saved to `user://settings.json`).
* **Minecraft HUD**: ten hearts, an XP bar and numbered hotbar slots with cooldown fills.
* **Block textures** are flat colours with a one-texel bevel (like a stone-brick block) instead of fine noise.
* Hits flash the screen and freeze the game for a few frames; footsteps, dust puffs and damage flashes round out the feedback.

## Roadmap

* Co-op (2-4 goblins in one dungeon): the player, mob and dungeon scripts are separated so networking can be layered on with `MultiplayerSynchronizer`.
* More themes, bosses, secret rooms and legendary effects.
