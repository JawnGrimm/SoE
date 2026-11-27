# LimboAI setup (Godot 4.7.2)

Scribe of Eras uses the **LimboAI 1.8.1 GDExtension build**. The pinned `gdextension-4.6` release supports Godot 4.6 and newer, including the project's Godot 4.7.2 target. Do not install an engine-module build; that requires a custom Godot executable.

## Install on Windows

1. Close the Godot editor.
2. Open PowerShell in the Scribe of Eras repository root.
3. Run:

   ```powershell
   powershell -ExecutionPolicy Bypass -File .\tools\install_limboai.ps1
   ```

4. Reopen `project.godot` in Godot 4.7.2 and let the filesystem scan finish.

The installer downloads `limboai+v1.8.1.gdextension-4.6.zip`, verifies its SHA-256 checksum, locates `addons/limboai/bin/limboai.gdextension`, validates the Windows x86_64 editor library, and installs the package at `res://addons/limboai/`. If an existing `addons/limboai` folder is present, it is moved aside to a timestamped backup. If copying fails, the backup is restored.

## Important: GDExtension, not an editor plugin

LimboAI's GDExtension build does **not** use `plugin.cfg` and does not need to be enabled under Project Settings > Plugins. Godot discovers the `limboai.gdextension` descriptor and loads the matching native library. The descriptor references platform-specific libraries under `addons/limboai/bin/`.

`addons/limboai+v1.8.1.demo-project/` is the upstream demo project, retained as a reference/tutorial. It is separate from the installed plugin. Native binaries are intentionally not committed; the installer retrieves the pinned release and verifies it before use.

## Verify

After reopening the project, check the Godot Output/Debugger for GDExtension load errors. LimboAI's classes and behavior-tree resources should be available to the editor. If the extension fails to load, confirm `addons/limboai/bin/limboai.gdextension` and `addons/limboai/bin/liblimboai.windows.editor.x86_64.dll` exist and that the project is running a compatible 64-bit Godot 4.6+ build.

Upstream release: https://github.com/limbonaut/limboai/releases/tag/v1.8.1
