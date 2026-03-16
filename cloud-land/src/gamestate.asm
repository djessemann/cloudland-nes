; ============================================================
; Game State Machine
; Each state has an init (runs once) and update (runs each frame).
; state_initialized: 0 = need init, 1 = run update
; ============================================================
.segment "CODE"

; ------------------------------------------------------------
; state_dispatch
; Called each frame from main loop. Routes to current state.
; ------------------------------------------------------------
.proc state_dispatch
    lda game_state

    cmp #STATE_TITLE
    beq @title
    cmp #STATE_GAMEPLAY
    beq @gameplay
    cmp #STATE_PAUSED
    beq @paused
    cmp #STATE_LEVEL_CLEAR
    beq @level_clear
    cmp #STATE_GAME_OVER
    beq @game_over
    cmp #STATE_WIN
    beq @win
    cmp #STATE_DYING
    beq @dying
    rts                         ; Unknown state — do nothing

@title:
    jmp state_title
@gameplay:
    jmp state_gameplay
@paused:
    jmp state_paused
@level_clear:
    jmp state_level_clear
@game_over:
    jmp state_game_over
@win:
    jmp state_win
@dying:
    jmp state_dying
.endproc

; ------------------------------------------------------------
; change_state
; Transition to a new state. A = new STATE_* value.
; Clears init flag and disables rendering for screen setup.
; ------------------------------------------------------------
.proc change_state
    sta game_state
    lda #$00
    sta state_initialized

    ; Disable rendering during screen setup
    lda #$00
    sta $2001
    sta ppu_mask

    ; Wait for vblank so PPU is safe to write
    ; (NMI will still fire and set nmi_ready)
@wait:
    lda nmi_ready
    beq @wait
    lda #$00
    sta nmi_ready

    rts
.endproc

; ============================================================
; TITLE state
; ============================================================
.proc state_title
    lda state_initialized
    bne @update

    ; --- INIT ---
    ; Load title palette
    lda #<palette_title
    sta ptr_lo
    lda #>palette_title
    sta ptr_hi
    jsr load_palettes

    ; Clear nametable and all sprites
    jsr clear_nametable
    jsr clear_oam_sprites

    ; Draw "CLOUD LAND" large text centered
    ; 10 chars x 3 tiles wide = 30 tiles; screen = 32 tiles
    ; Start at tile col 1, tile row 5
    lda #$01
    sta temp_1
    lda #$05
    sta temp_2
    jsr draw_large_text

    ; Draw "PRESS START" centered
    ; 11 chars; center = (32-11)/2 = 10 (tile col 10)
    ; Place at tile row 20
    lda #<str_press_start
    sta ptr_lo
    lda #>str_press_start
    sta ptr_hi
    lda #$0A                    ; Col 10
    sta temp_1
    lda #$14                    ; Row 20
    sta temp_2
    jsr draw_text

    ; Flush VRAM buffer (wait for NMI)
    jsr wait_vram_flush

    ; Re-enable rendering
    lda #%00011110
    sta ppu_mask
    sta $2001
    lda ppu_ctrl
    sta $2000
    lda #$00
    sta $2005
    sta $2005

    lda #$01
    sta state_initialized

@update:
    ; Wait for Start press
    lda buttons_new
    and #BUTTON_START
    beq @done

    ; Start game: reset score, level 0, lives, seed RNG, go to GAMEPLAY
    lda #$00
    sta score
    sta current_level
    sta hearts_in_level
    sta gameplay_paused_resume
    lda #STARTING_LIVES
    sta player_lives

    ; Seed RNG from frame counter (non-zero guaranteed by adding 1)
    lda frame_counter
    ora #$01                    ; Ensure seed is never zero
    sta rng_seed
    lda frame_counter
    eor #$A5                    ; Mix up high byte
    ora #$01
    sta rng_seed+1

    lda #STATE_GAMEPLAY
    jsr change_state

@done:
    rts
.endproc

