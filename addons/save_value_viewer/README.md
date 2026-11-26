# Save Value Viewer

Read-only viewer for Godot `ConfigFile` and JSON save files. Lists every value, filters, and
copies. It never writes to the file.

- License: MIT (see `LICENSE.md` in this folder, and the repository root)
- Repository: https://github.com/onpont/save-value-viewer
- Tested with Godot 4.4.1, 4.5.2, 4.6.3 and 4.7.2 on Windows 11 (Godot 4.4 or newer).

Enable the plugin in **Project → Project Settings → Plugins**, then open the **Value Viewer** tab
in the editor's main screen.

- A file named `.cfg`, `.ini` or `.json` is read as that format. A file whose name says nothing —
  a `save_data.sav`, a `.dat`, a file with no extension — is read by its content: JSON when the
  whole file parses as JSON, otherwise as a Godot ConfigFile. The status line says which reader
  was used.
- Sample files to try it on: `examples/settings.cfg` and `examples/progress.json`
  in this folder (open them with Open file…). The panel never writes to them,
  and deleting this `examples` folder does not affect the add-on.
