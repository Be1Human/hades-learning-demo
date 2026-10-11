# Building and validating the public source

[Project overview](../../README.md) · [Architecture](ARCHITECTURE.md)

Run commands from this repository's root, the directory containing `project.godot`. The public repository is an independent game project.

The target toolchain is **Godot 4.7.2 for Windows x64**, using Forward+ / Vulkan and its matching Windows export template. During **v0.1.0** release preparation, this public snapshot completed a clean import and Windows export on the current Windows host. The public smoke checks passed 13/13 and combat checks passed 11/11, both at fixed 60 fps. This is a clean-source build on the same host, not validation on a separate new machine.

## Install the tools

- Install Godot **4.7.2**, preferably including its console executable for readable logs.
- Install the matching **4.7.2 export templates** through Godot, or obtain a matching `windows_release_x86_64.exe` for the optional directory override below.
- Use Windows x64 and a Vulkan-capable GPU for native rendering.
- Install Microsoft YaHei or Noto Sans CJK SC for the Chinese UI. No new CJK font is embedded in the package.
- Use PowerShell for the public Windows build helper and Python **3.10 or newer** for static repository validation.

Obtain the engine and templates from the official Godot distribution. Do not silently substitute another version and reuse results from the recorded version. The public source does not distribute a private `.tools/` directory or pre-populated `.godot/` import cache.

## Configure your installation

The build helper accepts `-Godot`, then `GODOT_BIN`, then the `godot` command on `PATH` as its engine location. Configure your installation without embedding a workstation path in the repository:

```powershell
$env:GODOT_BIN = Read-Host 'Full path to your Godot 4.7.2 console executable'
& $env:GODOT_BIN --version
```

If matching templates are installed in Godot's standard location, no template override is needed. Otherwise set a directory containing `windows_release_x86_64.exe`:

```powershell
$env:GODOT_TEMPLATES = Read-Host 'Directory containing the matching Windows export template'
```

`GODOT_TEMPLATES` is a directory used by this project's helper, not a claim that every Godot command reads that variable. Equivalent helper arguments are `-Godot` and `-TemplateDir`.

## Import and run source

Open the editor and allow resource import to finish:

```powershell
& $env:GODOT_BIN --editor --path .
```

Then launch the configured main scene:

```powershell
& $env:GODOT_BIN --path .
```

`project.godot` uses `res://scenes/frontend/main.tscn`, which provides the complete menu-to-run flow. It instantiates `scenes/frontend/run.tscn`. Historical standalone entry points, if retained, are not the current frontend.

Source execution requires the actual runtime images, GLBs, fonts, and audio files. A successful script parse alone does not prove those assets imported or rendered correctly. No paid generation or After Effects installation is required for the included game.

## Export Windows x64

Use the public helper:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/build.ps1
```

Or provide the installation explicitly:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/build.ps1 -Godot $env:GODOT_BIN -TemplateDir $env:GODOT_TEMPLATES
```

Omit `-TemplateDir` when using normally installed templates. The public preset is named **Windows** and outputs `build/HadesDemo.exe` and `build/HadesDemo.pck`. Both files are needed to play.

## Validate the checkout

Run the public static checks:

```powershell
python tools/validate_public_repo.py
```

This checks public links/resources, license records, and privacy constraints. Static checks do not run the game.

After imports complete, run both checks with the recorded timing:

```powershell
& $env:GODOT_BIN --headless --fixed-fps 60 --path . --script tests/public_smoke.gd
& $env:GODOT_BIN --headless --fixed-fps 60 --path . --script tests/combat_smoke.gd
```

Expected results for the recorded v0.1.0 source are **13 passed / 0 failed** and **11 passed / 0 failed**, respectively. Check each process's exit code and complete output, not only the final totals. `--fixed-fps 60` is part of the test conditions and keeps the run consistent with the controlled simulation checks.

To reproduce the clean-source check, use a fresh checkout without a copied `.godot/` cache or previous build outputs. Record `& $env:GODOT_BIN --version`, allow a fresh import, run the static validator and both commands above, then export with `tools/build.ps1`. Save the command output and results for that checkout. This procedure does not require deleting an existing working copy.

Start `build/HadesDemo.exe` independently from File Explorer and check the main menu, a new run, Chinese glyphs, sound, pause/resume, and return to menu. A headless pass does not establish GPU rendering, readable text, or audible output on a different machine.

Controlled branch tests and natural gameplay replays answer different questions. A controlled test can place the game in a state to cover a UI branch; a natural run uses input events and normal enemy AI. Package-resource checks with the matching editor engine are also distinct from launching the release EXE. Describe the method used rather than merging these into a stronger claim.

## Optional authoring tools

Blender and generation-service tooling are needed only to rebuild authored assets, not to use the included runtime GLBs. FFmpeg/FFprobe can encode and inspect new replay media; they are not runtime dependencies.

Follow [Asset provenance](ASSET_PROVENANCE.md), [LICENSE](../../LICENSE), and [NOTICE](../../NOTICE.md) when changing or redistributing content. The project is for non-commercial learning; third-party components retain their own terms.
