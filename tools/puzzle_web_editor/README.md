# Puzzle Web Editor

Local HTML editor for chess puzzles with board preview and JSON CRUD.

## Features

- Load all puzzle pools: `easy`, `medium`, `hard`
- Fight filter mapped from `data/opponents.json` (`chess_difficulty` -> pool)
- Create, duplicate, edit, and delete puzzles
- Board preview from FEN with solution playback (prev/next/reset)
- Save changes back to `data/puzzles/puzzles_*.json`

## Run

From repo root:

```bash
python tools/puzzle_web_editor/server.py
```

Then open:

- <http://127.0.0.1:8765>

## Notes

- This tool writes directly to the JSON files used by the game.
- Use `Save Pool` after edits.
- `Reload Pool` discards unsaved edits in the current pool.
