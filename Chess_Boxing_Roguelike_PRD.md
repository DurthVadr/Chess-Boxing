# Chess Boxing Roguelike — Product Requirements Document

## 1. Overview

**Title:** Chess Boxing Roguelike (working title)
**Genre:** Roguelike / Turn-based strategy
**Platform:** Desktop (PC / Mac)
**Engine:** Godot 4 (GDScript)
**Art Direction:** Balatro-inspired — bold flat colors, CRT/scanline shader, heavy typography, juicy animations, retro texture/grain
**Target Audience:** Indie game fans, roguelike enthusiasts, chess players, people who think chess boxing is hilarious

### Elevator Pitch

A roguelike where you fight your way through a chess boxing tournament. Each round alternates between solving chess puzzles under pressure and surviving a turn-based boxing match. Between fights, you draft powerful perks that bend the rules of both chess and boxing. Win by checkmate or knockout — lose either, and your run is over.

---

## 2. Core Game Loop

```
[SELECT FIGHTER] → [OPPONENT REVEAL] → [CHESS ROUND] → [BOXING ROUND] → [PERK DRAFT] → repeat → [FINAL BOSS] → [WIN / LOSE]
```

### 2.1 Run Structure

- A single run = **5 opponents** in a tournament bracket
- Each opponent fight = **2-3 alternating rounds** (Chess → Boxing → Chess → Boxing...)
- First to win by **checkmate** (solving all chess puzzles) or **KO** (reducing opponent HP to 0) wins the fight
- If the player loses any fight, the run ends (permadeath)
- Runs should take approximately **20-30 minutes**

### 2.2 Chess Phase

The chess phase is **puzzle-based**, not a full chess game. This keeps pacing tight and matches the intensity of boxing rounds.

**Core Mechanics:**
- Player is presented with a chess puzzle (e.g., "Mate in 2", "Find the fork", "Defend the king")
- Puzzles are pulled from a curated database, tagged by difficulty (1-5 stars) and theme
- Player has a **time limit** (starts at 60s, can be modified by perks)
- **Scoring:** Solving faster and with fewer incorrect moves grants a **Chess Bonus** that carries into the boxing phase
- **Chess Bonus effects:** bonus damage on first punch, temporary defense buff, stamina recovery, etc.
- **Failure:** If the timer runs out or too many wrong moves, the opponent gets a Boxing Bonus instead

**Puzzle Difficulty Scaling:**
- Opponents 1-2: 1-2 star puzzles (simple tactics: forks, pins, back-rank mates)
- Opponents 3-4: 3-4 star puzzles (combinations, sacrifices, positional themes)
- Opponent 5 (boss): 4-5 star puzzles (deep calculation, quiet moves, endgame studies)

**Puzzle Themes Tied to Opponents:**
- Aggressive opponents → attacking puzzles (sacrifices, mating attacks)
- Defensive opponents → endgame puzzles (pawn endings, fortress defense)
- Tricky opponents → tactical puzzles (discovered attacks, zwischenzug)

### 2.3 Boxing Phase

The boxing phase is **turn-based** with a timing/rhythm element. Think Punch-Out!! meets Slay the Spire.

**Core Mechanics:**
- Player and opponent each have **HP** and **Stamina**
- Each turn, player chooses from available **actions:**
  - **Jab** — Low damage, low stamina cost, fast (can combo)
  - **Cross** — Medium damage, medium stamina cost
  - **Hook** — High damage, high stamina cost, can be dodged
  - **Uppercut** — Very high damage, very high stamina cost, slow windup
  - **Block** — Reduces incoming damage, recovers some stamina
  - **Dodge** — Chance to avoid attack entirely (higher chance vs slow attacks)
  - **Clinch** — Skip turn, recover stamina, opponent also skips
- Opponent telegraphs their next move (icon/animation hint), so player can react strategically
- **Stamina management** is key — going all-out leaves you vulnerable
- **Chess Bonus** from the previous phase modifies this round (e.g., extra action, damage buff, stamina boost)

