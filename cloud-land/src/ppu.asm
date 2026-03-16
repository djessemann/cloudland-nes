; ============================================================
; PPU Utility Routines
; ============================================================
.segment "CODE"

; ------------------------------------------------------------
; load_palettes
; Copy 32 bytes of palette data to PPU $3F00.
; Must be called with rendering disabled (during init or vblank).
; Expects palette data address in ptr_lo/ptr_hi.
; ------------------------------------------------------------
.proc load_palettes
    lda $2002                   ; Reset PPU address latch
    lda #$3F
    sta $2006
    lda #$00
    sta $2006                   ; PPU address = $3F00

    ldy #$00
@loop:
    lda (ptr_lo), y
    sta $2007
    iny
    cpy #$20                    ; 32 bytes = 4 BG + 4 sprite palettes
    bne @loop

    ; Reset PPU address and scroll to avoid visual glitches
    lda #$00
    sta $2006
    sta $2006
    sta $2005
    sta $2005
    rts
.endproc

; ------------------------------------------------------------
; clear_nametable
; Fill nametable 0 ($2000-$23FF) with tile $00 and zero attributes.
; Must be called with rendering disabled.
; ------------------------------------------------------------
.proc clear_nametable
    lda $2002                   ; Reset PPU address latch
    lda #$20
    sta $2006
    lda #$00
    sta $2006                   ; PPU address = $2000

    ; Write 1024 bytes of $00 (960 tiles + 64 attribute bytes)
    lda #$00
    ldx #$04                    ; 4 x 256 = 1024
    ldy #$00
@loop:
    sta $2007
    iny
    bne @loop
    dex
    bne @loop
    rts
.endproc

; ------------------------------------------------------------
; draw_text
; Buffer a null-terminated ASCII string into VRAM buffer for
; NMI to flush. Converts ASCII codes directly to tile indices.
;
; Input: ptr_lo/ptr_hi = string address
;        temp_1 = nametable tile X (0-31)
;        temp_2 = nametable tile Y (0-29)
; Clobbers: A, X, Y, temp_3, temp_4
; ------------------------------------------------------------
.proc draw_text
    ; Calculate nametable address: $2000 + (Y * 32) + X
    lda temp_2
    lsr a
    lsr a
    lsr a
    clc
    adc #$20                    ; Base nametable at $2000
    sta temp_4                  ; temp_4 = address high byte

    lda temp_2
    asl a
    asl a
    asl a
    asl a
    asl a                       ; A = (Y & 7) * 32
    clc
    adc temp_1                  ; A = low byte + X offset
    sta temp_3                  ; temp_3 = address low byte
    bcc @no_carry
    inc temp_4
@no_carry:

    ; First pass: count string length
    ldy #$00
@count:
    lda (ptr_lo), y
    beq @counted
    iny
    jmp @count
@counted:
    sty temp_1                  ; temp_1 = string length (reuse)

    ; Write VRAM buffer entry: [addr_hi, addr_lo, length, data...]
    ldx vram_buf_len
    lda temp_4
    sta vram_buf, x
    inx
    lda temp_3
    sta vram_buf, x
    inx
    lda temp_1
    sta vram_buf, x
    inx

    ; Copy string bytes (tile indices = ASCII values)
    ldy #$00
@copy:
    cpy temp_1
    beq @done
    lda (ptr_lo), y
    sta vram_buf, x
    inx
    iny
    jmp @copy
@done:
    stx vram_buf_len
    rts
.endproc

; ------------------------------------------------------------
; draw_large_text
; Draw "CLOUD LAND" using 3x3 tile large font characters.
; Reads str_cloud_land: each byte is base tile for a 3x3 char.
;
; Input: temp_1 = starting nametable tile X
;        temp_2 = starting nametable tile Y
; Clobbers: A, X, Y, temp_3, temp_4, ptr_lo, ptr_hi
; ------------------------------------------------------------
.proc draw_large_text
    lda #<str_cloud_land
    sta ptr_lo
    lda #>str_cloud_land
    sta ptr_hi

    ldy #$00                    ; String index
@char_loop:
    lda (ptr_lo), y
    cmp #$FF                    ; Terminator?
    beq @done
    sta temp_3                  ; temp_3 = base tile

    ; Save Y (string index) and temp_1 (current X) on stack
    tya
    pha
    lda temp_1
    pha

    ; Draw 3 rows of 3 tiles each
    ldx #$00                    ; Row counter
