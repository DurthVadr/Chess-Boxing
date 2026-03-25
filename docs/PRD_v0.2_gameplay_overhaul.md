# Chess Boxing Roguelike — PRD v0.2: Gameplay Overhaul

**Codename:** "Grandmaster's Gambit"
**Version:** 0.2
**Date:** 2026-03-25
**Vision:** Balatro meets En Passant meets Punch-Out — a roguelike where chess skill charges your fists and every perk draft reshapes your entire strategy.

---

## 1. Design Pillars

**Pillar 1 — The Bridge:** Chess and boxing are not two minigames. They are one system. Performance in chess directly multiplies your power in boxing. Decisions in boxing alter the conditions of your next chess puzzle. Every action ripples forward.

**Pillar 2 — Broken Combos:** The player should be able to "break" the game. Perks must interact, multiply, and create emergent strategies the designer didn't explicitly plan. A run where you stumble into a disgusting synergy should feel like you discovered a cheat code. This is the Balatro principle.

**Pillar 3 — Readable Opponents:** Every opponent is a puzzle, not a dice roll. The player should be able to learn tells, exploit patterns, and feel like a genius when they read a feint correctly. This is the Punch-Out principle.

**Pillar 4 — One More Run:** No two runs should play the same. The combination of fighter choice, perk draft order, opponent gimmicks, and puzzle selection should create enough variance that the player always thinks "okay but what if I tried a sacrifice build next time."

---

## 2. Core System: The Heat Meter

### 2.1 What It Replaces

The current `chess_bonus` (a flat 0.0–1.0 float that adds 0–5 damage) is replaced by **Heat** — a visible, central multiplier that scales everything.

### 2.2 How Heat Works

Heat is a floating-point multiplier displayed prominently between the chess and boxing phases. It starts at **1.0×** each fight and is rebuilt every chess round.

**Heat Calculation (per chess round):**

```
base_heat = 1.0

# Time component (0.0 – 2.0 bonus)
time_ratio = time_remaining / time_limit
time_heat = time_ratio * 2.0

# Accuracy component (0.0 – 1.5 bonus)
if mistakes == 0:
    accuracy_heat = 1.5
elif mistakes == 1:
    accuracy_heat = 0.75
elif mistakes == 2:
    accuracy_heat = 0.25
else:
    accuracy_heat = 0.0

# Difficulty component (0.0 – 0.5 bonus)
difficulty_heat = puzzle_difficulty * 0.1  # difficulty 1–5

heat = base_heat + time_heat + accuracy_heat + difficulty_heat
# Possible range: 1.0 – 5.0
```

