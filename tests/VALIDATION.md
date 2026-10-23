# Validation

Portable regression suite: **52 checks passed**, Godot 4.7.2 stable on Windows. No functional failures or script errors. The additional startup checks cover successful-start receipts, selection/content changes, incomplete mounts, editable folders, invalid hook caches, interrupted startup, the automatic-start preference, and mount-order changes.

The actual two-pass launch/restart also completed successfully in the isolated executable.

Native integration: **13 checks passed** using the installed game's engine, Godot 4.6.3-rc2, and game version 2026.08.18.12.05 in a separate workspace executable. Steam was disabled, APPDATA redirected, and a save copy used. Checks covered embedded-pack discovery, loading the existing speed mod, close without restart, real Escape input, pending changes across reopening, retaining running mods, pause state, and an unchanged save SHA-256.

The test executable's exit emits native GPU/resource cleanup warnings. These do not appear in the portable regression suite; they are not counted as successful checks or represented as fixed by this change.

The native runner is supplied as `native_runner.gd` for inspection. It is intentionally guarded to run only in the isolated `work/loader-integration-userdata` layout with Steam disabled. It must be packaged with legally available local game resources and the loader; it is not a mod for installation into the live game.

Not covered: a complete campaign, all third-party mods, every supported engine/OS, power-loss fault injection, or malicious-package fuzzing. Performance improvements have not been benchmarked across large mod collections.

## Automatic startup validation

The isolated native executable was launched repeatedly with the same enabled speed-mod package and persistent sandbox configuration. `startup_native_runner.gd` records process IDs, startup-menu presentations, whether the mod loaded, and the save hash. Observation files are cleared between scenarios; the executable and cache remain unchanged for the warm launch.

| Scenario | Processes | Startup menus | Result |
|---|---:|---:|---|
| First setup | 2 | 1 | One preparation restart; speed mod loaded. |
| Unchanged next launch | 1 | 0 | Speed mod loaded automatically, without restarting. |
| Explicit `--modloader-menu` | 1 | 1 | Manager opened on demand; no unnecessary restart. |
| Simulated interrupted-start marker | 2 | 1 | Recovery rebuilt the state; speed mod loaded. |
| Disable speed mod in saved settings | 2 | 2 | Changed selection used setup; speed mod absent in the final session. |

The sandbox save hash was unchanged in every scenario. The startup runner is guarded to the isolated `work/startup-integration-userdata` layout with Steam disabled. No game files, live save data, or repacked executables are distributed with the tests. These scenarios use an autoload-only mod; they do not establish startup compatibility for every script-rewriting mod.

