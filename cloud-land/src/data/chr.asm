; ============================================================
; CHR-ROM Data (8KB = 8192 bytes)
; Pattern table 0 ($0000-$0FFF): Background tiles
; Pattern table 1 ($1000-$1FFF): Sprite tiles
; ============================================================
.segment "CHR"

; ============================================================
; Background Pattern Table ($0000-$0FFF)
; ============================================================

; --- Tile $00: Blank (all transparent = backdrop color) ---
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00

; --- Tile $01: Solid fill — palette color 1 ---
; Bitplane 0 = $FF, Bitplane 1 = $00 → color index 1
.byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
.byte $00,$00,$00,$00,$00,$00,$00,$00

; --- Tile $02: Solid fill — palette color 2 ---
; Bitplane 0 = $00, Bitplane 1 = $FF → color index 2
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF

; --- Tile $03: Solid fill — palette color 3 ---
; Bitplane 0 = $FF, Bitplane 1 = $FF → color index 3
.byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
.byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF

; --- Tile $04: Cloud top-left corner ---
; Rounded corner transitioning from empty to solid white
.byte $00,$03,$07,$1F,$3F,$7F,$FF,$FF
.byte $00,$00,$00,$00,$00,$00,$00,$00

; --- Tile $05: Cloud bump A (centered peak) ---
; Scalloped cloud bump with peak in center
.byte $3C,$7E,$FF,$FF,$FF,$FF,$FF,$FF
.byte $00,$00,$00,$00,$00,$00,$00,$00

; --- Tile $06: Cloud bump B (edge peaks, dip in center) ---
; Alternates with bump A to create scalloped cloud edge
.byte $C3,$E7,$FF,$FF,$FF,$FF,$FF,$FF
.byte $00,$00,$00,$00,$00,$00,$00,$00

; --- Tile $07: Cloud top-right corner ---
; Mirror of $04
.byte $00,$C0,$E0,$F8,$FC,$FE,$FF,$FF
.byte $00,$00,$00,$00,$00,$00,$00,$00

; --- Tile $08: Platform left cap (rounded bottom-left) ---
; Solid top, rounded bottom-left corner
.byte $FF,$FF,$FF,$FF,$FF,$7F,$3F,$0F
.byte $00,$00,$00,$00,$00,$00,$00,$00

; --- Tile $09: Platform right cap (rounded bottom-right) ---
; Solid top, rounded bottom-right corner
.byte $FF,$FF,$FF,$FF,$FF,$FE,$FC,$F0
.byte $00,$00,$00,$00,$00,$00,$00,$00

; --- Tiles $0A-$1F: Reserved (zeros) ---
.res (($20 - $0A) * 16), $00

; ============================================================
; 8x8 Font — ASCII-mapped starting at tile $20
; Press Start 2P style blocky letterforms
; Tile index = ASCII code (e.g. 'A' = $41 = tile $41)
; Each tile: 8 bytes bitplane 0, 8 bytes bitplane 1
; Using color index 1 (BP0=pixel, BP1=0) for single-color text
; ============================================================

; --- Tile $20: SPACE ---
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00

; --- Tile $21: ! ---
.byte $18,$18,$18,$18,$18,$00,$18,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00

; --- Tile $22: " ---
.byte $6C,$6C,$6C,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00

; --- Tile $23: # ---
.byte $6C,$6C,$FE,$6C,$FE,$6C,$6C,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00

; --- Tile $24: $ ---
.byte $18,$3E,$60,$3C,$06,$7C,$18,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00

; --- Tile $25: % ---
.byte $00,$C6,$CC,$18,$30,$66,$C6,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00

; --- Tile $26: & ---
.byte $38,$6C,$38,$76,$DC,$CC,$76,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00

; --- Tile $27: ' ---
.byte $18,$18,$30,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00

; --- Tile $28: ( ---
.byte $0C,$18,$30,$30,$30,$18,$0C,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00

; --- Tile $29: ) ---
.byte $30,$18,$0C,$0C,$0C,$18,$30,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00

; --- Tile $2A: * ---
.byte $00,$66,$3C,$FF,$3C,$66,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00

; --- Tile $2B: + ---
.byte $00,$18,$18,$7E,$18,$18,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00

; --- Tile $2C: , ---
.byte $00,$00,$00,$00,$00,$18,$18,$30
.byte $00,$00,$00,$00,$00,$00,$00,$00

; --- Tile $2D: - ---
.byte $00,$00,$00,$7E,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00

