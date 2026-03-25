Add a new opponent to the tournament.

## Instructions

1. Read `data/opponents.json` to see existing opponents and their structure
2. Ask the user for opponent details if not provided: name, archetype (brawler/technician/boss), stats, flavor text
3. Generate an `id` following the existing pattern (opponent_N)
4. Create the opponent entry matching the JSON structure with fields: id, name, archetype, hp, stamina, damage_mod, defense_mod, chess_difficulty, flavor_text, puzzle_themes
5. Add it to `data/opponents.json`
6. If the opponent needs special AI behavior, check `scripts/boxing/opponent_ai.gd` and add logic there
7. Summarize what was added

## Argument
$ARGUMENTS — Optional: opponent name and archetype, e.g. "Rocky 'The Tank' Rivera, brawler"
