; ============================================================
; Controller Input
; ============================================================
.segment "CODE"

; ------------------------------------------------------------
; read_controller
; Read controller 1 state into `buttons`.
; Computes `buttons_new` = buttons pressed this frame (edge detect).
; Bit layout: A B Sel Start Up Down Left Right
; ------------------------------------------------------------
.proc read_controller
    ; Save previous frame's state
    lda buttons
    sta buttons_prev

    ; Strobe controller
    lda #$01
    sta $4016
    lda #$00
    sta $4016

    ; Read 8 buttons — each read returns button state in bit 0
    ldx #$08
@loop:
    lda $4016
    lsr a                       ; Bit 0 -> carry
    rol buttons                 ; Carry -> buttons (bit 0), shifts left
    dex
    bne @loop

    ; Compute newly pressed buttons (pressed now AND not pressed last frame)
    lda buttons
    eor buttons_prev            ; Bits that changed
    and buttons                 ; Only the ones that are now pressed
    sta buttons_new

    rts
.endproc
