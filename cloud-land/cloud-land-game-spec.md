# Cloud Land — Game Specification

> **Source of truth for all behavioral and gameplay logic.**
> For visual layout, sprite art, animation states, and level mocks, refer to the Figma file:
> https://www.figma.com/design/CWiYu2rnBatKq8C4Uw5UPa/cloud-land-nes-game

---

## Build Target

- **Output:** A valid `.nes` ROM playable in any NES emulator (FCEUX, Mesen, Nestopia)
- **Language:** 6502 assembly using **ca65/ld65** (cc65 suite)
- **Mapper:** NROM-256 (mapper 0) — 32KB PRG-ROM + 8KB CHR-ROM
- **iNES header:** 2 PRG banks, 1 CHR bank, mapper 0, vertical mirroring
- **Build command:**
  ```
  ca65 -o main.o src/main.asm
  ld65 -C nes.cfg -o cloud-land.nes main.o
  ```
- **Project structure:**
  ```
  cloud-land/
  ├── src/
  │   ├── header.asm          ; 16-byte iNES header
  │   ├── reset.asm           ; Hardware init (exact boot sequence required)
  │   ├── main.asm            ; Entry point, includes all modules, main loop + state machine
  │   ├── nmi.asm             ; NMI handler — flush VRAM buffer, OAM DMA, palette updates
  │   ├── ppu.asm             ; VRAM buffer system, draw_text, nametable/palette load routines
  │   ├── input.asm           ; Controller read (latching, 8-bit shift read, edge detection)
  │   ├── player.asm          ; Player update: physics, movement, animation, state
  │   ├── birds.asm           ; Bird entity system: patrol, oscillation, animation, respawn
  │   ├── hearts.asm          ; Heart spawn/despawn, collection, valid-position lookup
  │   ├── collision.asm       ; Platform AABB checks, bird-player hitbox, screen bounds
  │   ├── constants.asm       ; All tunable values: physics, speeds, difficulty tables
  │   ├── gamestate.asm       ; State transition handlers (title, gameplay, dying, clear, gameover, win, pause)
  │   ├── sound.asm           ; SFX triggers and APU channel updates
  │   ├── music.asm           ; Song data, melody/accompaniment playback, envelope system
  │   └── data/
  │       ├── palettes.asm    ; Palette data tables for each level + special screens
  │       ├── levels.asm      ; Platform coordinate tables (x, y) per level, spawn points
  │       ├── strings.asm     ; All game text as null-terminated strings
  │       └── chr.asm         ; CHR tile data inline (.byte sequences for all tiles)
  ├── nes.cfg                 ; ld65 linker config (ZP, RAM, PRG-ROM, CHR-ROM, vectors)
  ├── Makefile                ; Build: ca65 → ld65 → cloud-land.nes
  └── cloud-land-game-spec.md
  ```

---

## Technical Foundation

- **Resolution:** 256x240 pixels
- **Tile grid:** 8x8px — all positions snap to 8px increments where possible
- **HUD region:** y=0 to y=23 (24px tall) — the player can enter this region, but birds and hearts cannot spawn or move here
- **Playfield region:** y=24 to y=239 — birds and hearts are restricted to this region
- **Font:** Press Start 2P style, 8x8px, white for body text. Title screen "CLOUD LAND" uses a 3x3 tile (24x24px) large font.
- **Platform size:** 48x8px (6 tiles wide, 1 tile tall). Platforms may extend partially off-screen edges.
- **Background:** The level background color fills the entire frame — purely visual, no collision
- **Sprite size:** 16x16px (player, birds — implemented as 2x2 hardware sprites); 8x8px (hearts — 1 hardware sprite)

### NES Hardware Constraints

- **Palettes:** 4 background palettes x 4 colors each (first color of each is shared backdrop = level background color). 4 sprite palettes x 4 colors each (first color transparent).
- **Sprite limit:** Max 64 hardware sprites total; max 8 per scanline. At peak: player (4 sprites) + 4 birds (4 sprites each) + 2 hearts (1 each) = 22 sprites.
- **CHR tile budget:** 256 tiles total across two 128-tile pattern tables. Background tiles in $0000-$0FFF, sprite tiles in $1000-$1FFF.
- **VRAM writes:** Never write to PPU ($2006/$2007) outside of vblank. All updates buffered in RAM (192-byte VRAM buffer) and flushed during NMI.
- **Game loop:** "Split" method — game logic runs in the main thread, PPU updates run in NMI only.
- **Zero page:** Used aggressively for frequently accessed variables (entity positions, game state flags, counters).

