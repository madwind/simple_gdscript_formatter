# simple_gdscript_formatter

### Format GDScript (`Ctrl + Alt + L`)
*no Python dependencies*  
Formats GDScript using a lossless lexer, concrete syntax tree (CST), and a
structured layout printer. Implemented entirely in GDScript, with no runtime
dependencies. Tested with Godot 4.6.

Normal formatting preserves declaration order, strings, and comment text. It
supports nested classes, lambdas, match branches, annotations, typed collections,
and multiline expressions. Formatting is deterministic and idempotent. Editor
Tab/space indentation preferences remain supported.

### Open in External Editor (`Ctrl + E`)
*Bypasses the "Use External Editor" setting*  
Opens the current file in your configured external editor (Rider/VS Code/etc.) without enabling `text_editor/external/use_external_editor` in Godot settings.

### Source API

```gdscript
const Formatter = preload("res://addons/simple_gdscript_formatter/formatter.gd")

var formatted := Formatter.new().format_source(source)
# Optional indentation text and target line width (defaults: tabs, 100 columns).
var with_spaces := Formatter.new().format_source(source, "    ", 100)
```

The source API also works headlessly, without a `CodeEdit` or editor settings.
Line breaks use LF; line endings inside literals are preserved verbatim. Existing
multiline groups remain multiline. The target width breaks groups where syntax
allows it; it does not split strings, comments, or unparenthesized expressions.
Detected lexical errors or unmatched delimiters leave the source unchanged.

Member organization is a separate, explicit transformation:

```gdscript
const Organizer = preload("res://addons/simple_gdscript_formatter/transform/member_organizer.gd")

var organized := Organizer.new().organize(source)
```

Organization can change member initialization order. Documentation and annotations
move with their declarations, and standalone comment blocks act as ordering
barriers. The normal formatter never invokes the organizer.

### Implementation

```text
Source -> Lexer -> TokenStream -> CST Parser -> CST Formatter -> Doc -> Printer
```

`syntax/` owns tokenization, recursive descent for declarations and statements,
and Pratt parsing for expressions. Token offsets and line/column positions are
zero-based Unicode code-point indices; all ranges have exclusive ends. CST nodes
reference the original token stream, including trivia. Parsing is syntax-only.

`format/` turns CST structure into `Text`, `Line`, `SoftLine`, `Concat`, `Indent`,
and `Group` documents. The printer handles layout only. There is no placeholder
extraction, syntax regex, AST, semantic analysis, or legacy formatting pipeline.

### Tests

Run from the project root:

```sh
godot --headless --path . --script test/run_tests.gd
```

The suite checks lossless tokens and positions, declaration/comment attachment,
statement and expression structure, layout, editor indentation, and idempotence.
It formats every addon script and compiles the results with Godot. Runtime tests
compare original and formatted initializer order, lambdas, properties, match
branches, collections, and operator behavior with several indentation settings.

`test/test.gd` is the input fixture and `test/result.gd` is its expected output.
To deliberately regenerate that expected output after a formatting change:

```sh
godot --headless --path . --script test/run_tests.gd -- --update-golden
```
