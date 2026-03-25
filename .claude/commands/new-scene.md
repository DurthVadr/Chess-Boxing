Create a new game scene with boilerplate.

## Instructions

1. Ask the user what the scene is for if not provided
2. Create a new folder under `scenes/` with a descriptive snake_case name
3. Create the `.gd` script file with:
   - `extends` matching the root node type (usually Control for UI scenes, Node2D for gameplay)
   - Standard `@onready` references using `%NodeName` syntax
   - `_ready()` function
   - Connection to GameManager where appropriate
4. Create a minimal `.tscn` file or instruct the user to create it in the Godot editor (prefer the latter since .tscn files are complex)
5. If this scene is part of the game flow, update `scripts/autoload/game_manager.gd` to add a phase transition for it
6. Follow the project's dark jewel-tone art style conventions from CLAUDE.md

## Argument
$ARGUMENTS — Optional: scene name and purpose, e.g. "settings_menu: pause menu with volume and display options"
