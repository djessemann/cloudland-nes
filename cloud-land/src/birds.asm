; ============================================================
; Bird Module — 4 birds per level, movement, oscillation, OAM
; ============================================================
.segment "CODE"

; ------------------------------------------------------------
; birds_init
; Initialize all 4 birds for current level.
; ------------------------------------------------------------
.proc birds_init
    ; Load bird init X positions for this level
    ldx current_level
    lda bird_init_x_lo, x
    sta ptr_lo
    lda bird_init_x_hi, x
    sta ptr_hi

    ; Copy X positions
    ldy #$00
@copy_x:
    lda (ptr_lo), y
    sta bird_x, y
    iny
    cpy #NUM_BIRDS
    bne @copy_x

    ; Load bird init directions
    ldx current_level
    lda bird_init_dir_lo, x
    sta ptr_lo
    lda bird_init_dir_hi, x
    sta ptr_hi

    ldy #$00
@copy_dir:
    lda (ptr_lo), y
    sta bird_dir, y
    iny
    cpy #NUM_BIRDS
    bne @copy_dir

    ; Set initial Y from zone centers, zero offsets
    ldx #$00
@init_bird:
    lda bird_zone_center_y, x
    sta bird_y, x

    lda #$01
    sta bird_alive, x

    lda #$00
    sta bird_y_offset, x
    sta bird_osc_dir, x
    sta bird_anim_frame, x
    sta bird_x_sub, x          ; Clear sub-pixel accumulator

    ; Init per-bird speed: 4.4 fixed-point ($10 = 1.0 px/frame)
    lda #$10
    sta bird_cur_speed, x

    ; Stagger osc timers so birds don't sync
    txa
    asl a
    asl a                       ; * 4 for stagger
    clc
    adc #$01
    sta bird_osc_timer, x

    lda #BIRD_ANIM_SPEED
    sta bird_anim_timer, x

    inx
    cpx #NUM_BIRDS
    bne @init_bird

    rts
.endproc

; ------------------------------------------------------------
; birds_update
; Update all 4 birds: horizontal move, oscillation, animation.
; ------------------------------------------------------------
.proc birds_update
    ; Cache per-level osc speed (same for all birds in a level)
    ldx current_level
    lda bird_osc_speed, x
    sta temp_4                  ; Osc speed (timer reset value)

    ldx #$00
@bird_loop:
    cpx #NUM_BIRDS
    bne @bird_continue
    jmp @done
@bird_continue:
    ; Check if bird is alive
    lda bird_alive, x
    bne @bird_alive
    jmp @bird_dead

@bird_alive:
    ; --- Compute pixels to move from 4.4 fixed-point speed ---
    ; Integer part of speed
    lda bird_cur_speed, x
    lsr a
    lsr a
    lsr a
    lsr a
    sta temp_3                  ; Integer pixels (at least)

    ; Fractional part of speed: accumulate sub-pixel
    lda bird_cur_speed, x
    and #$0F                    ; Fractional nibble
    clc
    adc bird_x_sub, x          ; Add to accumulator
    cmp #$10                    ; Overflow into a pixel?
    bcc @no_frac_carry
    sbc #$10                    ; Remove overflow
    inc temp_3                  ; Extra pixel this frame
@no_frac_carry:
    sta bird_x_sub, x          ; Store updated fraction

    ; temp_3 = total pixels to move this frame

    ; --- Horizontal movement ---
    lda bird_dir, x
    bne @move_left

    ; Moving right
    lda bird_x, x
    clc
    adc temp_3
    sta bird_x, x
    cmp #SCREEN_RIGHT
    bcc @horiz_done
    lda #SCREEN_RIGHT
    sta bird_x, x
    lda #$01
    sta bird_dir, x            ; Reverse to left
    jmp @horiz_done

@move_left:
    lda bird_x, x
    sec
    sbc temp_3
    sta bird_x, x
    bcs @horiz_done
    ; Underflow: clamp to 0, reverse
    lda #$00
    sta bird_x, x
    sta bird_dir, x            ; Reverse to right

@horiz_done:

    ; --- Vertical oscillation (triangle wave) ---
    dec bird_osc_timer, x
    bne @osc_done

    ; Timer expired: move 1px and reset
    lda temp_4
    sta bird_osc_timer, x      ; Reset timer

    lda bird_osc_dir, x
    bne @osc_up

    ; Moving down (offset increasing)
    inc bird_y_offset, x
    ; Check if reached positive amplitude limit
    ; amplitude/2 is half the total range
    stx temp_1                  ; Save X
    ldy current_level
    lda bird_osc_amplitude, y
    lsr a                       ; / 2 = half amplitude
    ldx temp_1                  ; Restore X
    cmp bird_y_offset, x
    bne @osc_done
    ; Reached limit: reverse direction
    lda #$01
    sta bird_osc_dir, x
    jmp @osc_done