@row_loop:
    cpx #$03
    beq @next_char

    stx temp_4                  ; Save row counter

    ; Compute tile Y for this row
    txa
    clc
    adc temp_2                  ; A = tile Y + row

    ; Build VRAM buffer entry
    pha                         ; Save Y coord
    ldx vram_buf_len

    ; PPU address high byte
    pla
    pha
    lsr a
    lsr a
    lsr a
    clc
    adc #$20
    sta vram_buf, x
    inx

    ; PPU address low byte
    pla
    asl a
    asl a
    asl a
    asl a
    asl a
    clc
    adc temp_1
    sta vram_buf, x
    inx

    ; Length = 3
    lda #$03
    sta vram_buf, x
    inx

    ; 3 tile indices: base + (row * 3) + 0, +1, +2
    lda temp_4                  ; Row
    asl a
    clc
    adc temp_4                  ; * 3
    clc
    adc temp_3                  ; + base tile
    sta vram_buf, x
    inx
    clc
    adc #$01
    sta vram_buf, x
    inx
    clc
    adc #$01
    sta vram_buf, x
    inx

    stx vram_buf_len

    ldx temp_4                  ; Restore row counter
    inx
    jmp @row_loop

@next_char:
    pla                         ; Restore X pos
    clc
    adc #$03
    sta temp_1

    pla                         ; Restore string index
    tay
    iny
    jmp @char_loop

@done:
    rts
.endproc

; ------------------------------------------------------------
; draw_number
; Draw a 1-2 digit decimal number to VRAM buffer.
;
; Input: A = number (0-99)
;        temp_1 = nametable tile X
;        temp_2 = nametable tile Y
; Clobbers: A, X, Y, temp_3, temp_4
; ------------------------------------------------------------
.proc draw_number
    sta temp_3                  ; Save number

    ; Calculate nametable address
    lda temp_2
    lsr a
    lsr a
    lsr a
    clc
    adc #$20
    sta temp_4                  ; High byte

    lda temp_2
    asl a
    asl a
    asl a
    asl a
    asl a
    clc
    adc temp_1
    pha                         ; Save low byte

    ; Single or two digits?
    lda temp_3
    cmp #10
    bcs @two_digits

    ; --- Single digit ---
    ldx vram_buf_len
    lda temp_4
    sta vram_buf, x
    inx
    pla
    sta vram_buf, x
    inx
    lda #$01
    sta vram_buf, x
    inx
    lda temp_3
    clc
    adc #$30                    ; ASCII '0'
    sta vram_buf, x
    inx
    stx vram_buf_len
    rts

@two_digits:
    ldy #$00                    ; Tens counter
    lda temp_3
@div10:
    cmp #10
    bcc @div_done
    sec
    sbc #10
    iny
    jmp @div10
@div_done:
    sta temp_3                  ; Ones digit

    ldx vram_buf_len
    lda temp_4
    sta vram_buf, x
    inx
    pla
    sta vram_buf, x
    inx
    lda #$02
    sta vram_buf, x
    inx
    tya
    clc
    adc #$30                    ; Tens tile
    sta vram_buf, x
    inx
    lda temp_3
    clc
    adc #$30                    ; Ones tile
    sta vram_buf, x
    inx
    stx vram_buf_len
    rts
.endproc

; ------------------------------------------------------------
; draw_number_2d
; Like draw_number but always writes 2 digits with leading zero.
;
; Input: A = number (0-99), temp_1 = tile X, temp_2 = tile Y
; Clobbers: A, X, Y, temp_3, temp_4
; ------------------------------------------------------------
.proc draw_number_2d
    sta temp_3                  ; Save number

    ; Calculate nametable address
    lda temp_2
    lsr a
    lsr a
    lsr a
    clc
    adc #$20
    sta temp_4                  ; High byte

    lda temp_2
    asl a
    asl a
    asl a
    asl a
    asl a
    clc
    adc temp_1                  ; Low byte

    ; Write 2-tile VRAM entry
    ldx vram_buf_len
    pha                         ; Save low byte
    lda temp_4
    sta vram_buf, x
    inx
    pla                         ; Restore low byte
    sta vram_buf, x
    inx
    lda #$02                    ; Always 2 tiles
    sta vram_buf, x
    inx

    ; Divide by 10
    ldy #$00                    ; Tens counter
    lda temp_3
