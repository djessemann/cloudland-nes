; ============================================================
; Cloud Land — NES Game
; Main assembly file
; ============================================================

; === iNES Header ===
.include "header.asm"

; ============================================================
; Compile-time Constants
; ============================================================

; Game states
STATE_TITLE       = $00
STATE_GAMEPLAY    = $01
STATE_PAUSED      = $02
STATE_LEVEL_CLEAR = $03
STATE_GAME_OVER   = $04
STATE_WIN         = $05
STATE_DYING       = $06

; Controller buttons (bit positions after read)
BUTTON_A      = %10000000
BUTTON_B      = %01000000
BUTTON_SELECT = %00100000
BUTTON_START  = %00010000
BUTTON_UP     = %00001000
BUTTON_DOWN   = %00000100
BUTTON_LEFT   = %00000010
BUTTON_RIGHT  = %00000001

; Gameplay constants
.include "constants.asm"

; ============================================================
; Zero Page Variables ($00-$FF)
; ============================================================
.segment "ZEROPAGE"

; NMI synchronization
nmi_ready:       .res 1        ; Set to 1 by NMI, cleared by main loop

; Game state
game_state:      .res 1        ; Current state (STATE_*)
current_level:   .res 1        ; Current level (0-4)
score:           .res 1        ; Cumulative score (0-50)
hearts_in_level: .res 1        ; Hearts collected in current level (0-10)
frame_counter:   .res 1        ; General purpose frame counter

; Controller
buttons:         .res 1        ; Current frame button state
buttons_prev:    .res 1        ; Previous frame button state
buttons_new:     .res 1        ; Newly pressed this frame (edge detect)

; PPU shadow registers
ppu_ctrl:        .res 1        ; Shadow of $2000
ppu_mask:        .res 1        ; Shadow of $2001
ppu_scroll_x:    .res 1        ; Horizontal scroll
ppu_scroll_y:    .res 1        ; Vertical scroll

; State machine
state_initialized: .res 1     ; 0 = need init, 1 = run update

; General purpose temp/pointer
temp_1:          .res 1
temp_2:          .res 1
temp_3:          .res 1
temp_4:          .res 1
ptr_lo:          .res 1        ; General purpose pointer (low byte)
ptr_hi:          .res 1        ; General purpose pointer (high byte)

; Player state
player_x:        .res 1        ; Pixel X position
player_y:        .res 1        ; Pixel Y position
player_vel_x:    .res 1        ; Signed X velocity (pixels/frame)
player_vel_y:    .res 1        ; Signed Y velocity high byte (negative=up)
player_vel_y_lo: .res 1        ; Y velocity sub-pixel (fractional, 8.8 fixed-point)
player_y_sub:    .res 1        ; Y position sub-pixel (fractional, 8.8 fixed-point)
player_x_sub:    .res 1        ; X position sub-pixel (fractional, 8.8 fixed-point)
player_on_ground:.res 1        ; 1 = on platform, 0 = airborne
player_facing:   .res 1        ; 0 = right, 1 = left
player_anim_frame:.res 1       ; Animation frame index
player_anim_timer:.res 1       ; Walk animation countdown
player_jump_held:.res 1        ; 1 = A held since jump start
player_state:    .res 1        ; 0 = alive, 1 = dying
player_prev_y:   .res 1        ; Y from last frame (landing detect)

; Bird state (struct-of-arrays, 4 each)
bird_x:          .res 4        ; Pixel X per bird
bird_y:          .res 4        ; Pixel Y per bird
bird_dir:        .res 4        ; 0=right, 1=left
bird_y_offset:   .res 4        ; Signed offset from zone center
bird_osc_dir:    .res 4        ; 0=moving down, 1=moving up
bird_osc_timer:  .res 4        ; Frames until next 1px move
bird_anim_frame: .res 4        ; Anim index (0-5, into sequence)
bird_anim_timer: .res 4        ; Anim countdown
bird_alive:      .res 4        ; 0=dead, 1=alive
bird_death_vel:  .res 4        ; Death fall velocity (signed byte)
bird_respawn_lo: .res 4        ; Respawn countdown low byte (16-bit)
bird_respawn_hi: .res 4        ; Respawn countdown high byte
bird_cur_speed:  .res 4        ; Per-bird speed, 4.4 fixed-point ($10=1px/f)
bird_x_sub:      .res 4        ; Sub-pixel X accumulator (0-15)

; Heart state (struct-of-arrays, 2 each)
heart_x:         .res 2
heart_y:         .res 2
heart_active:    .res 2        ; 0=inactive, 1=active
heart_timer_lo:  .res 2        ; Despawn timer low byte
heart_timer_hi:  .res 2        ; Despawn timer high byte
heart_spawn_timer:.res 1       ; Frames until next spawn attempt
heart_spawn_index:.res 1       ; Round-robin index into positions