; ============================================================
; GAMEPLAY state
; ============================================================
.proc state_gameplay
    lda state_initialized
    bne @update

    ; --- INIT ---
    ; Snapshot score at level start (for restoring on death)
    lda score
    sta level_base_score

    ; Full init: load palette, draw screen, init entities
    ldx current_level
    lda palette_table_lo, x
    sta ptr_lo
    lda palette_table_hi, x
    sta ptr_hi
    jsr load_palettes

    jsr clear_nametable
    jsr draw_hud
    jsr wait_vram_flush
    jsr draw_platforms_buffered

    ; Initialize all entities
    jsr clear_oam_sprites
    jsr player_init
    jsr birds_init
    jsr hearts_init
    jsr music_play
    ; Re-enable rendering (BG + sprites)
    lda #%00011110
    sta ppu_mask
    sta $2001
    lda ppu_ctrl
    sta $2000
    lda #$00
    sta $2005
    sta $2005

    lda #$01
    sta state_initialized

@update:
    ; --- Check for Start (pause) ---
    lda buttons_new
    and #BUTTON_START
    beq @no_pause

    ; Pause: stop music, change state
    jsr music_stop
    lda #STATE_PAUSED
    jsr change_state
    sta state_initialized
    rts

@no_pause:
    ; --- Update entities ---
    jsr player_update
    jsr check_platform_collision

    ; Check screen bounds (carry set = fell off bottom)
    jsr check_screen_bounds
    bcc @no_fall_death
    jmp @trigger_death
@no_fall_death:

    jsr birds_update
    jsr hearts_update

    ; --- Collision checks ---
    ; Bird collision (carry set = hit; A=0 stomp, A=1 death)
    jsr check_bird_player_collision
    bcc @no_bird_hit
    cmp #$00
    bne @trigger_death          ; Regular hit → die

    ; --- STOMP: kill bird, bounce player ---
    ldx temp_4                  ; Bird index from collision
    lda #$00
    sta bird_alive, x           ; Mark bird dead
    lda #256-4
    sta bird_death_vel, x       ; Initial upward pop
    lda #<BIRD_RESPAWN_FRAMES
    sta bird_respawn_lo, x      ; Start 5-second respawn timer
    lda #>BIRD_RESPAWN_FRAMES
    sta bird_respawn_hi, x

    lda #STOMP_BOUNCE_VEL
    sta player_vel_y            ; Bounce player upward
    lda #$00
    sta player_vel_y_lo
    sta player_on_ground        ; Player is airborne

    ; Allow variable bounce height (hold A = higher bounce)
    lda buttons
    and #BUTTON_A
    beq @stomp_no_a
    lda #$01
@stomp_no_a:
    sta player_jump_held
    jsr sfx_play_stomp

@no_bird_hit:

    ; Heart collection (handled internally)
    jsr check_heart_player_collision

    ; --- Check level clear ---
    lda hearts_in_level
    cmp #HEARTS_PER_LEVEL
    bcc @no_clear

    jsr music_stop
    lda #STATE_LEVEL_CLEAR
    jsr change_state
    rts

@no_clear:
    ; --- Update animation (after collision so on_ground is correct) ---
    jsr player_update_animation

    ; --- Write all OAM ---
    jsr player_write_oam
    jsr birds_write_oam
    jsr hearts_write_oam

    rts

@trigger_death:
    jsr music_stop
    jsr sfx_play_death
    lda #STATE_DYING
    jsr change_state
    rts
.endproc

; ============================================================
; DYING state — Death animation, then transition to GAME OVER
; ============================================================
.proc state_dying
    lda state_initialized
    bne @update

    ; --- INIT ---
    ; Set up death fall: small upward pop, then gravity takes over
    lda #DEATH_FALL_FRAMES
    sta dying_timer
    lda #256-4                  ; Initial upward pop (-4 pixels/frame)
    sta dying_vel

    ; Hide hearts during death
    jsr hearts_hide_oam

    ; Re-enable rendering (keep gameplay screen visible)
    lda #%00011110
    sta ppu_mask
    sta $2001
    lda ppu_ctrl
    sta $2000
    lda #$00
    sta $2005
    sta $2005

    lda #$01
    sta state_initialized

@update:
    ; --- Apply death velocity (player falls off screen) ---
    lda dying_vel
    bmi @vel_up

    ; Falling down: clamp on overflow
    clc
    adc player_y
    bcs @clamp_y
    sta player_y
    jmp @apply_grav

@vel_up:
    ; Moving up (death pop): no clamp, normal signed add
    clc
    adc player_y
    sta player_y
    jmp @apply_grav

