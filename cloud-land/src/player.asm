; ============================================================
; Player Module — Movement, Physics, Animation, OAM
; ============================================================
.segment "CODE"

; ------------------------------------------------------------
; player_init
; Set spawn position and reset all player state.
; ------------------------------------------------------------
.proc player_init
    ldx current_level
    lda player_spawn_x, x
    sta player_x
    lda player_spawn_y, x
    sta player_y
    sta player_prev_y

    lda #$00
    sta player_vel_x
    sta player_vel_y
    sta player_vel_y_lo
    sta player_y_sub
    sta player_x_sub
    sta player_facing

    lda #$01
    sta player_on_ground        ; Start grounded (spawn is on a platform)
    sta player_anim_frame
    sta player_jump_held
    sta player_state

    lda #WALK_ANIM_SPEED
    sta player_anim_timer
    rts
.endproc

; ------------------------------------------------------------
; player_update
; Called each frame: input → physics → velocity → animation.
; Collision is handled separately after this returns.
; ------------------------------------------------------------
.proc player_update
    ; Save previous Y for landing detection
    lda player_y
    sta player_prev_y

    ; --- Horizontal input ---
    lda #$00
    sta player_vel_x            ; Default: no movement

    lda buttons
    and #BUTTON_RIGHT
    beq @check_left
    lda #$01                    ; Positive = moving right (direction flag)
    sta player_vel_x
    lda #$01
    sta player_facing           ; 1 = right (H-flip sprite to face right)
    jmp @horiz_done

@check_left:
    lda buttons
    and #BUTTON_LEFT
    beq @horiz_done
    lda #$FF                    ; Negative = moving left (direction flag)
    sta player_vel_x
    lda #$00
    sta player_facing           ; 0 = left (sprite default faces left)

@horiz_done:

    ; --- Jump input ---
    ; Can only initiate jump when on ground
    lda player_on_ground
    beq @check_jump_release

    ; On ground: check for new A press
    lda buttons_new
    and #BUTTON_A
    beq @jump_done

    ; Initiate jump
    lda #256-JUMP_FORCE_MAX     ; Negative = upward velocity (high byte)
    sta player_vel_y
    lda #$00
    sta player_vel_y_lo         ; Clear sub-pixel velocity
    sta player_on_ground
    lda #$01
    sta player_jump_held
    jsr sfx_play_jump
    jmp @jump_done

@check_jump_release:
    ; Airborne: check if A was released early (variable jump)
    lda player_jump_held
    beq @jump_done              ; Already released, nothing to do

    lda buttons
    and #BUTTON_A
    bne @jump_done              ; Still held, let it ride

    ; A released while rising: cut jump short
    lda #$00
    sta player_jump_held

    ; If still moving upward and faster than min force, clamp
    lda player_vel_y
    bpl @jump_done              ; Already falling, no clamp needed

    ; vel_y is negative. If rising faster than -JUMP_FORCE_MIN, clamp.
    cmp #256-JUMP_FORCE_MIN
    bcs @jump_done              ; vel_y >= -JUMP_FORCE_MIN (already slow enough)
    lda #256-JUMP_FORCE_MIN     ; Clamp to -JUMP_FORCE_MIN
    sta player_vel_y
    lda #$00
    sta player_vel_y_lo         ; Clear sub-pixel velocity on clamp

@jump_done:

    ; --- Apply gravity (16-bit fixed-point) ---
    lda player_on_ground
    bne @no_gravity             ; Don't apply gravity when grounded

    ; Add gravity to velocity: vel_y (16-bit) += GRAVITY (16-bit)
    lda player_vel_y_lo
    clc
    adc #GRAVITY_LO
    sta player_vel_y_lo
    lda player_vel_y
    adc #GRAVITY_HI             ; Add high byte + carry from lo

    ; Clamp to max fall speed
    bmi @grav_store             ; Negative = still rising, no clamp
    cmp #MAX_FALL_SPEED
    bcc @grav_store             ; Below max, OK
    lda #MAX_FALL_SPEED         ; Clamp high byte
    ldx #$00
    stx player_vel_y_lo         ; Clear sub-pixel on clamp
@grav_store:
    sta player_vel_y
@no_gravity:

    ; --- Apply X velocity (16-bit fixed-point) ---
    lda player_vel_x
    beq @x_done                 ; No horizontal movement
    bmi @move_left

    ; Moving right: add WALK_SPEED (hi.lo) to player_x (hi.sub)
    lda player_x_sub
    clc
    adc #WALK_SPEED_LO
    sta player_x_sub
    lda player_x
    adc #WALK_SPEED             ; Add whole + carry from sub
    bcs @clamp_right            ; Overflow = past 255
    cmp #SCREEN_RIGHT
    bcc @store_x
    beq @store_x