; Death / RNG / Misc
dying_timer:     .res 1
dying_vel:       .res 1
rng_seed:        .res 2        ; 16-bit LFSR
gameplay_paused_resume: .res 1
player_lives:    .res 1        ; Lives remaining (0-3)
level_base_score:.res 1        ; Score snapshot at level start

; Sound state
sfx_pulse1_id:   .res 1        ; Current SFX on pulse 1 (0=none)
sfx_pulse1_timer:.res 1        ; Frame counter for pulse 1 SFX
sfx_pulse2_id:   .res 1        ; Current SFX on pulse 2 (0=none)
sfx_pulse2_timer:.res 1        ; Frame counter for pulse 2 SFX

; Music state
music_playing:   .res 1        ; 0=stopped, 1=playing
music_p1_pos:    .res 1        ; Byte offset into melody_data
music_p1_timer:  .res 1        ; Frames remaining on current melody note
music_p1_note:   .res 1        ; Current note index (0=rest)
music_p1_total:  .res 1        ; Total duration of current note (for envelope)
music_p1_restore:.res 1        ; 1=need to restore pitch after SFX
music_p1_period_hi:.res 1      ; Tracked period hi (avoids phase restart click)
music_p2_pos:    .res 1        ; Byte offset into accomp_data
music_p2_timer:  .res 1        ; Frames remaining on current accomp note
music_p2_note:   .res 1        ; Current note index (0=rest)
music_p2_total:  .res 1        ; Total duration of current accomp note
music_p2_restore:.res 1        ; 1=need to restore pitch after SFX

; ============================================================
; OAM Shadow Buffer ($0200-$02FF)
; ============================================================
.segment "OAM"
oam_buf:         .res 256

; ============================================================
; BSS Variables ($0300+)
; ============================================================
.segment "BSS"

; VRAM update buffer — NMI flushes this to PPU each frame
; Format: [addr_hi, addr_lo, length, data...] repeated
vram_buf_len:    .res 1        ; Total bytes used in buffer
vram_buf:        .res 192      ; Buffer data (192 bytes for large writes)

; Heart valid spawn positions (computed per level)
heart_valid_count: .res 1      ; Number of valid positions
heart_valid_x:   .res 24       ; X coords of spawn candidates
heart_valid_y:   .res 24       ; Y coords of spawn candidates

; ============================================================
; Code
; ============================================================
.include "reset.asm"
.include "nmi.asm"
.include "ppu.asm"
.include "input.asm"
.include "gamestate.asm"
.include "player.asm"
.include "collision.asm"
.include "birds.asm"
.include "hearts.asm"
.include "sound.asm"
.include "music.asm"

; ============================================================
; Main — Called after reset boot sequence completes
; ============================================================
.segment "CODE"

.proc main
    ; --- Set PPU control: NMI on, BG pattern $0000, sprite pattern $1000 ---
    lda #%10001000
    sta ppu_ctrl
    sta $2000

    ; --- Reset scroll ---
    lda #$00
    sta ppu_scroll_x
    sta ppu_scroll_y

    ; --- Initialize APU sound ---
    jsr sound_init

    ; --- Initialize game state ---
.ifdef TEST_WIN
    lda #STATE_WIN
    sta game_state
    lda #50
    sta score
    lda #$04
    sta current_level
    lda #STARTING_LIVES
    sta player_lives
.else
    lda #STATE_TITLE
    sta game_state
    lda #$00
    sta score
    sta current_level
.endif
    lda #$00
    sta hearts_in_level
    sta frame_counter
    sta state_initialized

    ; === Main Game Loop ===
@loop:
    ; Wait for NMI (vblank sync)
    lda #$00
    sta nmi_ready
@wait_nmi:
    lda nmi_ready
    beq @wait_nmi

    ; Tick frame counter
    inc frame_counter

    ; Read controller
    jsr read_controller

    ; State dispatch
    jsr state_dispatch

    jmp @loop
.endproc

; ============================================================
; IRQ Handler (unused — required for vector table)
; ============================================================
.proc irq_handler
    rti
.endproc

; ============================================================
; Read-Only Data
; ============================================================
.include "data/palettes.asm"
.include "data/strings.asm"
.include "data/levels.asm"

; ============================================================
; Vectors (at $FFFA-$FFFF)
; ============================================================
.segment "VECTORS"
    .word nmi_handler           ; $FFFA — NMI
    .word reset                 ; $FFFC — Reset
    .word irq_handler           ; $FFFE — IRQ/BRK

; ============================================================
; CHR-ROM (8KB)
; ============================================================
.include "data/chr.asm"