**Opponent AI Archetypes:**
- **Brawler** — High damage, predictable patterns, low chess skill
- **Technician** — Balanced, reads your patterns, adapts
- **Turtle** — High defense, waits for counters, strong at chess
- **Glass Cannon** — Low HP, explosive damage, solves puzzles fast
- **The Grandmaster** (Boss) — Excellent at both, unique mechanics

### 2.4 Perk Draft Phase

After each fight (except the last), the player drafts perks. This is the roguelike progression layer.

**Draft Mechanic:**
- Player is offered **3 random perks**, picks **1**
- Perks are categorized:
  - **Chess Perks** (blue) — Affect the puzzle phase
  - **Boxing Perks** (red) — Affect the boxing phase
  - **Hybrid Perks** (purple) — Affect both or create cross-phase synergies
  - **Wild Perks** (gold) — Rare, powerful, sometimes risky

**Example Perks:**

| Perk Name | Type | Effect |
|---|---|---|
| Scholar's Gambit | Chess | +15s time on all puzzles |
| Bishop's Blessing | Chess | First wrong move doesn't count |
| Iron Jaw | Boxing | Reduce all incoming damage by 1 |
| Haymaker | Boxing | Uppercuts cost 50% less stamina |
| Mind Over Muscle | Hybrid | Chess Bonus effects are doubled |
| Rope-a-Dope | Hybrid | Blocking in boxing grants chess time bonus next round |
| Blitz Mode | Wild | Puzzle time halved, but Chess Bonus is tripled |
| Second Wind | Boxing | Once per fight, recover 30% HP when below 10% |
| Zugzwang | Chess | If you solve a puzzle in <10s, opponent loses a boxing turn |
| Pawn Storm | Wild | Replace one boxing action with a unique "Pawn Storm" AoE attack |

**Perk Synergy System:**
- Holding 3+ perks of the same color grants a **set bonus** (e.g., 3 Chess perks = puzzles start with 1 hint revealed)
- Some perks explicitly reference others (e.g., "If you have Iron Jaw, this perk also grants +2 damage")

---

## 3. Meta Progression (Between Runs)

To keep players coming back, there should be light permanent progression:

- **Fighter Unlocks:** Start with 1 fighter archetype, unlock more by achieving milestones
- **Perk Pool Expansion:** New perks are added to the draft pool as you complete runs
- **Puzzle Pack Unlocks:** Beating the game unlocks harder puzzle sets
- **Stat Tracking:** Best run times, fastest puzzle solves, most damage dealt, etc.
- **Cosmetics:** Alternate fighter skins, ring themes, chess piece styles

### Fighter Archetypes (Unlockable)

| Archetype | Starting Stats | Passive |
|---|---|---|
| The Rookie | Balanced HP/Stamina | No passive — pure skill |
| The Grandmaster | Low HP, High Stamina | Starts with +20s chess time |
| The Brawler | High HP, Low Stamina | Jabs deal +1 damage |
| The Hustler | Medium HP/Stamina | Sees opponent's first boxing move for free |
| The Prodigy | Very Low HP, Very High Stamina | Chess Bonus effects are 1.5x |

---

## 4. UI/UX Design

### Art Style: Balatro-Inspired

- **Color palette:** Deep blacks, rich jewel tones (emerald, ruby, gold, sapphire), cream/off-white for text
- **Typography:** Bold, large, slightly distressed serif or slab-serif fonts for headers; clean monospace for stats
- **CRT shader:** Subtle scanlines, slight vignette, chromatic aberration on transitions
- **Card aesthetic:** Perks are presented as physical cards with foil/holographic effects on rares
- **Juice:** Screen shake on hits, scale bounce on puzzle solves, particle bursts on KO, satisfying SFX on every interaction
- **Grain/texture:** Subtle paper or film grain overlay on all screens

### Key Screens