; --- Tile $2E: . ---
.byte $00,$00,$00,$00,$00,$18,$18,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00

; --- Tile $2F: / ---
.byte $06,$0C,$18,$30,$60,$C0,$80,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00

; --- Tile $30: 0 ---
.byte $7C,$C6,$CE,$D6,$E6,$C6,$7C,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00

; --- Tile $31: 1 ---
.byte $18,$38,$18,$18,$18,$18,$7E,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00

; --- Tile $32: 2 ---
.byte $7C,$C6,$06,$1C,$30,$66,$FE,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00

; --- Tile $33: 3 ---
.byte $7C,$C6,$06,$3C,$06,$C6,$7C,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00

; --- Tile $34: 4 ---
.byte $1C,$3C,$6C,$CC,$FE,$0C,$0C,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00

; --- Tile $35: 5 ---
.byte $FE,$C0,$FC,$06,$06,$C6,$7C,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00

; --- Tile $36: 6 ---
.byte $3C,$60,$C0,$FC,$C6,$C6,$7C,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00

; --- Tile $37: 7 ---
.byte $FE,$C6,$0C,$18,$30,$30,$30,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00

; --- Tile $38: 8 ---
.byte $7C,$C6,$C6,$7C,$C6,$C6,$7C,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00

; --- Tile $39: 9 ---
.byte $7C,$C6,$C6,$7E,$06,$0C,$78,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00

; --- Tile $3A: : ---
.byte $00,$18,$18,$00,$18,$18,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00

; --- Tile $3B: ; ---
.byte $00,$18,$18,$00,$18,$18,$30,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00

; --- Tile $3C: < ---
.byte $0C,$18,$30,$60,$30,$18,$0C,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00

; --- Tile $3D: = ---
.byte $00,$00,$7E,$00,$7E,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00

; --- Tile $3E: > ---
.byte $30,$18,$0C,$06,$0C,$18,$30,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00

; --- Tile $3F: ? ---
.byte $7C,$C6,$0C,$18,$18,$00,$18,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00

; --- Tile $40: @ ---
.byte $7C,$C6,$DE,$DE,$DC,$C0,$7C,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00

; --- Tile $41: A ---
.byte $38,$6C,$C6,$C6,$FE,$C6,$C6,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00

; --- Tile $42: B ---
.byte $FC,$C6,$C6,$FC,$C6,$C6,$FC,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00

; --- Tile $43: C ---
.byte $7C,$C6,$C0,$C0,$C0,$C6,$7C,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00

; --- Tile $44: D ---
.byte $F8,$CC,$C6,$C6,$C6,$CC,$F8,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00

; --- Tile $45: E ---
.byte $FE,$C0,$C0,$F8,$C0,$C0,$FE,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00

; --- Tile $46: F ---
.byte $FE,$C0,$C0,$F8,$C0,$C0,$C0,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00

; --- Tile $47: G ---
.byte $7C,$C6,$C0,$CE,$C6,$C6,$7E,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00

; --- Tile $48: H ---
.byte $C6,$C6,$C6,$FE,$C6,$C6,$C6,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00

; --- Tile $49: I ---
.byte $7E,$18,$18,$18,$18,$18,$7E,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00

; --- Tile $4A: J ---
.byte $1E,$06,$06,$06,$C6,$C6,$7C,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00

; --- Tile $4B: K ---
.byte $C6,$CC,$D8,$F0,$D8,$CC,$C6,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00

; --- Tile $4C: L ---
.byte $C0,$C0,$C0,$C0,$C0,$C0,$FE,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00

; --- Tile $4D: M ---
.byte $C6,$EE,$FE,$D6,$C6,$C6,$C6,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00

; --- Tile $4E: N ---
.byte $C6,$E6,$F6,$DE,$CE,$C6,$C6,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00

; --- Tile $4F: O ---
.byte $7C,$C6,$C6,$C6,$C6,$C6,$7C,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00

; --- Tile $50: P ---
.byte $FC,$C6,$C6,$FC,$C0,$C0,$C0,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00

; --- Tile $51: Q ---
.byte $7C,$C6,$C6,$C6,$D6,$DE,$7C,$06
.byte $00,$00,$00,$00,$00,$00,$00,$00

; --- Tile $52: R ---
.byte $FC,$C6,$C6,$FC,$D8,$CC,$C6,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00

