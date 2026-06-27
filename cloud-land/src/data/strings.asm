; ============================================================
; String Data — Null-terminated ASCII strings
; All game text lives here. draw_text converts ASCII → tile index.
; ============================================================
.segment "RODATA"

str_press_start:
    .byte "PRESS START", $00

str_level:
    .byte "LEVEL ", $00

str_score:
    .byte "SCORE ", $00

str_level_clear:
    .byte "LEVEL CLEAR!", $00

str_oops:
    .byte "OOPS!", $00

str_game_over:
    .byte "GAME OVER", $00

str_lives:
    .byte "LIVES ", $00

str_paused:
    .byte "PAUSED", $00

str_you_win:
    .byte "YOU WIN!", $00

str_goodnite:
    .byte "GOODNITE XOXO", $00

; Title char index sequences for draw_title_ppu.
; Character indices: C=0, L=1, O=2, U=3, D=4, A=5, N=6
; $FF = terminator
str_title_cloud:
    .byte 0, 1, 2, 3, 4, $FF       ; C L O U D
str_title_land:
    .byte 1, 5, 6, 4, $FF          ; L A N D

; Pointer tables for character bitmask data (indexed by char index 0-6)
title_char_data_lo:
    .byte <title_char_C, <title_char_L, <title_char_O
    .byte <title_char_U, <title_char_D, <title_char_A, <title_char_N
title_char_data_hi:
    .byte >title_char_C, >title_char_L, >title_char_O
    .byte >title_char_U, >title_char_D, >title_char_A, >title_char_N

; 5x7 bitmasks: bits 7-3 = columns 0-4 (left to right), 7 rows top to bottom
title_char_C: .byte $78,$80,$80,$80,$80,$80,$78  ; .XXXX / X.... x5 / .XXXX
title_char_L: .byte $80,$80,$80,$80,$80,$80,$F8  ; X.... x6 / XXXXX
title_char_O: .byte $70,$88,$88,$88,$88,$88,$70  ; .XXX. / X...X x5 / .XXX.
title_char_U: .byte $88,$88,$88,$88,$88,$88,$70  ; X...X x6 / .XXX.
title_char_D: .byte $F0,$88,$88,$88,$88,$88,$F0  ; XXXX. / X...X x5 / XXXX.
title_char_A: .byte $70,$88,$88,$F8,$88,$88,$88  ; .XXX. / X...X x2 / XXXXX / X...X x3
title_char_N: .byte $88,$C8,$A8,$98,$88,$88,$88  ; X...X / XX..X / X.X.X / X..XX / X...X x3
