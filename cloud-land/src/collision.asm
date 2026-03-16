; ============================================================
; Collision Module — Platform, Screen Bounds, Entity Checks
; ============================================================
.segment "CODE"

; ------------------------------------------------------------
; check_screen_bounds
; Clamp player X to screen, detect bottom-of-screen death.
; Sets carry if player fell off bottom (death trigger).
; ------------------------------------------------------------
.proc check_screen_bounds
    ; Clamp X: 0 to SCREEN_RIGHT
    lda player_x
    cmp #SCREEN_RIGHT+1
    bcc @x_ok
    ; Check if it wrapped past 0 (very high value = went left past 0)
    cmp #$80
    bcs @clamp_left
    lda #SCREEN_RIGHT
    sta player_x
    jmp @x_ok
@clamp_left:
    lda #$00
    sta player_x
@x_ok:

    ; Check bottom death: if player_y >= SCREEN_BOTTOM
    lda player_y
    cmp #SCREEN_BOTTOM
    bcc @no_death
    sec                         ; Signal death
    rts
@no_death:
    clc
    rts
.endproc

; ------------------------------------------------------------
; check_platform_collision
; Iterate all platforms for current level, resolve AABB.
; Priority: landing (top), head bump (bottom), side push.
; ------------------------------------------------------------
.proc check_platform_collision
    ldx current_level
    lda level_platforms_lo, x
    sta ptr_lo
    lda level_platforms_hi, x
    sta ptr_hi
    lda level_platform_count, x
    sta temp_4                  ; Platform counter

    ldy #$00                    ; Data offset into platform table

@loop:
    lda temp_4
    beq @done

    ; Read platform X, Y
    lda (ptr_lo), y
    sta temp_1                  ; plat_x
    iny
    lda (ptr_lo), y
    sta temp_2                  ; plat_y
    iny

    ; Save iteration state
    tya
    pha
    lda temp_4
    pha

    jsr check_one_platform

    ; Restore
    pla
    sta temp_4
    dec temp_4
    pla
    tay
    jmp @loop

@done:
    rts
.endproc

; ------------------------------------------------------------
; check_one_platform
; Test player AABB vs one platform (temp_1=plat_x, temp_2=plat_y).
; Resolves collision by snapping player position.
; ------------------------------------------------------------
.proc check_one_platform
    ; --- Check horizontal overlap ---
    ; player_x + PLAYER_WIDTH > plat_x ?
    lda player_x
    clc
    adc #PLAYER_WIDTH
    bcs @player_right_ok        ; Overflow = right edge > 255, always overlaps
    cmp temp_1
    bcc @bail                   ; player right edge < plat left
    beq @bail
@player_right_ok:

    ; plat_x + PLATFORM_WIDTH > player_x ?
    lda temp_1
    clc
    adc #PLATFORM_WIDTH
    bcs @plat_right_ok          ; Overflow = right edge > 255, always overlaps
    cmp player_x
    bcc @bail                   ; plat right edge < player left
    beq @bail
@plat_right_ok:

    ; Horizontal overlap confirmed. Check vertical interactions.

    ; --- Landing check ---
    ; Was player's bottom at or above platform top last frame?
    lda player_prev_y
    clc
    adc #PLAYER_HEIGHT
    cmp temp_2
    beq @check_land_cur         ; prev bottom == plat top → at surface, allow
    bcs @not_landing            ; prev bottom > plat top → was below, skip
@check_land_cur:

    ; Is player's bottom now at or below platform top?
    lda player_y
    clc
    adc #PLAYER_HEIGHT
    cmp temp_2
    bcc @bail                   ; current bottom < plat top → hasn't reached
    jmp @do_land

@bail:
    jmp @no_collision

@do_land:

    ; LANDING — snap player to stand on platform
    lda temp_2
    sec
    sbc #PLAYER_HEIGHT
    sta player_y
    lda #$00
    sta player_y_sub            ; Clear sub-pixel position
    sta player_vel_y
    sta player_vel_y_lo         ; Clear sub-pixel velocity
    lda #$01
    sta player_on_ground
    rts

@not_landing:
    ; --- Head bump check ---
    ; Was player's top below platform bottom last frame?
    lda player_prev_y
    cmp temp_2
    bcc @check_sides            ; prev_y < plat_y → was above, skip head bump

    lda temp_2
    clc
    adc #PLATFORM_HEIGHT
    sta temp_3                  ; plat bottom

    lda player_prev_y
    cmp temp_3
    bcc @check_sides            ; prev top < plat bottom → was inside, skip

    ; Is player's top now above platform bottom?
    lda player_y
    cmp temp_3
    bcs @check_sides            ; current top >= plat bottom → no bump

    ; HEAD BUMP — snap player below platform
    lda temp_3
    sta player_y
    lda #$00
    sta player_y_sub            ; Clear sub-pixel position
    ; Kill upward velocity
    lda player_vel_y
    bpl @check_sides            ; Already falling, leave it
    lda #$00
    sta player_vel_y
    sta player_vel_y_lo         ; Clear sub-pixel velocity
    rts