@div10:
    cmp #10
    bcc @div_done
    sec
    sbc #10
    iny
    jmp @div10
@div_done:
    sta temp_3                  ; Ones digit

    tya
    clc
    adc #$30                    ; Tens tile (0 → '0')
    sta vram_buf, x
    inx
    lda temp_3
    clc
    adc #$30                    ; Ones tile
    sta vram_buf, x
    inx
    stx vram_buf_len
    rts
.endproc

; ------------------------------------------------------------
; draw_hud
; Draws "LEVEL X" at tile (1,1) and "SCORE XX" at tile (24,1).
;
; Input: current_level (0-4), score (0-50)
; Clobbers: A, X, Y, temp_1-4, ptr_lo, ptr_hi
; ------------------------------------------------------------
.proc draw_hud
    ; "LEVEL "
    lda #<str_level
    sta ptr_lo
    lda #>str_level
    sta ptr_hi
    lda #$01
    sta temp_1                  ; Col 1
    lda #$01
    sta temp_2                  ; Row 1
    jsr draw_text

    ; Level number at col 7, row 1
    lda #$07
    sta temp_1
    lda #$01
    sta temp_2
    lda current_level
    clc
    adc #$01                    ; 0-based → 1-based
    jsr draw_number

    ; "LIVES "
    lda #<str_lives
    sta ptr_lo
    lda #>str_lives
    sta ptr_hi
    lda #$0C                    ; Col 12
    sta temp_1
    lda #$01
    sta temp_2
    jsr draw_text

    ; Lives number (2-digit) at col 18, row 1
    lda #$12
    sta temp_1
    lda #$01
    sta temp_2
    lda player_lives
    jsr draw_number_2d

    ; "SCORE "
    lda #<str_score
    sta ptr_lo
    lda #>str_score
    sta ptr_hi
    lda #$17                    ; Col 23
    sta temp_1
    lda #$01
    sta temp_2
    jsr draw_text

    ; Score number (2-digit) at col 29, row 1
    lda #$1D
    sta temp_1
    lda #$01
    sta temp_2
    lda score
    jsr draw_number_2d
    rts
.endproc

; ------------------------------------------------------------
; draw_hud_win
; Win screen HUD: "LEVEL X" and "SCORE XX" only (no LIVES).
;
; Input: current_level (0-4), score (0-50)
; Clobbers: A, X, Y, temp_1-4, ptr_lo, ptr_hi
; ------------------------------------------------------------
.proc draw_hud_win
    ; "LEVEL "
    lda #<str_level
    sta ptr_lo
    lda #>str_level
    sta ptr_hi
    lda #$01
    sta temp_1                  ; Col 1
    lda #$01
    sta temp_2                  ; Row 1
    jsr draw_text

    ; Level number at col 7, row 1
    lda #$07
    sta temp_1
    lda #$01
    sta temp_2
    lda current_level
    clc
    adc #$01                    ; 0-based → 1-based
    jsr draw_number

    ; "SCORE "
    lda #<str_score
    sta ptr_lo
    lda #>str_score
    sta ptr_hi
    lda #$17                    ; Col 23
    sta temp_1
    lda #$01
    sta temp_2
    jsr draw_text

    ; Score number (2-digit) at col 29, row 1
    lda #$1D
    sta temp_1
    lda #$01
    sta temp_2
    lda score
    jsr draw_number_2d
    rts
.endproc

; ------------------------------------------------------------
; draw_platforms
; Draw platforms for the current level onto the nametable.
; Platforms are 48px = 6 tiles of tile $01 (solid white).
;
; Input: current_level (0-4)
; Clobbers: A, X, Y, temp_1-4, ptr_lo, ptr_hi
; ------------------------------------------------------------
.proc draw_platforms
    ldx current_level
    lda level_platforms_lo, x
    sta ptr_lo
    lda level_platforms_hi, x
    sta ptr_hi

    lda level_platform_count, x
    sta temp_4                  ; Platform counter

    ldy #$00                    ; Data index
