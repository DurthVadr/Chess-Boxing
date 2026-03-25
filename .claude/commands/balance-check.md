Analyze game balance across perks, opponents, and combat.

## Instructions

1. Read all data files: `data/perks.json`, `data/opponents.json`, `data/fighters.json`
2. Read combat logic: `scripts/boxing/combat_manager.gd`, `scripts/boxing/boxing_action.gd`, `scripts/boxing/opponent_ai.gd`
3. Read perk/bonus systems: `scripts/systems/perk_system.gd`, `scripts/chess/chess_bonus.gd`, `scripts/systems/heat_system.gd`
4. Analyze and report on:
   - **Damage curves**: How much damage can the player deal per round? Are any perks creating degenerate combos?
   - **Opponent scaling**: Is the HP/damage/defense progression between opponents smooth?
   - **Perk value**: Are all perks roughly equal in power for their rarity tier?
   - **Action economy**: Are any boxing actions strictly dominant?
   - **Chess-boxing synergy**: Do hybrid/wild perks create interesting decisions?
5. Flag any obvious issues and suggest specific number tweaks
6. Present findings in a clear table format where possible
