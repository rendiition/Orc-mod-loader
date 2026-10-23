# OrcKit

A mod loader for **Sir, We Have an Orc Problem**. OrcKit adds a **Mods** button to the game's main menu and lets you enable mods, manage load order, and configure participating mods in-game.

This fork builds on [Estonia's OrcKit](https://github.com/ESTONlA/Orc-mod-loader). See the [full changelog](CHANGES.md) for the fork's improvements.

[Installation](#installation) · [Using the menu](#using-the-menu) · [Save backups](#optional-save-backups) · [Development](#development) · [Full changelog](CHANGES.md)

## What's new in 1.2.0

| Improvement | What it does |
|---|---|
| **Automatic startup** | After a successful setup, unchanged enabled mod packages load directly on future launches without the startup menu or another restart. |
| **Close without restarting** | Dismiss the in-game Mods window with **X**, **Esc**, or **Back to Game**. |
| **Clear restart choices** | Changed loadouts offer **Restart now**, **Save for next launch**, or **Keep editing**. Pending changes remain visible when you reopen the menu. |
| **Dependency-aware loading** | Required mods must be enabled and compatible. Prerequisites load first; cycles and blocked dependencies prevent affected mods from loading. |
| **More reliable configuration and caches** | Configuration replacements retain verified backups. Cache checks account for package, loader, and game content changes. |
| **Improved discovery and browsing** | Discover scripts in embedded executable packs, see scan progress, reuse cached scan results, and filter the mod list without rebuilding it. |
| **A shared Settings tab** | View installation details, enable save backups or performance diagnostics, and adjust settings exposed by participating mods. |

See [CHANGES.md](CHANGES.md) for implementation details and limits.

## Installation

1. Close the game.
2. In Steam, right-click the game and select **Manage → Browse local files**. Use the folder containing the game's executable, such as `swhaop.exe`.
3. Copy [OrcLoader.gd](OrcLoader.gd) and [override.cfg](override.cfg) from the same OrcKit revision into that folder. When updating, keep a copy of your existing configuration and preserve any unrelated custom settings.
4. Create a folder named `mods` beside the executable if it does not already exist.
5. Place your mod packages in `mods`, launch the game, and select your loadout in OrcKit.

The resulting layout should look like this:

```text
Sir, We Have an Orc Problem/
├── swhaop.exe
├── OrcLoader.gd
├── override.cfg
└── mods/
    └── YourMod.vmz
```

OrcKit resolves the `mods` directory from the **running executable's location**. It does not target a fixed Steam drive or a separate playtest executable.

Supported packages are `.vmz`, `.zip`, and `.pck`. Loose mod folders are available through **Developer Mode**. Install one copy of each mod rather than both its archive and unpacked folder.

## Using the menu

Open **Mods** from the game's main menu to enable or disable mods, adjust load order, search installed mods, hide disabled entries, or open the mods folder.

While the game is running, **X**, **Esc**, or **Back to Game** closes an unchanged loadout immediately. With pending changes, closing offers these choices:

| Choice | Result |
|---|---|
| **Restart now** | Restart to apply the selected loadout. |
| **Save for next launch** | Return to the current session with its existing mods still running. |
| **Keep editing** | Stay in the Mods window. |

Changes are saved as you edit. Reopening the menu retains the restart reminder; reverting to the running loadout clears it. Search and display preferences do not require a restart. Closing the loader preserves the game's pause state.

The **first setup** still requires a launch choice and may restart once to prepare mods. Future launches automatically resume a verified, unchanged loadout. Changed packages or load order, game/loader updates, editable folder mods, or an invalid cache return to setup and may require another restart. Closing the in-game menu does not unload running mods.

Automatic startup is enabled by default. Turn off **Load saved mods automatically on startup** in Settings to show the manager each time. To request the manager for one launch, use `swhaop.exe -- --modloader-menu` (Steam launch options: `-- --modloader-menu`). You can always open **Mods** from the in-game menu.

### Load order and dependencies

Required dependencies load before the mods that use them. Among mods whose prerequisites are satisfied, higher priority values load later. Later resource overrides generally win when packages replace the same file; priority does not bypass dependency requirements or resolve every kind of conflict.

Missing, disabled, or incompatible prerequisites—and dependency cycles—block affected mods. Check the displayed warnings when a mod does not load.

## Optional save backups

Under **Settings**, enable **Back up saves before launching a changed mod loadout**. Before an explicit launch or restart with a changed loadout, OrcKit copies supported `.save` files and verifies their hashes. A detected backup failure cancels that launch. **Save for next launch** alone does not create a backup.

Snapshots are stored in `orckit_save_snapshots/<timestamp>/` inside the game's user-data directory (`user://` in Godot). Each snapshot includes a manifest. OrcKit never automatically restores or deletes these snapshots.

Backups cover `.save` files at the user-data root and directly inside numeric Steam-ID folders. Custom mod save locations are not included. See [coverage limits and restoration guidance](CHANGES.md#optional-save-snapshots).

## Compatibility and testing

OrcKit originated as a playtest loader. This fork has been tested on Windows with:

| Test environment | Result |
|---|---|
| Game build `2026.08.18.12.05`, native Godot `4.6.3-rc2` | **13 isolated in-game checks passed**, plus the two-pass restart flow. |
| Standalone Godot `4.7.2` | **52 regression checks passed**, including automatic-start validation and fallbacks. |

Additional native startup scenarios verify first setup, an unchanged launch, forced menu access, interrupted-start recovery, and changed enabled mods. See the [startup results](tests/VALIDATION.md#automatic-startup-validation).

Native tests used an isolated executable, disabled Steam integration, and redirected save storage. The test save's hash remained unchanged. Testing does not establish compatibility with every game build or third-party mod, and performance gains have not been benchmarked. See the [validation report](tests/VALIDATION.md), including native shutdown warnings and untested scenarios.

The **Settings** tab shows the detected game and engine versions, executable, mods directory, and script-discovery source. A compatibility-manifest fallback is identified explicitly; discovering scripts does not by itself establish compatibility.

## Troubleshooting

| Problem | Check |
|---|---|
| OrcKit does not appear | Confirm that `OrcLoader.gd` and `override.cfg` are beside the executable you launch. Check the autoload entry below. |
| A mod is absent from the list | Check the folder shown in Settings. Enable Developer Mode for loose folders. |
| A mod is blocked | Read its dependency or archive warnings. Required mods must be installed, enabled, and version-compatible. |
| Changes have not taken effect | Restart to apply the pending loadout. Saving for next launch leaves the current session unchanged. |
| An archive is rejected or a scan is incomplete | See the [scan limits](CHANGES.md#scanning-and-responsiveness). The scanner is not a sandbox or a guarantee that a mod is safe. |
| Settings cannot be saved | Check available disk space and write permissions. The menu reports the failure instead of silently dismissing. |

The loader's entry in `override.cfg` is:

```ini
[autoload]
OrcKit="*res://OrcLoader.gd"
```

Preserve other configuration you need when editing this file.

## Development

Start with the [upstream mod template](https://github.com/ESTONlA/modmenu) and [OrcKit wiki](https://github.com/ESTONlA/Orc-mod-loader/wiki).

Edit the modules in [`src/`](src/), then generate the combined loader using either command:

```sh
python build.py
# Or, with Bash:
bash build.sh
```

Both use the module order in `build.sh`. Keep the generated `OrcLoader.gd` and the distributed copy at `release/OrcKit/OrcLoader.gd` synchronized with source changes.

Run the isolated regression suite with Python and a Godot executable:

```sh
python tests/run_tests.py --godot /path/to/godot
```

Mods can expose live choice settings through `register_mod_setting()` and read saved values with `get_mod_setting()`. See the [shared settings API example](CHANGES.md#shared-mod-settings-api). Existing mods must opt in to appear in that panel.

## Credits and license

Created by **Estonia and contributors**. [Upstream repository](https://github.com/ESTONlA/Orc-mod-loader) · [This fork](https://github.com/rendiition/Orc-mod-loader).

Licensed under the **MIT License**. See [LICENSE.md](LICENSE.md) for the full terms.