@clamp_right:
    lda #SCREEN_RIGHT
    ldx #$00
    stx player_x_sub            ; Clear sub-pixel on clamp
@store_x:
    sta player_x
    jmp @x_done

@move_left:
    ; Subtract WALK_SPEED (hi.lo) from player_x (hi.sub)
    lda player_x_sub
    sec
    sbc #WALK_SPEED_LO
    sta player_x_sub
    lda player_x
    sbc #WALK_SPEED             ; Sub whole + borrow from sub
    bcc @clamp_left             ; Underflow = past 0
    sta player_x
    jmp @x_done
@clamp_left:
    lda #$00
    sta player_x
    sta player_x_sub            ; Clear sub-pixel on clamp

@x_done:

    ; --- Apply Y velocity (16-bit fixed-point) ---
    ; Add vel_y (hi.lo) to player_y (hi.sub)
    lda player_y_sub
    clc
    adc player_vel_y_lo
    sta player_y_sub
    lda player_y
    adc player_vel_y
    sta player_y

    ; Clamp at top of screen: if rising and Y wrapped past 0, clamp
    lda player_vel_y
    bpl @y_no_top_clamp         ; Not rising, skip
    lda player_y
    cmp #SCREEN_BOTTOM
    bcc @y_no_top_clamp         ; Y < 240, no wrap occurred
    ; Wrapped past top — clamp to Y=0 and kill upward velocity
    lda #$00
    sta player_y
    sta player_y_sub
    sta player_vel_y
    sta player_vel_y_lo
@y_no_top_clamp:
    ; Note: Y overflow/death handled by check_screen_bounds

    ; --- Clear on_ground for this frame ---
    ; Collision code will re-set it if we land on a platform
    lda #$00
    sta player_on_ground

    ; NOTE: Animation is updated in state_gameplay AFTER collision
    ; detection, so player_on_ground is correct when animation runs.

    rts
.endproc

; ------------------------------------------------------------
; player_update_animation
; Sets anim_frame based on state: jump, walk, or stand.
; ------------------------------------------------------------
.proc player_update_animation
    ; Airborne = jump frame
    lda player_on_ground
    bne @on_ground

    lda #$03                    ; Jump frame index
    sta player_anim_frame
    rts

@on_ground:
    ; Moving = walk animation
    lda player_vel_x
    beq @standing

    ; Walking: toggle between walk1 (1) and walk2 (2) on timer
    dec player_anim_timer
    bne @keep_frame
    lda #WALK_ANIM_SPEED
    sta player_anim_timer

    lda player_anim_frame
    cmp #$01
    beq @switch_to_walk2
    lda #$01                    ; Walk frame 1
    sta player_anim_frame
    rts
@switch_to_walk2:
    lda #$02                    ; Walk frame 2
    sta player_anim_frame
@keep_frame:
    rts

@standing:
    lda #$00                    ; Stand frame
    sta player_anim_frame
    lda #WALK_ANIM_SPEED
    sta player_anim_timer       ; Reset timer for next walk
    rts
.endproc

; ------------------------------------------------------------
; player_write_oam
; Write 4 hardware sprites (2x2 metasprite) to OAM buffer.
; Handles horizontal flip when facing left.
; ------------------------------------------------------------
.proc player_write_oam
    ; Calculate base tile from anim frame (0=stand, 1=walk1, 2=walk2, 3=jump)
    lda player_anim_frame
    asl a
    asl a                       ; * 4 tiles per frame
    sta temp_1                  ; temp_1 = base tile index

    ; Determine attribute byte and tile order
    lda player_facing
    bne @facing_left

    ; --- Facing right (no flip) ---
    ; Sprite 0: top-left
    ldx #OAM_PLAYER
    lda player_y
    sta oam_buf, x              ; Y
    lda temp_1
    sta oam_buf+1, x            ; Tile TL
    lda #$00                    ; Palette 0, no flip
    sta oam_buf+2, x            ; Attr
    lda player_x
    sta oam_buf+3, x            ; X

    ; Sprite 1: top-right
    lda player_y
    sta oam_buf+4, x
    lda temp_1
    clc
    adc #$01
    sta oam_buf+5, x            ; Tile TR
    lda #$00
    sta oam_buf+6, x
    lda player_x
    clc
    adc #$08
    sta oam_buf+7, x

    ; Sprite 2: bottom-left
    lda player_y
    clc
    adc #$08
    sta oam_buf+8, x
    lda temp_1
    clc
    adc #$02
    sta oam_buf+9, x            ; Tile BL
    lda #$00
    sta oam_buf+10, x
    lda player_x
    sta oam_buf+11, x

    ; Sprite 3: bottom-right
    lda player_y
    clc
    adc #$08
    sta oam_buf+12, x
    lda temp_1
    clc
    adc #$03
    sta oam_buf+13, x           ; Tile BR
    lda #$00
    sta oam_buf+14, x
    lda player_x
    clc
    adc #$08
    sta oam_buf+15, x
    rts

