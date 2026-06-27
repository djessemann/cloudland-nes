; ============================================================
; Palette Data
; Each palette set is 32 bytes: 4 BG palettes + 4 sprite palettes.
; First byte of each BG palette is the shared backdrop color.
; ============================================================
.segment "RODATA"

; --- Title screen palette ---
; Cyan/turquoise background (matches level 1), white cloud body, med-blue shadow
palette_title:
    ; Background palettes
    .byte $2C, $30, $11, $0F       ; BG 0: cyan, white, med-blue shadow, black
    .byte $2C, $30, $11, $0F       ; BG 1
    .byte $2C, $30, $11, $0F       ; BG 2
    .byte $2C, $30, $11, $0F       ; BG 3
    ; Sprite palettes (sprites hidden on title screen; values don't matter)
    .byte $2C, $28, $15, $04
    .byte $2C, $28, $19, $09
    .byte $2C, $15, $25, $30
    .byte $2C, $0F, $10, $30

; --- Level 1 palette ---
palette_level1:
    ; Background palettes
    .byte $2C, $30, $0F, $0F       ; BG 0: cyan, white, black, black
    .byte $2C, $30, $0F, $0F       ; BG 1
    .byte $2C, $30, $0F, $0F       ; BG 2
    .byte $2C, $30, $0F, $0F       ; BG 3
    ; Sprite palettes
    .byte $2C, $28, $15, $04       ; SPR 0: player cat (yellow eyes, hot pink paws, deep purple body)
    .byte $2C, $28, $19, $09       ; SPR 1: bird (yellow eye, dark green beak, very dark green body)
    .byte $2C, $15, $25, $30       ; SPR 2: heart (hot pink, light pink, white)
    .byte $2C, $0F, $10, $30       ; SPR 3: unused

; --- Level 2 palette (green background $2B) ---
palette_level2:
    .byte $2B, $30, $0F, $0F
    .byte $2B, $30, $0F, $0F
    .byte $2B, $30, $0F, $0F
    .byte $2B, $30, $0F, $0F
    .byte $2B, $28, $15, $04       ; SPR 0: player cat (yellow eyes, hot pink paws, deep purple body)
    .byte $2B, $28, $19, $09
    .byte $2B, $15, $25, $30
    .byte $2B, $0F, $10, $30

; --- Level 3 palette (blue background $21) ---
palette_level3:
    .byte $21, $30, $0F, $0F
    .byte $21, $30, $0F, $0F
    .byte $21, $30, $0F, $0F
    .byte $21, $30, $0F, $0F
    .byte $21, $28, $15, $04       ; SPR 0: player cat (yellow eyes, hot pink paws, deep purple body)
    .byte $21, $28, $19, $09
    .byte $21, $15, $25, $30
    .byte $21, $0F, $10, $30

; --- Level 4 palette (purple background $22) ---
palette_level4:
    .byte $22, $30, $0F, $0F
    .byte $22, $30, $0F, $0F
    .byte $22, $30, $0F, $0F
    .byte $22, $30, $0F, $0F
    .byte $22, $28, $15, $04       ; SPR 0: player cat (yellow eyes, hot pink paws, deep purple body)
    .byte $22, $28, $19, $09
    .byte $22, $15, $25, $30
    .byte $22, $0F, $10, $30

; --- Level 5 palette (pink background $34) ---
palette_level5:
    .byte $34, $30, $0F, $0F
    .byte $34, $30, $0F, $0F
    .byte $34, $30, $0F, $0F
    .byte $34, $30, $0F, $0F
    .byte $34, $28, $15, $04       ; SPR 0: player cat (yellow eyes, hot pink paws, deep purple body)
    .byte $34, $28, $19, $09
    .byte $34, $15, $25, $30
    .byte $34, $0F, $10, $30

; --- Game Over palette (black background $0F) ---
palette_gameover:
    .byte $0F, $30, $0F, $0F
    .byte $0F, $30, $0F, $0F
    .byte $0F, $30, $0F, $0F
    .byte $0F, $30, $0F, $0F
    .byte $0F, $28, $15, $04       ; SPR 0: player cat (yellow eyes, hot pink paws, deep purple body)
    .byte $0F, $28, $19, $09
    .byte $0F, $15, $25, $30
    .byte $0F, $0F, $10, $30

; --- Win screen palette (rainbow stripes) ---
; Backdrop = dark red $16 (top stripe via blank tiles)
; Color 1 = white $30 (text — font tiles use bitplane 0 = color 1)
; Color 2 = dark purple $03 (dialog box tile $02); P3 uses $14 violet
; Color 3 = stripe color (stripe tile $03)
; Stripes: red(backdrop), orange(P0), yellow(P1), green(P2), blue(P3), violet(P3 c2)
palette_win:
    .byte $03, $30, $16, $27       ; BG 0: dk purple bg, white text, dark red stripe, orange stripe
    .byte $03, $30, $16, $38       ; BG 1: dk purple bg, white text, (dark red), yellow stripe
    .byte $03, $30, $16, $19       ; BG 2: dk purple bg, white text, (dark red), green stripe
    .byte $03, $30, $14, $12       ; BG 3: dk purple bg, white text, violet, blue stripe
    .byte $03, $28, $15, $04       ; SPR 0: player cat (yellow eyes, hot pink paws, deep purple body)
    .byte $03, $28, $19, $09
    .byte $03, $15, $25, $30
    .byte $03, $0F, $10, $30

; --- Palette pointer table (indexed by level 0-4) ---
palette_table_lo:
    .byte <palette_level1, <palette_level2, <palette_level3
    .byte <palette_level4, <palette_level5

palette_table_hi:
    .byte >palette_level1, >palette_level2, >palette_level3
    .byte >palette_level4, >palette_level5
