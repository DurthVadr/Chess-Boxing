# Chess Boxing: Game Design Document

---

## 1. Core Vision & Pillars

### Elevator Pitch

A roguelike tournament game where you alternate between solving chess puzzles and turn-based boxing. Your brainpower on the board fuels your fists in the ring. Draft perks, build synergies, and fight your way to the championship — one checkmate and one uppercut at a time.

### The Core Player Fantasy

**You are a cerebral fighter.** You're the underdog who walks into a tournament where everyone is either smarter or stronger than you — but nobody is both. You feel the rush of solving a puzzle under pressure and channeling that mental edge into raw physical dominance. By the final bout, your perk build has turned you into a finely-tuned machine — a build you authored, a victory you earned.

The fantasy is *synergy mastery under pressure*: the satisfaction of Balatro's build-crafting married to the visceral tension of a boxing match.

### Key Design Pillars

1. **Brain Fuels Brawn** — Chess performance directly powers boxing. This is not two separate games glued together; it is one feedback loop. Every puzzle solved under pressure makes the next punch hit harder. Every lazy solve leaves you weaker in the ring.

2. **Readable Tension** — Every decision must be legible. The player should always know *what* is happening, *why* it matters, and *what they can do about it*. Telegraphed enemy actions, visible Heat meters, clear perk math. Complexity lives in the build — not in hidden information.

3. **Build Identity** — No two runs should feel the same. Perks, tag synergies, move upgrades, shop purchases, and tactic cards combine into a unique "build fingerprint." The player is a deckbuilder who happens to throw punches. The question is never "what do I pick?" but "what does my build *want*?"

4. **Pressure is the Point** — The chess timer, the shrinking HP bar, the boss drafting perks against you. The game should feel like a countdown. Comfort is the enemy of excitement. Every system should quietly ask: "Are you sure you can pull this off?"

---

## 2. The Gameplay Loops

### Micro Loop (Second-to-Second)

**During Chess:** Scan the board. Identify the tactic (fork, pin, sacrifice). Move a piece. The timer is ticking. Each correct move in the solution chain builds confidence — and Heat. A wrong move burns time and focus.

**During Boxing:** Read the opponent's telegraph. Choose two actions (from your unlocked set: Jab, Cross, Uppercut, Block, Dodge, Clinch). Nail the QTE timing. Watch damage numbers pop. Feel the hit-pause. Decide whether to play aggressive or defensive based on your HP, stamina, and remaining rounds.

### Macro Loop (Minute-to-Minute)

One **fight** against a tournament opponent consists of multiple alternating rounds:

1. **Chess Puzzle** — Solve a puzzle matched to the opponent's difficulty and theme. Performance generates Heat (1.0x to 5.0x multiplier) that scales your perk values and damage output.
2. **Boxing Round** — Simultaneous action selection. Both fighters choose actions, then QTE determines execution quality. Damage resolves. Stamina depletes. Opponent gimmicks activate.
3. **Repeat** until one fighter's HP reaches zero.

Between fights, the macro loop expands:
- **Move Upgrade** — Choose how your moveset evolves (upgrade Jab or unlock Cross after fight 1; equip 2 of 3 moves after fight 2).
- **Perk Draft** — Choose 1 of 3 perks. Tags matter — stacking tags triggers set bonuses.
- **Shop Phase** — Split between The Study (chess aids, tactic cards, intel) and The Gym (stat upgrades, combat tactics, services). Spend Rep earned from performance.

### Meta Loop (Session-to-Session)

Each run is a complete tournament arc — win or die, no mid-run saves (roguelike permadeath). Across runs:

- **Elo Rating** — Accumulates based on performance. Higher Elo unlocks new fighters with fundamentally different playstyles.
- **Achievement Unlocks** — Specific challenges (e.g., "Win without blocking," "Reach 4.5x Heat") permanently unlock rare perks and fighters into the pool.
- **Fighter Roster** — 5 fighters total, each demanding a different strategic approach. Unlocking and mastering all of them is the long-term chase.
- **Score & Rating** — F through S+ letter grades. Chasing a higher rating encourages optimization and risk-taking on future runs.

---

## 3. Core Mechanics & Systems

### Controls & Inputs

**Chess Phase:**
- Click/tap to select a piece, click/tap a destination square to move
- Timer visible at all times; visual urgency ramps as time runs low
- Wrong moves flash red and consume time — but do not end the puzzle (unless error limit is reached)