@facing_left:
    ; H-flip: swap TL↔TR and BL↔BR, set attribute bit 6
    ldx #OAM_PLAYER

    ; Sprite 0: top-left position gets TR tile (flipped)
    lda player_y
    sta oam_buf, x
    lda temp_1
    clc
    adc #$01                    ; TR tile
    sta oam_buf+1, x
    lda #$40                    ; H-flip
    sta oam_buf+2, x
    lda player_x
    sta oam_buf+3, x

    ; Sprite 1: top-right position gets TL tile (flipped)
    lda player_y
    sta oam_buf+4, x
    lda temp_1                  ; TL tile
    sta oam_buf+5, x
    lda #$40
    sta oam_buf+6, x
    lda player_x
    clc
    adc #$08
    sta oam_buf+7, x

    ; Sprite 2: bottom-left position gets BR tile (flipped)
    lda player_y
    clc
    adc #$08
    sta oam_buf+8, x
    lda temp_1
    clc
    adc #$03                    ; BR tile
    sta oam_buf+9, x
    lda #$40
    sta oam_buf+10, x
    lda player_x
    sta oam_buf+11, x

    ; Sprite 3: bottom-right position gets BL tile (flipped)
    lda player_y
    clc
    adc #$08
    sta oam_buf+12, x
    lda temp_1
    clc
    adc #$02                    ; BL tile
    sta oam_buf+13, x
    lda #$40
    sta oam_buf+14, x
    lda player_x
    clc
    adc #$08
    sta oam_buf+15, x
    rts
.endproc

; ------------------------------------------------------------
; player_write_oam_death
; Write death sprite: standing frame, vertically flipped.
; Swap top↔bottom rows, set V-flip bit (bit 7).
; ------------------------------------------------------------
.proc player_write_oam_death
    ldx #OAM_PLAYER

    ; Sprite 0: top position gets BL tile (V-flipped)
    lda player_y
    sta oam_buf, x
    lda #SPR_PLAYER_STAND + 2   ; BL tile
    sta oam_buf+1, x
    lda #$80                    ; V-flip, palette 0
    sta oam_buf+2, x
    lda player_x
    sta oam_buf+3, x

    ; Sprite 1: top-right gets BR tile (V-flipped)
    lda player_y
    sta oam_buf+4, x
    lda #SPR_PLAYER_STAND + 3   ; BR tile
    sta oam_buf+5, x
    lda #$80
    sta oam_buf+6, x
    lda player_x
    clc
    adc #$08
    sta oam_buf+7, x

    ; Sprite 2: bottom gets TL tile (V-flipped)
    lda player_y
    clc
    adc #$08
    sta oam_buf+8, x
    lda #SPR_PLAYER_STAND       ; TL tile
    sta oam_buf+9, x
    lda #$80
    sta oam_buf+10, x
    lda player_x
    sta oam_buf+11, x

    ; Sprite 3: bottom-right gets TR tile (V-flipped)
    lda player_y
    clc
    adc #$08
    sta oam_buf+12, x
    lda #SPR_PLAYER_STAND + 1   ; TR tile
    sta oam_buf+13, x
    lda #$80
    sta oam_buf+14, x
    lda player_x
    clc
    adc #$08
    sta oam_buf+15, x
    rts
.endproc

; ------------------------------------------------------------
; rng_next
; Advance 16-bit Galois LFSR. Returns random byte in A.
; Must seed rng_seed to non-zero before first use.
; ------------------------------------------------------------
.proc rng_next
    lda rng_seed
    asl a
    rol rng_seed+1
    bcc @no_tap
    lda rng_seed
    eor #$B8
    sta rng_seed
    lda rng_seed+1
    eor #$00
    sta rng_seed+1
@no_tap:
    lda rng_seed
    rts
.endproc
