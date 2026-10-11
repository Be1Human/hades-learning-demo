# Public demo media

Open [index.html](index.html) to view six game screenshots and two complete automated playthroughs. The game UI is shown in Simplified Chinese; this page uses English descriptions.

## Capture method

- Godot 4.7.2 renders the final Windows release PCK at 1440 × 900.
- The automated player sends real keyboard and mouse `InputEvent` events. Physics, enemy AI, damage, resources, boons, and death defiance remain active.
- The replay does not edit health, resources, or spawns, teleport actors, inject either ending, or invoke character action methods directly.
- Victory defeats nine enemies, including the boss. Defeat is caused by actual enemies after the automated player stops attacking.
- Both recordings return to the main menu, start a fresh run, and return from pause.
- Videos are H.264, 30 fps, and have no audio track. The victory clip lasts 47.93 seconds; the defeat clip lasts 43.50 seconds.
- The actual release executable was checked separately through its default entry. These replay recordings use the Godot engine with the release PCK because the release template does not execute the external capture script.

## Known visual limit

Victory results freeze the background immediately, so the last enemy's death animation can stop in a transitional pose. This playable prototype does not claim completed original-game visual fidelity.

## Public-file boundary

Only this directory's HTML, README, privacy-check JSON, six PNG images, and two MP4 videos belong to the public demonstration set. Links stay inside this directory. No remote embeds, analytics, cookies, or external scripts are used.

The original execution manifests and logs are excluded: they contain local machine paths and runtime metadata. Local settings and development conversations are also excluded. Media is captured directly from the game viewport, not the desktop.

See [privacy-check.json](privacy-check.json) for relative file names, hashes, dimensions, metadata checks, and local-link validation.
