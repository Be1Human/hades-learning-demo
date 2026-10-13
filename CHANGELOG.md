# Changelog

## 0.1.1 — 2026-10-13

- Replace the charging skull's primitive assembly with an authored Blender mesh:
  carved eye sockets and nasal cavity, cheek arches, 24 teeth, a hinged jaw,
  painted bone planes, sutures and ember eyes.
- Add hover, anticipation, charge, recovery, hurt and death poses driven by the
  existing gameplay state. Keep damage, attack timing and collision rules intact.
- Load the skull independently instead of retaining an invisible humanoid mesh.
- Add a focused regression suite and bilingual before/after comparison with a
  controlled native charge recording. Original-game visual fidelity is not claimed.

## 0.1.0 — 2026-10-12

- Publish the independently runnable three-room learning Demo.
- Connect main menu, settings, pause, dialogue, rewards, boons, results and retry.
- Integrate expanded hero actions, bloodstones, three combat families, mixed enemies,
  a four-pattern boss and one death-defiance charge.
- Localize the game interface into Simplified Chinese and add English documentation.
- Preserve actual input-driven victory/defeat demonstrations and disclose controlled tests.
- Fix dash input-buffer handling during a bloodstone cast.
- Add provenance, non-commercial terms, repository conventions and privacy checks.

Visual fidelity remains unfinished. The boss and witch use existing skeleton
variants, some enemy weapon/cloth intersections and foot sliding remain, and the
last defeated enemy's death animation can freeze during the victory transition.
Real After Effects source-library integration has not been verified.
