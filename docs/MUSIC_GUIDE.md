# Music Sourcing Guide — Chess Boxing Roguelike

## The Vibe

Balatro's soundtrack is jazzy, lo-fi, and slightly sinister — smooth piano over muted drums with a retro warmth, like you're in a backroom card game at 2 AM. Our version tilts darker and more physical — the jazz should feel like a smoky boxing gym, not a cocktail lounge.

**Keywords to search:** jazz lo-fi, noir jazz, dark jazz instrumental, smoky jazz, retro game jazz, casino jazz, card game music, boxing jazz

---

## Track Slots & What to Look For

The MusicManager expects `.ogg` files in `assets/audio/music/`. Here's every slot:

### 1. `menu_jazz.ogg` — Main Menu / Fighter Select

**Mood:** Cool, inviting, confident. The "sit down, let's play" track.
**Tempo:** Slow-medium (~80-100 BPM)
**Instruments:** Piano lead, walking bass, brushed drums
**Balatro reference:** The main menu theme — chill but with swagger

**Where to find:**
- Mixkit → search "jazz piano" or "lounge jazz"
- Bensound → "The Jazz Piano" (piano trio, perfect vibe) — [bensound.com/royalty-free-music/jazz](https://www.bensound.com/royalty-free-music/jazz)
- Pixabay → search "noir jazz" or "card game"

### 2. `tournament_tension.ogg` — Tournament Bracket / Opponent Reveal

**Mood:** Building tension, anticipation. Like sizing up your opponent across the ring.
**Tempo:** Slow (~70-90 BPM)
**Instruments:** Sparse piano, deep bass, subtle percussion, maybe a muted trumpet
**Key quality:** Should feel like something is about to happen

**Where to find:**
- Free Music Archive → search "dark jazz" or "tension jazz"
- Audionautix → jazz collection, look for minor-key tracks — [audionautix.com/free-music/jazz](https://audionautix.com/free-music/jazz)
- Pixabay → search "suspense jazz"

### 3. `chess_lofi.ogg` — Chess Puzzle (Normal)

**Mood:** Focused, contemplative, slightly tense. Brain at work.
**Tempo:** Medium (~90-110 BPM)
**Instruments:** Lo-fi piano, vinyl crackle, soft hi-hats, warm bass
**Key quality:** Should not distract from puzzle solving. Gentle enough to think to, but interesting enough to feel atmospheric.

**Where to find:**
- Pixabay → search "lo-fi study" or "lo-fi jazz" — [pixabay.com/music/search/lo-fi%20jazz/](https://pixabay.com/music/search/lo-fi%20jazz/)
- Chosic → lo-fi + jazz filter — [chosic.com/free-music/jazz/](https://www.chosic.com/free-music/jazz/)
- Mixkit → search "thinking" or "puzzle"

### 4. `chess_tense.ogg` — Chess Puzzle (Timer < 15s)

**Mood:** Urgency. Clock is ticking. Heart rate up.
**Tempo:** Faster (~120-140 BPM) or same tempo but more rhythmic drive
**Instruments:** Add ride cymbal, busier bass line, maybe a staccato piano pattern
**Key quality:** Should make you feel the time pressure without being annoying. Ideally a more intense variation of the normal chess track.

**Where to find:**
- Same sources as chess_lofi but search "uptempo jazz" or "fast jazz"
- Audionautix → jazz-funk section (more energy) — [audionautix.com/free-music/jazz-funk](https://audionautix.com/free-music/jazz-funk)
- Alternatively: use the same track as chess_lofi and pitch it up slightly in Audacity

### 5. `boxing_groove.ogg` — Boxing (Normal)

**Mood:** Action. Swagger. You're in the ring. This is the main gameplay track.
**Tempo:** Medium-fast (~110-130 BPM)
**Instruments:** Driving drums, funky bass, organ or electric piano stabs, maybe brass hits
**Balatro reference:** When the game picks up energy during play

**Where to find:**
- Mixkit → search "funk" or "action jazz"
- Audionautix → jazz-funk section (best bet for this slot)
- Pixabay → search "boxing" or "fight music funk"
- FStudios → action/funk section — [fesliyanstudios.com](https://www.fesliyanstudios.com/royalty-free-music/downloads-c/jazz-music/20)

### 6. `boxing_intense.ogg` — Boxing (Low HP, Either Fighter)

**Mood:** Desperate. The fight could end any second. Heartbeat energy.
**Tempo:** Fast (~130-150 BPM)
**Instruments:** Heavy drums, distorted bass, aggressive piano or organ, maybe ride cymbal going hard
**Key quality:** Should feel like the climax of a fight scene in a movie

**Where to find:**
- Pixabay → search "intense jazz" or "action dramatic"
- Free Music Archive → "free jazz" section (more chaotic energy)
- Alternatively: take boxing_groove.ogg, boost the high frequencies, add some distortion in Audacity

### 7. `boxing_boss.ogg` — Boxing vs. Magnus (Final Boss)

**Mood:** Epic. This is the final fight. Everything you've built leads here.
**Tempo:** Variable (~100-140 BPM)
**Instruments:** Full band — piano, bass, drums, brass, maybe strings. Bigger arrangement than other tracks.
**Key quality:** Should feel special. The player should know "this is THE fight" from the music alone.

**Where to find:**
- Free Music Archive → search "big band jazz" or "epic jazz"
- Pixabay → search "epic jazz" or "boss fight jazz"
- This is the hardest track to find for free — consider commissioning or AI-generating this one via Suno/Udio if free options don't cut it

### 8. `draft_smooth.ogg` — Perk Draft Screen

**Mood:** Smooth, rewarding, a breather between fights. Browsing your options.
**Tempo:** Slow (~70-90 BPM)
**Instruments:** Smooth piano, maybe vibraphone, gentle bass, no drums or very light brushes
**Balatro reference:** The shop music — contemplative, satisfying

**Where to find:**
- Bensound → "Hip Jazz" or smoother tracks
- Mixkit → search "smooth jazz" or "vibraphone"
- Chosic → jazz + chill filter

### 9. `victory_fanfare.ogg` — Results Screen (Win)

**Mood:** Triumphant but cool. You didn't just win, you looked good doing it.
**Tempo:** Medium (~100 BPM)
**Instruments:** Bright piano, walking bass, celebratory drum pattern, maybe a horn melody
**Key quality:** Short-loopable (30-60s). Should make the player feel like a champion.

**Where to find:**
- Mixkit → search "victory" or "celebration jazz"
- Pixabay → search "winner" or "triumph jazz"

### 10. `results_lose.ogg` — Results Screen (Loss)

**Mood:** Melancholy but not crushing. "Dust yourself off, try again."
**Tempo:** Slow (~60-80 BPM)
**Instruments:** Solo piano or piano + bass. Minor key. Sparse.
**Key quality:** Short-loopable (30-60s). Should motivate a retry, not depress.

**Where to find:**
- Pixabay → search "sad piano jazz" or "melancholy jazz"
- Free Music Archive → "solo piano" jazz
- Bensound → sadder/slower jazz tracks

---

## File Format Requirements

- **Format:** OGG Vorbis (`.ogg`) — Godot's preferred streaming format
- **Sample rate:** 44100 Hz
- **Bitrate:** 128-192 kbps (keeps file size reasonable)
- **Looping:** Tracks should loop cleanly. The MusicManager sets `loop = true` on all OGG streams.
- **Length:** 60-180 seconds per track is ideal. Shorter loops are fine if they're clean.

### Converting to OGG

If you download MP3 or WAV files, convert with:
```bash
# Using ffmpeg
ffmpeg -i input.mp3 -c:a libvorbis -q:a 5 output.ogg

# Using Audacity
# File → Export → Export as OGG → Quality 5
```

---

## Quick Start (Minimum Viable Music)

If you want music TODAY with minimal effort, grab these 4 tracks and reuse them:

| Slot | Source | Track |
|---|---|---|
| Menu + Draft + Tournament | Bensound | "The Jazz Piano" |
| Chess (both) | Pixabay | Any "lo-fi jazz" track |
| Boxing (all 3 slots) | Audionautix | Any "jazz-funk" track |
| Results (both) | Mixkit | Any "jazz piano" short loop |

That's 4 downloads to go from silence to atmosphere. Upgrade individual slots later.

---

## License Checklist

Before shipping, confirm for each track:

- [ ] License allows use in commercial games
- [ ] Attribution requirements noted (add to credits screen)
- [ ] No "personal use only" restrictions
- [ ] Track is not AI-generated from a platform that restricts commercial use

**Safe bets (no attribution needed):** Mixkit, Pixabay (post-2019 uploads), Chosic CC0 tracks
**Attribution required:** Audionautix (CC-BY 4.0), most Free Music Archive tracks

---

## Recommended Workflow

1. **Browse Pixabay and Mixkit first** — instant downloads, no signup, clear licenses
2. **Audition tracks against the game** — drop them in `assets/audio/music/` and hit play
3. **Use Audacity** to trim loops, adjust volume, convert to OGG
4. **Test crossfades** — the MusicManager crossfades over 1.5s, so make sure track intros/outros aren't jarring
5. **Iterate** — placeholder tracks now, polish later

Good luck hunting. The right 4-5 tracks will make this game feel 10× more polished overnight.
