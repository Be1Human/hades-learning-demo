# Runtime architecture

[Project overview](../../README.md) · [Building](BUILDING.md)

The current playable entry is `project.godot` → `scenes/frontend/main.tscn`. The development workspace retains earlier standalone demos and material previews for comparison; the public snapshot focuses on runtime resources and selected documentation. A retained older scene should not be confused with the current game.

## Frontend and campaign layers

`scripts/frontend/app.gd` owns the active run, menu screen, focus, and persistent settings. It instantiates `scenes/frontend/run.tscn` on Start Trial and disposes of the old run on restart or return to menu. Its view is built by `scripts/frontend/view.gd` using the project's UI resources and system Chinese fonts.

The run's implementation is layered through GDScript inheritance:

```text
scenes/frontend/run.tscn
  scripts/ui_systems/campaign.gd
    scripts/gameplay/fx_campaign.gd
      scripts/integration/campaign.gd
        scripts/demo01/arena.gd
```

- **`ui_systems/campaign.gd`** adds gate dialogue, a claim-once room reward, run coins, and a frontend-aware HUD. It blocks gameplay during UI modals and emits pause requests to the app.
- **`gameplay/fx_campaign.gd`** adds effect families, expanded enemy types, bloodstones, projectiles, revival, and gameplay-owned FX events.
- **`integration/campaign.gd`** joins the three rooms, rebuilds room geometry/navigation/obstacles, manages gates and the three-way numerical boon choice, and preserves the chosen bonus between rooms.
- **`demo01/arena.gd`** provides the existing combat simulation, input setup, movement/attack queries, wave lifecycle, damage reporting, hit-stop, and shared presentation services.

Changes to a base layer can affect both the final run and retained standalone tests. Check the current entry and relevant inheritance chain before changing a method solely because an older preview uses it.

## Flow and clocks

The frontend moves among main menu, gameplay, pause, settings, controls, death presentation, and results. The run has phases such as entry, dialogue, intro, combat, intermission, cleared, reward, boon, reviving, victory, and defeat.

Dialogue, reward, and boon phases suspend combat rather than displaying an overlay above an active fight. Frontend pause also disables run processing and suspends its audio. Resume restores the intended prior modal state. Returning to the main menu frees the run and shuts down its audio, preventing old actors and sounds from persisting beneath the menu.

The project physics tick setting is 120 Hz. Several controlled tests manually advance an action clock at 60 Hz; their test invocation documents that timing. Rendering, combat hit-stop, audio playback, and UI state do not all use an interchangeable clock.

## Characters, damage, and animation

`scripts/gameplay/fighter.gd` extends `scripts/demo01/fighter.gd` with bloodstone cast timing and death defiance. The base fighter handles movement, combo buffering, dashes, active attack windows, hurt reactions, and collision-constrained displacement. `scripts/demo01/rules.gd` is the current sword tuning source; its values are authored demo values, not measurements certified against the original game.

`scripts/demo01/visual.gd` extends `scripts/actor_visual.gd`. It loads the authored GLB resource, maps clip names and contact timing through `assets/characters/demo01/animation-manifest.json`, and applies the painted-character material setup. The current hero has ten core actions plus four locomotion transitions; the base enemy has five clips. Animation playback is coordinated with the combat action clock rather than being used as a substitute for damage rules.

`scripts/gameplay/enemy.gd` implements brute, witch, skull, and boss behaviors. Available rigs are reused for some visual variants. `scripts/gameplay/missile.gd` handles actual projectile travel, collisions, reflection, and bloodstone impacts. Damage, stone consumption, pickup, and cooldowns occur in gameplay code; FX are consequences of those events.

The enemy's `_create_visual()` factory selects `scripts/gameplay/skull_visual.gd` for charging skulls. This visual loads `assets/characters/skull-r01/skull.glb` directly, without a hidden humanoid or weapon. Its jaw hinge, hover, charge anticipation, recoil and fall are mesh transforms driven by the enemy state and clock; they are not skeletal animation clips. `shaders/skull_bone.gdshader` combines authored vertex colors with room lights and hit flashes. The enemy still owns facing, collision, health and the 0.55-second charge windup.

## Effects and lighting

`scripts/integration/fx.gd` adapts the shared `scripts/combat_fx.gd` presentation to the current sword rules and emits committed-attack events. `scripts/fx_events.gd` provides the gameplay event interface. Owners and channels allow interruption, replacement, room cleanup, and lifetime management.

The selected family is separate from the numerical room boon. Lightning, deflect, and tide add different combat responses; the room reward changes damage, health, or dash recharge. The inheritance structure preserves both systems rather than replacing one with the other.

`scripts/environment/tartarus_lighting.gd` and the shaders in `shaders/` provide the current local illumination, distance falloff, painted shading, and actor readability. Source lights follow effect lifetimes and are subject to budgets. This is an approximation of colored local lighting, not a physically simulated full multi-bounce solution or a proof of original-game fidelity.

## Environment, UI, and audio resources

The three room builders live under `scripts/environment/`. The entrance and colonnade extend the same architectural vocabulary; the twin-pit room is the principal original-image comparison layout. Room loading clears combat transients, rebuilds obstacles, and updates camera/lighting state.

`scripts/integration/boon_menu.gd` adapts the earlier boon artwork assembly to the actual runtime choices and Chinese text. `scripts/ui_boon_r02.gd` remains a historical preview foundation. UI registries under `assets/ui/` select runtime images, cached SVG rerenders, and bundled Latin fonts. Chinese text uses an existing system font; no newly embedded CJK font is supplied.

`scripts/audio_bank.gd` loads `assets/audio/bank.json`, maintains bounded audio voices, selects variants, and manages category buses, suspension, ambience, and shutdown. Per-cue source records are in the bank and `assets/audio/sources.json`.

Settings use `user://frontend-settings.cfg`. They cover volume, mute, and window mode. There is no serialized run save or permanent progression state.

## Public export and evidence boundaries

The public `tools/build.ps1` helper resolves the engine from its `-Godot` argument, `GODOT_BIN`, or `PATH`. It supports `-TemplateDir` / `GODOT_TEMPLATES` for an optional matching template directory. Its **Windows** preset exports `build/HadesDemo.exe` and the adjacent PCK. Raw JSON/SVG resources needed by direct file reads must remain included alongside imported resources.

The development release workflow distinguishes source tests, controlled package-resource checks, natural native replays, and independent release-EXE startup. Full internal histories and private review records remain outside the public snapshot. The public validator and `tests/public_smoke.gd` provide portable entry points for checking the published source; native behavior still needs checking on the target machine.

The separate AE study is independent research and not a required part of the public runtime. Its self-authored diagnostic atlas is not connected to final combat, and its verified player interface does not establish that a real third-party AE library has been exported or integrated.
