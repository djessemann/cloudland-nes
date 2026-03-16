; ============================================================
; Music Module — Home on the Range (8-bar loop)
;
; Pulse 1: melody (50% duty, vol=10, 3f attack / 8f release)
; Pulse 2: arpeggiated accompaniment (25% duty, vol=6)
;
; Key: F major   Time: 3/4 waltz
;
; Envelope:
;   Attack:  vol = elapsed*3 + 4, capped at 10 (0→4→7→10)
;   Release: vol = remaining + 1, starts at remaining < 8
;   Load frame starts at vol=4 to mask $4003 phase restart
;
; Phase restart optimization: only writes $4003 when period
; hi byte changes.
; ============================================================
.segment "CODE"

; Note index constants (match period tables below)
M_REST = 0
M_C3   = 1
M_D3   = 2
M_E3   = 3
M_F3   = 4
M_G3   = 5
M_A3   = 6
M_Bb3  = 7
M_C4   = 8
M_D4   = 9
M_E4   = 10
M_F4   = 11
M_G4   = 12
M_A4   = 13
M_Bb4  = 14
M_C5   = 15

; Pulse CTRL register templates
P1_DUTY  = %10110000            ; 50% duty, halt, const vol (OR in volume)
P1_START = %10110100            ; 50% duty, halt, const vol, vol=4 (attack start)
P1_MUTE  = %10110000            ; 50% duty, halt, const vol, vol=0
P2_VOL   = %01110110            ; 25% duty, halt, const vol, vol=6
P2_MUTE  = %01110000            ; 25% duty, halt, const vol, vol=0

; ------------------------------------------------------------
; music_play — start music from the beginning
; ------------------------------------------------------------
.proc music_play
    lda #1
    sta music_playing
    lda #0
    sta music_p1_pos
    sta music_p1_timer
    sta music_p1_note
    sta music_p1_total
    sta music_p1_restore
    sta music_p1_period_hi
    sta music_p2_pos
    sta music_p2_timer
    sta music_p2_note
    sta music_p2_total
    sta music_p2_restore
    ; Mute Pulse 1 (melody disabled), disable sweep on Pulse 2
    lda #P1_MUTE
    sta $4000
    lda #$08
    sta $4005
    rts
.endproc

; ------------------------------------------------------------
; music_stop — silence music and mark stopped
; ------------------------------------------------------------
.proc music_stop
    lda #0
    sta music_playing
    ; Force-silence both channels unconditionally
    lda #P1_MUTE
    sta $4000
    lda #P2_MUTE
    sta $4004
    rts
.endproc

; ------------------------------------------------------------
; music_resume — resume from pause (preserves position)
; ------------------------------------------------------------
.proc music_resume
    lda #1
    sta music_playing
    ; Force pitch restore on next tick
    sta music_p1_restore
    sta music_p2_restore
    ; Clear period_hi tracking (force $4003 write on restore)
    lda #$FF
    sta music_p1_period_hi
    rts
.endproc

; ------------------------------------------------------------
; music_tick — advance both channels one frame
; Called once per frame from sound_update.
; ------------------------------------------------------------
.proc music_tick
    lda music_playing
    bne @active
    rts
@active:
    jmp @tick_p2

; === Pulse 1: melody with envelope ===

@tick_p1:
    lda music_p1_timer
    beq @p1_load
    dec music_p1_timer

    ; --- Sustain frame ---
    lda music_p1_note
    beq @p1_sustain_rts         ; Rest note, nothing to update

    ; If SFX active, mark for restore and skip
    lda sfx_pulse1_id
    beq @p1_no_sfx
    lda #1
    sta music_p1_restore
    lda #$FF                    ; Invalidate period_hi tracking (SFX overwrites $4003)
    sta music_p1_period_hi
@p1_sustain_rts:
    rts

