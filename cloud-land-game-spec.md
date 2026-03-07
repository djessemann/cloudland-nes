# Cloud Land — Game Specification

> **Source of truth for all behavioral and gameplay logic.**
> For visual layout, sprite art, animation states, and level mocks, refer to the Figma file:
> https://www.figma.com/design/CWiYu2rnBatKq8C4Uw5UPa/cloud-land-nes-game

---

## Build Target

- **Output:** A valid `.nes` ROM playable in any NES emulator (FCEUX, Mesen, Nestopia)
- **Language:** 6502 assembly using **ca65/ld65** (cc65 suite)
- **Mapper:** NROM-256 (mapper 0) — 32KB PRG-ROM + 8KB CHR-ROM. Sufficient for this game.
- **iNES header:** Required. 2 PRG banks, 1 CHR bank, mapper 0, vertical mirroring
- **Build command:**
  ```
  ca65 -o main.o src/main.asm
  ld65 -C nes.cfg -o cloud-land.nes main.o
  ```
- **Recommended project structure:**
  ```
  project/
  ├── src/
  │   ├── header.asm       ; iNES header
  │   ├── reset.asm        ; Hardware init (exact boot sequence required)
  │   ├── main.asm         ; Game state machine + main loop
  │   ├── nmi.asm          ; NMI handler — PPU updates only
  │   ├── ppu.asm          ; VRAM buffer, palette load, nametable write
  │   ├── input.asm        ; Controller read
  │   ├── entities.asm     ; Player, birds, hearts (struct-of-arrays layout)
  │   ├── collision.asm    ; Platform + sprite collision
  │   └── data/
  │       ├── palettes.asm
  │       └── levels.asm
  ├── chr/
  │   └── tiles.chr        ; 8KB CHR binary — all tile and sprite graphics
  ├── nes.cfg              ; Linker memory layout
  └── Makefile
  ```

---

## Technical Foundation

- **Resolution:** 256×240 pixels
- **Tile grid:** 8×8px — all positions should snap to 8px increments where possible
- **HUD region:** y=0 to y=23 (24px tall) — no gameplay objects appear here
- **Playfield region:** y=24 to y=239
- **Font:** Press Start 2P, 8px, white
- **Platform size:** 72×8px, color white (`#FFFFFF`)
- **Background:** The level background color fills the entire frame and is purely visual — it has no collision or gameplay interaction
- **Sprite size:** 16×16px (player, birds — implemented as 2×2 hardware sprites); 8×8px (hearts — 1 hardware sprite)

### NES Hardware Constraints

- **Palettes:** 4 background palettes × 4 colors each (first color of each is shared backdrop = level background color). 4 sprite palettes × 4 colors each (first color transparent). Plan palette assignments accordingly.
- **Sprite limit:** Max 64 hardware sprites total; max 8 per scanline. At peak: 4 birds (2 sprites each) + player (2 sprites) + 2 hearts (1 each) = 12 sprites. Scanline conflicts are possible — use flicker mitigation by cycling sprite priority each frame if needed.
- **CHR tile budget:** 256 tiles total across two 128-tile pattern tables. Background tiles in $0000–$0FFF, sprite tiles in $1000–$1FFF. Plan tile usage to stay within budget.
- **VRAM writes:** Never write to PPU ($2006/$2007) outside of vblank. All updates must be buffered in RAM and flushed during NMI.
- **Game loop:** Use the "split" method — game logic runs in the main thread, PPU updates run in NMI only. This handles lag frames correctly.
- **Zero page:** Use aggressively for frequently accessed variables (entity positions, game state flags, counters) — 6502 zero page access is significantly faster.

### NES Palette Index Mapping

The hex values specified throughout this doc are the target colors. Map them to the closest standard 2C02 NES palette indices when writing palette data:

| Color | Hex | Context |
|---|---|---|
| Level 1 / Title BG | `#39C3DF` | NES $2C |
| Level 2 BG | `#3AD974` | NES $1A |
| Level 3 BG | `#51A5FE` | NES $21 |
| Level 4 BG | `#8084FE` | NES $22 |
| Level 5 BG | `#F9B8FE` | NES $33 |
| White (platforms, text) | `#FFFFFF` | NES $30 |
| Dark red (win stripe) | `#A62721` | NES $16 |
| Orange (win stripe) | `#E19321` | NES $27 |
| Yellow-green (win stripe) | `#DEE086` | NES $38 |
| Dark green (win stripe) | `#2D7A00` | NES $0A |
| Blue (win stripe) | `#0B53D7` | NES $12 |
| Violet (win stripe) | `#9515BE` | NES $14 |
| Dark purple (win dialog) | `#300092` | NES $03 |

---

## Color Palette (NES-accurate hex values)

| Context | Hex |
|---|---|
| Title screen background | `#39C3DF` |
| Level 1 background | `#39C3DF` |
| Level 2 background | `#3AD974` |
| Level 3 background | `#51A5FE` |
| Level 4 background | `#8084FE` |
| Level 5 background | `#F9B8FE` |
| All platforms | `#FFFFFF` |
| All HUD text | `#FFFFFF` |
| Win screen dialog box | `#300092` |

**Win screen rainbow stripes (top to bottom):**
`#A62721` / `#E19321` / `#DEE086` / `#2D7A00` / `#0B53D7` / `#9515BE`

---

## Game States

```
TITLE → GAMEPLAY → LEVEL CLEAR → [next level or WIN SCREEN]
                 → GAME OVER → TITLE
```

| State | Description |
|---|---|
| `TITLE` | Static screen. "CLOUD LAND" + "PRESS START". No animation. |
| `GAMEPLAY` | Active play. HUD visible. |
| `PAUSED` | Overlay reading "PAUSED" centered on screen. All motion frozen. |
| `LEVEL_CLEAR` | "LEVEL CLEAR! PRESS START" centered. HUD shows current level + score. |
| `GAME_OVER` | "GAME OVER :( PRESS START" centered. HUD shows level + score. |
| `WIN` | Rainbow stripe screen with dialog box: "YOU WIN! / GOODNITE XOXO". HUD shows LEVEL 5 + final score. |

---

## Controls

| Input | Action |
|---|---|
| Start | Title → start game; Gameplay → toggle pause; Game Over / Win → return to Title |
| A button | Jump (variable height: short press = small jump, held = higher jump) |
| D-pad left/right | Move player left or right |

---

## HUD Layout

```
LEVEL X         SCORE XX
```

- "LEVEL X" — top-left, x=7, y=7
- "SCORE XX" — top-right, x=194, y=7
- Score is cumulative across levels (carries over)
- Max score: 50 (10 hearts × 5 levels)
- Display up to 2 digits

---

## Player

### Sprites
| State | Description |
|---|---|
| Standing | Default sprite when no input |
| Walking | Alternates between walk-frame-1 and walk-frame-2 while left/right held |
| Jumping | Active while A is held or player is airborne |
| Death | Upside-down version of standing sprite |

### Movement & Physics
- Reference established NES platformer physics for gravity, jump arc, and walk speed (e.g. Super Mario Bros. feel)
- Variable jump height: longer A press = higher apex
- Left/right movement applies in air as well as on ground
- All physics constants should be defined in a single configurable block for easy tuning during testing

### Collision
- Player collides with platforms from all sides (top, bottom, left, right) — cannot pass through. On horizontal collision with a platform edge, the player stops lateral movement but is not stuck — they can still jump or move away normally
- Player collides with screen left/right edges — cannot walk off sides
- If player moves below y=240 (falls off bottom of screen): trigger GAME OVER
- If player is hit by a bird: switch to death sprite, player falls downward off screen, then trigger GAME OVER
- No lives system. One hit = game over. (Architecture should make adding lives easy later.)

### Hitbox
- Use full 16×16 sprite bounds for player collision with platforms
- Use a forgiving reduced hitbox for bird collision — approximately 10×10px centered in the 16×16 sprite (reference common NES platformer practice)

---

## Enemy Birds

