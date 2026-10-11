# Playing Blade Trial

[Project overview](../../README.md) · [Building](BUILDING.md)

The game UI is Chinese. The English names below explain the current mechanics; they are not an English-language mode.

## Start the game

Extract a Windows release and double-click `HadesDemo.exe` in File Explorer. Its `HadesDemo.pck` must remain in the same directory. The public build helper writes these files under `build/`.

Use Windows x64 with a Vulkan-capable GPU. Chinese text requires an installed Microsoft YaHei or Noto Sans CJK SC system font. The game does not include a new embedded CJK font. Downloadable builds, when published, are listed in the repository's [Releases](https://github.com/Be1Human/hades-learning-demo/releases).

At the main menu choose **开始试炼** (Start Trial). **设置** opens settings, **操作说明** opens controls, and **退出游戏** exits.

## Controls

- **WASD:** move relative to the camera.
- **Mouse movement:** aim.
- **Left mouse button:** sword attacks and the three-hit combo. Attack during a dash to perform a dash strike.
- **Space:** dash and evade.
- **Right mouse button or Q:** nova area attack.
- **F:** cast a bloodstone in your aim direction.
- **1 / 2 / 3:** select Lightning / Deflect / Tide while in the entrance hall or a cleared room. This is unavailable during combat.
- **E:** interact when close to the gate or exit.
- **Esc:** pause or resume. The pause menu also provides settings, controls, restart, and return to the main menu.
- **Arrow keys, Tab, Enter:** navigate and confirm menu choices. Mouse selection also works.

Restart through the pause or result menu. The frontend suppresses the old standalone demo's R shortcut.

## Complete one run

1. **Entrance hall — 冥门前厅.** Move around and choose an effect family. Walk to the gate and press E. Continue or skip the short dialogue to enter the combat room.
2. **Twin-pit room — 双火池战斗厅.** Clear the first two waves. The enemy mix adds ranged and charging threats alongside melee brutes. Pits and architecture constrain movement and attack lines.
3. **Claim the reward.** After clearing the room, approach the exit and press E. Claim the gift, then select one numerical upgrade. You receive 50 run coins and healing. Coins are displayed in results; there is no shop in this demo.
4. **Colonnade — 守卫柱廊.** Complete the final wave, including the boss and supporting enemies. The boss uses telegraphed whip, rush, barrage, and blast patterns.
5. **Results.** Victory or final death leads to **再试一次** (Retry) or **返回主菜单** (Return to Main Menu). A new run resets upgrades, resources, and run statistics.

Returning to the main menu ends the current run. There is no saved-run continuation or permanent progression.

## Two separate upgrade systems

**Effect family** is selected with 1/2/3 in safe phases and modifies real combat behavior:

- **Lightning — 雷电:** chain lightning on hits, area lightning with nova, and a lightning strike on nearby enemies when dashing.
- **Deflect — 守护:** short projectile-reflection windows on attacks, nova, and dash. It is an active timing window, not permanent invulnerability.
- **Tide — 潮汐:** additional knockback. Armed targets that collide with solid walls can receive extra damage.

**The room reward** is a separate three-way numerical choice:

- **Keen Edge — 利刃:** weapon, dash-strike, and nova damage +30%.
- **Stalwart Heart — 坚毅之心:** maximum health +25, immediately restore 25 health.
- **Swift Step — 疾步:** dash cooldown -25%, from 0.62 to 0.465 seconds.

Every reward choice additionally restores up to 20 health, limited by maximum health. The selected reward carries into the final room and is cleared on restart. These are the demo's implemented values, not a claim that all original Hades boon rules are reproduced.

## Bloodstones and survival

You start with three bloodstones. A cast consumes a stone on release. A hit can embed it in an enemy; it later drops, or drops when its owner dies. Move close to a dropped stone to collect it; the resource returns when the pickup animation reaches you. Room loading replenishes the pool and clears old projectiles and stones.

Each run has one **death defiance — 死亡反抗**. The first lethal hit starts a revival sequence and restores half of maximum health. Once that charge is spent, another lethal hit leads to defeat. Dash has a short invulnerability window; damage, cooldowns, and collisions are active game rules.

## Settings and known presentation limits

Volume, mute, and fullscreen/windowed state save automatically. The game uses Godot's `user://frontend-settings.cfg`; the exact filesystem location follows the project's Godot user-data directory. Settings survive a restart, while the run itself does not.

Art and animation remain a work in progress. Witch and boss visuals are rig variants, held-club/hem intersections remain, and results can freeze a falling enemy before its death animation finishes. The [public overview](../../README.md) shows actual demo screenshots; functional verification does not imply visual-fidelity acceptance.
