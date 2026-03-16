; ============================================================
; iNES Header (16 bytes)
; NROM-256: 32KB PRG-ROM + 8KB CHR-ROM, mapper 0
; ============================================================
.segment "HEADER"
    .byte "NES", $1A            ; iNES magic number
    .byte $02                   ; 2 x 16KB PRG-ROM banks = 32KB
    .byte $01                   ; 1 x 8KB CHR-ROM bank = 8KB
    .byte %00000001             ; Flags 6: vertical mirroring, mapper 0 (low nybble)
    .byte %00000000             ; Flags 7: mapper 0 (high nybble)
    .byte $00                   ; Flags 8: PRG-RAM size (unused)
    .byte $00                   ; Flags 9: TV system (NTSC)
    .byte $00                   ; Flags 10: unused
    .byte $00, $00, $00, $00, $00  ; Padding to 16 bytes
