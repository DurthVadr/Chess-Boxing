Add chess puzzles to the puzzle database.

## Instructions

1. Read the appropriate puzzle file in `data/puzzles/` based on difficulty (puzzles_easy.json, puzzles_medium.json, puzzles_hard.json)
2. Ask the user for puzzle details if not provided: FEN position, solution moves (UCI format like "e2e4"), difficulty, and optional theme
3. Validate the FEN string format looks correct (has 8 ranks separated by /)
4. Validate solution moves are in UCI format (4-5 chars like "e2e4" or "e7e8q" for promotion)
5. Create the puzzle entry matching the existing JSON structure
6. Add it to the appropriate difficulty file
7. Summarize what was added

## Argument
$ARGUMENTS — Optional: difficulty level and/or FEN string
