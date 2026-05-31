; --------------------------------------------------
; enemy constants
; --------------------------------------------------
ENEMY_OAM_START = $0204
NUMBER_OF_ENEMIES = 5

; --------------------------------------------------
; enemy flags
; --------------------------------------------------
ENEMY_ALIVE = %10000000
ENEMY_FLAG_6 = %00100000
ENEMY_FLAG_5 = %00100000
ENEMY_FLAG_4 = %00010000
ENEMY_FLAG_3 = %00001000
ENEMY_FLAG_2 = %00000100
ENEMY_MOVING_RIGHT = %00000010
ENEMY_MOVING_LEFT = %00000001

.segment "ZEROPAGE"

; --------------------------------------------------
; enemy SoA
; --------------------------------------------------
enemy_x: .res NUMBER_OF_ENEMIES
enemy_y: .res NUMBER_OF_ENEMIES
enemy_type: .res NUMBER_OF_ENEMIES
enemy_flags: .res NUMBER_OF_ENEMIES

; --------------------------------------------------
; enemy SoA
; current_enemy - this is the enemy that gets processed and updated during aloop
; enemy_frame_number - current animation frame of the enemy that is being dealt with during a loop
; enemy_spawn_number - the enemy number that will be spawned
; enemy_spawn_index - there are multiple tables containing data that will be used when spawing an enemy, this is the index into those tables
; enemy_spawn_wait - used in conjunction with the timer to delay when the next enemy will be spawned.
; --------------------------------------------------
current_enemy: .res 1
enemy_frame_number: .res 1
enemy_spawn_number: .res 1
enemy_spawn_index: .res 1
enemy_spawn_wait: .res 1

.segment "BSS"

.segment "CODE"

.proc ProcessEnemeies
  SAVE_REGISTERS

  ldx #$00

loop:
  stx current_enemy
  lda enemy_flags, x
  and #ENEMY_ALIVE
  beq next
  jsr UpdateEnemies
next:
  inx
  cpx #$05
  bne loop

  RESTORE_REGISTERS
  rts
.endproc

.proc UpdateEnemies
  SAVE_REGISTERS

  ldx current_enemy

; --------------------------------------------------
; Dont process inactive enemies
; --------------------------------------------------
  lda enemy_flags, x
  and #ENEMY_ALIVE
  bne enemy_alive
  jmp done
enemy_alive:

; --------------------------------------------------
; Kill enemies that go off the bottom of the screen
; --------------------------------------------------
  lda enemy_y, x
  cmp #240
  bcc enemy_on_screen
  lda #%00000000
  sta enemy_flags, x
enemy_on_screen:

;;;;;
  lda #$04
  sta enemy_frame_number
  inc enemy_y, x
;;;;;

  jsr DrawEnemies

done:
  RESTORE_REGISTERS
  rts
.endproc

.proc DrawEnemies
  SAVE_REGISTERS

; --------------------------------------------------
; point to tiles and attributes of appropriate graphics
; --------------------------------------------------
  ldy enemy_frame_number
  lda frames_lo_table, y
  sta scratch_03_lo
  lda frames_hi_table, y
  sta scratch_03_hi
  frame = scratch_03

; --------------------------------------------------
; add x and y position of current enemy to pointer
; --------------------------------------------------
  ldx current_enemy
  lda enemy_y, x
  sta scratch_01
  lda enemy_x, x
  sta scratch_02
  xpos = scratch_01
  ypos = scratch_02

; --------------------------------------------------
; need enemy_type as a multiple of 16 as the
; enemy_move_down_frames_table is laid out in rows of 16 bytes
; --------------------------------------------------
  ldx current_enemy
  lda enemy_type, x
  asl a
  asl a
  asl a
  asl a
  tay

; --------------------------------------------------
; enemies are 4x4 tiles so need 16 bytes in OAM
; --------------------------------------------------
  lda current_enemy
  asl a
  asl a
  asl a
  asl a
  tax

; --------------------------------------------------
; draw top left
; --------------------------------------------------
  lda xpos
  sta ENEMY_OAM_START, x
  inx
  lda (frame), y
  sta ENEMY_OAM_START, x
  inx
  iny
  lda (frame), y
  sta ENEMY_OAM_START, x
  inx
  lda ypos
  sta ENEMY_OAM_START, x

