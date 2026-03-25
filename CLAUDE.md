# Chess Boxing Roguelike

## Project Overview
A roguelike where you fight through a chess boxing tournament. Alternates between solving chess puzzles and turn-based boxing. Between fights, draft perks that bend the rules of both chess and boxing.

## Tech Stack
- **Engine:** Godot 4.6 (GDScript)
- **Platform:** Desktop (PC / Mac)
- **Art Direction:** Balatro-inspired — bold flat colors, CRT shader, heavy typography, juicy animations

## Project Structure
```
project.godot          — Main project config, autoloads defined here
scripts/autoload/      — GameManager (global state), AudioManager (SFX)
scripts/chess/         — ChessBoardLogic (FEN/puzzles), ChessBonus
scripts/boxing/        — BoxingAction, CombatManager, OpponentAI
scripts/ui/            — Juice (animations), Transition
scenes/                — One folder per screen, each has .tscn + .gd
data/                  — JSON files: puzzles, perks, opponents, fighters
assets/shaders/        — CRT and grain shaders
```

## Game Flow
```
Main Menu → Fighter Select → Tournament Bracket → Opponent Reveal
→ Chess Puzzle → Boxing Round → (repeat) → Perk Draft → next opponent → Results
```

## Key Architecture Decisions
- **Single GameManager autoload** holds all run state (fighter, HP, perks, opponent index)
- **Phase transitions** are handled by GameManager.change_phase() which calls change_scene_to_file()
- **Chess puzzles** use FEN notation, solution moves in UCI format (e.g., "e2e4")
- **Boxing combat** resolves simultaneously — player and opponent both choose actions
- **Perks** are stored as Dictionaries with an "effect" key that game systems check

## Current State (MVP / v0.1)
- 1 playable fighter (The Rookie)
- 3 opponents (Brawler → Technician → Boss)
- 10 easy + 5 medium + 5 hard chess puzzles
- 12 perks in the draft pool
- All 7 boxing actions with opponent AI
- Placeholder art (colored rectangles)
- CRT shader overlay

## Conventions
- Scene scripts go in the same folder as their .tscn file
- Use `%NodeName` (unique name) for @onready references in scenes
- Static utility classes use class_name (e.g., Juice, ChessBonus, ChessBoardLogic)
- Data classes use class_name with RefCounted base
- JSON for all game data (not Resources) — keeps it editable and diffable
- Signals for loose coupling between systems

## Theme / Art Style
- **Dark jewel-tone palette:** deep blacks (#0D0A14), emerald, ruby, gold (#E5C04C), sapphire
- **Global theme:** `assets/theme.tres` — all scenes inherit from this
- **CRT shader:** `assets/shaders/crt.gdshader` uses `hint_screen_texture` for screen-space post-processing
- **Chess board:** Dark purple/indigo squares, cream/gold pieces
- **Buttons:** Dark purple with gold hover/press borders
- Do NOT use bright/saturated SaaS-style colors — keep everything moody and atmospheric

## Running & Testing
- **Run game:** `godot --path . scenes/main_menu/main_menu.tscn` or open in Godot 4.6 and hit F5
- **Run headless (CI):** `godot --path . --headless --quit` (validates scene loading, catches parse errors)
- **Lint GDScript:** `gdlint scripts/ scenes/` (requires gdtoolkit: `pip3 install gdtoolkit`)
- **Format GDScript:** `gdformat scripts/ scenes/` (auto-fix formatting)
- Main scene: `scenes/main_menu/main_menu.tscn`

## Custom Commands
- `/new-perk` — Add a perk to the draft pool and wire up its effect
- `/new-opponent` — Add a tournament opponent with stats and AI
- `/new-scene` — Scaffold a new scene folder with .gd boilerplate
- `/add-puzzle` — Add chess puzzles (FEN + UCI solution) to the database
- `/balance-check` — Analyze game balance across all systems

## What's NOT implemented yet (out of scope for MVP)
- Meta progression / saves
- Multiple fighter archetypes (only The Rookie is unlocked)
- Procedural opponent generation
- Full Lichess puzzle database integration
- Music / polished art / settings menu
