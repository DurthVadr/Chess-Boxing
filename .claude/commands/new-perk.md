Add a new perk to the game.

## Instructions

1. Read `data/perks.json` to see existing perks and their structure
2. Ask the user for perk details if not provided: name, description, type (boxing/chess/hybrid/wild), rarity (common/uncommon/rare), and what it does
3. Generate a snake_case `id` from the name
4. Create the perk entry matching the existing JSON structure with fields: id, name, description, type, tags, rarity, effect, values, heat_scaled, flavor
5. Add it to `data/perks.json`
6. Search for where perk effects are checked in the codebase (grep for existing effect names) and wire up the new effect in the appropriate game system(s)
7. Summarize what was added and where the effect is handled

## Argument
$ARGUMENTS — Optional: perk name and description, e.g. "Iron Jaw: Block absorbs 50% more damage"
