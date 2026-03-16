; ============================================================
; Configurable Constants
; All tunable gameplay values in one place for easy adjustment.
; ============================================================

; === Physics (8.8 fixed-point for Y axis) ===
GRAVITY_HI       = $00          ; Gravity whole pixel component
GRAVITY_LO       = $60          ; Gravity sub-pixel ($60/256 ≈ 0.375 px/frame²)
JUMP_FORCE_MIN   = $02          ; Minimum jump velocity, short tap (whole pixels/frame)
JUMP_FORCE_MAX   = $07          ; Maximum jump velocity, held A (whole pixels/frame)
WALK_SPEED       = $01          ; Horizontal speed whole pixels/frame (8.8 hi)
WALK_SPEED_LO    = $9A          ; Horizontal speed sub-pixel ($019A ≈ 1.6 px/frame)
MAX_FALL_SPEED   = $04          ; Terminal velocity (whole pixels/frame)

; === Dimensions ===
PLAYER_WIDTH     = 16           ; Player sprite width (pixels)
PLAYER_HEIGHT    = 16           ; Player sprite height (pixels)
PLATFORM_WIDTH   = 48           ; Platform width (pixels, 6 tiles)
PLATFORM_HEIGHT  = 8            ; Platform height (pixels, 1 tile)

; === Screen Bounds ===
SCREEN_RIGHT     = 240          ; Max player X (256 - 16)
SCREEN_BOTTOM    = 240          ; Below this Y = death

; === Collision ===
BIRD_HITBOX_SIZE   = $0A        ; 10px forgiving hitbox centered in 16px sprite
BIRD_HITBOX_OFFSET = $03        ; Offset from sprite origin to hitbox origin

; === Scoring ===
HEARTS_PER_LEVEL = 10           ; Hearts needed to clear each level
MAX_SCORE        = 50           ; Maximum cumulative score (10 x 5 levels)
TOTAL_LEVELS     = 5            ; Number of levels in the game

; === Lives ===
STARTING_LIVES   = 5            ; Lives at game start

; === Death ===
DEATH_FALL_FRAMES = 30          ; ~0.5 seconds at 60fps before GAME OVER transition
DYING_GRAVITY    = $01          ; Gravity during death fall animation

; === Stomp ===
STOMP_BOUNCE_VEL = $FA          ; Player bounce after stomp (-6 px/frame)
BIRD_DEATH_GRAVITY = $01        ; Gravity for dying bird's fall animation
BIRD_RESPAWN_FRAMES = 300       ; 5 seconds at 60fps (16-bit: $012C)

; === Hearts ===
HEART_DESPAWN_MIN = 240         ; ~4 seconds at 60fps
HEART_DESPAWN_MAX = 480         ; ~8 seconds at 60fps
MAX_HEARTS_ONSCREEN = 2         ; Maximum hearts visible at once
HEART_SPAWN_DELAY = 120         ; Frames between spawn attempts (~2 sec)

; === Sprite Tile Indices (pattern table 1) ===
SPR_PLAYER_STAND = $00          ; Player standing frame (tiles $00-$03)
SPR_PLAYER_WALK1 = $04          ; Player walk frame 1
SPR_PLAYER_WALK2 = $08          ; Player walk frame 2
SPR_PLAYER_JUMP  = $0C          ; Player jump frame
SPR_BIRD_BASE    = $10          ; Bird frame 1 (4 frames, +4 tiles each)
SPR_HEART        = $1C          ; Heart collectible (single 8x8 tile)

; === OAM Offsets ===
OAM_PLAYER       = $00          ; Player metasprite (4 sprites, 16 bytes)
OAM_BIRD0        = $10          ; Bird 0 metasprite
OAM_BIRD1        = $20          ; Bird 1
OAM_BIRD2        = $30          ; Bird 2
OAM_BIRD3        = $40          ; Bird 3
OAM_HEART0       = $50          ; Heart 0 (single sprite, 4 bytes)
OAM_HEART1       = $54          ; Heart 1

; === Animation ===
WALK_ANIM_SPEED  = $08          ; Frames between walk sprite toggles
BIRD_ANIM_SPEED  = $06          ; Frames between bird wing flap frames

; === Bird Zones (Y center of each oscillation band) ===
BIRD_ZONE0_CENTER = 36          ; Zone 0: y=16-55
BIRD_ZONE1_CENTER = 76          ; Zone 1: y=56-95
BIRD_ZONE2_CENTER = 124         ; Zone 2: y=104-143
BIRD_ZONE3_CENTER = 172         ; Zone 3: y=152-191
NUM_BIRDS        = 4            ; Birds per level