1. **Title Screen** — Logo, "New Run" / "Collection" / "Settings" — moody, atmospheric
2. **Fighter Select** — Card-style fighter display with stats and passive
3. **Tournament Bracket** — Visual bracket showing upcoming opponents (silhouettes until revealed)
4. **Opponent Reveal** — Dramatic card flip showing opponent name, archetype, and flavor text
5. **Chess Phase** — Chess board (clean, readable), timer, move input, bonus meter
6. **Boxing Phase** — Side-view or top-down ring, HP/Stamina bars, action buttons, telegraph indicators
7. **Perk Draft** — 3 cards dealt face-down, flip to reveal, pick one with satisfying animation
8. **Victory/Defeat** — Run summary with stats, unlocks earned, "Try Again" prompt

---

## 5. Technical Architecture (Godot 4)

### Project Structure

```
chess-boxing-roguelike/
├── project.godot
├── assets/
│   ├── fonts/
│   ├── sprites/
│   │   ├── fighters/
│   │   ├── chess_pieces/
│   │   ├── ui/
│   │   └── effects/
│   ├── audio/
│   │   ├── sfx/
│   │   └── music/
│   └── shaders/
│       ├── crt.gdshader
│       └── grain.gdshader
├── scenes/
│   ├── main_menu/
│   │   └── main_menu.tscn
│   ├── fighter_select/
│   │   └── fighter_select.tscn
│   ├── tournament/
│   │   └── tournament_bracket.tscn
│   ├── chess_phase/
│   │   ├── chess_phase.tscn
│   │   ├── chess_board.tscn
│   │   └── puzzle_display.tscn
│   ├── boxing_phase/
│   │   ├── boxing_phase.tscn
│   │   ├── fighter_display.tscn
│   │   └── action_panel.tscn
│   ├── perk_draft/
│   │   └── perk_draft.tscn
│   └── results/
│       └── run_results.tscn
├── scripts/
│   ├── autoload/
│   │   ├── game_manager.gd        # Global state, run management
│   │   ├── audio_manager.gd       # SFX and music
│   │   └── save_manager.gd        # Meta progression persistence
│   ├── chess/
│   │   ├── puzzle.gd              # Puzzle data class
│   │   ├── puzzle_database.gd     # Load/filter puzzles
│   │   ├── chess_board_logic.gd   # Board state, move validation
│   │   └── chess_bonus.gd         # Bonus calculation
│   ├── boxing/
│   │   ├── fighter.gd             # Fighter stats, HP, stamina
│   │   ├── action.gd              # Action definitions
│   │   ├── combat_manager.gd      # Turn resolution
│   │   └── opponent_ai.gd         # AI behavior per archetype
│   ├── perks/
│   │   ├── perk.gd                # Perk data class
│   │   ├── perk_database.gd       # All perks, filtering, weights
│   │   └── perk_effects.gd        # Apply perk effects to game state
│   ├── opponents/
│   │   ├── opponent.gd            # Opponent data class
│   │   └── opponent_generator.gd  # Procedural opponent generation
│   └── ui/
│       ├── juice.gd               # Screen shake, scale bounce, etc.
│       └── transition.gd          # Scene transitions
└── data/
    ├── puzzles/
    │   ├── puzzles_easy.json
    │   ├── puzzles_medium.json
    │   └── puzzles_hard.json
    ├── perks.json
    ├── opponents.json
    └── fighters.json
```

### Key Technical Decisions