**Boxing Phase:**
- Select two actions per turn from your available moveset via UI buttons/cards
- QTE input after action selection determines execution quality (timing-based)
- Tactic cards played from hand (max 3 in hand) before action selection

### Primary Mechanics

#### The Heat System

Heat is the connective tissue between chess and boxing. It is a multiplier (1.0x baseline, caps at 5.0x) generated by chess puzzle performance:

- **Fast solves** generate more Heat than slow ones
- **Mistake-free solves** generate more Heat than sloppy ones
- **Multi-move puzzles** with deep solutions generate more Heat
- **30% of Heat carries over** between rounds within a fight (so early performance echoes into later rounds)
- Heat scales any perk marked `heat_scaled: true`, amplifying its value proportionally

Heat is the player's primary motivation to invest in chess skill. A 1.0x Heat run and a 4.0x Heat run are fundamentally different power levels.

#### Boxing Actions

Three core actions, progressively unlocked:

| Action | Base Damage | QTE Type | Feel |
|---|---|---|---|
| **Jab** | 6 | Easy (wide timing window) | Reliable, spammable, safe |
| **Cross** | 10 | Gradual (narrowing window) | Solid mid-range, rewards patience |
| **Uppercut** | 25 | High-variance (tiny window, big payoff) | Risky knockout punch |

Plus three defensive/utility actions always available:
- **Block** — Reduces incoming damage by 50% (modified by perks)
- **Dodge** — Chance to fully avoid damage entirely; fails if read correctly
- **Clinch** — Recovers 20 stamina; no damage dealt or received

Players choose **two actions per turn** (simultaneous with opponent). Resolution is simultaneous — both fighters' actions land in the same exchange.

#### Move Progression

Players don't start with all moves. The moveset evolves through the tournament:

- **Start of run:** Jab only
- **After Fight 1:** Choose — "Upgrade Jab" (enhanced Jab) **or** "Unlock Cross"
- **After Fight 2:** Uppercut auto-unlocks. Choose 2 of 3 to equip going forward

This creates early-run identity. A player who upgrades Jab early plays a fundamentally different game than one who rushes Cross.

#### QTE (Quick Time Events)

Each attack action triggers a QTE that determines hit quality:
- **Perfect timing:** Full damage + chance for bonus effects
- **Good timing:** Full damage
- **Missed timing:** Reduced damage or whiff

QTE difficulty scales with action power: Jabs are forgiving, Uppercuts are ruthless. This creates a skill-expression layer — raw damage isn't free, you have to earn it with execution.

#### Perk System

Perks are the build-crafting engine. Drafted between fights (pick 1 of 3), perks fall into categories:

- **Boxing perks** — Direct combat modifiers (damage, defense, stamina)
- **Chess perks** — Puzzle aids and chess-to-boxing bridges
- **Hybrid perks** — Cross-domain synergies (solve fast = guaranteed hit, etc.)
- **Wild perks** — High-risk/high-reward transformative effects

**Tags** are the synergy language. Each perk carries 1-2 tags from: `speed`, `power`, `timing`, `defensive`, `tempo`, `sacrifice`, `chess`, `boxing`. Accumulating tags triggers **set bonuses**:

| Tag | 2-Piece Bonus | 3-Piece Bonus |
|---|---|---|
| Speed | Jabs cost 3 less stamina | Jabs cost 0 stamina |
| Power | +3 base damage all attacks | Attacks ignore half of Block |
| Defensive | Block recovers +5 stamina | Blocking reflects 3 damage |
| Timing | +5s chess time | Timer pauses 2s after correct moves |
| Tempo | Heat retention 30% -> 50% | Hit streaks add +0.5 Heat |
| Sacrifice | Start at 80% HP, +1.0 base Heat | Start at 50% HP, +2.0 base Heat |
| Chess | Puzzles highlight which piece to move | After solving, see opponent's first action |
| Boxing | +10 max stamina | Full stamina restore between rounds |

The tension: do you pick the individually strongest perk, or the one that completes a set bonus? This is the Balatro-esque decision space.

#### Perk Reference Table

