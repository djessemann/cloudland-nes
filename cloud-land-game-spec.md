# Cloud Land — Game Specification

> **Source of truth for all behavioral and gameplay logic.**
> For visual layout, sprite art, animation states, and level mocks, refer to the Figma file:
> https://www.figma.com/design/CWiYu2rnBatKq8C4Uw5UPa/cloud-land-nes-game

---

## Technical Foundation

- **Resolution:** 256×240 pixels
- **Tile grid:** 8×8px — all positions should snap to 8px increments where possible
- **HUD region:** y=0 to y=23 (24px tall) — no gameplay objects appear here
- **Playfield region:** y=24 to y=239
- **Font:** Press Start 2P, 8px, white
- **Platform size:** 72×8px, color white (`#FFFFFF`)
- **Background:** The level background color fills the entire frame and is purely visual — it has no collision or gameplay interaction
- **Sprite size:** 16×16px (player, birds); 8×8px (hearts)

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

All of the following should be defined together in a single easily-editable config section (top of main game file or a dedicated `config` object/file):

```
// Physics
GRAVITY
JUMP_FORCE_MIN
JUMP_FORCE_MAX
WALK_SPEED

// Birds (per level array)
BIRD_SPEED[5]
BIRD_OSCILLATION_SPEED[5]
BIRD_OSCILLATION_AMPLITUDE[5]

// Hearts
HEART_DESPAWN_MIN_SECONDS
HEART_DESPAWN_MAX_SECONDS
HEART_SPAWN_SPEED_MULTIPLIER[5]

// Collision
BIRD_HITBOX_SIZE  // centered reduced hitbox, ~10x10

// Scoring
HEARTS_PER_LEVEL  // default: 10
MAX_SCORE         // default: 50
```

This structure should make it straightforward to add lives, score multipliers, difficulty modes, or other complexity later without refactoring core game logic.

---

## Implementation Notes

- Research and reference NES platformer physics conventions (Super Mario Bros. in particular) for gravity, jump arc, walk acceleration, and collision feel
- Bird hitbox should feel forgiving — err on the side of the player surviving near-misses
- Heart spawn logic should validate reachability before placing — don't spawn hearts that require frame-perfect jumps
- All game state transitions should be clean (no residual motion or input bleed between states)
