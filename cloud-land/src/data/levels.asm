; ============================================================
; Level Data — Platform coordinates and player spawn points
; Platform format: x, y, width (in pixels). 72px wide, 8px tall.
; ============================================================
.segment "RODATA"

; --- Platform counts per level ---
level_platform_count:
    .byte 12, 6, 4, 6, 4

; --- Platform coordinate tables ---
; Each entry: x_pos, y_pos (width is always 48px = 6 tiles)

level1_platforms:
    ; Row 4 (top, y=56)
    .byte  32, 56
    .byte 120, 56
    .byte 208, 56
    ; Row 3 (y=104)
    .byte   0, 104
    .byte  88, 104
    .byte 176, 104
    ; Row 2 (y=152)
    .byte  32, 152
    .byte 120, 152
    .byte 208, 152
    ; Row 1 (bottom, y=200)
    .byte   0, 200
    .byte  88, 200
    .byte 176, 200

level2_platforms:
    ; Row 4 (y=56)
    .byte   0, 56
    .byte 176, 56
    ; Row 3 (y=104)
    .byte  88, 104
    ; Row 2 (y=152)
    .byte   0, 152
    .byte 176, 152
    ; Row 1 (y=200)
    .byte  88, 200

level3_platforms:
    ; Row 4 (y=56)
    .byte  48, 56
    ; Row 3 (y=104)
    .byte 136, 104
    ; Row 2 (y=152)
    .byte  48, 152
    ; Row 1 (y=200)
    .byte 136, 200

level4_platforms:
    ; Row 4 (y=56)
    .byte  24, 56
    .byte 168, 56
    ; Row 3 (y=104)
    .byte  16, 104
    .byte 176, 104
    ; Row 2 (y=152)
    .byte  96, 152
    ; Row 1 (y=200)
    .byte  88, 200

level5_platforms:
    ; Row 4 (y=56)
    .byte  88, 56
    ; Row 3 (y=104)
    .byte   0, 104
    ; Row 2 (y=152)
    .byte  88, 152
    ; Row 1 (y=200)
    .byte 176, 200

; --- Platform table pointers (low/high bytes, indexed by level 0-4) ---
level_platforms_lo:
    .byte <level1_platforms, <level2_platforms, <level3_platforms
    .byte <level4_platforms, <level5_platforms

level_platforms_hi:
    .byte >level1_platforms, >level2_platforms, >level3_platforms
    .byte >level4_platforms, >level5_platforms

; --- Player spawn positions (sprite x, sprite y per level) ---
player_spawn_x:
    .byte  10, 24, 40, 104, 200

player_spawn_y:
    .byte 184, 40, 136, 136, 184

; --- Bird speed tables (indexed by level 0-4) ---
bird_speed:
    .byte $01, $01, $01, $01, $01

bird_osc_speed:
    .byte $01, $01, $01, $01, $01

bird_osc_amplitude:
    .byte $18, $18, $18, $18, $18

; --- Heart despawn speed multiplier per level (4.4 fixed point) ---
heart_speed_mult:
    .byte $10, $12, $14, $16, $18

; --- Bird zone center Y values (oscillation midpoints) ---
bird_zone_center_y:
    .byte 36, 76, 124, 172

; --- Bird initial X positions (4 birds x 5 levels = 20 bytes) ---
; Stagger starting X across screen for visual variety
bird_init_x_l1:  .byte  20, 200,  60, 160   ; Level 1
bird_init_x_l2:  .byte 220, 180,  80, 120   ; Level 2
bird_init_x_l3:  .byte 200,  40, 160,  80   ; Level 3
bird_init_x_l4:  .byte  60, 180,  20, 220   ; Level 4
bird_init_x_l5:  .byte 180,  40, 120,  60   ; Level 5

bird_init_x_lo:
    .byte <bird_init_x_l1, <bird_init_x_l2, <bird_init_x_l3
    .byte <bird_init_x_l4, <bird_init_x_l5
bird_init_x_hi:
    .byte >bird_init_x_l1, >bird_init_x_l2, >bird_init_x_l3
    .byte >bird_init_x_l4, >bird_init_x_l5

; --- Bird initial direction (4 birds x 5 levels) ---
; 0=right, 1=left. Alternate for variety.
bird_init_dir_l1: .byte 0, 1, 1, 0
bird_init_dir_l2: .byte 0, 0, 0, 1
bird_init_dir_l3: .byte 0, 1, 0, 1
bird_init_dir_l4: .byte 1, 0, 1, 0
bird_init_dir_l5: .byte 0, 1, 1, 0

bird_init_dir_lo:
    .byte <bird_init_dir_l1, <bird_init_dir_l2, <bird_init_dir_l3
    .byte <bird_init_dir_l4, <bird_init_dir_l5
bird_init_dir_hi:
    .byte >bird_init_dir_l1, >bird_init_dir_l2, >bird_init_dir_l3
    .byte >bird_init_dir_l4, >bird_init_dir_l5

; --- Bird animation sequence (ping-pong: 0,1,2,1) ---
bird_anim_sequence:
    .byte 0, 1, 2, 1
BIRD_ANIM_SEQ_LEN = 4
