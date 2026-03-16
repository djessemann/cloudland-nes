; ============================================================
; Sound Module — APU SFX system (Pulse 1 + Pulse 2)
; Pulse 1: Jump, Death
; Pulse 2: Heart collect
; ============================================================
.segment "CODE"

; SFX IDs for Pulse 1
SFX_NONE  = $00
SFX_JUMP  = $01
SFX_DEATH = $02

; SFX IDs for Pulse 2
SFX_HEART = $01
SFX_STOMP = $02

; SFX durations (frames)
SFX_JUMP_LEN  = 24
SFX_DEATH_LEN = 48
SFX_HEART_LEN = 16
SFX_STOMP_LEN = 24

; ------------------------------------------------------------
; sound_init
; Enable APU channels and silence everything.
; ------------------------------------------------------------
.proc sound_init
    ; Enable pulse 1 and pulse 2 channels
    lda #$03
    sta $4015

    ; Silence both channels
    lda #$10                    ; Const volume, vol=0
    sta $4000
    sta $4004
    lda #$08                    ; Disable sweep
    sta $4001
    sta $4005
    lda #$00
    sta $4002
    sta $4003
    sta $4006
    sta $4007

    ; Silence triangle
    sta $4008
    sta $400A
    sta $400B

    ; Clear state
    sta sfx_pulse1_id
    sta sfx_pulse1_timer
    sta sfx_pulse2_id
    sta sfx_pulse2_timer
    sta music_playing
    sta music_p1_pos
    sta music_p1_timer
    sta music_p1_note
    sta music_p1_total
    sta music_p1_restore
    sta music_p1_period_hi
    sta music_p2_pos
    sta music_p2_timer
    sta music_p2_note
    sta music_p2_restore
    rts
.endproc

; ------------------------------------------------------------
; sound_update
; Called from NMI every frame. Processes active SFX.
; ------------------------------------------------------------
.proc sound_update
    ; === Pulse 1 channel ===
    lda sfx_pulse1_id
    bne @p1_active
    jmp @p1_done
@p1_active:
    cmp #SFX_JUMP
    beq @p1_jump
    cmp #SFX_DEATH
    beq @p1_death
    jmp @p1_done

@p1_jump:
    lda sfx_pulse1_timer
    bne @p1_jump_tick
    ; Frame 0: setup manual rising chirp
    lda #$9C                    ; 50% duty, halt, const vol, vol=12
    sta $4000
    lda #$08                    ; Sweep disabled
    sta $4001
    lda #$C0                    ; Timer lo (period=$C0, ~580Hz)
    sta $4002
    lda #$08                    ; Timer hi=0, length load
    sta $4003
    jmp @p1_advance

@p1_jump_tick:
    cmp #SFX_JUMP_LEN
    bcs @p1_silence
    ; Manual pitch rise: period = $C0 - timer * 3
    ; Range $C0→$4E over 24 frames (~580Hz→~1400Hz)
    pha
    sta temp_1
    asl a                       ; timer * 2
    clc
    adc temp_1                  ; timer * 3
    sta temp_1
    lda #$C0
    sec
    sbc temp_1                  ; $C0 - timer*3
    sta $4002                   ; Timer lo only
    pla
    ; Fade volume: 12 - (timer / 3) approx via timer/4
    lsr a
    lsr a                       ; timer / 4
    sta temp_1
    lda #$0C
    sec
    sbc temp_1
    bmi @p1_silence
    ora #$90                    ; 50% duty, halt, const vol
    sta $4000
    jmp @p1_advance

@p1_death:
    lda sfx_pulse1_timer
    bne @p1_death_tick
    ; Frame 0: setup initial pitch, no sweep (manual control)
    lda #$DF                    ; 75% duty, halt, const vol, vol=15
    sta $4000
    lda #$08                    ; Sweep disabled
    sta $4001
    lda #$60                    ; Timer lo (period=$060, ~1160Hz)
    sta $4002
    lda #$08                    ; Timer hi=0, length load
    sta $4003
    jmp @p1_advance

@p1_death_tick:
    cmp #SFX_DEATH_LEN
    bcs @p1_silence
    ; Manual pitch descent: period = $060 + timer * 3
    ; Stays within 8 bits ($60→$ED), never writes $4003 (no phase restart)
    pha
    sta temp_1
    asl a                       ; timer * 2
    clc
    adc temp_1                  ; timer * 3
    clc
    adc #$60                    ; + base period
    sta $4002                   ; Timer lo only
    pla
    ; Fade volume: vol = 15 - (timer / 4)
    lsr a
    lsr a                       ; timer / 4
    sta temp_1
    lda #$0F
    sec
    sbc temp_1
    bmi @p1_silence             ; Underflow = done
    ora #$D0                    ; 75% duty, halt, const vol
    sta $4000
    jmp @p1_advance

