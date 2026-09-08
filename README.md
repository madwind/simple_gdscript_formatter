# simple_gdscript_formatter

### Format GDScript and shaders (`Ctrl + Alt + L`)
*no Python dependencies*  
Formats GDScript using a lossless lexer, concrete syntax tree (CST), and a
structured layout printer. Implemented entirely in GDScript, with no runtime
dependencies. Tested with Godot 4.6.

Godot shader files (`.gdshader`) are also supported by a separate formatter.

Normal formatting preserves declaration order, strings, and comment text. It
supports nested classes, lambdas, match branches, annotations, typed collections,
and multiline expressions. Formatting is deterministic and idempotent. Editor
Tab/space indentation preferences remain supported.

### Open in External Editor (`Ctrl + E`)
*Bypasses the "Use External Editor" setting*  
Opens the current file in your configured external editor (Rider/VS Code/etc.) without enabling `text_editor/external/use_external_editor` in Godot settings.