### NES Palette Index Mapping

| Color | NES Index | Context |
|---|---|---|
| Level 1 / Title BG | $2C | Cyan backdrop |
| Level 2 BG | $2B | Green backdrop |
| Level 3 BG | $21 | Blue backdrop |
| Level 4 BG | $22 | Purple backdrop |
| Level 5 BG | $34 | Pink backdrop |
| White | $30 | Platforms, text |
| Black | $0F | Game Over background |
| Dark red | $16 | Win stripe 1 |
| Orange | $27 | Win stripe 2 |
| Yellow-green | $38 | Win stripe 3 |
| Dark green | $19 | Win stripe 4 |
| Blue | $12 | Win stripe 5 |
| Violet | $14 | Win stripe 6 |
| Dark purple | $03 | Win dialog box backdrop |

---

## Game States

```
TITLE ──[Start]──> GAMEPLAY (Level 1)
                     |
                     ├──[10 hearts]──> LEVEL_CLEAR ──[Start]──> GAMEPLAY (next level)
                     |                                           or WIN (after L5)
                     |
                     ├──[bird hit / fall off]──> DYING ──> GAME_OVER
                     |                                      ├─[lives > 0]──[Start]──> GAMEPLAY (retry level)
                     |                                      └─[lives = 0]──[Start]──> TITLE
                     |
                     └──[Start]──> PAUSED ──[Start]──> GAMEPLAY (resume)
```

| State | Description |
|---|---|
| `TITLE` | Static screen. "CLOUD LAND" (24x24px large font) + "PRESS START" (8x8px font). No animation. |
| `GAMEPLAY` | Active play. HUD visible. Player, birds, hearts all updating. Music playing. |
| `PAUSED` | Blank screen with current level's background color. "PAUSED" centered. HUD visible. All motion frozen. Music stopped. |
| `DYING` | 30-frame death animation. Player shown with vertically-flipped sprite, pops upward then falls with gravity. Birds continue moving. Hearts hidden. After timer: decrement lives, transition to GAME_OVER. |
| `GAME_OVER` | Black background. If lives remain: shows "OOPS!" — score reverts to level start, hearts reset, press Start retries current level. If no lives: shows "GAME OVER" — press Start returns to title (full reset). HUD visible. |
| `LEVEL_CLEAR` | Current level's background color. "LEVEL CLEAR!" and "PRESS START" centered. HUD shows current level + score. Press Start advances to next level. |
| `WIN` | Rainbow stripe background with dark purple dialog box: "YOU WIN!" / "GOODNITE XOXO". HUD shows LEVEL 5 + final score (no lives display). Press Start returns to title. |

---

## Controls

| Input | Action |
|---|---|
| D-pad left/right | Move player left or right |
| A button | Jump (variable height: tap = short jump, hold = higher jump) |
| Start | Title: start game. Gameplay: toggle pause. All other screens: advance. |

---

## HUD Layout

```
LEVEL X      LIVES XX      SCORE XX
```

- "LEVEL X" — top-left (X = 1-5, displayed as current_level + 1)
- "LIVES XX" — center (2-digit, zero-padded)
- "SCORE XX" — top-right (2-digit, zero-padded)
- Score is cumulative across levels (carries over)
- Max score: 50 (10 hearts x 5 levels)
- Win screen HUD omits LIVES display

---

## Player

### Character
A purple cat with yellow eyes and pink paws. 16x16px (2x2 hardware sprites).

### Sprites
| State | Description |
|---|---|
| Standing | Default sprite when no input and on ground |
| Walking | Alternates between walk-frame-1 and walk-frame-2 every 8 frames while moving |
| Jumping | Active while player is airborne |
| Death | Standing sprite vertically flipped (via OAM attributes — no separate CHR tiles) |