@p1_no_sfx:
    ; Check if we need to restore pitch after SFX ended
    lda music_p1_restore
    beq @p1_envelope

    ; One-time restore: rewrite period + sweep
    lda #0
    sta music_p1_restore
    lda #$08
    sta $4001
    ldx music_p1_note
    lda note_period_lo, x
    sta $4002
    lda note_period_hi, x
    ora #%00001000
    sta music_p1_period_hi
    sta $4003
    ; Fall through to envelope to set correct volume

@p1_envelope:
    ; --- Fade-in: vol = elapsed*3 + 4, cap at 10 ---
    lda music_p1_total
    sec
    sbc music_p1_timer          ; elapsed
    cmp #3
    bcs @p1_fin_full
    ; elapsed < 3: vol = elapsed*3 + 4
    sta temp_1
    asl a                       ; * 2
    clc
    adc temp_1                  ; * 3
    clc
    adc #4                      ; + 4
    jmp @p1_calc_fout
@p1_fin_full:
    lda #10

@p1_calc_fout:
    sta temp_1                  ; fade_in vol saved

    ; --- Fade-out: vol = remaining + 1 (when remaining < 8) ---
    lda music_p1_timer
    cmp #8
    bcs @p1_use_fin             ; remaining >= 8, no fade-out needed
    ; vol = remaining + 1
    clc
    adc #1
    ; Take min(fade_in, fade_out)
    cmp temp_1
    bcc @p1_write_vol           ; fade_out < fade_in, use fade_out
@p1_use_fin:
    lda temp_1                  ; use fade_in vol
@p1_write_vol:
    ora #P1_DUTY
    sta $4000
    rts

; --- Load next melody event ---
@p1_load:
    ldx music_p1_pos
    lda melody_data, x
    cmp #$FF
    beq @p1_loop

    sta music_p1_note
    inx
    ldy melody_data, x         ; duration
    inx
    stx music_p1_pos
    sty music_p1_timer
    sty music_p1_total

    ; Skip ALL APU writes if SFX owns the channel
    ldy sfx_pulse1_id
    bne @p1_sfx_owns

    lda music_p1_note
    cmp #M_REST
    beq @p1_rest

    ; Pitched note (no SFX active)
    tax
    lda #P1_START               ; Start at vol=4 (masks phase restart click)
    sta $4000
    ; Write period lo (always)
    lda note_period_lo, x
    sta $4002
    ; Write period hi only if changed (avoids phase restart click)
    lda note_period_hi, x
    ora #%00001000
    cmp music_p1_period_hi
    beq @p1_skip_hi
    sta music_p1_period_hi
    sta $4003
@p1_skip_hi:
    lda #0
    sta music_p1_restore
    rts

@p1_sfx_owns:
    ; SFX active — don't touch APU; mark restore for pitched notes
    lda music_p1_note
    cmp #M_REST
    beq @p1_sfx_rest
    lda #1
    sta music_p1_restore
    lda #$FF                    ; Invalidate period_hi (SFX overwrites $4003)
    sta music_p1_period_hi
@p1_sfx_rest:
    rts

@p1_rest:
    lda #P1_MUTE
    sta $4000
    rts

@p1_loop:
    lda #0
    sta music_p1_pos
    sta music_p1_timer
    jmp @tick_p1

; === Pulse 2: accompaniment with soft envelope ===

@tick_p2:
    lda music_p2_timer
    beq @p2_load
    dec music_p2_timer

    ; Sustain: if rest, nothing to do
    lda music_p2_note
    beq @p2_sustain_rts

    ; If SFX active, mark for restore and skip
    lda sfx_pulse2_id
    beq @p2_no_sfx
    lda #1
    sta music_p2_restore
@p2_sustain_rts:
    rts

@p2_no_sfx:
    ; Check if we need to restore pitch after SFX ended
    lda music_p2_restore
    beq @p2_envelope

    ; One-time restore: rewrite period + sweep
    lda #0
    sta music_p2_restore
    lda #$08
    sta $4005
    ldx music_p2_note
    lda note_period_lo, x
    sta $4006
    lda note_period_hi, x
    ora #%00001000
    sta $4007
    ; Fall through to envelope