; --- Tile $53: S ---
.byte $7C,$C6,$C0,$7C,$06,$C6,$7C,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00

; --- Tile $54: T ---
.byte $7E,$18,$18,$18,$18,$18,$18,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00

; --- Tile $55: U ---
.byte $C6,$C6,$C6,$C6,$C6,$C6,$7C,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00

; --- Tile $56: V ---
.byte $C6,$C6,$C6,$C6,$6C,$38,$10,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00

; --- Tile $57: W ---
.byte $C6,$C6,$C6,$D6,$FE,$EE,$C6,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00

; --- Tile $58: X ---
.byte $C6,$6C,$38,$38,$38,$6C,$C6,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00

; --- Tile $59: Y ---
.byte $66,$66,$66,$3C,$18,$18,$18,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00

; --- Tile $5A: Z ---
.byte $FE,$0C,$18,$30,$60,$C0,$FE,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00

; --- Tiles $5B-$5F: Reserved punctuation (zeros) ---
.res (($60 - $5B) * 16), $00

; ============================================================
; Large Title Font — 3x3 tiles (24x24px) per character
; Tiles $60-$9E: C, L, O, U, D, space, A, N (8 chars x 9 tiles)
; "CLOUD LAND" = C L O U D [space] L A N D
; Layout per char: top-left, top-mid, top-right,
;                  mid-left, mid-mid, mid-right,
;                  bot-left, bot-mid, bot-right
; ============================================================

; === 'C' large — tiles $60-$68 ===
; Top-left
.byte $03,$0F,$1F,$3F,$3C,$78,$78,$70
.byte $00,$00,$00,$00,$00,$00,$00,$00
; Top-mid
.byte $FF,$FF,$FF,$FF,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
; Top-right
.byte $C0,$F0,$F8,$FC,$3C,$1E,$1E,$0E
.byte $00,$00,$00,$00,$00,$00,$00,$00
; Mid-left
.byte $70,$70,$70,$70,$70,$70,$70,$70
.byte $00,$00,$00,$00,$00,$00,$00,$00
; Mid-mid
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
; Mid-right
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
; Bot-left
.byte $70,$78,$78,$3C,$3F,$1F,$0F,$03
.byte $00,$00,$00,$00,$00,$00,$00,$00
; Bot-mid
.byte $00,$00,$00,$00,$FF,$FF,$FF,$FF
.byte $00,$00,$00,$00,$00,$00,$00,$00
; Bot-right
.byte $00,$1E,$1E,$3C,$FC,$F8,$F0,$C0
.byte $00,$00,$00,$00,$00,$00,$00,$00

; === 'L' large — tiles $69-$71 ===
; Top-left
.byte $70,$70,$70,$70,$70,$70,$70,$70
.byte $00,$00,$00,$00,$00,$00,$00,$00
; Top-mid
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
; Top-right
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
; Mid-left
.byte $70,$70,$70,$70,$70,$70,$70,$70
.byte $00,$00,$00,$00,$00,$00,$00,$00
; Mid-mid
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
; Mid-right
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
; Bot-left
.byte $70,$70,$70,$70,$7F,$7F,$7F,$7F
.byte $00,$00,$00,$00,$00,$00,$00,$00
; Bot-mid
.byte $00,$00,$00,$00,$FF,$FF,$FF,$FF
.byte $00,$00,$00,$00,$00,$00,$00,$00
; Bot-right
.byte $00,$00,$00,$00,$FE,$FE,$FE,$FE
.byte $00,$00,$00,$00,$00,$00,$00,$00

; === 'O' large — tiles $72-$7A ===
; Top-left
.byte $03,$0F,$1F,$3F,$3C,$78,$78,$70
.byte $00,$00,$00,$00,$00,$00,$00,$00
; Top-mid
.byte $FF,$FF,$FF,$FF,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
; Top-right
.byte $C0,$F0,$F8,$FC,$3C,$1E,$1E,$0E
.byte $00,$00,$00,$00,$00,$00,$00,$00
; Mid-left
.byte $70,$70,$70,$70,$70,$70,$70,$70
.byte $00,$00,$00,$00,$00,$00,$00,$00
; Mid-mid
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
; Mid-right
.byte $0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E
.byte $00,$00,$00,$00,$00,$00,$00,$00
; Bot-left
.byte $70,$78,$78,$3C,$3F,$1F,$0F,$03
.byte $00,$00,$00,$00,$00,$00,$00,$00
; Bot-mid
.byte $00,$00,$00,$00,$FF,$FF,$FF,$FF
.byte $00,$00,$00,$00,$00,$00,$00,$00
; Bot-right
.byte $0E,$1E,$1E,$3C,$FC,$F8,$F0,$C0
.byte $00,$00,$00,$00,$00,$00,$00,$00

