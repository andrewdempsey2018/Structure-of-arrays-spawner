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
; enemy_x, enemy_y position coordinates of enemy
; enemy_type type of enemy sprite
; enemy_flags currently holds alive or dead, use for other attributes as needed
; enemy_path the flight path the enemy flies when it is alive
; enemy_path_index the flight path is held in data tables, this is the index into those tables
; --------------------------------------------------
enemy_x: .res NUMBER_OF_ENEMIES
enemy_y: .res NUMBER_OF_ENEMIES
enemy_type: .res NUMBER_OF_ENEMIES
enemy_flags: .res NUMBER_OF_ENEMIES
enemy_path: .res NUMBER_OF_ENEMIES
enemy_path_index: .res NUMBER_OF_ENEMIES

; --------------------------------------------------
; enemy SoA
; current_enemy - this is the enemy that gets processed and updated during aloop
; enemy_frame_number - current animation frame of the enemy that is being dealt with during a loop
; enemy_spawn_number - the enemy number that will be spawned
; enemy_spawn_index - there are multiple tables containing data that will be used when spawing an enemy, this is the index into those tables
; enemy_spawn_wait - used in conjunction with the timer to delay when the next enemy will be spawned.
; enemy_spawn_script - used in conjunction with spawn_enemy_qty_wait_table
; --------------------------------------------------
current_enemy: .res 1
enemy_frame_number: .res 1
enemy_spawn_number: .res 1
enemy_spawn_index: .res 1
enemy_spawn_wait: .res 1
enemy_spawn_script: .res 1

.segment "BSS"

.segment "RODATA"
.include "../data/enemy_data.asm"

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
  ;lda spawn_enemy_wait_table, y
  ;sta enemy_spawn_wait

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