@check_sides:
    ; --- Side collision ---
    ; Only if there's vertical overlap
    lda player_y
    clc
    adc #PLAYER_HEIGHT
    cmp temp_2
    bcc @no_collision           ; player bottom < plat top
    beq @no_collision

    lda temp_2
    clc
    adc #PLATFORM_HEIGHT
    cmp player_y
    bcc @no_collision           ; plat bottom < player top
    beq @no_collision

    ; Vertical overlap confirmed. Push player out horizontally.
    ; Determine which side: compare player center to platform center
    lda player_x
    clc
    adc #PLAYER_WIDTH/2         ; Player center X
    sta temp_3

    lda temp_1
    clc
    adc #PLATFORM_WIDTH/2       ; Platform center X
    cmp temp_3
    bcc @push_right             ; Player center is right of platform center

    ; Push player left (player is to the left of platform)
    lda temp_1
    sec
    sbc #PLAYER_WIDTH
    bcc @clamp_zero             ; Would go negative
    sta player_x
    lda #$00
    sta player_vel_x
    rts
@clamp_zero:
    lda #$00
    sta player_x
    sta player_vel_x
    rts

@push_right:
    ; Push player right (player is to the right of platform)
    lda temp_1
    clc
    adc #PLATFORM_WIDTH
    cmp #SCREEN_RIGHT+1
    bcs @clamp_right
    sta player_x
    lda #$00
    sta player_vel_x
    rts
@clamp_right:
    lda #SCREEN_RIGHT
    sta player_x
    lda #$00
    sta player_vel_x

@no_collision:
    rts
.endproc

; ------------------------------------------------------------
; check_bird_player_collision
; Check all 4 birds vs player using reduced hitboxes.
; Returns: carry set = collision (death), carry clear = safe.
; ------------------------------------------------------------
.proc check_bird_player_collision
    ldx #$00                    ; Bird index

@loop:
    cpx #NUM_BIRDS
    beq @no_hit

    ; Skip dead birds
    lda bird_alive, x
    beq @next

    ; Bird hitbox: (bird_x + offset, bird_y + offset) size 10x10
    ; Player hitbox: (player_x + offset, player_y + offset) size 10x10

    ; Check X overlap
    lda player_x
    clc
    adc #BIRD_HITBOX_OFFSET
    sta temp_1                  ; Player hitbox left

    lda bird_x, x
    clc
    adc #BIRD_HITBOX_OFFSET
    sta temp_2                  ; Bird hitbox left

    ; player_left + size > bird_left ?
    lda temp_1
    clc
    adc #BIRD_HITBOX_SIZE
    cmp temp_2
    bcc @next                   ; No X overlap
    beq @next

    ; bird_left + size > player_left ?
    lda temp_2
    clc
    adc #BIRD_HITBOX_SIZE
    cmp temp_1
    bcc @next
    beq @next

    ; Check Y overlap
    lda player_y
    clc
    adc #BIRD_HITBOX_OFFSET
    sta temp_1                  ; Player hitbox top

    lda bird_y, x
    clc
    adc #BIRD_HITBOX_OFFSET
    sta temp_2                  ; Bird hitbox top

    lda temp_1
    clc
    adc #BIRD_HITBOX_SIZE
    cmp temp_2
    bcc @next
    beq @next

    lda temp_2
    clc
    adc #BIRD_HITBOX_SIZE
    cmp temp_1
    bcc @next
    beq @next

    ; HIT! Determine if stomp or regular hit.
    stx temp_4                  ; Save bird index for caller

    ; Stomp condition 1: player must be falling (vel_y >= 0, bit 7 clear)
    lda player_vel_y
    bmi @regular_hit            ; Rising = not a stomp

    ; Stomp condition 2: player is above bird (player_y < bird_y)
    lda player_y
    cmp bird_y, x
    bcs @regular_hit            ; player_y >= bird_y = not above

    ; STOMP: carry set, A=0 (zero flag set)
    lda #$00
    sec
    rts

@regular_hit:
    ; DEATH: carry set, A=1 (zero flag clear)
    lda #$01
    sec
    rts

@next:
    inx
    jmp @loop

@no_hit:
    clc
    rts
.endproc

; ------------------------------------------------------------
; check_heart_player_collision
; Check active hearts vs player (full 16x16 player, 8x8 heart).
; Handles collection internally (deactivate, score, HUD update).
; ------------------------------------------------------------
.proc check_heart_player_collision
    ldx #$00

@loop:
    cpx #MAX_HEARTS_ONSCREEN
    beq @done

    lda heart_active, x
    beq @next                   ; Inactive, skip

    ; X overlap: player_x + 16 > heart_x AND heart_x + 8 > player_x
    lda player_x
    clc
    adc #PLAYER_WIDTH
    cmp heart_x, x
    bcc @next
    beq @next

    lda heart_x, x
    clc
    adc #$08                    ; Heart width
    cmp player_x
    bcc @next
    beq @next

    ; Y overlap: player_y + 16 > heart_y AND heart_y + 8 > player_y
    lda player_y
    clc
    adc #PLAYER_HEIGHT
    cmp heart_y, x
    bcc @next
    beq @next

    lda heart_y, x
    clc
    adc #$08
    cmp player_y
    bcc @next
    beq @next

    ; COLLECTED!
    lda #$00
    sta heart_active, x         ; Deactivate

    inc hearts_in_level
    inc score

    jsr sfx_play_heart

    ; Queue HUD score update (2-digit with leading zero)
    txa
    pha
    lda #$1D                    ; Col 29
    sta temp_1
    lda #$01                    ; Row 1
    sta temp_2
    lda score
    jsr draw_number_2d
    pla
    tax

@next:
    inx
    jmp @loop

@done:
    rts
.endproc