; === 'U' large — tiles $7B-$83 ===
; Top-left
.byte $70,$70,$70,$70,$70,$70,$70,$70
.byte $00,$00,$00,$00,$00,$00,$00,$00
; Top-mid
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
; Top-right
.byte $0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E
.byte $00,$00,$00,$00,$00,$00,$00,$00
; Mid-left
.byte $70,$70,$70,$70,$70,$70,$70,$70
.byte $00,$00,$00,$00,$00,$00,$00,$00
; Mid-mid
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
; Mid-right
.byte $0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E
.byte $00,$00,$00,$00,$00,$00,$00,$00
; Bot-left
.byte $70,$78,$78,$3C,$3F,$1F,$0F,$03
.byte $00,$00,$00,$00,$00,$00,$00,$00
; Bot-mid
.byte $00,$00,$00,$00,$FF,$FF,$FF,$FF
.byte $00,$00,$00,$00,$00,$00,$00,$00
; Bot-right
.byte $0E,$1E,$1E,$3C,$FC,$F8,$F0,$C0
.byte $00,$00,$00,$00,$00,$00,$00,$00

; === 'D' large — tiles $84-$8C ===
; Top-left
.byte $7F,$7F,$7F,$7F,$70,$70,$70,$70
.byte $00,$00,$00,$00,$00,$00,$00,$00
; Top-mid
.byte $FF,$FF,$FF,$FF,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
; Top-right
.byte $80,$E0,$F0,$F8,$3C,$1E,$0E,$0E
.byte $00,$00,$00,$00,$00,$00,$00,$00
; Mid-left
.byte $70,$70,$70,$70,$70,$70,$70,$70
.byte $00,$00,$00,$00,$00,$00,$00,$00
; Mid-mid
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
; Mid-right
.byte $0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E
.byte $00,$00,$00,$00,$00,$00,$00,$00
; Bot-left
.byte $70,$70,$70,$70,$7F,$7F,$7F,$7F
.byte $00,$00,$00,$00,$00,$00,$00,$00
; Bot-mid
.byte $00,$00,$00,$00,$FF,$FF,$FF,$FF
.byte $00,$00,$00,$00,$00,$00,$00,$00
; Bot-right
.byte $0E,$0E,$1E,$3C,$F8,$F0,$E0,$80
.byte $00,$00,$00,$00,$00,$00,$00,$00

; === large SPACE — tiles $8D-$95 ===
.res (9 * 16), $00

; === 'A' large — tiles $96-$9E ===
; Top-left
.byte $03,$0F,$1F,$3F,$3C,$78,$78,$70
.byte $00,$00,$00,$00,$00,$00,$00,$00
; Top-mid
.byte $FF,$FF,$FF,$FF,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
; Top-right
.byte $C0,$F0,$F8,$FC,$3C,$1E,$1E,$0E
.byte $00,$00,$00,$00,$00,$00,$00,$00
; Mid-left
.byte $70,$70,$7F,$7F,$7F,$7F,$70,$70
.byte $00,$00,$00,$00,$00,$00,$00,$00
; Mid-mid
.byte $00,$00,$FF,$FF,$FF,$FF,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
; Mid-right
.byte $0E,$0E,$FE,$FE,$FE,$FE,$0E,$0E
.byte $00,$00,$00,$00,$00,$00,$00,$00
; Bot-left
.byte $70,$70,$70,$70,$70,$70,$70,$70
.byte $00,$00,$00,$00,$00,$00,$00,$00
; Bot-mid
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
; Bot-right
.byte $0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E
.byte $00,$00,$00,$00,$00,$00,$00,$00