@clamp_y:
    lda #SCREEN_BOTTOM
    sta player_y

@apply_grav:
    ; Apply gravity to death velocity
    lda dying_vel
    clc
    adc #DYING_GRAVITY
    sta dying_vel

    ; Birds keep flying during death
    jsr birds_update

    ; Write OAM: hide player if offscreen, show death sprite if visible
    lda player_y
    cmp #SCREEN_BOTTOM
    bcs @hide_player

    jsr player_write_oam_death
    jmp @write_birds

@hide_player:
    lda #$F0                    ; $F0 = offscreen (below visible area)
    sta oam_buf + OAM_PLAYER
    sta oam_buf + OAM_PLAYER + 4
    sta oam_buf + OAM_PLAYER + 8
    sta oam_buf + OAM_PLAYER + 12

@write_birds:
    jsr birds_write_oam

    ; --- Count down timer ---
    dec dying_timer
    bne @done

    ; Timer expired → decrement lives, go to GAME OVER screen
    dec player_lives
    lda #STATE_GAME_OVER
    jsr change_state

@done:
    rts
.endproc

; ============================================================
; PAUSED state
; Rendering is already disabled by change_state before init.
; ============================================================
.proc state_paused
    lda state_initialized
    bne @update

    ; --- INIT (rendering is off) ---
    ; Hide all sprites
    jsr clear_oam_sprites

    ; Clear nametable (removes platforms)
    jsr clear_nametable

    ; Draw HUD (level + score) — stays visible
    jsr draw_hud

    ; Draw "PAUSED" centered: 6 chars, col 13, row 14
    lda #<str_paused
    sta ptr_lo
    lda #>str_paused
    sta ptr_hi
    lda #$0D                    ; Col 13
    sta temp_1
    lda #$0E                    ; Row 14
    sta temp_2
    jsr draw_text

    ; Flush VRAM buffer
    jsr wait_vram_flush

    ; Re-enable rendering (BG + sprites)
    lda #%00011110
    sta ppu_mask
    sta $2001
    lda ppu_ctrl
    sta $2000
    lda #$00
    sta $2005
    sta $2005

    lda #$01
    sta state_initialized

@update:
    lda buttons_new
    and #BUTTON_START
    beq @done

    ; --- UNPAUSE ---
    ; Disable rendering for safe PPU writes
    lda #$00
    sta $2001
    sta ppu_mask

    ; Wait for vblank so PPU is safe
@wait_vb:
    lda nmi_ready
    beq @wait_vb
    lda #$00
    sta nmi_ready

    ; Redraw full gameplay screen
    jsr clear_nametable
    jsr draw_hud
    jsr wait_vram_flush
    jsr draw_platforms_buffered

    ; Re-enable rendering (BG + sprites)
    lda #%00011110
    sta ppu_mask
    sta $2001
    lda ppu_ctrl
    sta $2000
    lda #$00
    sta $2005
    sta $2005

    ; Return to gameplay (skip entity init)
    jsr music_resume
    lda #STATE_GAMEPLAY
    sta game_state
    lda #$01
    sta state_initialized

@done:
    rts
.endproc

; ============================================================
; LEVEL_CLEAR state
; ============================================================
.proc state_level_clear
    lda state_initialized
    bne @update

    ; --- INIT ---
    ldx current_level
    lda palette_table_lo, x
    sta ptr_lo
    lda palette_table_hi, x
    sta ptr_hi
    jsr load_palettes

    jsr clear_nametable

    ; "LEVEL CLEAR!" centered: 12 chars, col = (32-12)/2 = 10
    lda #<str_level_clear
    sta ptr_lo
    lda #>str_level_clear
    sta ptr_hi
    lda #$0A
    sta temp_1
    lda #$0D                    ; Row 13
    sta temp_2
    jsr draw_text

    ; "PRESS START" centered: 11 chars, col 10
    lda #<str_press_start
    sta ptr_lo
    lda #>str_press_start
    sta ptr_hi
    lda #$0A
    sta temp_1
    lda #$10                    ; Row 16
    sta temp_2
    jsr draw_text

    ; HUD
    jsr draw_hud

    jsr wait_vram_flush

    lda #%00001110
    sta ppu_mask
    sta $2001
    lda ppu_ctrl
    sta $2000
    lda #$00
    sta $2005
    sta $2005

    lda #$01
    sta state_initialized

