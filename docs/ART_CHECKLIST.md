# Art Asset Checklist

Comprehensive list of every sprite, texture, and visual asset needed to complete the game.

## HIGH PRIORITY — Blocks Gameplay

- [ ] **Magnus animation sheet** — Boss has only static portrait, no boxing animation (`animsheet_magnus.png`)
- [ ] **Magnus frame map JSON** — `data/sprite_frames/animsheet_magnus_frames.json`
- [ ] **Marcus frame map JSON** — `data/sprite_frames/animsheet_punch_2_frames.json` (sheet exists, no frame definitions)
- [ ] **Suki frame map JSON** — `data/sprite_frames/animsheet_punch_3_frames.json` (sheet exists, no frame definitions)
- [ ] **Elena frame map JSON** — `data/sprite_frames/animsheet_punch_4_frames.json` (sheet exists, no frame definitions)

## MEDIUM PRIORITY — Blocks Unlockable Fighters

Each needs a neutral portrait + ~6 idle animation frames:

- [ ] **Grandmaster** — `grandmaster_neutral.png` + `grandmaster_idle/frame_0..5.png`
- [ ] **Brawler** — `brawler_neutral.png` + `brawler_idle/frame_0..5.png`
- [ ] **Hustler** — `hustler_neutral.png` + `hustler_idle/frame_0..5.png`
- [ ] **Prodigy** — `prodigy_neutral.png` + `prodigy_idle/frame_0..5.png`
- [ ] **64px portraits** for each above (for tournament bracket display)
- [ ] **Punch animation sheets** for each above (4x2 grid, like opponents)

## LOWER PRIORITY — Polish & Feel

### Backgrounds & Atmosphere

- [ ] **Main menu background** — currently solid `#0D0A14`, could use a textured/illustrated bg
- [ ] **Scene transition art** — any between-phase splash screens
- [ ] **Results screen background** — currently text-only

### Chess Phase

- [ ] **Chess piece sprites on board** — currently text symbols (K/Q/R/B/N/P); piece icon PNGs exist in `assets/sprites/icons/` but aren't used on the board
- [ ] **Missing chess icons** — Queen (white & dark), Rook dark, Bishop dark, King dark — only partial set exists
- [ ] **Board square textures** — currently ColorRects with hardcoded colors

### Boxing Phase

- [ ] **Action icons** — JAB/CROSS/UPPERCUT are text-only, no illustrations
- [ ] **Hit/impact VFX sprites** — currently all code-driven (screen shake, flash)
- [ ] **QTE visual indicator art** — timing bar graphics
- [ ] **Combo counter art** — currently a text label

### Perk & Shop System

- [ ] **Perk card icons** — currently ASCII symbols (`>>`, `!!`, `[]`, etc.)
- [ ] **Shop item icons** — currently text descriptions only
- [ ] **Rarity border/glow treatments** for perk cards (common/uncommon/rare)

### UI Chrome

- [ ] **Button textures** — currently theme-styled flat panels, could have illustrated borders
- [ ] **Panel/card nine-patch textures** — for perk cards, shop panels, info boxes
- [ ] **HP bar custom texture** — currently default ProgressBar
- [ ] **Heat meter art** — visual representation of heat multiplier

### Misc

- [ ] **App icon** — game icon for window/export
- [ ] **Logo/title art** — game title treatment for main menu
- [ ] **Loading/splash screen**

## Already Complete

- ✅ Rookie fighter (neutral + 6 idle frames)
- ✅ 4 opponent portraits (64px + neutral) — Vinnie, Suki, Elena, Marcus
- ✅ Magnus portraits (64px + neutral)
- ✅ Vinnie animation sheet + JSON frame map
- ✅ 4 opponent punch animation sheets (Vinnie, Marcus, Suki, Elena)
- ✅ All 9 tactic card icons
- ✅ CRT shader, grain shader, particles shader
- ✅ Balatro font
- ✅ Global theme (`theme.tres`)
- ✅ Partial chess piece icons (pawn, rook, knight, bishop, king — white & some dark)