### Behavior
- Each level has **4 birds**, one per bounding zone (see Figma gameplay details frame for zone layout)
- Birds fly **horizontally** within their zone, bouncing left/right when hitting the screen edge
- Sprite **flips horizontally** on direction change
- Birds **oscillate vertically** within their zone while moving horizontally (sinusoidal motion)
- Animation cycles through 4 wing-flap frames; animation speed should be synchronized with vertical oscillation so that wing flaps visually drive the upward motion

### Spawn
- Each bird starts at a **different horizontal and vertical position** within its zone so movement patterns feel varied from the start

### Difficulty Scaling
- Movement speed and oscillation speed increase slightly with each level
- All speed/oscillation values should be defined in a configurable block per level

---

## Hearts

- Max **2 hearts** on screen at once
- Hearts **spawn randomly** within the playfield, near platforms in mid-air
- Spawn positions must always be **reachable by the player** via normal movement and jumping — determine valid spawn zones based on jump height and platform layout
- Hearts **despawn** after a random duration if not collected
- Base despawn timer: **3–8 seconds** (configurable)
- Spawn/despawn speed **increases slightly** per level (configurable per-level multiplier)
- Collecting a heart: **score +1**
- Collecting **10 hearts** in a level triggers LEVEL CLEAR

---

## Level Layouts

All platform coordinates reference the top-left corner of the 72×8px platform within the 256×240 game canvas. The Figma level mocks use placeholder layouts — Claude Code should use these as directional guidance for staggered, vertically distributed platforms, and should determine final pixel-snapped coordinates that:
1. Are reachable from each other via the player's jump arc
2. Allow hearts to spawn in mid-air nearby and remain collectible
3. Provide enough vertical challenge without dead ends

### Platform counts per level (fewer = harder)
| Level | Platforms | Difficulty intent |
|---|---|---|
| 1 | 12 | Easiest — dense grid, lots of footing |
| 2 | 6 | Medium — sparser, more gaps |
| 3 | 4 | Harder — minimal platforms |
| 4 | 6 | Hard — clustered differently than L2 |
| 5 | 4 | Hardest — most sparse |

### Player spawn position per level
- Player spawns at the **bottom-center of the playfield**, on or just above the lowest reachable platform
- Exact spawn coordinates should be determined relative to each level's platform layout

---

## Screens Reference

### Title Screen
- Background: `#39C3DF`
- "CLOUD LAND" large text, centered upper area
- "PRESS START" small text, centered lower area
- Press Start → go to Level 1

### Level Clear Screen
- Centered text: "LEVEL CLEAR! PRESS START"
- HUD shows current level number and score
- Press Start → advance to next level (or WIN if level 5 was just completed)

### Game Over Screen
- Centered text: "GAME OVER :( PRESS START"
- HUD shows level number and score at time of death
- Press Start → return to TITLE
- On returning to Title and starting again: **score resets to 0, start at Level 1**

### Win Screen
- Full-screen rainbow horizontal stripes (top to bottom): `#A62721` / `#E19321` / `#DEE086` / `#2D7A00` / `#0B53D7` / `#9515BE`
- Centered dialog box (`#300092`): "YOU WIN!" + blank line + "GOODNITE XOXO"
- HUD remains visible: shows LEVEL 5 and final score
- Press Start → return to TITLE

### Pause Overlay
- Semi-transparent or solid overlay with centered text: "PAUSED"
- All game motion frozen while paused
- Press Start again to resume

---

## Configurable Constants Block

All tunable values should be defined together at the top of a dedicated `constants.asm` file (or clearly marked block in `main.asm`) using ca65 `.define` or `.byte`/`.word` table declarations. This makes future tuning — adding lives, score multipliers, difficulty modes — straightforward without touching game logic.

