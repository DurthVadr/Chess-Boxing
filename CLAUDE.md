# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview
A roguelike chess boxing tournament game built in Godot 4.6 (GDScript). Players alternate between solving chess puzzles and turn-based boxing, drafting perks between fights. Balatro-inspired art direction: bold flat colors, CRT shader, heavy typography, juicy animations.

## Running & Testing
```bash
# Run the game
godot --path . scenes/main_menu/main_menu.tscn

# Validate scenes headless (CI)
godot --path . --headless --quit

# Lint GDScript (requires: pip3 install gdtoolkit)
gdlint scripts/ scenes/

# Format GDScript
gdformat scripts/ scenes/
```

## Architecture

### Autoloads (defined in project.godot)
- **GameManager** — Central hub for all run state (fighter, HP, perks, heat, opponent index, shop/tactics). Handles phase transitions via `change_phase(GamePhase.X)` which calls `change_scene_to_file()`.
- **AudioManager** — SFX playback
- **MusicManager** — Background music with intensity shifting
- **SaveManager** — Meta-progression persistence (unlocked fighters, achievements, perks, best scores) to `user://save_data.json`. Does NOT save mid-run state (roguelike permadeath).
- **CRTOverlay** — Global CRT post-processing shader

### Static Utility Systems (RefCounted, all use class_name)
These are stateless classes with static methods — they don't hold state, GameManager does:
- **HeatSystem** — Calculates heat multiplier (1.0–5.0) from chess puzzle performance. Heat scales perk values and carries 30% between rounds.
- **PerkSystem** — Tag counting, set bonus thresholds, perk value queries. Tags: speed, power, timing, defensive, tempo, sacrifice, chess, boxing.
- **ShopSystem** — Dual-shop inventory (The Study / The Gym), Rep currency calculation, purchase validation.
- **TacticCardSystem** — Consumable cards (max 3 in hand) played during boxing. Applies combat mods (blind, guaranteed hit, acts first, etc.).
- **GimmickSystem** — Per-opponent special mechanics (Elena: scaling damage, Marcus: fortress, Suki: L-shaped combos, Magnus: perk drafter).
- **ScoringSystem** — End-of-run score calculation and letter rating (F through S+).
- **AchievementSystem** — Achievement checks at run end.

### Combat System
- **CombatManager** (instanced RefCounted) — Resolves boxing actions with QTE modifiers. Queries GameManager for perk bonuses, tactic overrides, shop bonuses.
- **BoxingAction** — Three actions: JAB (6 dmg, easy QTE), CROSS (10 dmg, gradual QTE), UPPERCUT (25 dmg, high variance QTE).
- **OpponentAI** — Per-archetype behavior with weighted action selection and telegraphing.
- **ComboSystem** — Tracks combo chains for bonus damage.
- Boxing resolves simultaneously: player and opponent both choose actions, then QTE determines outcome.

### Chess System
- **ChessBoardLogic** (instanced RefCounted) — FEN parsing, puzzle setup, move validation. Solutions in UCI format (e.g., "e2e4"). `try_move()` returns 0 (wrong), 1 (correct, more moves), 2 (puzzle complete).
- **ChessBonus** — Legacy helper, heat system now handles puzzle-to-combat scaling.

### Game Flow
```
Main Menu → Fighter Select → Tournament Bracket → Opponent Reveal
→ Chess Puzzle → Boxing Round → (repeat per round) → Move Upgrade → Perk Draft → Shop → next opponent → Results
```
Phase transitions: `GameManager.change_phase(GamePhase.X)` → `get_tree().change_scene_to_file()`

### Move Progression
Players start with JAB only. After fight 1: choose "Upgrade Jab" or "Unlock Cross". After fight 2: auto-unlock Uppercut, choose 2 of 3 to equip.

### Data-Driven Design
All game content is JSON (not Godot Resources) in `data/`:
- `perks.json` — Perk definitions with `effect` key, `values` dict, `heat_scaled` bool
- `opponents.json` — Enemy stats, archetype, gimmick, `fight_position`, `chess_difficulty`
- `fighters.json` — Player character stats
- `puzzles/*.json` — Easy/medium/hard chess puzzles (FEN + UCI solution)
- `set_bonuses.json` — Tag threshold bonuses
- `boss_perks.json` — Magnus-specific perks
- `shop_study.json` / `shop_gym.json` — Shop inventories
- `achievements.json` — Achievement definitions

## Conventions

### GDScript Style
- Scene scripts live in the same folder as their `.tscn` file
- Use `%NodeName` (unique name syntax) for `@onready` references
- Static utility classes use `class_name` (e.g., `Juice`, `ChessBonus`, `HeatSystem`)
- Data classes extend `RefCounted` with `class_name`
- Signals for loose coupling between systems
- Use enum constants, not raw integers (e.g., `TextureRect.EXPAND_IGNORE_SIZE` not `1`)

### Perk Schema
```json
{
  "id": "quick_hands",
  "name": "Quick Hands",
  "description": "Jabs deal +2 damage",
  "type": "boxing",
  "tags": ["speed", "boxing"],
  "rarity": "common",
  "effect": "jab_damage_bonus",
  "values": {"damage": 2},
  "heat_scaled": true
}
```
Check perks with: `GameManager.has_perk("effect_name")`, `GameManager.get_perk_raw_value()`, `GameManager.get_perk_scaled_value()`, or `PerkSystem.get_named_value(perk, key)`.

### Theme & Colors
Dark jewel-tone palette — do NOT use bright/saturated SaaS-style colors:
- Background: `#0D0A14` (deep black)
- Accent: `#E5C04C` (gold)
- Chess board: dark purple/indigo squares, cream/gold pieces
- Buttons: dark purple with gold hover/press borders
- Global theme: `assets/theme.tres` — all scenes inherit from this
- CRT shader: `assets/shaders/crt.gdshader` (hint_screen_texture for screen-space post-processing)

## Custom Commands
- `/new-perk` — Add a perk to the draft pool and wire up its effect
- `/new-opponent` — Add a tournament opponent with stats and AI
- `/new-scene` — Scaffold a new scene folder with .gd boilerplate
- `/add-puzzle` — Add chess puzzles (FEN + UCI solution) to the database
- `/balance-check` — Analyze game balance across all systems

## Current State (MVP / v0.1)
- 1 playable fighter (The Rookie)
- 4 opponents with fight_position ordering and path-based boss selection
- Easy/medium/hard chess puzzle pools
- 12+ perks with tag-based set bonuses
- 3 boxing actions (JAB, CROSS, UPPERCUT) with QTE variants
- Dual shop system (Study + Gym) with tactic cards
- Achievement system with fighter/perk unlocks
- CRT shader overlay, scoring system with letter ratings
- Placeholder art (colored rectangles)