@p2_envelope:
    ; --- Fade-in: vol = elapsed + 1, cap at 6 ---
    lda music_p2_total
    sec
    sbc music_p2_timer          ; elapsed frames
    clc
    adc #1                      ; vol = elapsed + 1
    cmp #7
    bcc @p2_fin_ok
    lda #6
@p2_fin_ok:
    sta temp_1                  ; fade-in vol

    ; --- Fade-out: vol = remaining + 1 (when remaining < 6) ---
    lda music_p2_timer
    cmp #6
    bcs @p2_use_fin             ; remaining >= 6, no fade-out
    clc
    adc #1                      ; vol = remaining + 1
    cmp temp_1
    bcc @p2_write_vol           ; fade_out < fade_in, use fade_out
@p2_use_fin:
    lda temp_1
@p2_write_vol:
    ora #%01110000              ; 25% duty, halt, const vol
    sta $4004
    rts

; --- Load next accompaniment event ---
@p2_load:
    ldx music_p2_pos
    lda accomp_data, x
    cmp #$FF
    beq @p2_loop

    sta music_p2_note
    inx
    ldy accomp_data, x
    inx
    stx music_p2_pos
    sty music_p2_timer
    sty music_p2_total

    lda music_p2_note
    cmp #M_REST
    beq @p2_rest

    ; Pitched note
    ldy sfx_pulse2_id
    bne @p2_sfx_skip

    tax
    lda #%01110001              ; 25% duty, halt, const vol, vol=1 (soft attack start)
    sta $4004
    lda note_period_lo, x
    sta $4006
    lda note_period_hi, x
    ora #%00001000
    sta $4007
    lda #0
    sta music_p2_restore
    rts

@p2_sfx_skip:
    lda #1
    sta music_p2_restore
    rts

@p2_rest:
    lda #P2_MUTE
    sta $4004
    rts

@p2_loop:
    lda #0
    sta music_p2_pos
    sta music_p2_timer
    jmp @tick_p2
.endproc

; ============================================================
; RODATA — period tables and song data
; ============================================================
.segment "RODATA"

note_period_lo:
  .byte $00               ; 0  = REST
  .byte $56               ; 1  = C3   ($0356)
  .byte $F9               ; 2  = D3   ($02F9)
  .byte $A6               ; 3  = E3   ($02A6)
  .byte $7F               ; 4  = F3   ($027F)
  .byte $3A               ; 5  = G3   ($023A)
  .byte $FB               ; 6  = A3   ($01FB)
  .byte $DF               ; 7  = Bb3  ($01DF)
  .byte $AB               ; 8  = C4   ($01AB)
  .byte $7C               ; 9  = D4   ($017C)
  .byte $52               ; 10 = E4   ($0152)
  .byte $3F               ; 11 = F4   ($013F)
  .byte $1C               ; 12 = G4   ($011C)
  .byte $FD               ; 13 = A4   ($00FD)
  .byte $EF               ; 14 = Bb4  ($00EF)
  .byte $D5               ; 15 = C5   ($00D5)

note_period_hi:
  .byte $00               ; 0  = REST
  .byte $03               ; 1  = C3
  .byte $02               ; 2  = D3
  .byte $02               ; 3  = E3
  .byte $02               ; 4  = F3
  .byte $02               ; 5  = G3
  .byte $01               ; 6  = A3
  .byte $01               ; 7  = Bb3
  .byte $01               ; 8  = C4
  .byte $01               ; 9  = D4
  .byte $01               ; 10 = E4
  .byte $01               ; 11 = F4
  .byte $01               ; 12 = G4
  .byte $00               ; 13 = A4
  .byte $00               ; 14 = Bb4
  .byte $00               ; 15 = C5

