# Chess Boxing Roguelike — Copilot Instructions

A roguelike tournament game alternating between chess puzzles and turn-based boxing, built in Godot 4.6 (GDScript).

## Commands

```bash
# Run the game
godot --path . scenes/main_menu/main_menu.tscn

# Validate scenes (headless CI check)
godot --path . --headless --quit

# Lint GDScript (requires: pip3 install gdtoolkit)
gdlint scripts/ scenes/

# Format GDScript
gdformat scripts/ scenes/
```

## Architecture

### Autoloads (Global Singletons)
Defined in `project.godot` under `[autoload]`:
- **GameManager** — All run state (fighter, HP, perks, opponent index), phase transitions via `change_phase()`
- **AudioManager** — SFX playback
- **MusicManager** — Background music with intensity shifting
- **SaveManager** — Persistence (meta progression)

### Game Flow
```
Main Menu → Fighter Select → Tournament Bracket → Opponent Reveal
→ Chess Puzzle → Boxing Round → (repeat) → Perk Draft/Shop → next opponent → Results
```

Phase transitions happen through `GameManager.change_phase(GamePhase.X)` which calls `change_scene_to_file()`.

### Scene Organization
Each screen lives in its own folder under `scenes/` with both `.tscn` and `.gd` files:
```
scenes/
  main_menu/main_menu.tscn + main_menu.gd
  chess_phase/chess_phase.tscn + chess_phase.gd
  boxing_phase/boxing_phase.tscn + boxing_phase.gd
  ...
```

### Data-Driven Design
All game content is JSON (not Godot Resources) for easy editing and diffing:
- `data/perks.json` — Perk definitions with `effect` key checked by game systems
- `data/opponents.json` — Enemy stats, archetype, gimmicks
- `data/fighters.json` — Player character stats
- `data/puzzles/*.json` — Chess puzzles in FEN notation, solutions in UCI format (e.g., "e2e4")
- `data/shop_*.json` — Purchasable items

### Core Systems
| System | Location | Purpose |
|--------|----------|---------|
| Combat resolution | `scripts/boxing/combat_manager.gd` | Simultaneous action resolution |
| Opponent AI | `scripts/boxing/opponent_ai.gd` | Per-archetype behavior trees |
| Chess logic | `scripts/chess/chess_board_logic.gd` | FEN parsing, move validation |
| Perk effects | `scripts/systems/perk_system.gd` | Value lookups, heat scaling |
| Heat system | `GameManager.heat` | Multiplier (1.0–5.0) from puzzle performance |

## Conventions

### GDScript Style
- Use `%NodeName` (unique name syntax) for `@onready` references
- Static utility classes get `class_name` (e.g., `Juice`, `ChessBonus`)
- Data classes extend `RefCounted` with `class_name`
- Signals for loose coupling between systems
- Prefix unused parameters with `_` to silence warnings

### Perk Schema
```json
{
  "id": "quick_hands",
  "name": "Quick Hands",
  "description": "Jabs deal +2 damage",
  "type": "boxing",           // boxing | chess | hybrid | wild
  "tags": ["speed", "boxing"],
  "rarity": "common",         // common | uncommon | rare
  "effect": "jab_damage_bonus",
  "values": {"damage": 2},
  "heat_scaled": true
}
```
Check perk effects with: `GameManager.has_perk("effect_name")` or `PerkSystem.get_value(perk)`.

### Theme & Colors
Dark jewel-tone palette — do NOT use bright SaaS colors:
- Background: `#0D0A14` (deep black)
- Accent: `#E5C04C` (gold)
- Chess board: dark purple/indigo squares
- Global theme: `assets/theme.tres`

### TextureRect Settings
Use enum constants, not integers:
```gdscript
texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
```