| Perk | Rarity | Type | Tags | Effect | Heat Scaled |
|---|---|---|---|---|---|
| Quick Hands | Common | Boxing | speed, boxing | Jabs deal +2 damage | Yes |
| Flicker Jab | Common | Boxing | speed | Jabs can only be dodged 10% of the time | No |
| Speedbag | Uncommon | Boxing | speed, boxing | After 3 jabs, all jabs deal +1 (stacks) | Yes |
| Lightning Reflexes | Rare | Boxing | speed, defensive | +15% dodge chance | No |
| Blitz Mode | Rare | Wild | speed, sacrifice | Chess time halved, Heat from puzzles x2 | No |
| Tempo Master | Uncommon | Hybrid | speed, timing | Solve in <15s: first boxing action guaranteed hit | No |
| Heavyweight | Common | Boxing | power | Cross deals +4 damage | Yes |
| Iron Fists | Uncommon | Boxing | power | Hook deals +5 damage | Yes |
| Haymaker | Uncommon | Boxing | power | Uppercuts cost 50% less stamina | No |
| Pile Driver | Uncommon | Boxing | power, tempo | Each consecutive attack adds +1 damage (resets on non-attack) | Yes |
| Knockout Artist | Rare | Boxing | power, timing | If opponent HP <20%, uppercuts always land | No |
| Glass Cannon | Rare | Wild | power, sacrifice | Max HP halved, all damage dealt x2 | No |
| Patience | Common | Boxing | timing, defensive | Block on turn 1: +3 damage for turns 2-8 | Yes |
| Metronome | Uncommon | Boxing | timing | Alternating attack/defense gives +2 damage per attack | Yes |
| Time Pressure | Uncommon | Hybrid | timing, tempo | Each second remaining on puzzle = +0.5 bonus damage first turn | Yes |
| Zugzwang | Rare | Chess | timing, chess | Solve in <10s: opponent's first action forced to CLINCH | No |
| Last Second | Rare | Wild | timing, sacrifice | Solving with <5s left triples Heat; failing costs 15 HP | No |
| Iron Jaw | Common | Boxing | defensive, boxing | Reduce all incoming damage by 1 | Yes |
| Turtle Shell | Common | Boxing | defensive | Block reduces damage by 60% instead of 50% | No |
| Endurance | Common | Boxing | defensive, boxing | +20 max stamina | No |
| Second Wind | Rare | Boxing | defensive | Once per fight, recover 30% HP when below 10% | Yes |
| Rope-a-Dope | Uncommon | Hybrid | defensive, tempo | Blocking stores 50% of damage blocked; next attack adds it | Yes |
| Momentum | Common | Hybrid | tempo | Each consecutive successful action adds +0.1 Heat | No |
| Adrenaline | Uncommon | Hybrid | tempo, boxing | Land 3 hits without damage: +5s chess time next round | No |
| Intimidation | Uncommon | Hybrid | tempo, power | End round with opponent <50% HP: their next puzzle is easier | No |
| Mind Over Muscle | Rare | Hybrid | tempo, chess | Heat multiplier applies at 1.5x its value | No |
| Flow State | Rare | Hybrid | tempo, timing | Solve puzzle AND win round: +0.3 permanent base Heat | No |
| Scholar's Gambit | Common | Chess | chess | +15s chess time | No |
| Bishop's Blessing | Uncommon | Chess | chess, defensive | First wrong move doesn't count as mistake | No |
| Deep Calculation | Uncommon | Chess | chess | Puzzles with 3+ solution moves give x1.5 Heat | No |
| Grandmaster's Eye | Rare | Chess | chess, timing | Puzzle highlights piece to move; first-try bonus: +0.5 Heat | No |
| Blood Sacrifice | Rare | Wild | sacrifice | Lose 5 HP per puzzle, gain permanent +1 damage (stacks) | No |
| Pawn Storm | Uncommon | Chess | sacrifice, chess | Sacrifice 10 HP to reveal first solution move; skip = +1.0 Heat | No |
| All In | Rare | Wild | sacrifice, power | +50% damage dealt, cannot block or dodge | No |
| Queen's Gambit | Rare | Wild | sacrifice, timing | Skip this draft; next draft offers 5 choices, all Rare | No |
| Borrowed Time | Uncommon | Chess | sacrifice, tempo | +30s chess time; each unused second costs 0.5 HP | No |
| Clinch Master | Common | Boxing | boxing, defensive | Clinch recovers 30 stamina instead of 20 | No |
| Southpaw | Uncommon | Boxing | boxing, speed | Hooks have -20% dodge chance (harder to avoid) | No |
| Body Work | Uncommon | Boxing | boxing, power | Cross and Hook reduce opponent max stamina by 2 per fight | No |
| Corner Man | Rare | Boxing | boxing | Between boxing rounds, recover 15% HP | No |