; === 'N' large — tiles $9F-$A7 ===
; Uniform 3px diagonal with consistent stair-step (advance,advance,hold).
; Left bar cols 1-3, right bar cols 20-22, diagonal 3px wide.
; Top-left: bar merges with diagonal departing rightward
.byte $7C,$7E,$7E,$77,$73,$73,$71,$70
.byte $00,$00,$00,$00,$00,$00,$00,$00
; Top-mid: diagonal enters from left
.byte $00,$00,$00,$00,$80,$80,$C0,$E0
.byte $00,$00,$00,$00,$00,$00,$00,$00
; Top-right: right bar only
.byte $0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E
.byte $00,$00,$00,$00,$00,$00,$00,$00
; Mid-left: left bar only (diagonal is in mid tile)
.byte $70,$70,$70,$70,$70,$70,$70,$70
.byte $00,$00,$00,$00,$00,$00,$00,$00
; Mid-mid: diagonal passes through center, uniform 3px
.byte $E0,$70,$38,$38,$1C,$0E,$0E,$07
.byte $00,$00,$00,$00,$00,$00,$00,$00
; Mid-right: right bar only (diagonal still in mid tile)
.byte $0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E
.byte $00,$00,$00,$00,$00,$00,$00,$00
; Bot-left: left bar only
.byte $70,$70,$70,$70,$70,$70,$70,$70
.byte $00,$00,$00,$00,$00,$00,$00,$00
; Bot-mid: diagonal exits rightward
.byte $03,$03,$01,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
; Bot-right: diagonal merges with right bar
.byte $8E,$8E,$CE,$EE,$EE,$7E,$3E,$1E
.byte $00,$00,$00,$00,$00,$00,$00,$00

; --- Pad remaining BG tiles to fill pattern table 0 ($0000-$0FFF) ---
; We've used tiles $00-$A7 = 168 tiles x 16 bytes = 2688 bytes
; Pattern table 0 = 4096 bytes, so pad remaining:
.res ($1000 - (168 * 16)), $00

; ============================================================
; Sprite Pattern Table ($1000-$1FFF)
; ============================================================

; === Player Standing — 4 tiles (2x2, 16x16px) ===
; Tile arrangement: [TL][TR]  Sprite palette 0 (cat: purple body, yellow eyes, pink tail/paws)
;                   [BL][BR]
; Colors: 1=yellow(eyes), 2=pink(tail/paws), 3=dark purple(body)
;   ....33....33....       Ears
;   ....333..333....       Head
;   ....33333333....
;   ....33333333....
;   ....31133113....       Eyes (yellow)
;   ....33333333....
;   .....333333.....       Body
;   .....333333.....
;   .....333333.....       Body
;   .....3333332....       Tail starts (connected to body)
;   .....33333322...       Tail grows diagonal
;   .....33..33.22..       Legs + tail
;   .....22..22.....       Paws (pink)
;   ................
; Top-left (left ear + left head)
.byte $0C,$0E,$0F,$0F,$0F,$0F,$07,$07
.byte $0C,$0E,$0F,$0F,$09,$0F,$07,$07
; Top-right (right ear + right head)
.byte $30,$70,$F0,$F0,$F0,$F0,$E0,$E0
.byte $30,$70,$F0,$F0,$90,$F0,$E0,$E0
; Bottom-left (body + legs)
.byte $07,$07,$07,$06,$00,$00,$00,$00
.byte $07,$07,$07,$06,$06,$00,$00,$00
; Bottom-right (body + tail diagonal + paws)
.byte $E0,$E0,$E0,$60,$00,$00,$00,$00
.byte $E0,$F0,$F8,$66,$60,$00,$00,$00

; === Player Walk Frame 1 — 4 tiles ===
;   (same head rows 0-6)
;   .....333333.....       Body
;   .....3333332....       Tail starts (connected, in TR tile)
;   .....33333322...       Tail grows
;   .....333333.....       Body
;   .....333333.....       Body
;   ....33....33....       Legs wide apart
;   ....22.....22...       Paws spread
;   ................
; Top-left (same head)
.byte $0C,$0E,$0F,$0F,$0F,$0F,$07,$07
.byte $0C,$0E,$0F,$0F,$09,$0F,$07,$07
; Top-right (tail at row 7 — connected to body)
.byte $30,$70,$F0,$F0,$F0,$F0,$E0,$E0
.byte $30,$70,$F0,$F0,$90,$F0,$E0,$F0
; Bottom-left (left leg forward)
.byte $07,$07,$07,$0C,$00,$00,$00,$00
.byte $07,$07,$07,$0C,$0C,$00,$00,$00
; Bottom-right (tail continues + right leg back)
.byte $E0,$E0,$E0,$30,$00,$00,$00,$00
.byte $F8,$E0,$E0,$30,$18,$00,$00,$00