@platform_loop:
    lda temp_4
    beq @done

    ; Read X pixel, convert to tile col
    lda (ptr_lo), y
    iny
    lsr a
    lsr a
    lsr a
    sta temp_1                  ; Tile column

    ; Read Y pixel, convert to tile row
    lda (ptr_lo), y
    iny
    lsr a
    lsr a
    lsr a
    sta temp_2                  ; Tile row

    ; Save state
    tya
    pha
    lda temp_4
    pha

    ; Compute nametable address
    lda temp_2
    lsr a
    lsr a
    lsr a
    clc
    adc #$20
    sta temp_3                  ; High byte

    lda temp_2
    asl a
    asl a
    asl a
    asl a
    asl a
    clc
    adc temp_1
    sta temp_4                  ; Low byte
    bcc @no_carry
    inc temp_3
@no_carry:

    ; Clip tile count: min(6, 32 - tile_col) to avoid wrapping
    lda #32
    sec
    sbc temp_1                  ; A = 32 - tile_col
    cmp #$06
    bcc @use_clipped            ; If < 6, use clipped count
    lda #$06                    ; Otherwise use 6
@use_clipped:
    sta temp_2                  ; temp_2 = tile count (reuse)

    ; Write platform tiles with cloud caps to VRAM buffer
    ldx vram_buf_len
    lda temp_3
    sta vram_buf, x
    inx
    lda temp_4
    sta vram_buf, x
    inx
    lda temp_2                  ; Clipped tile count
    sta vram_buf, x
    inx

    ldy temp_2                  ; Total tiles to write
    beq @tiles_written

    ; First tile: left cap ($08)
    lda #$08
    sta vram_buf, x
    inx
    dey
    beq @tiles_written

    ; Middle tiles + last tile
@cap_loop:
    cpy #$01
    beq @right_cap
    lda #$01                    ; Solid white middle tile
    sta vram_buf, x
    inx
    dey
    jmp @cap_loop

@right_cap:
    lda #$09                    ; Right cap tile
    sta vram_buf, x
    inx

@tiles_written:
    stx vram_buf_len

    ; Restore state
    pla
    sta temp_4
    dec temp_4
    pla
    tay
    jmp @platform_loop

@done:
    rts
.endproc

; ------------------------------------------------------------
; draw_cloud_tops
; Draw cloud bump tiles one row ABOVE each platform.
; Creates a scalloped cloud silhouette above each platform.
; Pattern: [corner-L] [bump-A] [bump-B] [bump-A] [bump-B] [corner-R]
;
; Input: current_level (0-4)
; Clobbers: A, X, Y, temp_1-4, ptr_lo, ptr_hi
; ------------------------------------------------------------
.proc draw_cloud_tops
    ldx current_level
    lda level_platforms_lo, x
    sta ptr_lo
    lda level_platforms_hi, x
    sta ptr_hi

    lda level_platform_count, x
    sta temp_4                  ; Platform counter

    ldy #$00                    ; Data index
@cloud_loop:
    lda temp_4
    bne @not_done
    jmp @done
@not_done:

    ; Read X pixel, convert to tile col
    lda (ptr_lo), y
    iny
    lsr a
    lsr a
    lsr a
    sta temp_1                  ; Tile column

    ; Read Y pixel, convert to tile row - 1 (row ABOVE platform)
    lda (ptr_lo), y
    iny
    lsr a
    lsr a
    lsr a
    sec
    sbc #$01                    ; One row above platform
    bcs @no_skip_cloud          ; Safety: skip if row would be negative
    jmp @skip_cloud
@no_skip_cloud:
    sta temp_2                  ; Tile row (above platform)

    ; Save state
    tya
    pha
    lda temp_4
    pha

    ; Compute nametable address for cloud top row
    lda temp_2
    lsr a
    lsr a
    lsr a
    clc
    adc #$20
    sta temp_3                  ; High byte

    lda temp_2
    asl a
    asl a
    asl a
    asl a
    asl a
    clc
    adc temp_1
    sta temp_4                  ; Low byte
    bcc @no_carry
    inc temp_3
@no_carry:

    ; Clip tile count: min(6, 32 - tile_col)
    lda #32
    sec
    sbc temp_1
    cmp #$06
    bcc @use_clipped
    lda #$06
