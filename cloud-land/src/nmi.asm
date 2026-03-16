; ============================================================
; NMI Handler — Runs every vblank
; All PPU writes happen here. Game logic stays in main thread.
; ============================================================
.segment "CODE"

.proc nmi_handler
    ; Save registers
    pha
    txa
    pha
    tya
    pha

    ; --- OAM DMA transfer (copy $0200-$02FF to PPU OAM) ---
    lda #$00
    sta $2003                   ; Set OAM start address to 0
    lda #>oam_buf               ; High byte of oam_buf ($02)
    sta $4014                   ; Trigger OAM DMA

    ; --- Flush VRAM buffer if anything is queued ---
    ldx vram_buf_len
    beq @no_vram_update

    lda $2002                   ; Reset PPU address latch

    ldx #$00
@vram_loop:
    cpx vram_buf_len
    beq @vram_done

    ; Read PPU address (high byte, then low byte)
    lda vram_buf, x
    sta $2006
    inx
    lda vram_buf, x
    sta $2006
    inx

    ; Read data length
    lda vram_buf, x
    sta temp_1
    inx

    ; Write data bytes
    ldy #$00
@data_loop:
    cpy temp_1
    beq @next_entry
    lda vram_buf, x
    sta $2007
    inx
    iny
    jmp @data_loop

@next_entry:
    jmp @vram_loop

@vram_done:
    ; Clear buffer
    lda #$00
    sta vram_buf_len

@no_vram_update:
    ; --- Apply PPU registers ---
    lda ppu_ctrl
    sta $2000
    lda ppu_mask
    sta $2001
    lda ppu_scroll_x
    sta $2005
    lda ppu_scroll_y
    sta $2005

    ; --- Update sound ---
    jsr sound_update

    ; --- Signal main loop ---
    lda #$01
    sta nmi_ready

    ; Restore registers
    pla
    tay
    pla
    tax
    pla
    rti
.endproc