; --------------------------------------------------
; draw top right
; --------------------------------------------------
  inx
  iny
  lda xpos
  sta ENEMY_OAM_START, x
  inx
  lda (frame), y
  sta ENEMY_OAM_START, x
  inx
  iny
  lda (frame), y
  sta ENEMY_OAM_START, x
  inx
  lda ypos
  clc
  adc #$08
  sta ENEMY_OAM_START, x

; --------------------------------------------------
; draw bottom left
; --------------------------------------------------
  inx
  iny
  lda xpos
  clc
  adc #$08
  sta ENEMY_OAM_START, x
  inx
  lda (frame), y
  sta ENEMY_OAM_START, x
  inx
  iny
  lda (frame), y
  sta ENEMY_OAM_START, x
  inx
  lda ypos
  sta ENEMY_OAM_START, x

; --------------------------------------------------
; draw bottom right
; --------------------------------------------------
  inx
  iny
  lda xpos
  clc
  adc #$08
  sta ENEMY_OAM_START, x
  inx
  lda (frame), y
  sta ENEMY_OAM_START, x
  inx
  iny
  lda (frame), y
  sta ENEMY_OAM_START, x
  inx
  lda ypos
  clc
  adc #$08
  sta ENEMY_OAM_START, x

  RESTORE_REGISTERS
  rts
.endproc

.proc SpawnEnemy
  SAVE_REGISTERS

; --------------------------------------------------
; select the next index into each of the tables that
; contain enemy type, x and y positions etc.
; --------------------------------------------------
  inc enemy_spawn_index
  lda enemy_spawn_index
  cmp #255
  bne dont_reset_spawn_index
  lda #$00
  sta enemy_spawn_index
dont_reset_spawn_index:
  tay

; --------------------------------------------------
; select the next enemy number to spawn
; --------------------------------------------------
  inc enemy_spawn_number
  lda enemy_spawn_number
  cmp #NUMBER_OF_ENEMIES
  bne dont_reset_spawn_num
  lda #$00
  sta enemy_spawn_number
dont_reset_spawn_num:
  tax

; --------------------------------------------------
; how much time to wait before next enemy spawns
; --------------------------------------------------
  lda spawn_enemy_wait_table, y
  sta enemy_spawn_wait

; --------------------------------------------------
; set bit 7 of enemy flag - enemy is now alive
; --------------------------------------------------
  lda #ENEMY_ALIVE
  sta enemy_flags, x

; --------------------------------------------------
; set initial x and y positions of enemy
; --------------------------------------------------
  lda spawn_enemy_xpos_table, y
  sta enemy_x, x
  lda spawn_enemy_ypos_table, y
  sta enemy_y, x

; --------------------------------------------------
; set the type of enemy that will spawn
; --------------------------------------------------
  lda spawn_enemy_type_table, y
  sta enemy_type, x

  RESTORE_REGISTERS
  rts
.endproc

.segment "RODATA"

enemy_move_down_frames_table:
; tiletl,attribtl,tiletr,attribtr,tilebl,attribbl,tilebr,attribbr,
; padding,padding,padding,padding,padding,padding,padding,padding
  .byte $02,$00,$03,$00,$12,$00,$13,$00,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; type 0
  .byte $04,$00,$05,$00,$14,$00,$15,$00,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; type 1
  .byte $02,$01,$03,$01,$12,$01,$13,$01,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; type 2
  .byte $04,$02,$05,$02,$14,$02,$15,$02,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; type 3
  .byte $04,$03,$05,$03,$14,$03,$15,$03,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; type 4

enemy_move_left_frames_table:
; tiletl,attribtl,tiletr,attribtr,tilebl,attribbl,tilebr,attribbr,
; padding,padding,padding,padding,padding,padding,padding,padding
  .byte $22,$00,$23,$00,$32,$00,$33,$00,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; type 0
  .byte $24,$00,$25,$00,$34,$00,$35,$00,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; type 1
  .byte $22,$01,$23,$01,$32,$01,$33,$01,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; type 2
  .byte $24,$02,$25,$02,$34,$02,$35,$02,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; type 3
  .byte $24,$03,$25,$03,$34,$03,$35,$03,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; type 4