#### Tactic Cards

Consumable single-use cards (max 3 in hand) purchased from shops and played during boxing. These are chess concepts weaponized as combat modifiers:

**Study Tactics (chess-themed):**
- **Fork** (3 Rep) — Opponent chooses actions blind (no telegraph)
- **Pin** (4 Rep) — Lock one opponent action slot to Block
- **En Passant** (4 Rep) — If opponent dodges, it auto-fails + 1.5x damage
- **Discovery** (3 Rep) — Your Block also deals 50% of your other action's damage
- **Zwischenzug** (5 Rep) — Insert a free Jab between opponent's two actions

**Gym Tactics (boxing-themed):**
- **Sacrifice** (3 Rep) — Lose 8 HP, both your actions guaranteed hits
- **Back Rank** (4 Rep) — If opponent <30% HP, Uppercut ignores dodge and block
- **Tempo** (4 Rep) — You act first; Action 1 resolves before opponent picks Action 2
- **Endgame** (5 Rep) — +3 damage all attacks for rest of fight (stacks)

#### Dual Shop System

Between fights, players spend **Rep** (earned from performance) at two shops:

**The Study** (chess-brain themed):
- Tactic cards (Fork, Pin, En Passant, Discovery, Zwischenzug)
- +10s chess time (max 3 purchases = +30s)
- +1 free puzzle mistake (max 3 purchases)
- Puzzle Scout (see next fight's puzzle theme)
- Draft Reroll (3 new choices on next perk draft)

**The Gym** (boxing-body themed):
- Tactic cards (Sacrifice, Back Rank, Tempo, Endgame)
- +8 max HP and heal (max 3 purchases = +24 HP)
- +10 max stamina (max 3 purchases = +30 stamina)
- +1 base damage (max 2 purchases = +2 damage)
- Scouting Report (see opponent's AI style and gimmick)
- Perk Removal (remove a perk to tighten tag synergies)

The dual-shop framing reinforces the brain-vs-brawn tension. Spending all your Rep at The Study makes puzzles easier but leaves you physically weaker. Spending at The Gym makes you a better boxer but you'll struggle with harder puzzles.

### Interlocking Systems

The game's depth comes from how systems feed into each other:

- **Chess -> Heat -> Perk Scaling:** Solve well -> higher Heat -> heat-scaled perks hit harder -> boxing rounds go faster -> less HP lost -> more room for sacrifice perks
- **Tags -> Set Bonuses -> Playstyle:** Stacking speed tags -> free Jabs -> enables Speedbag stacking -> enables Pile Driver consecutive bonus -> a "death by a thousand cuts" build emerges
- **Sacrifice loop:** Blood Sacrifice costs 5 HP per puzzle -> stacking permanent damage -> Glass Cannon halves HP but doubles damage -> Death Wish set bonus starts you at 50% HP but +2.0 Heat -> you're a nuke made of paper
- **Tactic Cards -> Timing:** Saving a Tempo card for the fight where you've built enough damage to one-shot with an Uppercut. Or saving Fork for a gimmick opponent who telegraphs heavily.
- **Move Progression -> Build Path:** Upgrading Jab early synergizes with speed perks. Rushing Cross opens power tag builds. The choice cascades forward.

### Failure & Success States

**Win condition:** Reduce the opponent's HP to zero in boxing. Do this for all tournament opponents to win.

**Loss conditions:**
- Your HP reaches zero in boxing -> **Run Over.** Roguelike permadeath. Back to fighter select.
- Chess puzzle timeout -> No Heat generated; enter boxing cold (1.0x multiplier). Not an instant loss — but a severe disadvantage.
- Puzzle failure (too many wrong moves) -> Same as timeout penalty, with possible HP cost from certain perks.

**Consequences of loss are permanent within a run.** There are no continues, no checkpoints. But meta-progression (Elo, unlocks) persists across runs.

---

## 4. Entities & AI

### Player Characters (Fighters)

Five fighters, each a distinct strategic identity:

#### The Rookie (Starting character)
- HP: 110 | Stamina: 100 | Damage: 1.05x
- Passive: *Steady Rhythm* — +1 damage on solved puzzles
- Pattern: Jab/Jab/Jab
- Design intent: Balanced, forgiving, teaches core loop. Slightly above-average damage, standard puzzle time, moderate error penalty.

#### The Grandmaster (Unlock: Win a tournament)
- HP: 85 | Stamina: 120 | Damage: 0.95x
- Passive: *Deep Prep* — +6s puzzle time, low error penalty, +3 solve damage
- Pattern: Cross/Cross/Cross
- Design intent: Chess-focused. Fragile but rewards puzzle mastery enormously. For players who want to win fights on the board.

#### The Brawler (Unlock: Win a fight taking <10 damage)
- HP: 160 | Stamina: 80 | Damage: 1.35x
- Passive: *Iron Chin* — High damage, +3 HP regen per exchange
- Pattern: Uppercut
- Puzzle time: -1s | Error penalty: 2.8x
- Design intent: Anti-chess. Massive HP and damage, brutal puzzle penalties. For players who want to muscle through with boxing skill and accept chess as a penalty phase.

#### The Hustler (Unlock: Solve a puzzle in <5 seconds)
- HP: 105 | Stamina: 100 | Damage: 1.2x
- Passive: *Fast Hands* — Mixed pattern, +2s puzzle time, +2 regen
- Pattern: Uppercut/Jab
- Design intent: Speed-oriented. Rewards fast, aggressive play across both phases. The "tempo" character.

#### The Prodigy (Unlock: Reach 4.5x Heat)
- HP: 95 | Stamina: 130 | Damage: 1.25x
- Passive: *Calculated Burst* — +4 solve damage with full combo pattern
- Pattern: Jab/Cross/Uppercut
- Design intent: The skill ceiling character. High stamina, strong damage, fantastic solve bonus — but requires mastery of all three moves and consistent puzzle performance.

### Opponents

The tournament bracket features 5 opponents with escalating difficulty and unique gimmicks:

#### Fight 1 — Vinnie "The Pawn" Kowalski
- **Archetype:** Brawler
- **Stats:** 60 HP | 80 Stamina | 0.8x Damage | 0.8x Defense
- **Chess:** Easy (mate-in-1, forks)
- **Gimmick:** None
- *"A loudmouth from Brooklyn who learned chess last Tuesday. Hits hard but thinks harder... wait, no, he doesn't think at all."*
- **Design Role:** Tutorial fight. Low stats, simple puzzles. Teaches the chess->Heat->boxing rhythm without punishing mistakes.

#### Fight 2 — Suki "The Knight" Tanaka
- **Archetype:** Glass Cannon
- **Stats:** 50 HP | 110 Stamina | 1.3x Damage | 0.6x Defense
- **Chess:** Medium (forks, tactical combinations)
- **Gimmick: L-Shaped Combos** — Her attacks alternate attack/movement patterns (attack+dodge or dodge+attack). Predictable but deadly (+5 bonus damage on combo).
- *"Moves like an L-shaped nightmare. You never see her coming — but you always feel her leaving."*
- **Design Role:** Teaches reading telegraphs and exploiting patterns. She hits hard but is fragile — the player learns that understanding the opponent matters more than raw stats.

#### Fight 3A — Elena "The Bishop" Petrov (Elena path)
- **Archetype:** Technician
- **Stats:** 80 HP | 90 Stamina | 1.0x Damage | 1.0x Defense
- **Chess:** Hard (combinations, positional play, sacrifices)
- **Gimmick: Diagonal Thinking** — Gains +2 damage *every round* regardless of chess performance. A ticking clock.
- *"Former chess prodigy turned amateur boxer. Reads your patterns like an open book. Good luck."*
- **Design Role:** The "race" fight. Elena starts fair but becomes overwhelming. The player must win quickly or be crushed by scaling. Punishes passive/defensive builds.

#### Fight 3B — Marcus "The Rook" Williams (Marcus path)
- **Archetype:** Turtle
- **Stats:** 120 HP | 70 Stamina | 0.7x Damage | 1.4x Defense
- **Chess:** Medium (endgame, positional, defense)
- **Gimmick: Fortress** — Cannot be KO'd by a single hit (min 1 HP from any hit). Blocking heals him 2 HP.
- *"Built like a castle wall. You can hit him all day and he'll still be standing. Patient. Inevitable."*
- **Design Role:** The "attrition" fight. Single-hit burst builds crumble against him. The player must sustain pressure and prevent healing. Rewards combo-based and stamina-efficient builds.

#### Final Boss — Magnus "The Grandmaster" Thunderfist
- **Archetype:** Boss
- **Stats:** 100 HP | 100 Stamina | 1.2x Damage | 1.2x Defense
- **Chess:** Expert (deep calculation, quiet moves, endgame, sacrifice)
- **Gimmick: Adaptation** — Magnus *drafts a perk* before each boxing round from a boss-exclusive pool:
  - *Grandmaster's Prep* — +3 damage to all attacks
  - *Castling* — Block restores 5 HP
  - *Promotion* — +3 damage after round 3
  - *King's Guard* — 25% damage reduction
  - *Endgame Vision* — Reads your Action 1 before choosing his Action 2
- *"The reigning champion. They say he solved a mate-in-7 while getting punched in the face. He didn't flinch."*
- **Design Role:** The mirror match. Magnus builds a perk loadout *during the fight*, creating an arms race. Early rounds are manageable; late rounds are terrifying. The player must either end it fast or have a build strong enough to outscale a boss with escalating advantages.

### Tournament Structure: The Path Split

After Fight 2, the bracket forks:
- **Elena's path** — Tests aggressive, time-pressured play
- **Marcus's path** — Tests sustained attrition and combo play

Both paths converge at Magnus (final boss). This gives runs replayability within the same fighter — the path you face demands different build priorities.

### Opponent AI Behavior

Each archetype has a weighted action selection model:

- **Brawler (Vinnie):** Favors attacks, rarely blocks, predictable
- **Glass Cannon (Suki):** Alternates between heavy attacks and dodges, avoids blocking
- **Technician (Elena):** Adapts to player patterns — if you attack often, she blocks more; if you block, she ramps up
- **Turtle (Marcus):** Heavy blocking with occasional counter-attacks, patient
- **Boss (Magnus):** Reads player actions (with Endgame Vision), drafts counters, escalates pressure

All opponents **telegraph** their next move with visual tells before the action selection phase, giving the player information to act on (unless blinded by the Fork tactic card).

---

## 5. Level Design & Pacing

### Tournament as Level Design

There are no spatial levels — the tournament bracket *is* the level design. Pacing is controlled by opponent ordering, difficulty curves, and the rhythm of chess/boxing/shop phases.

### Intensity Curve Per Fight

```
[Chess Puzzle]  — Focused, intellectual tension. Clock ticking. Brain-mode.
       |
[Boxing Round]  — Physical, visceral. Adrenaline. Action-mode.
       |
[Chess Puzzle]  — Back to brain. But now with stakes: your HP is lower.
       |
[Boxing Round]  — Escalating. Opponent gimmick may be ramping.
       |
  ... repeat until KO ...
```

Each fight is a micro-crescendo. Early rounds feel manageable. Late rounds feel desperate. Heat carry-over and gimmick scaling ensure that fights don't plateau.

### Intensity Curve Across the Run

| Phase | Intensity | Player Emotion | Design Intent |
|---|---|---|---|
| Fight 1 (Vinnie) | Low | Confidence, learning | Teach mechanics safely |
| Move Upgrade + Perk Draft + Shop | Cool-down | Planning, excitement | First meaningful decisions |
| Fight 2 (Suki) | Medium | Alertness, pattern reading | Introduce gimmicks and danger |
| Move Upgrade + Perk Draft + Shop | Cool-down | Build crystallizing | Path choice and commitment |
| Fight 3 (Elena/Marcus) | High | Pressure or endurance | Test the build under stress |
| Perk Draft + Shop | Cool-down | Fine-tuning | Final preparations |
| Fight 5 (Magnus) | Peak | Everything on the line | Climactic boss, no safety net |
| Results | Resolution | Satisfaction or motivation | Score reveal, achievements, retry hook |

### The Quiet Rooms

Between fights, perk drafts and shops serve as **decompression chambers.** The player shifts from execution to deliberation. These moments are critical — they let the player:
- Process what just happened
- Evaluate their build
- Plan for what's next
- Feel agency over their trajectory

The shop split (Study vs. Gym) spatially represents this decision: walk left to invest in your mind, walk right to invest in your body.

---

## 6. Progression & Economy

### In-Run Economy: Rep

**Rep** is earned through fight performance:
- Puzzle solve speed and accuracy
- Boxing damage dealt vs. damage taken
- Combo chains
- Heat level achieved

Rep is spent in shops between fights. It is *not* abundant — a player cannot buy everything they want. This creates meaningful shop decisions:
- Early game: invest in stats (HP/stamina) for survivability, or tactic cards for burst potential?
- Mid game: buy intel to prepare for the path boss, or a service to reshape your build?
- Late game: stock up on tactic cards for Magnus, or squeeze out final stat upgrades?

**Stat upgrade caps** (e.g., max 3 HP Training purchases) prevent "just buy stats" from being a dominant strategy. The shop rewards planning over hoarding.

### Resource Systems

**HP (Health):**
- Base set by fighter choice (85-160)
- Augmented by shop purchases (+8 per, max +24)
- Reduced by sacrifice perks (Blood Sacrifice, Borrowed Time, Sacrifice set bonuses)
- Recovered by specific perks (Second Wind, Corner Man) and shop purchases
- Never fully restores between fights — damage accumulates across the run

**Stamina (Per-Fight Resource):**
- Depleted by attacks, recovered by Block/Clinch/perks
- Resets between fights (unless modified by set bonuses)
- Gates aggression — you can't spam Uppercuts without stamina management

**Heat (Per-Round Multiplier):**
- Earned in chess, spent implicitly in boxing
- 30% retention between rounds (upgradable)
- Permanent base Heat bonuses from Flow State, Sacrifice set bonuses
- The primary "exchange rate" between the two halves of the game

### Difficulty Scaling

Difficulty escalates through multiple vectors simultaneously:

1. **Opponent stats** — HP, damage, and defense modifiers increase
2. **Chess difficulty** — Puzzles progress from mate-in-1 to multi-move deep calculation
3. **Gimmick complexity** — From "no gimmick" (Vinnie) to "the boss drafts perks" (Magnus)
4. **Retaliation count** — Later opponents get more retaliations (counter-attack opportunities): 1 -> 2 -> 2 -> 3
5. **Elo-based puzzle calibration** — Chess difficulty considers the opponent's base Elo: 800 -> 950 -> 1100 -> 1400

### Meta-Progression: Elo & Achievements

**Elo** accumulates across all runs. Fighter unlock thresholds:
- 0 Elo: The Rookie (starting)
- 300 Elo: The Grandmaster
- 600 Elo: The Brawler
- 900 Elo: The Hustler
- 1200 Elo: The Prodigy

Each fighter also requires a specific **achievement**:

| Achievement | Challenge | Unlocks |
|---|---|---|
| Contender | Win a tournament run | The Grandmaster |
| Iron Man | Win a fight taking <10 damage | The Brawler |
| Speed Demon | Solve a puzzle in <5 seconds | The Hustler |
| Chess Prodigy | Reach 4.5x Heat | The Prodigy |

Additional achievements unlock rare perks into the draft pool:

| Achievement | Challenge | Unlocks Perk |
|---|---|---|
| Glass Jaw | Win without ever blocking | Glass Cannon |
| Chess Master | Zero puzzle mistakes in a full run | Grandmaster's Eye |
| Sacrifice Everything | Win with 3+ sacrifice-tagged perks | Blood Sacrifice |
| S-Rank Fighter | Achieve S rating or higher | Knockout Artist |
| Combo King | 10 named combos in one run | Pile Driver |
| Arms Race | Beat Magnus while he has 3+ perks | Flow State |

This system ensures that the perk pool *grows* as the player improves. Early runs have a smaller, simpler perk pool. Experienced players encounter wilder, more synergistic options.

### Reward Schedules

- **Every puzzle:** Immediate Heat feedback (numerical, visual)
- **Every boxing exchange:** Damage numbers, combo notifications, stamina bars shifting
- **Every fight won:** Rep reward, move upgrade choice, perk draft
- **Every run completed:** Score breakdown, letter rating (F through S+), Elo change, achievement checks
- **Achievement unlocked:** New fighter or perk added to pool permanently

The schedule follows a **variable-ratio** pattern for the deepest rewards (achievements) and a **fixed-ratio** pattern for structural rewards (perk drafts after every fight).

---

## 7. Game Feel (Juice) & Readability

### Visual Readability

**Color Language:**
- Deep black (`#0D0A14`) — Background, negative space, framing
- Gold (`#E5C04C`) — Player actions, Heat, positive feedback, success states, currency
- Dark purple/indigo — Chess board dark squares, UI panels, buttons
- Cream/white — Chess board light squares, piece highlights, text
- Red — Damage taken, timer danger zone, wrong puzzle moves
- Green (muted) — HP recovery, stamina recovery

**Opponent Telegraphs:**
Before each boxing exchange, opponents display a **visual tell** indicating their likely action. This tell is partially readable (e.g., a raised fist suggests an attack, a guarded stance suggests a block) but not perfectly specific. Some gimmicks (Suki's L-shaped combos) make telegraphs more predictable; the Fork tactic card removes them entirely.

**Heat Visualization:**
Heat is displayed as a thermometer/meter with color transitions:
- 1.0x: Cool blue
- 2.0x: Warm amber
- 3.0x: Hot orange
- 4.0x: Burning red
- 5.0x: White-hot with particle effects

The Heat meter should be *always visible* — it is the single most important number in the game.

**Perk Tag Indicators:**
Active tag counts and set bonus thresholds are visible in the build screen. When a set bonus activates (2-piece or 3-piece), a clear visual indicator shows the bonus name and effect.

### Feedback Loops

**Hit Confirmation:**
- Screen shake scaled to damage dealt (light for Jab, heavy for Uppercut)
- Hit-pause (frame freeze) on contact — longer for critical/high-damage hits
- Damage numbers pop from the impact point with physics-based drift
- Opponent sprite recoils/flashes white on hit

**Chess Puzzle Feedback:**
- Correct move: Piece snaps into place with a satisfying click, slight screen pulse, Heat meter ticks up
- Wrong move: Piece bounces back, red flash, error sound, mistake counter increments
- Puzzle complete: Board dissolves into particles, Heat meter flares, transition wipe to boxing

**QTE Feedback:**
- Timing indicator narrows toward the "perfect" zone
- Perfect hit: Gold flash + bonus sound + extra screen shake
- Good hit: Standard confirmation
- Miss: Dull thud sound + reduced visual feedback + opponent advantage

**Combo Feedback:**
- Landing consecutive hits triggers combo counter with escalating visual flair
- Named combos display the combo name in bold typography
- Combo breaks with a visible "BREAK" indicator

**Perk Activation:**
- When a heat-scaled perk activates at high Heat, a subtle gold outline pulses on the perk icon
- Set bonus triggers display a brief banner across the screen

**KO Sequence:**
- Final blow gets extended hit-pause (~12 frames)
- Camera zooms slightly
- Opponent falls with dramatic animation
- "KO" text slams onto screen
- Crowd/ambient audio peaks then fades to silence before results

### Camera Systems

**Chess Phase:**
- Static top-down view of the chess board
- Slight zoom on the piece being moved
- Timer prominently framed in the composition

**Boxing Phase:**
- Side-view framing (classic fighting game perspective)
- Camera pulls back slightly as both fighters choose actions (wide shot for readability)
- Camera punches in on impact (tight shot for impact)
- Subtle camera drift toward the fighter taking damage (empathy framing)

**Transitions:**
- Chess -> Boxing: Board folds/dissolves, ring slides in from below
- Boxing -> Chess: Ring recedes, board materializes
- Between fights: Tournament bracket view with opponent portraits, camera tracks along the bracket path

### CRT Shader & Art Direction

The entire game is viewed through a global CRT post-processing shader — scanlines, slight curvature, color bleeding at edges. The Balatro-inspired aesthetic wrapper:
- Makes bold, flat colors feel *physical* — like you're watching the tournament on a beat-up bar TV
- Adds warmth and texture to what would otherwise be simple colored shapes
- Heavy typography (large, bold fonts) ensures readability through the shader
- The shader is always-on and applied at the screen level, unifying all phases visually

---

## Appendix: Game Flow Diagram

```
Main Menu
    |
Fighter Select
    |
Tournament Bracket
    |
Opponent Reveal -> Chess Puzzle -> Boxing Round(s) -> [repeat until KO]
    |
Move Upgrade (after fights 1-2)
    |
Perk Draft (pick 1 of 3)
    |
Shop (The Study / The Gym)
    |
Next Opponent... (or Final Boss)
    |
Results -> Score -> Letter Rating -> Achievements -> Elo Update
    |
Main Menu (new run or quit)
```