; -------------------------------------------------------
; Melody — Pulse 1
; Key: F major   Time: 3/4 waltz   ~100 BPM
; Chorus of "Home on the Range" (8-bar loop)
; -------------------------------------------------------
melody_data:
  ; Bar 1: "Home, home on"
  .byte M_C5, 67,  M_REST, 7
  .byte M_A4, 33,  M_REST, 7

  ; Bar 2: "the range"
  .byte M_Bb4,100, M_REST, 14

  ; Bar 3: "where the deer"
  .byte M_A4, 33,  M_REST, 4
  .byte M_G4, 33,  M_REST, 4
  .byte M_F4, 33,  M_REST, 7

  ; Bar 4: "and the an-"
  .byte M_D4, 49,  M_REST, 7
  .byte M_E4, 16,  M_REST, 3
  .byte M_F4, 33,  M_REST, 6

  ; Bar 5: "-te-lope play"
  .byte M_G4, 49,  M_REST, 7
  .byte M_F4, 16,  M_REST, 3
  .byte M_E4, 33,  M_REST, 6

  ; Bar 6: (hold)
  .byte M_D4,100,  M_REST, 14

  ; Bar 7: "skies are not"
  .byte M_F4, 49,  M_REST, 7
  .byte M_G4, 16,  M_REST, 3
  .byte M_A4, 33,  M_REST, 6

  ; Bar 8: "all day"
  .byte M_F4,100,  M_REST, 14

  .byte $FF

; -------------------------------------------------------
; Accompaniment — Pulse 2
; Waltz arpeggio: 6 notes per bar (2 per beat)
; Chords: F - Bb - F - Dm - C - Bb - Bb - F
; -------------------------------------------------------
accomp_data:
  ; Bar 1 (F)
  .byte M_F3,16, M_REST,3,  M_C4,16, M_REST,3,  M_A3,16, M_REST,3
  .byte M_C4,16, M_REST,3,  M_F3,16, M_REST,3,  M_A3,16, M_REST,3

  ; Bar 2 (Bb)
  .byte M_F3,16, M_REST,3,  M_Bb3,16, M_REST,3,  M_D4,16, M_REST,3
  .byte M_Bb3,16, M_REST,3,  M_F3,16, M_REST,3,  M_D4,16, M_REST,3

  ; Bar 3 (F)
  .byte M_F3,16, M_REST,3,  M_C4,16, M_REST,3,  M_A3,16, M_REST,3
  .byte M_C4,16, M_REST,3,  M_F3,16, M_REST,3,  M_A3,16, M_REST,3

  ; Bar 4 (Dm)
  .byte M_D3,16, M_REST,3,  M_A3,16, M_REST,3,  M_F3,16, M_REST,3
  .byte M_A3,16, M_REST,3,  M_D3,16, M_REST,3,  M_F3,16, M_REST,3

  ; Bar 5 (C)
  .byte M_C3,16, M_REST,3,  M_G3,16, M_REST,3,  M_E3,16, M_REST,3
  .byte M_G3,16, M_REST,3,  M_C3,16, M_REST,3,  M_E3,16, M_REST,3

  ; Bar 6 (Bb)
  .byte M_F3,16, M_REST,3,  M_Bb3,16, M_REST,3,  M_D4,16, M_REST,3
  .byte M_Bb3,16, M_REST,3,  M_F3,16, M_REST,3,  M_D4,16, M_REST,3

  ; Bar 7 (Bb)
  .byte M_F3,16, M_REST,3,  M_Bb3,16, M_REST,3,  M_D4,16, M_REST,3
  .byte M_Bb3,16, M_REST,3,  M_F3,16, M_REST,3,  M_D4,16, M_REST,3

  ; Bar 8 (F)
  .byte M_F3,16, M_REST,3,  M_C4,16, M_REST,3,  M_A3,16, M_REST,3
  .byte M_C4,16, M_REST,3,  M_F3,16, M_REST,3,  M_A3,16, M_REST,3

  .byte $FF