@update:
    lda buttons_new
    and #BUTTON_START
    beq @done

    ; Advance level
    inc current_level
    lda current_level
    cmp #TOTAL_LEVELS
    bcc @next_level

    ; Beat all 5 levels — WIN!
    lda #STATE_WIN
    jsr change_state
    jmp @done

@next_level:
    lda #$00
    sta hearts_in_level
    lda #STATE_GAMEPLAY
    jsr change_state

@done:
    rts
.endproc

; ============================================================
; GAME_OVER state
; ============================================================
.proc state_game_over
    lda state_initialized
    bne @update

    ; --- INIT ---
    lda #<palette_gameover
    sta ptr_lo
    lda #>palette_gameover
    sta ptr_hi
    jsr load_palettes

    jsr clear_nametable

    ; Branch on lives remaining
    lda player_lives
    bne @show_oops

    ; --- No lives left: show "GAME OVER" (9 chars, col 11) ---
    lda #<str_game_over
    sta ptr_lo
    lda #>str_game_over
    sta ptr_hi
    lda #$0B
    sta temp_1
    lda #$0D
    sta temp_2
    jsr draw_text
    jmp @draw_common

@show_oops:
    ; --- Lives remain: show "OOPS!" (5 chars, col 13) ---
    ; Restore score to level start and reset hearts
    lda level_base_score
    sta score
    lda #$00
    sta hearts_in_level

    lda #<str_oops
    sta ptr_lo
    lda #>str_oops
    sta ptr_hi
    lda #$0D
    sta temp_1
    lda #$0D
    sta temp_2
    jsr draw_text

@draw_common:
    ; "PRESS START" centered: 11 chars, col 10
    lda #<str_press_start
    sta ptr_lo
    lda #>str_press_start
    sta ptr_hi
    lda #$0A
    sta temp_1
    lda #$10
    sta temp_2
    jsr draw_text

    ; HUD (shows lives and restored score)
    jsr draw_hud

    jsr wait_vram_flush

    lda #%00001110
    sta ppu_mask
    sta $2001
    lda ppu_ctrl
    sta $2000
    lda #$00
    sta $2005
    sta $2005

    lda #$01
    sta state_initialized

@update:
    lda buttons_new
    and #BUTTON_START
    beq @done

    ; Branch on lives: restart level or return to title
    lda player_lives
    bne @restart_level

    ; No lives → title screen
    lda #STATE_TITLE
    jsr change_state
    jmp @done

@restart_level:
    ; Lives remain → replay current level
    lda #STATE_GAMEPLAY
    jsr change_state

@done:
    rts
.endproc

; ============================================================
; WIN state
; ============================================================
.proc state_win
    lda state_initialized
    bne @update

    ; --- INIT ---
    lda #<palette_win
    sta ptr_lo
    lda #>palette_win
    sta ptr_hi
    jsr load_palettes

    jsr clear_nametable

    ; Draw rainbow stripes (6 stripes, each ~5 tile rows = 40px)
    ; Stripe 1 (rows 3-7): blank tiles → shows backdrop (dark red)
    ; Stripe 2 (rows 8-12): solid-color-1 tiles + palette 0 (orange)
    jsr draw_win_stripes

    jsr wait_vram_flush

    ; Draw dialog box and text (separate flush to avoid overflow)
    jsr draw_win_dialog

    ; HUD: show LEVEL 5 and final score (no LIVES on win screen)
    lda #$04                    ; Level index 4 = Level 5
    sta current_level
    jsr draw_hud_win

    jsr wait_vram_flush

    lda #%00001110
    sta ppu_mask
    sta $2001
    lda ppu_ctrl
    sta $2000
    lda #$00
    sta $2005
    sta $2005

    lda #$01
    sta state_initialized

@update:
    lda buttons_new
    and #BUTTON_START
    beq @done

    lda #STATE_TITLE
    jsr change_state

@done:
    rts
.endproc

; ============================================================
; Helper: wait_vram_flush
; Wait for NMI to flush the VRAM buffer, then clear for next batch.
; ============================================================
.proc wait_vram_flush
    ; Temporarily enable rendering so NMI fires
    lda ppu_ctrl
    sta $2000
