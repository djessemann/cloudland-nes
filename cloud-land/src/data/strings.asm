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

; Large title: "CLOUD LAND" — stored as tile offsets into large font
; Each char maps to a base tile: C=$60, L=$69, O=$72, U=$7B, D=$84
; Space=$8D, A=$96, N=$9F
; The draw routine reads this and places 3x3 tile blocks
str_cloud_land:
    .byte $60, $69, $72, $7B, $84, $8D, $69, $96, $9F, $84, $FF  ; $FF = terminator
