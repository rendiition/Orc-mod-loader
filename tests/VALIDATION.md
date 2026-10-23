# Validation

Portable regression suite: **41 checks passed**, Godot 4.7.2 stable on Windows. No functional failures or script errors.

The actual two-pass launch/restart also completed successfully in the isolated executable.

Native integration: **13 checks passed** using the installed game's engine, Godot 4.6.3-rc2, and game version 2026.08.18.12.05 in a separate workspace executable. Steam was disabled, APPDATA redirected, and a save copy used. Checks covered embedded-pack discovery, loading the existing speed mod, close without restart, real Escape input, pending changes across reopening, retaining running mods, pause state, and an unchanged save SHA-256.

The test executable's exit emits native GPU/resource cleanup warnings. These do not appear in the portable regression suite; they are not counted as successful checks or represented as fixed by this change.

The native runner is supplied as `native_runner.gd` for inspection. It is intentionally guarded to run only in the isolated `work/loader-integration-userdata` layout with Steam disabled. It must be packaged with legally available local game resources and the loader; it is not a mod for installation into the live game.

Not covered: a complete campaign, all third-party mods, every supported engine/OS, power-loss fault injection, or malicious-package fuzzing. Performance improvements have not been benchmarked across large mod collections.