**On puzzle failure:** Heat drops to **0.5×** (a penalty, not zero — you can still fight, you're just weakened).

### 2.3 What Heat Multiplies

Heat is not just a damage boost. It scales the *effects* of your perks during the boxing round:

| System | Without Heat | With 3.5× Heat |
|---|---|---|
| Quick Hands (+2 jab dmg) | +2 | +7 |
| Iron Jaw (-1 incoming dmg) | -1 | -3 |
| Rope Burn (stored block dmg) | stored × 1 | stored × 3.5 |
| Second Wind (30% HP recovery) | 30% | 100%+ (capped at max HP) |

**Not multiplied by Heat:** Base action damage (JAB still does 5 base), stamina costs, chess timer. Only perk effects scale — this makes perks feel powerful and makes the chess phase feel consequential.

### 2.4 Heat Display

A large thermometer/bar between the fighter portraits. It pulses and glows as it fills. When Heat exceeds 3.0×, the screen gets a subtle warm tint and particle effects. When Heat is below 1.0× (failure), the screen goes cold blue.

### 2.5 Heat Retention (Between Rounds)

Within a single fight, Heat partially carries over between chess rounds:

```
retained_heat = previous_heat * 0.3
new_heat = calculate_heat(puzzle_result) + retained_heat
```

This rewards consistency — solving both puzzles well in a fight gives a compounding advantage.

---

## 3. Core System: Perk Overhaul

### 3.1 Tag System

Every perk now has 1–2 **tags** from the following pool:

| Tag | Fantasy | Color |
|---|---|---|
| `speed` | Fast hands, quick thinking | Electric Blue |
| `power` | Raw damage, brute force | Crimson Red |
| `timing` | Precision, windows, thresholds | Gold |
| `defensive` | Blocking, damage reduction, healing | Emerald Green |
| `tempo` | Flow between chess and boxing | Purple |
| `sacrifice` | Pay a cost for outsized reward | Blood Orange |
| `chess` | Enhances puzzle phase directly | Ivory |
| `boxing` | Enhances combat phase directly | Steel Gray |

Tags serve three purposes: (a) visual identity on perk cards, (b) set bonus triggers, (c) player can read their "build" at a glance.

### 3.2 Set Bonuses

When you accumulate enough perks sharing a tag, a **Set Bonus** activates — shown as a banner across the perk collection.

| Tag | 2-Set Bonus | 3-Set Bonus |
|---|---|---|
| `speed` | Jabs cost 3 less stamina | Jabs cost 0 stamina |
| `power` | +3 base damage to all attacks | All attacks ignore Block (50% reduction → 25%) |
| `defensive` | Block recovers +5 extra stamina | Blocking reflects 3 damage back |
| `timing` | +5s chess time | Chess timer pauses for 2s after each correct move |
| `tempo` | Heat retention between rounds: 30% → 50% | Boxing streaks (3 hits without taking damage) add +0.5 Heat |
| `sacrifice` | Start each fight at 80% HP, but +1.0 base Heat | Start at 50% HP, but +2.0 base Heat |
| `chess` | See which piece to move first (subtle highlight) | After solving, see opponent's first boxing action |
| `boxing` | +10 max stamina | Stamina fully restores between boxing rounds (not just fights) |

### 3.3 Perk Pool (40 Perks)

#### Speed Perks (6)

| # | Name | Rarity | Tags | Effect |
|---|---|---|---|---|
| 1 | Quick Hands | Common | `speed`, `boxing` | Jabs deal +2 damage |
| 2 | Blitz Mode | Rare | `speed`, `sacrifice` | Chess time halved. Heat from puzzles ×2 |
| 3 | Tempo Master | Uncommon | `speed`, `timing` | Solve puzzle in <15s → first boxing action guaranteed hit |
| 4 | Flicker Jab | Common | `speed` | Jab dodge chance reduced to 10% (from 25%) — almost unhittable |
| 5 | Speedbag | Uncommon | `speed`, `boxing` | After landing 3 jabs in a fight, all jabs deal +1 for rest of fight. Stacks. |
| 6 | Lightning Reflexes | Rare | `speed`, `defensive` | Dodge chance for all attacks +15% |

#### Power Perks (6)

| # | Name | Rarity | Tags | Effect |
|---|---|---|---|---|
| 7 | Haymaker | Uncommon | `power`, `boxing` | Uppercuts cost 50% less stamina |
| 8 | Glass Cannon | Rare | `power`, `sacrifice` | Max HP halved. All damage dealt ×2 |
| 9 | Heavyweight | Common | `power` | Cross deals +4 damage |
| 10 | Knockout Artist | Rare | `power`, `timing` | If opponent HP <20%, uppercuts are guaranteed hit |
| 11 | Iron Fists | Uncommon | `power` | Hook deals +5 damage |
| 12 | Pile Driver | Uncommon | `power`, `tempo` | Each consecutive attack action (no blocks/dodges/clinches) adds +1 damage. Resets on non-attack. |

#### Timing Perks (5)

| # | Name | Rarity | Tags | Effect |
|---|---|---|---|---|
| 13 | Zugzwang | Rare | `timing`, `chess` | Solve puzzle in <10s → opponent's first boxing action is forced CLINCH |
| 14 | Time Pressure | Uncommon | `timing`, `tempo` | Each second remaining on puzzle timer = +0.5 bonus damage first boxing turn |
| 15 | Patience | Common | `timing`, `defensive` | If you block on turn 1 of boxing, gain +3 damage for turns 2–8 |
| 16 | Last Second | Rare | `timing`, `sacrifice` | Solving with <5s remaining triples Heat. Failing costs 15 HP. |
| 17 | Metronome | Uncommon | `timing` | Alternating attack/defense actions (attack, block, attack, block...) gives +2 damage to each attack |

#### Defensive Perks (5)

| # | Name | Rarity | Tags | Effect |
|---|---|---|---|---|
| 18 | Iron Jaw | Common | `defensive`, `boxing` | Reduce all incoming damage by 1 (scales with Heat) |
| 19 | Second Wind | Rare | `defensive` | Once per fight, recover 30% HP when below 10% (scales with Heat) |
| 20 | Rope-a-Dope | Uncommon | `defensive`, `tempo` | Blocking stores 50% of damage blocked. Next attack adds stored damage. Resets after release. |
| 21 | Turtle Shell | Common | `defensive` | Block reduces damage by 60% instead of 50% |
| 22 | Endurance | Common | `defensive`, `boxing` | +20 max stamina |

#### Tempo Perks (5)

| # | Name | Rarity | Tags | Effect |
|---|---|---|---|---|
| 23 | Adrenaline | Uncommon | `tempo`, `boxing` | Landing 3 hits without getting hit grants +5s chess time next round |
| 24 | Intimidation | Uncommon | `tempo`, `power` | End a boxing round with opponent below 50% HP → their next chess puzzle is one tier easier |
| 25 | Momentum | Common | `tempo` | Each consecutive successful action (hit lands, dodge succeeds, block reduces) adds +0.1 Heat. Resets on whiff. |
| 26 | Mind Over Muscle | Rare | `tempo`, `chess` | Heat multiplier applies at 1.5× its value (3.0× Heat acts like 4.5×) |
| 27 | Flow State | Rare | `tempo`, `timing` | If you solve the chess puzzle AND win the boxing round, gain a permanent +0.3 base Heat for the rest of the run |

#### Sacrifice Perks (5)

| # | Name | Rarity | Tags | Effect |
|---|---|---|---|---|
| 28 | Blood Sacrifice | Rare | `sacrifice` | Lose 5 HP per chess puzzle. Gain permanent +1 damage to all attacks for rest of run. Stacks. |
| 29 | Pawn Storm | Uncommon | `sacrifice`, `chess` | Sacrifice 10 HP to reveal the first solution move. If you solve without using it, +1.0 Heat. |
| 30 | All In | Rare | `sacrifice`, `power` | Your attacks deal +50% damage. You cannot block or dodge. |
| 31 | Queen's Gambit | Rare | `sacrifice`, `timing` | Skip this perk draft entirely. Next draft offers 5 choices, all Rare. |
| 32 | Borrowed Time | Uncommon | `sacrifice`, `tempo` | +30s chess time. Each unused second costs 0.5 HP after the puzzle. |

#### Chess Perks (4)

| # | Name | Rarity | Tags | Effect |
|---|---|---|---|---|
| 33 | Scholar's Gambit | Common | `chess` | +15s chess time |
| 34 | Bishop's Blessing | Uncommon | `chess`, `defensive` | First wrong move doesn't count as a mistake |
| 35 | Grandmaster's Eye | Rare | `chess`, `timing` | Puzzle shows which piece to move (but not where). Correct first-try bonus: +0.5 Heat. |
| 36 | Deep Calculation | Uncommon | `chess` | Puzzles with 3+ solution moves give ×1.5 Heat |

#### Boxing Perks (4)

| # | Name | Rarity | Tags | Effect |
|---|---|---|---|---|
| 37 | Clinch Master | Common | `boxing`, `defensive` | Clinch recovers 30 stamina instead of 20 |
| 38 | Southpaw | Uncommon | `boxing`, `speed` | Hooks have -20% dodge chance (harder to avoid) |
| 39 | Body Work | Uncommon | `boxing`, `power` | Hits to body (cross, hook) reduce opponent max stamina by 2 permanently per fight |
| 40 | Corner Man | Rare | `boxing` | Between boxing rounds within a fight, recover 15% HP |

### 3.4 Perk Draft Changes

**Current:** 3 cards, pick 1. Happens between fights only.

**New:**

- **Between fights:** Offered 3 perks, pick 1 (unchanged count but far deeper choices)
- **After a "Brilliant" chess solve (Heat ≥ 4.0):** Bonus mini-draft — pick 1 of 2 Common perks immediately before boxing. Reward for chess excellence.
- **Queen's Gambit interaction:** Skip a draft → next draft has 5 Rare choices.
- **Card display upgrade:** Each card now shows its tags as colored pips, and if picking it would trigger a Set Bonus, the bonus is previewed in gold text at the bottom of the card.
- **Synergy preview:** When hovering a perk card, any existing perks that share a tag glow in the perk sidebar.

---

## 4. Core System: Boxing Rework

### 4.1 Combo Sequences

Single-action turns are replaced by **2-action sequences** (expandable to 3-action in later updates). Each turn, the player queues two actions that resolve in order.

**Why 2 actions:** This creates meaningful sequences without overwhelming the player. "DODGE then UPPERCUT" is a fundamentally different choice than "UPPERCUT then DODGE."

**Combo Examples:**

| Sequence | Name | Bonus |
|---|---|---|
| DODGE → UPPERCUT | Slip Counter | If dodge succeeds, uppercut is guaranteed hit |
| JAB → JAB | Double Tap | Second jab costs 50% stamina |
| JAB → CROSS | One-Two | Cross gets +3 damage |
| BLOCK → HOOK | Rope-a-Dope | Hook deals +damage equal to amount blocked |
| BLOCK → BLOCK | Hunker Down | Second block reduces damage by 75% |
| HOOK → UPPERCUT | Haymaker Combo | If hook lands, uppercut dodge chance halved |
| CLINCH → JAB | Dirty Boxing | Jab is guaranteed hit (holding opponent) |
| DODGE → DODGE | Float | Recover 5 stamina, both dodges get +10% success |

**Resolution order per turn:**
1. Player Action 1 resolves vs. Opponent Action 1
2. Player Action 2 resolves vs. Opponent Action 2
3. Combo bonuses apply
4. Stamina costs tallied
5. KO check

**Opponent combos:** Opponents also use 2-action sequences, and their patterns become part of their identity.

### 4.2 Telegraph System v2

Replace RNG-vague hints with **readable patterns:**

**Tell Window:** Before each turn, the opponent's portrait plays a brief animation (0.8s) that hints at their sequence. This is not random — it's deterministic per opponent archetype and learnable.

| Tell Animation | Meaning |
|---|---|
| Shoulder roll | First action is DODGE |
| Glove tap (light) | First action is JAB |
| Weight shift back | First action is BLOCK |
| Teeth grit + lean forward | First action is heavy attack (HOOK or UPPERCUT) |
| Arms drop | CLINCH incoming |
| Feint jab (pulls back) | First action is a FEINT — the real attack is Action 2 |

**Per-opponent tells:**

- **Vinnie:** Telegraphs everything. No feints. Turn 1 is always JAB → JAB. The tutorial opponent.
- **Elena:** Has feints. 30% of her tells are reversed. She'll show "heavy attack" but throw JAB → CROSS. The player must learn which tells are real through repetition across runs.
- **Magnus:** Phase 1 (HP >60%) has honest tells. Phase 2 (HP ≤60%) starts feinting. Phase 3 (HP ≤30%) — no tells at all, reads go dark. You must predict from pattern memory.

### 4.3 Stamina as Strategic Resource

Stamina becomes the primary tension driver:

- **Desperation zone (stamina < 20):** UI shifts, screen narrows slightly. Player is vulnerable but some perks activate here.
- **Clinch decision:** Clinching now only recovers stamina for the initiator (not both). The opponent gets a free Action 2 (uncontested). High cost for the recovery.
- **Stamina damage:** New mechanic — Body Work perk and certain opponent attacks can reduce *max* stamina within a fight. Getting body-worked means fewer options late in the fight.

### 4.4 Revised Action Stats (for 2-Action System)

| Action | Damage | Stamina Cost | Dodge Chance | Notes |
|---|---|---|---|---|
| JAB | 5 | 6 | 20% | Fast, cheap, combo starter |
| CROSS | 10 | 12 | 35% | Solid, good in combos |
| HOOK | 15 | 20 | 50% | Heavy, body damage |
| UPPERCUT | 22 | 28 | 65% | Devastating finisher |
| BLOCK | 0 | -8 (recover) | — | 50% damage reduction, stamina recovery |
| DODGE | 0 | 10 | — | Avoid damage, enables counters |
| CLINCH | 0 | -20 (recover) | — | Big recovery, but opponent gets free Action 2 |

Stamina costs slightly reduced across the board to support 2-action economy.

---

## 5. Core System: Opponent Gimmicks

Each opponent now has a **unique rule** that changes how you play against them. This is displayed during Opponent Reveal and cannot be changed.

### 5.1 Roster (MVP v0.2 — 5 Opponents)

| # | Name | Archetype | HP | Gimmick | Chess Diff |
|---|---|---|---|---|---|
| 1 | Vinnie "The Pawn" Kowalski | BRAWLER | 60 | **No Gimmick** — pure tutorial fight. Telegraphs everything. | 1 |
| 2 | Suki "The Knight" Tanaka | GLASS_CANNON | 50 | **L-Shaped** — her combos always alternate attack and movement (attack→dodge or dodge→attack). Predictable but deadly if you guess wrong. | 2 |
| 3 | Elena "The Bishop" Petrov | TECHNICIAN | 80 | **Diagonal Thinking** — she gains +2 damage per round regardless of chess performance. You must outpace her scaling by keeping your Heat high. | 3 |
| 4 | Marcus "The Rook" Williams | TURTLE | 120 | **Fortress** — cannot be KO'd by single hits (minimum 1 HP after any single action). Must be worn down with combos. Blocking heals him for 2 HP. Punishes passive play. | 4 |
| 5 | Magnus "The Grandmaster" Thunderfist | BOSS | 100 | **Adaptation** — Magnus drafts 1 visible perk before each boxing round from a curated boss pool. By the final round he has a build. You're in an arms race. | 5 |

### 5.2 Boss Perk Pool (Magnus Only)

Magnus draws from these between rounds:

| Perk | Effect |
|---|---|
| Grandmaster's Prep | +1.0 Heat equivalent on his attacks |
| Castling | Block restores 5 HP |
| Promotion | All attacks deal +3 after round 3 |
| King's Guard | 25% damage reduction |
| Endgame Vision | Reads your Action 1 before choosing his Action 2 |

These are shown to the player during the chess phase so they can plan around it.

---

## 6. Core System: Run Structure Rework

### 6.1 Tournament Format

**Current:** 3 opponents, linear.

**New:** 5 opponents in a bracket with a **fork after fight 2.**

```
Fight 1: Vinnie (mandatory tutorial)
Fight 2: Suki (mandatory)
         ┌─── Path A: Elena → Magnus
Fight 3: ┤
         └─── Path B: Marcus → Magnus
Fight 4: (chosen path opponent)
Fight 5: Magnus (mandatory boss)
```

This gives the player a meaningful choice — face the scaling damage of Elena or the immovable wall of Marcus — and adds replayability even with the same fighter.

### 6.2 Healing and Perk Draft Timing

| Event | What Happens |
|---|---|
| After Fight 1 | Heal 40% HP. Perk draft (3 choices). |
| After Fight 2 | Heal 30% HP. Perk draft (3 choices). Path fork choice. |
| After Fight 3 | Heal 30% HP. Perk draft (3 choices). |
| After Fight 4 | Heal 20% HP. Perk draft (3 choices). |
| Fight 5 (Magnus) | No heal. No draft. Use what you've built. |

Healing decreases as the run progresses — resources get tighter, tension rises.

### 6.3 Fight Structure (Revised)

Each fight now has up to **3 rounds** (was 4):

```
Round 1: Chess → Boxing (6 turns)
Round 2: Chess → Boxing (6 turns)
Round 3: Chess → Boxing (8 turns, final stand)
```

Reduced from 4 rounds to 3 to keep fights snappy. Turn count increases on the final round to allow for climactic finishes. If no KO after round 3, the fighter with higher HP% wins.

---

## 7. Scoring, Unlocks, and Meta-Progression

### 7.1 Run Rating

Each completed run (win or loss) receives a **Tournament Rating** from F to S+:

```
Base Score:
  +1000 per opponent defeated
  +500 for tournament win

Multipliers:
  Speed:     avg_puzzle_time < 20s  → ×1.3
  Accuracy:  total_mistakes == 0    → ×1.5
  Aggression: total_damage_dealt / total_damage_taken > 3.0 → ×1.2
  Style:     used ≥ 5 different boxing actions → ×1.1
  Synergy:   triggered ≥ 2 set bonuses → ×1.3

Rating Thresholds:
  F:  < 1000
  D:  1000 – 1999
  C:  2000 – 2999
  B:  3000 – 3999
  A:  4000 – 5499
  S:  5500 – 6999
  S+: 7000+
```

### 7.2 Unlock System

Achievements unlock new perks and fighters. Each achievement is a sentence the player can read and think "I bet I could do that."

| Achievement | Condition | Unlock |
|---|---|---|
| Glass Jaw | Win a run without ever blocking | Glass Cannon perk |
| Speed Demon | Solve 5 puzzles in under 15s (cumulative) | Lightning Reflexes perk |
| Chess Master | Complete a run with 0 puzzle mistakes | Grandmaster's Eye perk |
| The Brawler | Deal 200+ total damage in a single run | The Brawler (fighter) |
| The Grandmaster | Win a run with S rating | The Grandmaster (fighter) |
| The Hustler | Win a run using only jabs and dodges | The Hustler (fighter) |
| The Prodigy | Reach 5.0× Heat in any puzzle | The Prodigy (fighter) |
| Arms Race | Defeat Magnus while he has 3+ perks | Endgame Vision perk (player version) |
| Sacrifice Everything | Win a run with ≥3 sacrifice perks | Blood Sacrifice perk |
| One-Punch | KO any opponent in a single boxing turn | Knockout Artist perk |

### 7.3 Fighter Differentiation

Each fighter should feel like a different game:

| Fighter | HP | Stamina | Passive | Playstyle |
|---|---|---|---|---|
| The Rookie | 100 | 100 | None — pure skill | Balanced, learn the game |
| The Brawler | 130 | 80 | Jabs deal +1 damage | Boxing-heavy, overwhelm with volume |
| The Grandmaster | 70 | 120 | +20s chess time | Chess-heavy, maximize Heat |
| The Hustler | 90 | 100 | See opponent's Action 1 before choosing your Action 2 | Reactive, counter-puncher |
| The Prodigy | 60 | 130 | All perk effects ×1.5 (before Heat) | Build-dependent, glass cannon with perks |

---

## 8. Juice and Feel

### 8.1 Chess Phase Feel

- **Correct move:** Board piece slides with a satisfying snap. Green particle burst. Small screen shake. A rising tone (pitch increases with each consecutive correct move in a multi-move puzzle).
- **Fast solve:** Time freezes for 0.5s. "BRILLIANT" text punches onto screen at 2× scale, settles to 1×. Heat meter fills with a flame animation and whoosh SFX. The whole board briefly glows gold.
- **Mistake:** Piece rubber-bands back. Red flash. Buzzer. Timer visibly chunks down by 5s with a crack effect.
- **Failure:** Board cracks down the middle (animation). Heat meter drains with a sad deflation sound. Cold blue wash over screen.
- **Timer under 10s:** Heartbeat SFX. Timer pulses red. Board squares subtly pulse.

### 8.2 Boxing Phase Feel

- **Damage numbers:** Pop up above fighters, float upward, fade. White for normal, gold for Heat-boosted, red for critical.
- **Combo bonus:** When a named combo triggers (Slip Counter, One-Two, etc.), the combo name flashes across screen in Balatro-style bold typography with a satisfying CHUNK sound.
- **Heat multiplier in action:** When a Heat-scaled perk activates, show the math: "Quick Hands: +2 × 3.5 = +7" — numbers cascade and multiply visually, Balatro-style.
- **KO:** Slow motion on the final hit (0.3s). Camera shake. Opponent slides off-screen. "K.O." stamps on screen in huge distressed font.
- **Low HP:** Screen vignette darkens. Heartbeat SFX returns from chess phase (connecting the two phases sonically).

### 8.3 Perk Draft Feel

- **Card flip:** Staggered flip animation (already exists, keep it).
- **Synergy trigger:** When picking a perk that completes a Set Bonus, all perks sharing that tag fly to center screen, the Set Bonus name explodes outward in the tag's color. "SET BONUS: SPEED — JABS COST 0 STAMINA." Massive dopamine hit.
- **Rare perk:** Rare cards have a holographic shimmer effect on the border. The card vibrates slightly.
- **Queen's Gambit skip:** If player skips the draft, the 3 cards shatter dramatically, and "QUEEN'S GAMBIT" text appears with a chess piece animation. Building anticipation for the big draft next round.

### 8.4 Opponent Reveal Feel

- **Card flip already exists** — enhance it with opponent-specific flair:
  - Vinnie: Card crumples slightly, like it's cheap
  - Elena: Card unfolds precisely, like origami
  - Magnus: Card doesn't flip — it fades in through static, like he's been watching you

---

## 9. Data Architecture Changes

### 9.1 Perk JSON Schema (Updated)

```json
{
  "id": "glass_cannon",
  "name": "Glass Cannon",
  "description": "Max HP halved. All damage dealt ×2.",
  "type": "sacrifice",
  "tags": ["power", "sacrifice"],
  "rarity": "rare",
  "effect": "glass_cannon",
  "values": {
    "hp_multiplier": 0.5,
    "damage_multiplier": 2.0
  },
  "heat_scaled": true,
  "flavor": "They'll need a mop when you're done. Or when they're done with you."
}
```

Key additions: `tags` array, `values` dict (replaces single `value`), `heat_scaled` boolean, `flavor` text.

### 9.2 Opponent JSON Schema (Updated)

```json
{
  "id": "elena",
  "name": "Elena \"The Bishop\" Petrov",
  "archetype": "TECHNICIAN",
  "hp": 80,
  "stamina": 90,
  "damage_mod": 1.0,
  "defense_mod": 1.0,
  "chess_difficulty": 3,
  "gimmick": {
    "id": "scaling_damage",
    "name": "Diagonal Thinking",
    "description": "Gains +2 damage every round regardless of chess performance.",
    "value_per_round": 2
  },
  "tells": {
    "honest_ratio": 0.7,
    "feint_actions": ["HOOK", "UPPERCUT"]
  },
  "combo_patterns": [
    ["JAB", "CROSS"],
    ["DODGE", "HOOK"],
    ["BLOCK", "UPPERCUT"]
  ],
  "flavor": "Former chess prodigy turned amateur boxer. Reads your patterns like an open book.",
  "puzzle_themes": ["combination", "positional", "sacrifice"]
}
```

Key additions: `gimmick` object, `tells` object, `combo_patterns` array.

### 9.3 Run State (GameManager Additions)

```gdscript
# New state variables
var heat: float = 1.0
var heat_retained: float = 0.0
var base_heat_bonus: float = 0.0   # permanent bonuses (Flow State, sacrifice set)
var tag_counts: Dictionary = {}     # {"speed": 2, "power": 1, ...}
var active_set_bonuses: Array = []  # ["speed_2", "power_2"]
var blood_sacrifice_stacks: int = 0 # permanent damage from Blood Sacrifice
var run_score: int = 0
var run_multipliers: Dictionary = {}
var path_choice: String = ""        # "A" or "B"
var opponent_perks: Array = []      # Magnus's perks
```

---

## 10. Implementation Priority

### Phase 1 — The Engine (Week 1–2)

**Goal:** Heat system + expanded perks make the game feel different.

| Task | Effort | Impact |
|---|---|---|
| Implement Heat calculation in GameManager | Medium | Critical |
| Heat display UI (thermometer between portraits) | Medium | High |
| Refactor perks to use `tags` and `values` schema | Medium | Critical |
| Implement tag counting and Set Bonus detection | Medium | High |
| Add 28 new perks to JSON and implement effects | Large | Critical |
| Set Bonus activation logic and display | Medium | High |
| Heat scaling on perk effects in CombatManager | Medium | Critical |
| Perk draft synergy preview (tag highlighting) | Small | Medium |

### Phase 2 — The Fight (Week 3–4)

**Goal:** Boxing feels like Punch-Out, not a coin flip.

| Task | Effort | Impact |
|---|---|---|
| 2-action combo input UI | Large | Critical |
| Combo resolution logic in CombatManager | Large | Critical |
| Named combo detection and bonus application | Medium | High |
| Telegraph animation system | Large | High |
| Opponent tell patterns (per archetype) | Medium | High |
| Revised AI to use 2-action sequences | Medium | Critical |
| Stamina rebalance for 2-action economy | Small | Medium |

### Phase 3 — The Opponents (Week 5)

**Goal:** Every fight feels unique and memorable.

| Task | Effort | Impact |
|---|---|---|
| Add Suki and Marcus opponents + JSON data | Medium | High |
| Implement opponent gimmick system | Medium | High |
| Implement Marcus "Fortress" gimmick (can't be one-shot) | Small | Medium |
| Implement Elena "Diagonal Thinking" scaling | Small | Medium |
| Implement Magnus perk drafting + boss perk pool | Medium | High |
| Path fork UI in tournament bracket | Medium | Medium |
| 5-fight run structure with decreasing heals | Small | Medium |

### Phase 4 — The Loop (Week 6)

**Goal:** Players want to run it again.

| Task | Effort | Impact |
|---|---|---|
| Run scoring system | Medium | High |
| Achievement tracking | Medium | High |
| Unlock system (perks and fighters gated behind achievements) | Medium | High |
| Results screen overhaul (rating, score breakdown) | Medium | Medium |
| Save/load for unlock state (not run state — roguelike) | Medium | Medium |

### Phase 5 — The Polish (Week 7–8)

**Goal:** It *feels* like Balatro.

| Task | Effort | Impact |
|---|---|---|
| Chess solve juice (particles, screen shake, sound) | Medium | High |
| Boxing damage number popups with Heat math display | Medium | High |
| Combo name flash effect | Small | Medium |
| Set Bonus activation animation | Medium | High |
| Perk card holographic/shimmer for rares | Small | Medium |
| Opponent reveal per-character flair | Small | Low |
| Heartbeat SFX system (low timer + low HP) | Small | Medium |
| KO slow-motion effect | Small | Medium |

---

## 11. Success Metrics

How we know v0.2 is working:

- **"One more run" test:** Playtesters consistently start a second run immediately after their first without prompting.
- **Build diversity:** Across 10 playtester runs, at least 4 distinct "build archetypes" emerge naturally (speed build, power build, sacrifice build, tempo build, etc.).
- **Chess matters:** Playtesters report that the chess phase feels exciting and consequential, not like a chore before boxing.
- **Opponent identity:** Playtesters can name all 5 opponents and describe what makes each one different, after 3 runs.
- **Combo discovery:** Playtesters discover at least 1 perk synergy they weren't expecting and tell someone about it.

---

## 12. Out of Scope for v0.2

- Online multiplayer
- Procedural opponent generation
- Full Lichess puzzle database (stick with curated puzzles)
- Music (SFX only for now)
- Polished art (colored rectangles + typography is fine, this is about systems)
- Settings menu
- Controller support
- Mobile

---

## Appendix A: Perk Quick Reference (All 40)

| # | Name | Tags | Rarity | One-liner |
|---|---|---|---|---|
| 1 | Quick Hands | speed, boxing | C | Jabs +2 dmg |
| 2 | Blitz Mode | speed, sacrifice | R | Half chess time, ×2 Heat |
| 3 | Tempo Master | speed, timing | U | Fast solve = guaranteed first hit |
| 4 | Flicker Jab | speed | C | Jab dodge chance → 10% |
| 5 | Speedbag | speed, boxing | U | 3 jabs landed = +1 jab dmg (stacks) |
| 6 | Lightning Reflexes | speed, defensive | R | +15% dodge chance |
| 7 | Haymaker | power, boxing | U | Uppercuts cost 50% less stamina |
| 8 | Glass Cannon | power, sacrifice | R | Half HP, ×2 damage |
| 9 | Heavyweight | power | C | Cross +4 dmg |
| 10 | Knockout Artist | power, timing | R | Opp <20% HP = guaranteed uppercut |
| 11 | Iron Fists | power | U | Hook +5 dmg |
| 12 | Pile Driver | power, tempo | U | Consecutive attacks = +1 dmg each |
| 13 | Zugzwang | timing, chess | R | <10s solve = opp forced CLINCH |
| 14 | Time Pressure | timing, tempo | U | Seconds left = +0.5 dmg first turn |
| 15 | Patience | timing, defensive | C | Block turn 1 = +3 dmg turns 2–8 |
| 16 | Last Second | timing, sacrifice | R | <5s left triples Heat, fail = -15 HP |
| 17 | Metronome | timing | U | Alternate atk/def = +2 per attack |
| 18 | Iron Jaw | defensive, boxing | C | -1 incoming dmg (Heat scaled) |
| 19 | Second Wind | defensive | R | <10% HP = recover 30% once |
| 20 | Rope-a-Dope | defensive, tempo | U | Blocking stores dmg, released on next attack |
| 21 | Turtle Shell | defensive | C | Block = 60% reduction |
| 22 | Endurance | defensive, boxing | C | +20 max stamina |
| 23 | Adrenaline | tempo, boxing | U | 3 hits no damage taken = +5s chess |
| 24 | Intimidation | tempo, power | U | Opp <50% HP end of round = easier puzzle |
| 25 | Momentum | tempo | C | Consecutive successes = +0.1 Heat |
| 26 | Mind Over Muscle | tempo, chess | R | Heat applies at ×1.5 |
| 27 | Flow State | tempo, timing | R | Solve + win round = +0.3 permanent base Heat |
| 28 | Blood Sacrifice | sacrifice | R | -5 HP per puzzle, +1 permanent dmg |
| 29 | Pawn Storm | sacrifice, chess | U | Pay 10 HP for hint, skip it = +1.0 Heat |
| 30 | All In | sacrifice, power | R | +50% dmg, can't block/dodge |
| 31 | Queen's Gambit | sacrifice, timing | R | Skip draft → next = 5 Rare choices |
| 32 | Borrowed Time | sacrifice, tempo | U | +30s chess, unused seconds cost HP |
| 33 | Scholar's Gambit | chess | C | +15s chess time |
| 34 | Bishop's Blessing | chess, defensive | U | First mistake free |
| 35 | Grandmaster's Eye | chess, timing | R | Piece hint + first-try bonus |
| 36 | Deep Calculation | chess | U | 3+ move puzzles = ×1.5 Heat |
| 37 | Clinch Master | boxing, defensive | C | Clinch = 30 stamina |
| 38 | Southpaw | boxing, speed | U | Hooks -20% dodge chance |
| 39 | Body Work | boxing, power | U | Cross/Hook reduce opp max stamina by 2 |
| 40 | Corner Man | boxing | R | +15% HP between boxing rounds |

---

*End of PRD. Let's build this thing.*