@wait:
    lda vram_buf_len
    bne @wait_nmi
    rts
@wait_nmi:
    lda nmi_ready
    beq @wait_nmi
    lda #$00
    sta nmi_ready
    jmp @wait
.endproc

; ============================================================
; Helper: draw_platforms_buffered
; Draws cloud tops and platforms in two passes, flushing VRAM
; buffer between passes to stay within 192-byte buffer limit.
; Pass 1: cloud bump row above each platform (~108 bytes max)
; Pass 2: platform row with cap tiles (~108 bytes max)
; ============================================================
.proc draw_platforms_buffered
    jsr draw_cloud_tops
    jsr wait_vram_flush
    jsr draw_platforms
    jsr wait_vram_flush
    rts
.endproc

; ============================================================
; Helper: draw_win_stripes
; Fill nametable rows with solid-color tiles for rainbow effect.
; 4-row aligned stripes matching attribute table grid exactly.
; Uses tile $03 (color 3) for stripes, tile $02 (color 2) for violet.
; ============================================================
.proc draw_win_stripes
    ; Stripe layout (4-row aligned to attribute grid):
    ;   Rows 0-3:   HUD (blank = backdrop $03 dk purple)
    ;   Rows 4-7:   Red (tile $02, palette 0, c2=$16)
    ;   Rows 8-11:  Orange (tile $03, palette 0, c3=$27)
    ;   Rows 12-15: Yellow (tile $03, palette 1, c3=$38)
    ;   Rows 16-19: Green (tile $03, palette 2, c3=$19)
    ;   Rows 20-23: Blue (tile $03, palette 3, c3=$12)
    ;   Rows 24-29: Violet (tile $02, palette 3, c2=$14)

    ; Red: rows 4-7 (4 rows, tile $02 = c2 = dark red $16)
    ldx #$04
    lda #$04
    ldy #$02                    ; tile $02
    jsr fill_tile_rows_t

    jsr wait_vram_flush

    ; Orange: rows 8-11 (4 rows, tile $03)
    ldx #$08
    lda #$04
    ldy #$03                    ; tile $03
    jsr fill_tile_rows_t

    jsr wait_vram_flush

    ; Yellow: rows 12-15 (4 rows, tile $03)
    ldx #$0C
    lda #$04
    ldy #$03
    jsr fill_tile_rows_t

    jsr wait_vram_flush

    ; Green: rows 16-19 (4 rows, tile $03)
    ldx #$10
    lda #$04
    ldy #$03
    jsr fill_tile_rows_t

    jsr wait_vram_flush

    ; Blue: rows 20-23 (4 rows, tile $03)
    ldx #$14
    lda #$04
    ldy #$03
    jsr fill_tile_rows_t

    jsr wait_vram_flush

    ; Violet: rows 24-27 (4 rows, tile $02)
    ldx #$18
    lda #$04
    ldy #$02                    ; tile $02
    jsr fill_tile_rows_t

    jsr wait_vram_flush

    ; Violet continued: rows 28-29 (2 rows, tile $02)
    ldx #$1C
    lda #$02
    ldy #$02
    jsr fill_tile_rows_t

    ; Attribute table (fits in same buffer — 67 bytes)
    jsr write_win_attributes

    jsr wait_vram_flush

    rts
.endproc

; Fill N rows with tile Y starting at row X
; X = start row, A = number of rows, Y = tile index
.proc fill_tile_rows_t
    sty temp_3                  ; Tile to use
    sta temp_4                  ; Row count

@row_loop:
    lda temp_4
    beq @done

    ; Calculate nametable address for row X
    txa
    pha                         ; Save row number

    lsr a
    lsr a
    lsr a
    clc
    adc #$20
    sta temp_1                  ; Addr high

    pla
    pha
    asl a
    asl a
    asl a
    asl a
    asl a
    sta temp_2                  ; Addr low

    ; Write 32 tiles for this row
    ldy vram_buf_len
    lda temp_1
    sta vram_buf, y
    iny
    lda temp_2
    sta vram_buf, y
    iny
    lda #$20                    ; 32 tiles per row
    sta vram_buf, y
    iny

    ldx #$20