@use_clipped:
    sta temp_2                  ; tile count

    ; Write cloud top tiles to VRAM buffer
    ldx vram_buf_len
    lda temp_3
    sta vram_buf, x
    inx
    lda temp_4
    sta vram_buf, x
    inx
    lda temp_2
    sta vram_buf, x
    inx

    ; Write cloud tile pattern: $04, $05, $06, $05, $06, $07
    ; Tile sequence table (indexed 0-5)
    ldy temp_2                  ; Total tiles
    beq @cloud_written

    ; First tile: cloud top-left corner ($04)
    lda #$04
    sta vram_buf, x
    inx
    dey
    beq @cloud_written

    ; Middle tiles: alternate $05 (bump A) and $06 (bump B)
    lda #$00
    sta temp_2                  ; Toggle: 0=$05, 1=$06
@cloud_mid:
    cpy #$01
    beq @cloud_right            ; Last tile = right corner
    lda temp_2
    beq @bump_a
    lda #$06                    ; Bump B
    sta vram_buf, x
    inx
    lda #$00
    sta temp_2                  ; Reset toggle
    dey
    jmp @cloud_mid
@bump_a:
    lda #$05                    ; Bump A
    sta vram_buf, x
    inx
    lda #$01
    sta temp_2                  ; Set toggle
    dey
    jmp @cloud_mid

@cloud_right:
    lda #$07                    ; Cloud top-right corner
    sta vram_buf, x
    inx

@cloud_written:
    stx vram_buf_len

    ; Restore state
    pla
    sta temp_4
    dec temp_4
    pla
    tay
    jmp @cloud_loop

@skip_cloud:
    ; State not yet saved, just decrement counter and continue
    dec temp_4
    jmp @cloud_loop

@done:
    rts
.endproc

; ------------------------------------------------------------
; write_platform_tiles_direct
; Write a tile to all platform positions via direct PPU writes.
; Rendering MUST be disabled before calling this.
;
; Input: temp_3 = tile value ($00 to clear, $01 to draw)
;        current_level = level index (0-4)
; Clobbers: A, X, Y, temp_1, temp_2, temp_4, ptr_lo, ptr_hi
; ------------------------------------------------------------
.proc write_platform_tiles_direct
    lda $2002                   ; Reset PPU address latch

    ldx current_level
    lda level_platforms_lo, x
    sta ptr_lo
    lda level_platforms_hi, x
    sta ptr_hi

    lda level_platform_count, x
    sta temp_4                  ; Platform counter

    ldy #$00                    ; Data index
@platform_loop:
    lda temp_4
    beq @done

    ; Read X pixel, convert to tile col
    lda (ptr_lo), y
    iny
    lsr a
    lsr a
    lsr a
    sta temp_1                  ; Tile column

    ; Read Y pixel, convert to tile row
    lda (ptr_lo), y
    iny
    lsr a
    lsr a
    lsr a
    sta temp_2                  ; Tile row

    ; Save state
    tya
    pha
    lda temp_4
    pha

    ; Compute nametable address
    lda temp_2
    lsr a
    lsr a
    lsr a
    clc
    adc #$20
    sta temp_4                  ; High byte

    lda temp_2
    asl a
    asl a
    asl a
    asl a
    asl a
    clc
    adc temp_1
    bcc @no_carry
    inc temp_4
@no_carry:

    ; Set PPU address
    pha                         ; Save low byte
    lda temp_4
    sta $2006
    pla
    sta $2006

    ; Clip tile count: min(6, 32 - tile_col)
    lda #32
    sec
    sbc temp_1
    cmp #$06
    bcc @use_clipped
    lda #$06
@use_clipped:
    tax                         ; X = tile count

    ; Write tiles
    lda temp_3
@tile_loop:
    sta $2007
    dex
    bne @tile_loop

    ; Restore state
    pla
    sta temp_4
    dec temp_4
    pla
    tay
    jmp @platform_loop

@done:
    rts
.endproc

; ------------------------------------------------------------
; clear_oam_sprites
; Set all 64 sprite Y positions to $FF (offscreen/hidden).
; ------------------------------------------------------------
.proc clear_oam_sprites
    lda #$FF
    ldx #$00
@loop:
    sta oam_buf, x              ; Y byte = $FF (hidden)
    inx
    inx
    inx
    inx                         ; Skip tile, attr, X → next sprite
    bne @loop                   ; 64 sprites x 4 = 256 → wraps to 0
    rts
.endproc