; === Player Walk Frame 2 — 4 tiles ===
;   (same head rows 0-7)
;   .....333333.....       Body
;   .....3333332....       Tail starts (connected)
;   .....33333322...       Tail grows
;   .....33..33.22..       Legs closer + tail
;   ......22..22....       Paws narrow
;   ................
; Top-left (same head)
.byte $0C,$0E,$0F,$0F,$0F,$0F,$07,$07
.byte $0C,$0E,$0F,$0F,$09,$0F,$07,$07
; Top-right (same head, no tail in top half)
.byte $30,$70,$F0,$F0,$F0,$F0,$E0,$E0
.byte $30,$70,$F0,$F0,$90,$F0,$E0,$E0
; Bottom-left (legs closer together)
.byte $07,$07,$07,$06,$00,$00,$00,$00
.byte $07,$07,$07,$06,$03,$00,$00,$00
; Bottom-right (tail diagonal + paws)
.byte $E0,$E0,$E0,$60,$00,$00,$00,$00
.byte $E0,$F0,$F8,$66,$30,$00,$00,$00

; === Player Jump — 4 tiles ===
;   (same head rows 0-7)
;   .....333333.....       Body
;   .....3333332....       Tail droops down (1px, connected)
;   .....33223322...       Knees + tail touching leg (2px)
;   ......2222.22...       Paws + tail hangs straight down (2px)
;   ................
; Top-left (same head)
.byte $0C,$0E,$0F,$0F,$0F,$0F,$07,$07
.byte $0C,$0E,$0F,$0F,$09,$0F,$07,$07
; Top-right (same head)
.byte $30,$70,$F0,$F0,$F0,$F0,$E0,$E0
.byte $30,$70,$F0,$F0,$90,$F0,$E0,$E0
; Bottom-left (legs tucked up)
.byte $07,$07,$06,$00,$00,$00,$00,$00
.byte $07,$07,$07,$03,$00,$00,$00,$00
; Bottom-right (tail droops down with gravity, touching body)
.byte $E0,$E0,$60,$00,$00,$00,$00,$00
.byte $E0,$F0,$F8,$D8,$00,$00,$00,$00

; === Bird Frame 1 (wings up) — 4 tiles ===
; Color 1=yellow(eye), 2=dark green(beak), 3=very dark green(body/wings/tail)
; Top-left
.byte $0E,$02,$0F,$07,$07,$07,$1F,$3C
.byte $0E,$02,$0F,$07,$07,$07,$1F,$3C
; Top-right
.byte $00,$00,$00,$C0,$E0,$C0,$80,$00
.byte $00,$00,$00,$C0,$E0,$40,$B0,$20
; Bottom-left
.byte $70,$20,$00,$00,$00,$00,$00,$00
.byte $70,$20,$00,$00,$00,$00,$00,$00
; Bottom-right
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00

; === Bird Frame 2 (wings level) — 4 tiles ===
; Top-left
.byte $00,$00,$00,$07,$3F,$07,$1F,$3C
.byte $00,$00,$00,$07,$3F,$07,$1F,$3C
; Top-right
.byte $00,$00,$00,$C0,$E0,$C0,$80,$00
.byte $00,$00,$00,$C0,$E0,$40,$B0,$20
; Bottom-left
.byte $70,$20,$00,$00,$00,$00,$00,$00
.byte $70,$20,$00,$00,$00,$00,$00,$00
; Bottom-right
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00

; === Bird Frame 3 (wings down) — 4 tiles ===
; Top-left
.byte $00,$00,$00,$07,$07,$07,$1F,$3C
.byte $00,$00,$00,$07,$07,$07,$1F,$3C
; Top-right
.byte $00,$00,$00,$C0,$E0,$C0,$80,$00
.byte $00,$00,$00,$C0,$E0,$40,$B0,$20
; Bottom-left
.byte $76,$2E,$06,$02,$00,$00,$00,$00
.byte $76,$2E,$06,$02,$00,$00,$00,$00
; Bottom-right
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00

; === Heart — 1 tile (8x8px) ===
; Sprite palette 2 (pink tones)
; Solid pink body with 2-pixel white highlight in upper-left
.byte $00,$66,$FF,$FF,$FF,$7E,$3C,$18
.byte $00,$40,$40,$00,$00,$00,$00,$00

; --- Pad remaining sprite tiles to fill pattern table 1 ---
; Used: 4+4+4+4 player + 3*4 bird + 1 heart = 29 tiles = 464 bytes
; Pattern table 1 = 4096 bytes
.res ($1000 - (29 * 16)), $00