- **Chess Puzzle Data:** Use [Lichess puzzle database](https://database.lichess.org/#puzzles) (CC0 licensed, millions of puzzles with difficulty ratings and themes) — export a curated subset as JSON
- **Board Rendering:** Custom 2D board using Godot's TileMap or simple Sprite2D grid — no need for a chess engine, just validate the puzzle solution moves
- **State Management:** Single `GameManager` autoload holds all run state (current fighter, perks, opponent index, HP, etc.)
- **Save System:** Use Godot's `ConfigFile` or JSON for meta progression saves
- **Animation:** Use Godot's `Tween` nodes heavily for all juice effects
- **Audio:** Layered music system — base track + chess layer + boxing layer that crossfade

### Puzzle Data Format (JSON)

```json
{
  "id": "puzzle_001",
  "fen": "r1bqkb1r/pppp1ppp/2n2n2/4p2Q/2B1P3/8/PPPP1PPP/RNB1K1NR w KQkq - 4 4",
  "solution": ["Qxf7"],
  "themes": ["mateIn1", "short", "sacrifice"],
  "difficulty": 1,
  "description": "Scholar's Mate"
}
```

---

## 6. Prototype Scope (v0.1 — MVP)

Build the smallest thing that proves the core loop is fun.

### In Scope

- [ ] 1 fighter archetype (The Rookie — no passive, balanced stats)
- [ ] 3 opponents with fixed stats (easy → medium → hard)
- [ ] Chess phase with 10 curated puzzles (no procedural selection yet)
- [ ] Boxing phase with all 7 actions, basic opponent AI
- [ ] 1 perk draft between each fight (6-8 perks in the pool)
- [ ] Win/lose screen with basic stats
- [ ] Placeholder art (colored rectangles, basic shapes)
- [ ] Basic SFX (hit, solve, draft)
- [ ] CRT shader overlay

### Out of Scope (v0.1)

- Meta progression / saves
- Multiple fighter archetypes
- Procedural opponent generation
- Full puzzle database integration
- Music
- Polished art
- Settings menu
- Leaderboards

### Success Criteria for v0.1

The prototype is successful if:
1. The chess → boxing → perk loop feels like a coherent game, not three separate minigames
2. Players feel tension during chess puzzles (time pressure matters)
3. Boxing decisions feel meaningful (not just spam attack)
4. Perk choices create interesting decisions (not one obviously best pick)
5. A complete run takes 10-15 minutes

---

## 7. Milestone Plan

| Milestone | Scope | Estimated Time |
|---|---|---|
| **M0: Skeleton** | Scene transitions, game state flow, placeholder screens for all phases | 1 week |
| **M1: Chess Phase** | Board rendering, puzzle loading, move input, timer, bonus calc | 1-2 weeks |
| **M2: Boxing Phase** | Fighter display, HP/stamina, all actions, basic AI, turn resolution | 1-2 weeks |
| **M3: Perk System** | Perk data, draft UI, apply effects to game state | 1 week |
| **M4: Integration** | Full run flow, 3 opponents, win/lose conditions, balancing pass | 1 week |
| **M5: Juice Pass** | CRT shader, screen shake, animations, SFX, transitions | 1 week |
| **M6: Playtest** | Get 5+ people to play, collect feedback, iterate | 1 week |

**Total estimated time to playable prototype: 6-8 weeks**

---

## 8. Open Questions

1. **Chess input method:** Click pieces on board? Algebraic notation? Drag and drop? → Recommend drag-and-drop for desktop
2. **Boxing visual perspective:** Side-view (like Punch-Out!!) or top-down? → Recommend side-view for readability and drama
3. **Difficulty modes:** Should there be an easy mode, or is roguelike difficulty the only mode? → Start with one difficulty, add easy mode later if retention data suggests it
4. **Multiplayer potential:** Local 1v1 where one player does chess and the other does boxing? → Cool stretch goal, not for MVP
5. **Monetization:** Premium (one-time purchase) or free with cosmetic DLC? → Decide after prototype validates the concept

---

## 9. References & Inspiration

- **Balatro** — Art style, juice, card draft feel, perk/joker system
- **Slay the Spire** — Roguelike structure, perk synergies, opponent variety
- **Punch-Out!!** — Boxing feel, telegraph system, pattern recognition
- **Lichess** — Puzzle database, chess UI patterns
- **Buckshot Roulette** — Minimal art, maximum atmosphere, short run length
- **Inscryption** — Mixing genres within a roguelike framework

---

*This PRD is optimized to be handed to an AI coding assistant (like Claude Code) to scaffold and build the Godot 4 project. Each section is specific enough to implement against while leaving room for creative interpretation in the details.*
