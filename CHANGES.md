# OrcKit 1.2.0 — loadout workflow and reliability

## Automatic startup

After a loadout successfully completes setup, later launches automatically load its unchanged enabled archives without opening the startup manager or restarting the process. Existing file-scope mounting runs before game autoloads; the runtime validates the saved selection, dependency order, package hashes, executable/loader hashes, mounted archives, and cached hook pack before continuing. A successful-start receipt is written after the scene reload succeeds. The existing mod initialization path is reused.

First-time setup, changed loadouts or packages, game/loader updates, editable folder mods, and invalid or incomplete startup caches retain the setup flow. They may require a preparation restart. Safe mode is now checked before cached mods mount. Hook-pack hashes are checked before mounting, and mount order is compared in order rather than as an unordered set.

**Load saved mods automatically on startup** defaults to enabled in Settings. Disable it to keep the startup manager. The user argument `--modloader-menu` forces the manager for one launch; pass it after `--`. In-game access remains available through **Mods**.

The in-game Mods window now closes with its X, Escape, or Back to Game. If the selected loadout differs from the running one, closing offers Restart now, Save for next launch, or Keep editing. Saved changes remain pending across reopening. Reverting changes clears the warning; display preferences do not require a restart. The initial startup window still requires a launch choice.

Changes remain saved immediately, as in 1.1.0. Save for next launch does not unload or replace running mods. The loader does not change the game's pause state. Restart now passes through the existing suspicious-code confirmation.

## Reliability

- Enabled required dependencies must be present and version-compatible. A stable topological order puts prerequisites first, using priority/name as tie breakers among eligible mods. Cycles and their downstream dependents are blocked. A prerequisite that fails to mount prevents its dependents from loading.
- Configuration replacements retain a verified `.bak` file and replace the destination without first deleting it. UI save failures prevent dismissal and show an error.
- Script discovery supports a standalone pack and the executable's embedded PCK trailer. Settings displays the executable, engine/game versions, mods directory, and discovery source. Unknown layouts still use the compatibility manifest and identify that fallback explicitly; discovery is not a guarantee of game compatibility.
- Cache fingerprints include package content, resolved order, loader content, and executable content. Previous-session mounts validate fingerprints before reuse.
- Selected profile persistence is fixed.

## Scanning and responsiveness

- ZIP central-directory checks run before manifest parsing. Supported bounds are 32 MiB per entry, 256 MiB total unpacked size, and 10,000 entries. ZIP64, encrypted archives, duplicate entry names, and invalid directories are rejected. This is a compatibility limit, not a sandbox.
- Oversized text, unreadable files, and unsupported PCK scans report incomplete coverage. File scans use size checks before allocating where metadata is available.
- Security findings are cached as JSON by package SHA-256, loader version, and loader content hash. Folder mods are rescanned. Corrupt cache entries are ignored.
- Up to 16 MiB of archive bytes are reused between scanning and script analysis. Package fingerprints prevent stale path-only reuse.
- Discovery yields between entries and shows progress. A single package scan is still synchronous and can take time.
- Search and Hide disabled update existing row visibility instead of rebuilding the tab.
- Hook callback lists use copy-on-write registration. Dispatch retains snapshot semantics when a callback registers or unregisters another callback. Invalid callbacks are skipped; equal priorities use registration order.
- Script activation reuses its earlier inspection results. Optional diagnostics aggregate hook time and report scan/discovery time. No quantified performance gain is claimed.

## Optional save snapshots

Enable **Back up saves before launching a changed mod loadout** under Settings. Before an explicit launch/restart, the loader copies `.save` files at the user-data root and directly inside numeric Steam-ID directories. It verifies source and destination hashes and records a manifest. A backup failure cancels the requested launch. Save for next launch alone does not create a backup.

Backups are under `user://orckit_save_snapshots/<timestamp>/`. They are never automatically restored or deleted. Existing mods may already be running when the window opens: this is a recovery copy, not isolation from mod code. It does not cover arbitrary custom mod save locations or a concurrent write occurring after verification. To restore, close the game and copy the desired save back to its original relative location; account for Steam Cloud conflicts.

## Shared mod settings API

Mods can register choice settings for the Settings tab. Changes are saved first, then delivered to the registered callback; these settings apply live and do not request a loader restart.

```gdscript
var kit = Engine.get_meta("OrcmodLib")
kit.register_mod_setting("my_mod", "speed", "Default battle speed", [0.5, 1.0, 2.0, 3.0], 1.0, _on_speed_changed)
var speed = kit.get_mod_setting("my_mod", "speed", 1.0)
```

Registration validates the default and callback. Mods should validate saved values when reading them, and register settings before opening the menu. Existing mods are not modified automatically.

## Build and test

Run `python build.py` or `bash build.sh`. Both use the module order in `build.sh`; commit the regenerated `OrcLoader.gd` with source changes.

Run `python tests/run_tests.py --godot /path/to/godot`. The runner uses temporary project and user-data directories and does not require the game or Steam. It tests dependency order/blocking, configuration replacement failure, hook mutation, close/ESC/pending changes, profiles, ZIP bounds, embedded PCK discovery, scan caching, settings registration, and save snapshot copying.

Native-game validation is described in `tests/VALIDATION.md`. Game files and personal saves are not included in this repository.