@p1_silence:
    lda #$10                    ; Const vol, vol=0
    sta $4000
    lda #$08                    ; Disable sweep
    sta $4001
    lda #SFX_NONE
    sta sfx_pulse1_id
    jmp @p1_done

@p1_advance:
    inc sfx_pulse1_timer

@p1_done:
    ; === Pulse 2 channel ===
    lda sfx_pulse2_id
    bne @p2_active
    jmp @p2_done
@p2_active:
    cmp #SFX_STOMP
    beq @p2_stomp

    ; --- Heart collect SFX ---
    lda sfx_pulse2_timer
    bne @p2_note2

    ; Frame 0: Note 1 — C5 (period $0D5, ~523Hz)
    lda #$5C                    ; 25% duty, halt, const vol, vol=12
    sta $4004
    lda #$00                    ; No sweep
    sta $4005
    lda #$D5                    ; Timer lo
    sta $4006
    lda #$08                    ; Timer hi=0, length load
    sta $4007
    jmp @p2_advance

@p2_note2:
    cmp #4
    bne @p2_note3
    ; Frame 4: Note 2 — E5 (period $0A9, ~659Hz)
    lda #$A9
    sta $4006
    jmp @p2_advance

@p2_note3:
    cmp #8
    bne @p2_note4
    ; Frame 8: Note 3 — G5 (period $08E, ~784Hz)
    lda #$8E
    sta $4006
    jmp @p2_advance

@p2_note4:
    cmp #12
    bne @p2_check_end
    ; Frame 12: Note 4 — C6 (period $069, ~1047Hz)
    lda #$69
    sta $4006
    jmp @p2_advance

@p2_check_end:
    cmp #SFX_HEART_LEN
    bcs @p2_silence
    jmp @p2_advance

@p2_stomp:
    ; --- Stomp SFX: descending "bop" ---
    lda sfx_pulse2_timer
    bne @p2_stomp_tick
    ; Frame 0: setup manual descending chirp
    lda #$9E                    ; 50% duty, halt, const vol, vol=14
    sta $4004
    lda #$00                    ; No sweep
    sta $4005
    lda #$40                    ; Timer lo (high pitch start, ~1700Hz)
    sta $4006
    lda #$08                    ; Timer hi=0, length load
    sta $4007
    jmp @p2_advance

@p2_stomp_tick:
    cmp #SFX_STOMP_LEN
    bcs @p2_silence
    ; Descend pitch: period = $40 + timer * 3
    ; Range $40→$88 over 24 frames (~1700Hz→~840Hz)
    pha
    sta temp_1
    asl a                       ; timer * 2
    clc
    adc temp_1                  ; timer * 3
    clc
    adc #$40                    ; + base period
    sta $4006                   ; Timer lo only
    pla
    ; Fade volume: 14 - (timer / 2)
    lsr a                       ; timer / 2
    sta temp_1
    lda #$0E
    sec
    sbc temp_1
    bmi @p2_silence
    ora #$90                    ; 50% duty, halt, const vol
    sta $4004
    jmp @p2_advance

@p2_silence:
    lda #$10                    ; Const vol, vol=0
    sta $4004
    lda #SFX_NONE
    sta sfx_pulse2_id
    jmp @p2_done

@p2_advance:
    inc sfx_pulse2_timer

@p2_done:
    jsr music_tick
    rts
.endproc

; ------------------------------------------------------------
; SFX trigger functions — called from game code
; ------------------------------------------------------------

.proc sfx_play_jump
    lda #SFX_JUMP
    sta sfx_pulse1_id
    lda #$00
    sta sfx_pulse1_timer
    rts
.endproc

.proc sfx_play_death
    lda #SFX_DEATH
    sta sfx_pulse1_id
    lda #$00
    sta sfx_pulse1_timer
    rts
.endproc

.proc sfx_play_heart
    lda #SFX_HEART
    sta sfx_pulse2_id
    lda #$00
    sta sfx_pulse2_timer
    rts
.endproc

.proc sfx_play_stomp
    lda #SFX_STOMP
    sta sfx_pulse2_id
    lda #$00
    sta sfx_pulse2_timer
    rts
.endproc
