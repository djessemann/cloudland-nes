; ============================================================
; Reset Handler — Standard NES boot sequence
; ============================================================
.segment "CODE"

.proc reset
    sei                         ; Disable IRQs
    cld                         ; Clear decimal mode (not used on NES but required)
    ldx #$40
    stx $4017                   ; Disable APU frame IRQ
    ldx #$FF
    txs                         ; Initialize stack pointer to $01FF
    inx                         ; X = $00
    stx $2000                   ; Disable NMI
    stx $2001                   ; Disable rendering
    stx $4010                   ; Disable DMC IRQs

    ; --- Wait for first vblank ---
@vblank1:
    bit $2002
    bpl @vblank1

    ; --- Clear all RAM ($0000-$07FF) ---
    lda #$00
    ldx #$00
@clear_ram:
    sta $0000, x
    sta $0100, x
    sta $0200, x
    sta $0300, x
    sta $0400, x
    sta $0500, x
    sta $0600, x
    sta $0700, x
    inx
    bne @clear_ram

    ; --- Hide all sprites (Y position = $FF = off-screen) ---
    lda #$FF
    ldx #$00
@clear_oam:
    sta oam_buf, x
    inx
    bne @clear_oam

    ; --- Wait for second vblank (PPU is now fully warmed up) ---
@vblank2:
    bit $2002
    bpl @vblank2

    ; PPU is ready — jump to main game initialization
    jmp main
.endproc