### Movement & Physics
- Walk speed: ~1.6 px/frame (8.8 fixed-point: $019A)
- Variable jump height: tap A = -2 px/frame, hold A = -7 px/frame
- Jump can be released early to cut height short
- Gravity: ~0.375 px/frame² (8.8 fixed-point: $0060)
- Terminal velocity: 4 px/frame
- Sub-pixel accumulation for smooth fractional movement
- Left/right movement applies in air as well as on ground
- Player can move into the HUD region (y < 24) — no ceiling

### Collision
- **Platforms:** AABB collision from all sides. Priority: landing (top) > head bump (bottom) > side push. Landing snaps player onto platform surface. Head bump stops upward velocity. Side push prevents horizontal overlap.
- **Screen edges:** Horizontal clamped to 0-240 pixels
- **Fall death:** Y >= 240 triggers death
- **Bird hit:** Non-stomp contact triggers death (see Birds section for stomp rules)

### Hitboxes
- Full 16x16 for platform collision and heart collection
- Reduced 10x10 (offset +3px from sprite origin) for bird collision — forgiving to favor the player

---

## Enemy Birds

### Behavior
- Each level has **4 birds**, one per vertical zone
- Birds fly horizontally across the full screen width, reversing direction at screen edges
- Sprite flips horizontally on direction change
- Birds oscillate vertically within their zone (±12 pixels from zone center, 1px/frame)
- Wing-flap animation: 4 frames in ping-pong pattern (0,1,2,1), cycling every 6 frames
- Birds cannot enter the HUD region (y < 24)

### Bounding Zones

| Zone | Y Center | Oscillation Range |
|---|---|---|
| 0 (top) | 36 | y=24 to y=48 |
| 1 | 76 | y=64 to y=88 |
| 2 | 124 | y=112 to y=136 |
| 3 (bottom) | 172 | y=160 to y=184 |

### Stomp Mechanic
- If player is **falling** (vel_y >= 0) AND **above** the bird (player_y < bird_y) at the moment of collision: **stomp** — bird dies, player bounces upward (-6 px/frame; hold A for reduced bounce of -1 px/frame)
- Any other collision angle = **player death**
- Stomped birds play a brief upward pop then gravity-driven fall animation
- Birds respawn after 5 seconds (300 frames) on the opposite side of the screen from the player
- On respawn, bird speed increases by ~12.5%, capped at 3.0 px/frame

### Spawn
- Each bird starts at a different horizontal position within its zone per level (staggered)
- Birds alternate facing directions
- Initial speed: ~1.0 px/frame ($10 in 8.8 format)

---

## Hearts

- Max **2 hearts** on screen at once
- Hearts spawn from pre-computed positions near platforms (platform_x + 16, platform_y - 20)
- Positions with Y < 24 are excluded (HUD zone)
- Spawn sequence: 5 shuffled permutations of platform indices (60 total entries), guaranteeing variety
- Spawn attempt every 120 frames (~2 seconds) if a slot is available
- Hearts despawn after a random duration: 240-480 frames (4-8 seconds)
- Collecting a heart: **score +1**, increments hearts_in_level counter
- Collecting **10 hearts** in a level triggers LEVEL CLEAR

---

## Level Layouts

All platform coordinates reference the top-left corner of the 48x8px platform. Each platform has a scalloped cloud-top decoration row above it.

### Platform Coordinates

**Level 1 — 12 platforms (dense 3x4 staggered grid):**
| Row | Y | Platform X positions |
|---|---|---|
| Top | 56 | 48, 128, 208 |
| Upper-mid | 104 | 0, 88, 176 |
| Lower-mid | 152 | 48, 128, 208 |
| Bottom | 200 | 0, 88, 176 |

**Level 2 — 6 platforms (zigzag):**
| Row | Y | Platform X positions |
|---|---|---|
| Top | 56 | 0, 176 |
| Upper-mid | 104 | 88 |
| Lower-mid | 152 | 0, 176 |
| Bottom | 200 | 88 |

**Level 3 — 4 platforms (diagonal):**
| Row | Y | Platform X positions |
|---|---|---|
| Top | 56 | 32 |
| Upper-mid | 104 | 152 |
| Lower-mid | 152 | 32 |
| Bottom | 200 | 152 |

