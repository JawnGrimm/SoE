# LimboAI setup (Godot 4.7.2)

Scribe of Eras uses the **LimboAI 1.8.1 GDExtension build**. Do not install the Godot engine-module build: that requires a custom Godot executable. The GDExtension release supports Godot 4.6 and newer, which includes the project's Godot 4.7.2 target.

## Install on Windows

1. Close the Godot editor.
2. Open PowerShell in the Scribe of Eras repository root.
3. Run:

   ```powershell
   powershell -ExecutionPolicy Bypass -File .\tools\install_limboai.ps1
   ```

4. Reopen `project.godot` in Godot 4.7.2 and let the filesystem scan finish.

The installer downloads the pinned upstream release, verifies its SHA-256 checksum, installs the `addons/limboai` plugin folder, and enables it in the project's `[editor_plugins]` settings. If an `addons/limboai` folder already exists, it is moved aside to a timestamped backup before installation.

## What is in the repository

`addons/limboai+v1.8.1.demo-project/` is the upstream demo project, retained as a reference/tutorial. It is **not** the installed plugin. The actual plugin and native GDExtension libraries are installed separately by the script. Native binaries are intentionally not committed to this repository; the installer retrieves the pinned release and verifies it before use.

## Verify

In Godot, open **Project > Project Settings > Plugins** and confirm **LimboAI** is enabled. The LimboAI behavior-tree editor tools should then be available in the editor. If Godot reports that the GDExtension cannot be loaded, check that the downloaded build matches the host platform and that the project is running Godot 4.6 or newer.

Upstream release: https://github.com/limbonaut/limboai/releases/tag/v1.8.1