```asm
; === PHYSICS ===
GRAVITY            = $02   ; pixels/frame² (fixed point)
JUMP_FORCE_MIN     = $04   ; minimum jump velocity
JUMP_FORCE_MAX     = $09   ; maximum jump velocity (held A)
WALK_SPEED         = $02   ; pixels/frame

; === BIRDS (one value per level, indexed 0–4) ===
bird_speed:         .byte $01, $01, $02, $02, $03
bird_osc_speed:     .byte $01, $01, $02, $02, $03
bird_osc_amplitude: .byte $18, $18, $20, $20, $28

; === HEARTS ===
HEART_DESPAWN_MIN  = $B4   ; ~3 seconds at 60fps (180 frames)
HEART_DESPAWN_MAX  = $FF   ; ~4.25 seconds — adjust upward for full 8s range
; (use a per-level multiplier table to increase speed each level)
heart_speed_mult:   .byte $10, $12, $14, $16, $18  ; 1.0x → 1.5x scale

; === COLLISION ===
BIRD_HITBOX_SIZE   = $0A   ; 10px centered in 16px sprite
BIRD_HITBOX_OFFSET = $03   ; offset from sprite origin to hitbox origin

; === SCORING ===
HEARTS_PER_LEVEL   = $0A   ; 10 hearts to clear a level
MAX_SCORE          = $32   ; 50 (decimal)
```

---

## Sprite Art (CHR Tile Data)

The Figma file uses colored rectangles as placeholder sprites to indicate position, size, and animation state — not final pixel art. Claude Code should generate CHR tile data that approximates the intended shapes as closely as possible in 8×8px tile increments using the NES palette.

**Player** (16×16px = 2×2 hardware tiles): A simple humanoid figure. The death sprite is the standing sprite flipped vertically. Use the purple/violet color range from the NES palette.

**Enemy bird** (16×16px = 2×2 hardware tiles): A simple side-facing bird shape with 4 wing animation frames — wings up, wings mid-up, wings level, wings mid-down. Animation should read as a flapping cycle.

**Heart** (8×8px = 1 hardware tile): A simple heart shape.

**Platforms and background**: Rendered as background tiles, not sprites. Platforms are solid white (`#FFFFFF` / NES `$30`). Background is a flat color fill using the per-level palette backdrop color.

**HUD text and all on-screen text**: Rendered using background tiles. Every character that appears on screen must exist as a CHR tile — the NES has no system font. To make adding or changing text easy in the future, implement a complete font tileset and a reusable text-rendering routine:

- Define CHR tiles for the full printable ASCII range: A–Z, 0–9, and punctuation including space, colon, exclamation mark, question mark, apostrophe, period, comma, open/close parentheses, dash, and any others used in current screen text
- Lay the font tiles out in CHR in ASCII order starting at a known tile index (e.g. tile $20 = space, matching standard ASCII offsets) so the rendering routine can convert any ASCII character to a tile index with simple subtraction
- Implement a `draw_text` subroutine that accepts a pointer to a null-terminated string and an X/Y nametable position, and writes the corresponding tile indices to the VRAM buffer. All screen text — HUD labels, LEVEL CLEAR, GAME OVER, YOU WIN, PAUSED, PRESS START — should be rendered through this single routine
- With this system in place, changing or adding any text anywhere in the game only requires editing string data, with no CHR changes needed

Font style should match Press Start 2P — a blocky, all-caps, 8×8px bitmap letterform consistent with NES-era games.

All CHR data should be defined inline in assembly (`.byte` sequences) or as a binary `tiles.chr` file — whichever approach produces a cleaner, more maintainable result. Placeholder art that reads clearly at small size is the goal; visual polish can be iterated later.

---



- Follow the standard NES boot sequence exactly (sei, cld, disable APU IRQ, init stack, clear RAM, wait two vblanks before PPU use)
- Use the "split" game loop: logic in main thread, all PPU writes buffered and flushed in NMI only
- Entity data (player, birds, hearts) should use struct-of-arrays layout — separate arrays for x_pos[], y_pos[], state[], etc. This is idiomatic 6502 and significantly faster than array-of-structs
- Platform collision: store platform data as a table of (x, y, width) entries per level; check player AABB against each entry each frame
- Research and reference NES platformer physics conventions (Super Mario Bros. in particular) for gravity, jump arc, walk acceleration, and collision feel
- Bird hitbox should feel forgiving — err on the side of the player surviving near-misses
- Heart spawn logic should validate reachability before placing — don't spawn hearts that require frame-perfect jumps
- All game state transitions should be clean (no residual motion or input bleed between states)
- If sprite scanline overflow occurs (8+ sprites on one line), implement per-frame sprite cycling to produce even flicker rather than sprites disappearing entirely