**Level 4 — 6 platforms (valley shape):**
| Row | Y | Platform X positions |
|---|---|---|
| Top | 56 | 0, 176 |
| Upper-mid | 104 | 0, 176 |
| Lower-mid | 152 | 88 |
| Bottom | 200 | 88 |

**Level 5 — 4 platforms (scattered):**
| Row | Y | Platform X positions |
|---|---|---|
| Top | 56 | 88 |
| Upper-mid | 104 | 0 |
| Lower-mid | 152 | 88 |
| Bottom | 200 | 176 |

### Player Spawn Positions

| Level | Sprite X | Sprite Y | Standing on platform at |
|---|---|---|---|
| 1 | 10 | 184 | (x=0, y=200) — bottom-left |
| 2 | 24 | 40 | (x=0, y=56) — top-left |
| 3 | 40 | 136 | (x=32, y=152) — mid-left |
| 4 | 104 | 136 | (x=88, y=152) — center |
| 5 | 200 | 184 | (x=176, y=200) — bottom-right |

---

## Sound & Music

### Music
- **Song:** "Home on the Range" chorus — 8-bar loop in F major, 3/4 time, ~100 BPM
- **Pulse 1:** Melody (50% duty cycle, volume 10, attack/release envelope)
- **Pulse 2:** Waltz-style arpeggio accompaniment (25% duty cycle, volume 6, soft attack)
- **Chord progression:** F → Bb → F → Dm → C → Bb → Bb → F (6 arpeggio notes per bar)
- Music plays during GAMEPLAY state, stops during pause/death/level clear/game over
- Music resumes from pause position when unpausing

### Sound Effects
| SFX | Channel | Description |
|---|---|---|
| Jump | Pulse 1 | 24-frame rising chirp (period sweeps downward, vol fades 12→4) |
| Death | Pulse 1 | 48-frame descending woop (period sweeps upward, vol fades 15→0) |
| Heart collect | Pulse 2 | 16-frame ascending 4-note chord (C5→E5→G5→C6) |
| Stomp | Pulse 2 | 24-frame descending bop (period sweeps upward, vol fades 14→0) |

SFX temporarily takes over the music channel. When SFX ends, the music channel resumes without audible phase restart (period_hi caching).

---

## Screens Reference

### Title Screen
- Background: cyan ($2C)
- "CLOUD LAND" in 3x3 tile large font, centered upper area
- "PRESS START" in 8x8px font, centered lower area
- No animation — purely static

### Level Clear Screen
- Background: current level's background color
- HUD visible: level number, lives, score
- "LEVEL CLEAR!" + "PRESS START" centered
- Press Start: advance to next level (or WIN after level 5)

### Game Over Screen
- Background: black ($0F)
- **Lives remaining:** "OOPS!" + "PRESS START" — score reverts to level start, press Start retries current level
- **No lives:** "GAME OVER" + "PRESS START" — press Start returns to title, full reset
- HUD visible

### Win Screen
- 6 horizontal rainbow stripes (4 tile rows each, aligned to attribute grid): red, orange, yellow-green, green, blue, violet
- Centered dark purple dialog box (16x10 tiles): "YOU WIN!" + "GOODNITE XOXO"
- HUD shows LEVEL 5 and final score (no LIVES display)
- Press Start: return to title

### Pause Screen
- Blank screen with current level's background color (platforms and sprites hidden)
- "PAUSED" centered
- HUD visible (level, lives, score)

---

## CHR Tile Budget

### Background Pattern Table ($0000-$0FFF, 128 tiles)

| Tile Range | Count | Purpose |
|---|---|---|
| $00 | 1 | Blank tile (shows backdrop color) |
| $01 | 1 | Solid fill — palette color 1 |
| $02 | 1 | Solid fill — palette color 2 |
| $03 | 1 | Solid fill — palette color 3 |
| $04-$07 | 4 | Cloud top decoration tiles (scalloped pattern above platforms) |
| $08-$09 | 2 | Platform end caps (left, right) |
| $20-$5F | ~46 | 8x8 font: space ($20), punctuation, 0-9 ($30-$39), A-Z ($41-$5A) — ASCII-mapped |
| $60-$9E | 63 | Title large font: C, L, O, U, D, space, A, N as 3x3 tile characters (8 chars x ~9 tiles) |