@osc_up:
    ; Moving up (offset decreasing)
    dec bird_y_offset, x
    ; Check if reached negative amplitude limit
    ; Need signed compare: offset is signed byte
    ; Negative limit = -(amplitude/2) = 256 - amplitude/2
    stx temp_1
    ldy current_level
    lda bird_osc_amplitude, y
    lsr a                       ; half amplitude
    ; Negate: 256 - value
    sta temp_2
    lda #$00
    sec
    sbc temp_2                  ; A = -half_amplitude (two's complement)
    ldx temp_1
    cmp bird_y_offset, x
    bne @osc_done
    ; Reached limit: reverse direction
    lda #$00
    sta bird_osc_dir, x

@osc_done:
    ; Compute bird_y = zone_center + offset (signed add)
    lda bird_zone_center_y, x
    clc
    adc bird_y_offset, x
    sta bird_y, x

    ; --- Animation ---
    dec bird_anim_timer, x
    bne @anim_done
    lda #BIRD_ANIM_SPEED
    sta bird_anim_timer, x

    ; Advance in sequence (0-5, wrap)
    lda bird_anim_frame, x
    clc
    adc #$01
    cmp #BIRD_ANIM_SEQ_LEN
    bcc @store_anim
    lda #$00                    ; Wrap to start
@store_anim:
    sta bird_anim_frame, x

@anim_done:
    inx
    jmp @bird_loop

@bird_dead:
    ; --- Respawn timer (16-bit decrement) ---
    lda bird_respawn_lo, x
    ora bird_respawn_hi, x
    beq @do_respawn             ; Timer hit 0 → respawn

    lda bird_respawn_lo, x
    bne @dec_lo_only
    dec bird_respawn_hi, x      ; Borrow from high byte
@dec_lo_only:
    dec bird_respawn_lo, x

    ; --- Death fall physics (skip if already offscreen) ---
    lda bird_y, x
    cmp #$F0
    bcs @bird_dead_next         ; Already offscreen, just wait

    lda bird_death_vel, x
    bmi @dead_vel_up

    ; Falling down: add velocity to Y, check overflow
    clc
    adc bird_y, x
    bcs @dead_offscreen         ; Wrapped past 255
    cmp #SCREEN_BOTTOM
    bcs @dead_offscreen         ; Past screen bottom
    sta bird_y, x
    jmp @dead_apply_grav

@dead_vel_up:
    ; Moving up (initial pop): signed add
    clc
    adc bird_y, x
    sta bird_y, x

@dead_apply_grav:
    lda bird_death_vel, x
    clc
    adc #BIRD_DEATH_GRAVITY
    sta bird_death_vel, x

@bird_dead_next:
    inx
    jmp @bird_loop

@dead_offscreen:
    lda #$F0
    sta bird_y, x
    inx
    jmp @bird_loop

@do_respawn:
    ; Respawn bird as far from player as possible
    lda #$01
    sta bird_alive, x

    ; --- Increase speed by ~12.5% (speed += speed >> 3) ---
    lda bird_cur_speed, x
    lsr a
    lsr a
    lsr a                       ; speed / 8
    clc
    adc bird_cur_speed, x
    bcs @speed_cap              ; Overflow: cap
    cmp #$30                    ; Max 3.0 px/frame
    bcc @speed_ok
@speed_cap:
    lda #$30
@speed_ok:
    sta bird_cur_speed, x
    lda #$00
    sta bird_x_sub, x          ; Reset sub-pixel on respawn

    ; Reset oscillation and animation state
    lda #$00
    sta bird_y_offset, x
    sta bird_osc_dir, x
    sta bird_anim_frame, x
    lda #$01
    sta bird_osc_timer, x
    lda #BIRD_ANIM_SPEED
    sta bird_anim_timer, x

    ; Y = zone center
    lda bird_zone_center_y, x
    sta bird_y, x

    ; X = opposite side of screen from player
    lda player_x
    cmp #$80                    ; Player in left half?
    bcc @spawn_right

    ; Player on right → spawn on left
    lda #$00
    sta bird_x, x
    sta bird_dir, x             ; Face right (toward center)
    inx
    jmp @bird_loop

@spawn_right:
    ; Player on left → spawn on right
    lda #SCREEN_RIGHT
    sta bird_x, x
    lda #$01
    sta bird_dir, x             ; Face left (toward center)
    inx
    jmp @bird_loop

@done:
    rts
.endproc

; ------------------------------------------------------------
; birds_write_oam
; Write all 4 birds as 2x2 metasprites to OAM buffer.
; ------------------------------------------------------------
.proc birds_write_oam
    ldx #$00                    ; Bird index

@bird_loop:
    cpx #NUM_BIRDS
    bne @oam_continue
    jmp @done
@oam_continue:

    ; Save bird index
    stx temp_1

    ; Check if bird is alive
    lda bird_alive, x
    bne @bird_is_alive
    jmp @draw_dead

@bird_is_alive:
    ; Calculate OAM base: OAM_BIRD0 + bird_index * 16
    txa
    asl a
    asl a
    asl a
    asl a                       ; * 16
    clc
    adc #OAM_BIRD0
    tay                         ; Y = OAM offset

    ; Get tile base from animation sequence
    ldx temp_1
    lda bird_anim_frame, x
    tax
    lda bird_anim_sequence, x   ; Actual frame 0-3
    asl a
    asl a                       ; * 4 tiles per frame
    clc
    adc #SPR_BIRD_BASE
    sta temp_2                  ; Base tile index

    ; Determine attribute: palette 1 + H-flip if moving left
    ldx temp_1
    lda bird_dir, x
    beq @attr_right
    lda #$41                    ; Palette 1 + H-flip
    jmp @attr_set
@attr_right:
    lda #$01                    ; Palette 1, no flip
@attr_set:
    sta temp_3                  ; Attribute byte

    ldx temp_1                  ; Restore bird index for positions

    ; Check direction for tile order
    lda bird_dir, x
    bne @draw_flipped

    ; --- Normal (facing right) ---
    ; Sprite 0: top-left
    lda bird_y, x
    sta oam_buf, y
    lda temp_2
    sta oam_buf+1, y
    lda temp_3
    sta oam_buf+2, y
    lda bird_x, x
    sta oam_buf+3, y

    ; Sprite 1: top-right
    lda bird_y, x
    sta oam_buf+4, y
    lda temp_2
    clc
    adc #$01
    sta oam_buf+5, y
    lda temp_3
    sta oam_buf+6, y
    lda bird_x, x
    clc
    adc #$08
    sta oam_buf+7, y

    ; Sprite 2: bottom-left
    lda bird_y, x
    clc
    adc #$08
    sta oam_buf+8, y
    lda temp_2
    clc
    adc #$02
    sta oam_buf+9, y
    lda temp_3
    sta oam_buf+10, y
    lda bird_x, x
    sta oam_buf+11, y

    ; Sprite 3: bottom-right
    lda bird_y, x
    clc
    adc #$08
    sta oam_buf+12, y
    lda temp_2
    clc
    adc #$03
    sta oam_buf+13, y
    lda temp_3
    sta oam_buf+14, y
    lda bird_x, x
    clc
    adc #$08
    sta oam_buf+15, y

    jmp @next

@draw_flipped:
    ; H-flip: swap TL↔TR and BL↔BR in positions
    ; Sprite 0: left pos gets TR tile
    lda bird_y, x
    sta oam_buf, y
    lda temp_2
    clc
    adc #$01                    ; TR tile
    sta oam_buf+1, y
    lda temp_3
    sta oam_buf+2, y
    lda bird_x, x
    sta oam_buf+3, y

    ; Sprite 1: right pos gets TL tile
    lda bird_y, x
    sta oam_buf+4, y
    lda temp_2                  ; TL tile
    sta oam_buf+5, y
    lda temp_3
    sta oam_buf+6, y
    lda bird_x, x
    clc
    adc #$08
    sta oam_buf+7, y

    ; Sprite 2: bottom-left pos gets BR tile
    lda bird_y, x
    clc
    adc #$08
    sta oam_buf+8, y
    lda temp_2
    clc
    adc #$03                    ; BR tile
    sta oam_buf+9, y
    lda temp_3
    sta oam_buf+10, y
    lda bird_x, x
    sta oam_buf+11, y

    ; Sprite 3: bottom-right pos gets BL tile
    lda bird_y, x
    clc
    adc #$08
    sta oam_buf+12, y
    lda temp_2
    clc
    adc #$02                    ; BL tile
    sta oam_buf+13, y
    lda temp_3
    sta oam_buf+14, y
    lda bird_x, x
    clc
    adc #$08
    sta oam_buf+15, y

    jmp @next

@draw_dead:
    ; Calculate OAM base for dead bird
    ldx temp_1
    txa
    asl a
    asl a
    asl a
    asl a                       ; * 16
    clc
    adc #OAM_BIRD0
    tay                         ; Y = OAM offset

    ; Check if off-screen (hidden)
    ldx temp_1
    lda bird_y, x
    cmp #$F0
    bcc @dead_visible
    jmp @hide_dead_bird

@dead_visible:
    ; Use standing frame for death (base tile = SPR_BIRD_BASE)
    lda #SPR_BIRD_BASE
    sta temp_2                  ; Base tile index

    ; Attribute: V-flip ($80) + palette 1 ($01), add H-flip ($40) if facing left
    lda bird_dir, x
    beq @dead_attr_right
    lda #$C1                    ; Palette 1 + H-flip + V-flip
    jmp @dead_attr_set
@dead_attr_right:
    lda #$81                    ; Palette 1 + V-flip
@dead_attr_set:
    sta temp_3

    ldx temp_1
    lda bird_dir, x
    bne @dead_draw_hv_flip

    ; --- V-flip only (facing right): swap top↔bottom rows ---
    ; Sprite 0: top-left pos gets BL tile
    lda bird_y, x
    sta oam_buf, y
    lda temp_2
    clc
    adc #$02
    sta oam_buf+1, y
    lda temp_3
    sta oam_buf+2, y
    lda bird_x, x
    sta oam_buf+3, y

    ; Sprite 1: top-right pos gets BR tile
    lda bird_y, x
    sta oam_buf+4, y
    lda temp_2
    clc
    adc #$03
    sta oam_buf+5, y
    lda temp_3
    sta oam_buf+6, y
    lda bird_x, x
    clc
    adc #$08
    sta oam_buf+7, y

    ; Sprite 2: bottom-left pos gets TL tile
    lda bird_y, x
    clc
    adc #$08
    sta oam_buf+8, y
    lda temp_2
    sta oam_buf+9, y
    lda temp_3
    sta oam_buf+10, y
    lda bird_x, x
    sta oam_buf+11, y

    ; Sprite 3: bottom-right pos gets TR tile
    lda bird_y, x
    clc
    adc #$08
    sta oam_buf+12, y
    lda temp_2
    clc
    adc #$01
    sta oam_buf+13, y
    lda temp_3
    sta oam_buf+14, y
    lda bird_x, x
    clc
    adc #$08
    sta oam_buf+15, y

    jmp @next

@dead_draw_hv_flip:
    ; --- H+V flip (facing left): diagonal tile swap ---
    ; Sprite 0: top-left pos gets BR tile
    lda bird_y, x
    sta oam_buf, y
    lda temp_2
    clc
    adc #$03
    sta oam_buf+1, y
    lda temp_3
    sta oam_buf+2, y
    lda bird_x, x
    sta oam_buf+3, y

    ; Sprite 1: top-right pos gets BL tile
    lda bird_y, x
    sta oam_buf+4, y
    lda temp_2
    clc
    adc #$02
    sta oam_buf+5, y
    lda temp_3
    sta oam_buf+6, y
    lda bird_x, x
    clc
    adc #$08
    sta oam_buf+7, y

    ; Sprite 2: bottom-left pos gets TR tile
    lda bird_y, x
    clc
    adc #$08
    sta oam_buf+8, y
    lda temp_2
    clc
    adc #$01
    sta oam_buf+9, y
    lda temp_3
    sta oam_buf+10, y
    lda bird_x, x
    sta oam_buf+11, y

    ; Sprite 3: bottom-right pos gets TL tile
    lda bird_y, x
    clc
    adc #$08
    sta oam_buf+12, y
    lda temp_2
    sta oam_buf+13, y
    lda temp_3
    sta oam_buf+14, y
    lda bird_x, x
    clc
    adc #$08
    sta oam_buf+15, y

    jmp @next

@hide_dead_bird:
    lda #$FF
    sta oam_buf, y
    sta oam_buf+4, y
    sta oam_buf+8, y
    sta oam_buf+12, y

@next:
    ldx temp_1
    inx
    jmp @bird_loop

@done:
    rts
.endproc

; ------------------------------------------------------------
; birds_hide_oam
; Hide all bird sprites (used during death animation cleanup).
; ------------------------------------------------------------
.proc birds_hide_oam
    lda #$FF
    ldx #OAM_BIRD0
@loop:
    sta oam_buf, x
    inx
    inx
    inx
    inx
    cpx #OAM_BIRD0 + (NUM_BIRDS * 16)
    bne @loop
    rts
.endproc
