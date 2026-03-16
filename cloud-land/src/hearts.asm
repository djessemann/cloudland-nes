; ============================================================
; Heart Module — Spawn, despawn, collection, OAM
; ============================================================
.segment "RODATA"

; Pre-shuffled spawn sequence: 5 permutations of 0-11 (60 bytes).
; For levels with fewer platforms, each value is taken mod platform_count.
; Guarantees every cloud is visited at least 5 times before the loop resets.
HEART_SEQ_LEN = 60
heart_spawn_sequence:
  ; Perm 1
  .byte 7, 2, 10, 5, 0, 8, 3, 11, 6, 1, 9, 4
  ; Perm 2
  .byte 4, 9, 1, 6, 11, 3, 8, 0, 5, 10, 2, 7
  ; Perm 3
  .byte 10, 0, 7, 3, 9, 5, 1, 6, 11, 4, 8, 2
  ; Perm 4
  .byte 2, 8, 5, 11, 4, 0, 9, 7, 3, 6, 10, 1
  ; Perm 5
  .byte 6, 3, 11, 1, 7, 10, 4, 2, 8, 0, 5, 9

.segment "CODE"

; ------------------------------------------------------------
; hearts_init
; Deactivate hearts, compute valid spawn positions for level.
; ------------------------------------------------------------
.proc hearts_init
    ; Deactivate both hearts
    lda #$00
    sta heart_active
    sta heart_active+1
    sta heart_spawn_index

    lda #HEART_SPAWN_DELAY
    sta heart_spawn_timer

    ; Compute valid spawn positions from platform data
    jsr hearts_compute_positions
    rts
.endproc

; ------------------------------------------------------------
; hearts_compute_positions
; Generate candidate heart spawn positions above each platform.
; Position = (plat_x + 16, plat_y - 20). Filter out y < 24.
; Stores results in heart_valid_x/y/count (BSS).
; ------------------------------------------------------------
.proc hearts_compute_positions
    lda #$00
    sta heart_valid_count

    ldx current_level
    lda level_platforms_lo, x
    sta ptr_lo
    lda level_platforms_hi, x
    sta ptr_hi
    lda level_platform_count, x
    sta temp_4                  ; Platform count

    ldy #$00                    ; Offset into platform table

@loop:
    lda temp_4
    beq @done

    ; Read platform coords
    lda (ptr_lo), y
    sta temp_1                  ; plat_x
    iny
    lda (ptr_lo), y
    sta temp_2                  ; plat_y
    iny

    ; Candidate: x = plat_x + 16, y = plat_y - 20
    lda temp_2
    sec
    sbc #20
    cmp #24                     ; Must be >= 24 (below HUD)
    bcc @skip                   ; Too high, skip this position

    sta temp_3                  ; Valid Y

    ; Store position
    tya
    pha
    ldy heart_valid_count

    lda temp_1
    clc
    adc #16                     ; Center-ish on platform
    sta heart_valid_x, y

    lda temp_3
    sta heart_valid_y, y

    iny
    sty heart_valid_count

    pla
    tay

@skip:
    dec temp_4
    jmp @loop

@done:
    rts
.endproc

; ------------------------------------------------------------
; hearts_update
; Manage despawn timers and spawn new hearts.
; ------------------------------------------------------------
.proc hearts_update
    ; --- Update active hearts: decrement despawn timers ---
    ldx #$00
@timer_loop:
    cpx #MAX_HEARTS_ONSCREEN
    beq @timer_done

    lda heart_active, x
    beq @timer_next             ; Inactive, skip

    ; Decrement 16-bit timer
    lda heart_timer_lo, x
    sec
    sbc #$01
    sta heart_timer_lo, x
    lda heart_timer_hi, x
    sbc #$00
    sta heart_timer_hi, x

    ; Check if timer expired (both bytes zero)
    ora heart_timer_lo, x
    bne @timer_next

    ; Expired — deactivate
    lda #$00
    sta heart_active, x

@timer_next:
    inx
    jmp @timer_loop
@timer_done:

    ; --- Spawn logic ---
    dec heart_spawn_timer
    bne @spawn_done

    ; Reset spawn timer
    lda #HEART_SPAWN_DELAY
    sta heart_spawn_timer

    ; Check if we have room for another heart
    lda heart_active
    beq @spawn_slot0
    lda heart_active+1
    beq @spawn_slot1
    jmp @spawn_done             ; Both active, can't spawn

@spawn_slot0:
    ldx #$00
    jmp @do_spawn
@spawn_slot1:
    ldx #$01

@do_spawn:
    ; Check we have valid positions
    lda heart_valid_count
    beq @spawn_done

    stx temp_1                  ; Save heart slot index

    ; --- Sequence-based pick (all levels) ---
    ldy heart_spawn_index
    lda heart_spawn_sequence, y

    ; Advance index, wrap at HEART_SEQ_LEN
    iny
    cpy #HEART_SEQ_LEN
    bcc @seq_no_wrap
    ldy #0
@seq_no_wrap:
    sty heart_spawn_index

    ; Modulo by heart_valid_count (sequence values 0-11, count 4-12)
@seq_mod:
    cmp heart_valid_count
    bcc @pick_done
    sec
    sbc heart_valid_count
    jmp @seq_mod

@pick_done:
    tay                         ; Y = position index

    ldx temp_1                  ; Restore heart slot index
    lda heart_valid_x, y
    sta heart_x, x
    lda heart_valid_y, y
    sta heart_y, x

    lda #$01
    sta heart_active, x

    ; Set random despawn timer
    ; Range: ~240-495 frames (4-8 seconds)
    stx temp_1
    jsr rng_next
    ldx temp_1
    clc
    adc #<HEART_DESPAWN_MIN     ; Low byte: rng + 240
    sta heart_timer_lo, x
    lda #$00
    adc #>HEART_DESPAWN_MIN     ; High byte with carry
    sta heart_timer_hi, x

@spawn_done:
    rts
.endproc

; ------------------------------------------------------------
; hearts_write_oam
; Write active hearts to OAM, hide inactive ones.
; ------------------------------------------------------------
.proc hearts_write_oam
    ; Heart 0 at OAM_HEART0
    lda heart_active
    beq @hide0

    lda heart_y
    sta oam_buf + OAM_HEART0        ; Y
    lda #SPR_HEART
    sta oam_buf + OAM_HEART0 + 1    ; Tile
    lda #$02                         ; Palette 2 (heart palette)
    sta oam_buf + OAM_HEART0 + 2    ; Attr
    lda heart_x
    sta oam_buf + OAM_HEART0 + 3    ; X
    jmp @check1

@hide0:
    lda #$FF
    sta oam_buf + OAM_HEART0        ; Y = offscreen

@check1:
    ; Heart 1 at OAM_HEART1
    lda heart_active+1
    beq @hide1

    lda heart_y+1
    sta oam_buf + OAM_HEART1
    lda #SPR_HEART
    sta oam_buf + OAM_HEART1 + 1
    lda #$02
    sta oam_buf + OAM_HEART1 + 2
    lda heart_x+1
    sta oam_buf + OAM_HEART1 + 3
    rts

@hide1:
    lda #$FF
    sta oam_buf + OAM_HEART1
    rts
.endproc

; ------------------------------------------------------------
; hearts_hide_oam
; Hide all heart sprites (used during death/transitions).
; ------------------------------------------------------------
.proc hearts_hide_oam
    lda #$FF
    sta oam_buf + OAM_HEART0
    sta oam_buf + OAM_HEART1
    rts
.endproc