### Sprite Pattern Table ($1000-$1FFF, 128 tiles)

| Tile Range | Count | Purpose |
|---|---|---|
| $00-$03 | 4 | Player standing (2x2 tiles) |
| $04-$07 | 4 | Player walk frame 1 |
| $08-$0B | 4 | Player walk frame 2 |
| $0C-$0F | 4 | Player jump frame |
| $10-$1B | 16 | Bird frames 1-4 (4 anim frames x 4 tiles) |
| $1C | 1 | Heart (single 8x8 tile) |
| **Total** | **33** | |

---

## Configurable Constants

All tunable values defined in `constants.asm`:

```asm
; === Physics (8.8 fixed-point) ===
GRAVITY_HI       = $00          ; Gravity whole pixel component
GRAVITY_LO       = $60          ; Sub-pixel (~0.375 px/frame²)
JUMP_FORCE_MIN   = $02          ; Short tap jump velocity
JUMP_FORCE_MAX   = $07          ; Held-A jump velocity
WALK_SPEED       = $01          ; Walk speed whole pixels/frame
WALK_SPEED_LO    = $9A          ; Walk speed sub-pixel (~1.6 px/frame)
MAX_FALL_SPEED   = $04          ; Terminal velocity

; === Dimensions ===
PLATFORM_WIDTH   = 48           ; 6 tiles
PLATFORM_HEIGHT  = 8            ; 1 tile

; === Collision ===
BIRD_HITBOX_SIZE   = $0A        ; 10px forgiving hitbox
BIRD_HITBOX_OFFSET = $03        ; Offset from sprite origin

; === Scoring ===
HEARTS_PER_LEVEL = 10           ; Hearts to clear each level
MAX_SCORE        = 50           ; 10 x 5 levels
TOTAL_LEVELS     = 5

; === Lives ===
STARTING_LIVES   = 5

; === Death ===
DEATH_FALL_FRAMES = 30          ; ~0.5 seconds death animation

; === Stomp ===
STOMP_BOUNCE_VEL = $FA          ; -6 px/frame bounce
BIRD_RESPAWN_FRAMES = 300       ; 5-second respawn timer

; === Hearts ===
HEART_DESPAWN_MIN = 240         ; ~4 seconds
HEART_DESPAWN_MAX = 480         ; ~8 seconds
MAX_HEARTS_ONSCREEN = 2
HEART_SPAWN_DELAY = 120         ; ~2 seconds between spawn attempts

; === Animation ===
WALK_ANIM_SPEED  = $08          ; Frames between walk sprite toggles
BIRD_ANIM_SPEED  = $06          ; Frames between wing flap frames

; === Bird Zones (Y center of oscillation) ===
BIRD_ZONE0_CENTER = 36
BIRD_ZONE1_CENTER = 76
BIRD_ZONE2_CENTER = 124
BIRD_ZONE3_CENTER = 172
NUM_BIRDS        = 4
```

---

## Implementation Notes

- Standard NES boot sequence: sei, cld, disable APU IRQ, init stack, clear RAM, wait two vblanks
- "Split" game loop: logic in main thread, all PPU writes buffered and flushed in NMI only
- Entity data uses struct-of-arrays layout (separate arrays for x_pos[], y_pos[], state[], etc.)
- Platform collision: table of (x, y) entries per level; AABB check each frame with priority system
- 7-state machine with init/update pattern per state; `state_initialized` flag prevents re-init
- Score snapshot at level start (`level_base_score`) allows reverting score on death
- Bird hitbox is forgiving — err on the side of the player surviving near-misses
- Heart spawn logic uses pre-shuffled sequences to guarantee variety without runtime randomness
- All game state transitions disable rendering, clear PPU state, then re-enable after setup
- RNG seeded from frame counter at game start for heart spawn/despawn timing variety

### Win Screen Palette Strategy

Backdrop ($3F00) set to dark purple ($03) for HUD area. Rainbow stripes rendered using solid-fill tiles ($02, $03) with attribute table assignments mapping each 4-row band to the appropriate palette. Stripe boundaries align to attribute grid (4 tile rows = 32px each).