@tile_loop:
    lda temp_3
    sta vram_buf, y
    iny
    dex
    bne @tile_loop

    sty vram_buf_len

    pla
    tax
    inx                         ; Next row
    dec temp_4
    jmp @row_loop

@done:
    rts
.endproc

; Write attribute table for win screen palette assignments
; 4-row aligned: each attr row = one palette, no mixing
.proc write_win_attributes
    ; Attr row 0 (tiles 0-3):   P0 — HUD (dk purple backdrop)
    ; Attr row 1 (tiles 4-7):   P0 — red stripe (tile $02)
    ; Attr row 2 (tiles 8-11):  P0 — orange stripe
    ; Attr row 3 (tiles 12-15): P1 — yellow stripe
    ; Attr row 4 (tiles 16-19): P2 — green stripe
    ; Attr row 5 (tiles 20-23): P3 — blue stripe
    ; Attr row 6 (tiles 24-27): P3 — violet stripe
    ; Attr row 7 (tiles 28-29): P3 — violet stripe

    ldx vram_buf_len
    lda #$23
    sta vram_buf, x
    inx
    lda #$C0
    sta vram_buf, x
    inx
    lda #$40                    ; 64 bytes
    sta vram_buf, x
    inx

    ; Rows 0-2: all P0 (24 bytes)
    ldy #24
    lda #$00                    ; P0 = %00000000
@rows_p0:
    sta vram_buf, x
    inx
    dey
    bne @rows_p0

    ; Row 3: P1 (8 bytes)
    ldy #$08
    lda #%01010101              ; P1
@row_p1:
    sta vram_buf, x
    inx
    dey
    bne @row_p1

    ; Row 4: P2 (8 bytes)
    ldy #$08
    lda #%10101010              ; P2
@row_p2:
    sta vram_buf, x
    inx
    dey
    bne @row_p2

    ; Rows 5-7: P3 (24 bytes)
    ldy #24
    lda #%11111111              ; P3
@rows_p3:
    sta vram_buf, x
    inx
    dey
    bne @rows_p3

    stx vram_buf_len
    rts
.endproc

; Draw win screen dialog box and text
.proc draw_win_dialog
    ; Dialog box: 128x80px = 16x10 tiles of tile $00 (blank = backdrop dk purple)
    ; Centered: col = (32-16)/2 = 8, row = (30-10)/2 = 10
    ; Fill 10 rows of 16 tiles with tile $00 (backdrop $03 = dk purple)

    ldx #$0A                    ; Start row 10
    lda #$0A                    ; 10 rows
    sta temp_4

@box_loop:
    lda temp_4
    beq @box_done

    txa
    pha

    ; Compute nametable address for col 8, row X
    lsr a
    lsr a
    lsr a
    clc
    adc #$20
    sta temp_1                  ; Addr high

    pla
    pha
    asl a
    asl a
    asl a
    asl a
    asl a
    clc
    adc #$08                    ; Col 8
    sta temp_2                  ; Addr low
    bcc @no_carry
    inc temp_1
@no_carry:

    ldy vram_buf_len
    lda temp_1
    sta vram_buf, y
    iny
    lda temp_2
    sta vram_buf, y
    iny
    lda #$10                    ; 16 tiles
    sta vram_buf, y
    iny

    ldx #$10
@tile_loop:
    lda #$00                    ; Blank tile (backdrop = dk purple $03)
    sta vram_buf, y
    iny
    dex
    bne @tile_loop

    sty vram_buf_len

    pla
    tax
    inx
    dec temp_4
    jmp @box_loop

@box_done:
    jsr wait_vram_flush

    ; "YOU WIN!" centered in box: 8 chars at col 12, row 13
    lda #<str_you_win
    sta ptr_lo
    lda #>str_you_win
    sta ptr_hi
    lda #$0C                    ; Col 12
    sta temp_1
    lda #$0D                    ; Row 13
    sta temp_2
    jsr draw_text

    ; "GOODNITE XOXO" at col 9, row 16
    lda #<str_goodnite
    sta ptr_lo
    lda #>str_goodnite
    sta ptr_hi
    lda #$09
    sta temp_1
    lda #$10                    ; Row 16
    sta temp_2
    jsr draw_text

    rts
.endproc
