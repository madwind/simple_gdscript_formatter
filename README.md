# simple_gdscript_formatter

### Format GDScript and shaders (`Ctrl + Alt + L`)
*no Python dependencies*  
Formats GDScript using a lossless lexer, concrete syntax tree (CST), and a
structured layout printer. Implemented entirely in GDScript, with no runtime
dependencies.

Godot shader files (`.gdshader`) are also supported by a separate formatter.

Formatting sorts declarations into the configured Godot-style member order by
default, while preserving strings, comments, and declaration-associated
annotations. Set `simple_gdscript_formatter/organize_members` to `false` in
Project Settings to preserve the original declaration order. It supports
nested classes, lambdas, match branches, annotations, typed collections, and
multiline expressions. Formatting is deterministic and idempotent. Editor
Tab/space indentation preferences remain supported.

Member organization can change the order in which member initializers run. Set
the option to `false` for scripts that depend on the original initialization
order.

### Open in External Editor (`Ctrl + E`)
*Bypasses the "Use External Editor" setting*  
Opens the current file in your configured external editor (Rider/VS Code/etc.) without enabling `text_editor/external/use_external_editor` in Godot settings.
