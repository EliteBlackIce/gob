# Goblin Delivery Co.

You are a goblin. Your boss doesn't care. The parcels are screaming. Deliver them anyway.

A slapstick delivery RPG for **Godot 4.4** (GL Compatibility renderer, pure GDScript).
Everything - models, terrain, sounds, music - is generated procedurally, so the repo contains no binary assets.

## Run it

1. Install [Godot 4.4+](https://godotengine.org/download) (standard build, no .NET needed).
2. Open this folder as a project (or `godot --path .`) and press **F5**.

## Controls

| Key | Action |
| --- | --- |
| WASD | Move |
| Mouse | Look (ESC releases the mouse) |
| Space | Jump (don't, if you're carrying glass) |
| E | Interact / stamp during an inspection |
| LMB | Throw a bottle (everyone starts with 3) |
| F | Kick (knocks crows out of the sky, stuns slimes) |
| G | Toss the parcel a few metres - crows and slimes only want a *carried* parcel |
| Shift | Panic Dash *(learned in the cellar)* |
| Q (hold) | Parcel Slap *(learned in the cellar)* |
| C | Open your saved clips folder |

## The loop

A built-in tutorial walks you through it: gold arrows in the tavern point at your next objective
(blue = you have skill points to spend), and short hints pop up the first time something matters
(your parcel's quirk, crows, inspectors, the ogre, the sea, the mailbox).

* **The tavern is the post office.** Browse the job board, read Grubnik's letter, buy grog from Brin, then head out the front door.
* **Parcels have personalities.** A Screaming Cheese attracts crows, a Hot Potato (Literal) explodes unless cooled in seawater, a Wiggly Crate runs away, Grandma's Vase breaks if you jump, the Anvil slows you down.
* **The island fights back.**
  * **Crows** steal the parcel and eat it at their nest. Bottles and boots bring them down.
  * **Inspector Slimes** demand a stamp (timing minigame). Fail and they wear your parcel as a hat.
  * **The Customer Service Ogre** guards the gorge. Answer his riddle, or be *returned to sender* at speed.
  * The sea is not a road.
* **Skill tree (the cellar):** Courier, Scrapper, Fixer and Pack Rat - 12 skills that change how you play.
* **Grubnik's daily mandate** changes the rules: double pay (and double funerals), no dashing, heavier parcels, shorter deadlines.
* **Dying is part of the job.** You go on the Wall of Shame and the funeral is deducted from your pay.

## Viral moments

Big events (ogre launches, crow heists, potato detonations, perfect deliveries, deaths) fire a slow-mo
caption banner and **save a screenshot** to `user://clips/` (press **C** in game to open the folder).

## Project layout

```
scripts/   game code (game.gd = state/skills/jobs, island.gd = a run, tavern.gd = hub, ui.gd = all 2D)
shaders/   stylized.gdshader (painterly flat-facet look), water.gdshader
scenes/    main.tscn
tests/     smoke.gd, flow.gd (headless), shot.gd (screenshot tool)
```

## Asset sheets

`art/` has labelled contact sheets of every asset (goblins & creatures, parcels, props, island, tavern, UI, sound waveforms),
rendered straight from the engine with `tests/gallery.tscn` (modes: `studio`, `island`, `tavern`, `ui`, `audio`).

## Tests

```bash
# headless gameplay smoke test + end-to-end scene flow
godot --headless --fixed-fps 60 --path . res://tests/smoke.tscn
godot --headless --fixed-fps 60 --path . res://tests/flow.tscn

# render a scenario to PNG (needs a display, e.g. xvfb-run)
xvfb-run -a godot --path . --rendering-driver opengl3 res://tests/shot.tscn -- island_wide out.png
```

## Feel

Hits flash the screen and freeze the game for a few frames; footsteps, dust puffs, an ocean ambience loop
and a damage flash round out the feedback. Press ESC to release the mouse (a "PAUSED" banner shows).

## Roadmap

* Co-op (2-4 goblins carrying parcels together) - the player, parcel and enemy scripts are already separated so networking can be layered on with `MultiplayerSynchronizer`.
* More routes, parcels and enemies (toll trolls, mail-thief crows with nests you can raid).
* Tavern upgrades paid for with copper.