enemy_move_right_frames_table:
; tiletl,attribtl,tiletr,attribtr,tilebl,attribbl,tilebr,attribbr,
; padding,padding,padding,padding,padding,padding,padding,padding
  .byte $42,$00,$43,$00,$52,$00,$53,$00,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; type 0
  .byte $44,$00,$45,$00,$54,$00,$55,$00,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; type 1
  .byte $42,$01,$43,$01,$52,$01,$53,$01,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; type 2
  .byte $44,$02,$45,$02,$54,$02,$55,$02,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; type 3
  .byte $44,$03,$45,$03,$54,$03,$55,$03,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; type 4

explosion_frame_0_table:
  .byte $06,$00,$07,$00,$16,$00,$17,$00,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; type 0
  .byte $06,$00,$07,$00,$16,$00,$17,$00,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; type 1
  .byte $06,$00,$07,$00,$16,$00,$17,$00,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; type 2
  .byte $06,$00,$07,$00,$16,$00,$17,$00,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; type 3
  .byte $06,$00,$07,$00,$16,$00,$17,$00,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; type 4

explosion_frame_1_table:
  .byte $26,$00,$27,$00,$36,$00,$37,$00,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; type 0
  .byte $26,$00,$27,$00,$36,$00,$37,$00,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; type 1
  .byte $26,$00,$27,$00,$36,$00,$37,$00,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; type 2
  .byte $26,$00,$27,$00,$36,$00,$37,$00,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; type 3
  .byte $26,$00,$27,$00,$36,$00,$37,$00,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; type 4

explosion_frame_2_table:
  .byte $46,$00,$47,$00,$56,$00,$57,$00,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; type 0
  .byte $46,$00,$47,$00,$56,$00,$57,$00,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; type 1
  .byte $46,$00,$47,$00,$56,$00,$57,$00,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; type 2
  .byte $46,$00,$47,$00,$56,$00,$57,$00,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; type 3
  .byte $46,$00,$47,$00,$56,$00,$57,$00,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; type 4

explosion_frame_3_table:
  .byte $66,$00,$67,$00,$76,$00,$77,$00,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; type 0
  .byte $66,$00,$67,$00,$76,$00,$77,$00,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; type 1
  .byte $66,$00,$67,$00,$76,$00,$77,$00,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; type 2
  .byte $66,$00,$67,$00,$76,$00,$77,$00,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; type 3
  .byte $66,$00,$67,$00,$76,$00,$77,$00,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; type 4

frames_lo_table:
  .byte <explosion_frame_0_table,<explosion_frame_1_table,<explosion_frame_2_table,<explosion_frame_3_table,<enemy_move_down_frames_table,<enemy_move_left_frames_table,<enemy_move_right_frames_table

frames_hi_table:
  .byte >explosion_frame_0_table,>explosion_frame_1_table,>explosion_frame_2_table,>explosion_frame_3_table,>enemy_move_down_frames_table,>enemy_move_left_frames_table,>enemy_move_right_frames_table

; --------------------------------------------------
; Enemy data tables
; spawn_enemy_wait_table - how long to wait until next enemy spawns. Counts down -1 each time zero page 'timer' hits 0.
; spawn_enemy_xpos_table, spawn_enemy_ypos_table - x and y positions of enemy when it is first spawned
; spawn_enemy_type_table - the specific enemy type to spawn
; 
; 
; --------------------------------------------------
spawn_enemy_wait_table:
  .byte $02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02
  .byte $02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02
  .byte $02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02
  .byte $02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02

spawn_enemy_xpos_table:
  .byte $10,$20,$30,$40,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10
  .byte $10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10
  .byte $10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10
  .byte $10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10

spawn_enemy_ypos_table:
  .byte $10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10
  .byte $10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10
  .byte $10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10
  .byte $10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10

spawn_enemy_type_table:
  .byte $02,$01,$02,$03,$02,$02,$02,$02,$02,$02,$02,$02,$00,$02,$02,$02
  .byte $02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02
  .byte $02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02
  .byte $02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02