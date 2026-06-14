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
enemy_x_hi: .res NUMBER_OF_ENEMIES
enemy_x_lo: .res NUMBER_OF_ENEMIES
enemy_y_hi: .res NUMBER_OF_ENEMIES
enemy_y_lo: .res NUMBER_OF_ENEMIES
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
; Remove enemies that go off the bottom of the screen
; --------------------------------------------------
  lda enemy_y_hi, x
  cmp #240
  bcc enemy_on_screen
  lda #%00000000
  sta enemy_flags, x
  lda #$F0
  sta enemy_y_hi, x
  jsr DrawEnemies
  jmp done
enemy_on_screen:

; --------------------------------------------------
; Every 16 frames, get a new value from the enemy 
; data tables
; --------------------------------------------------
  lda timer
  and #%00001111
  bne dont_need_new_data
  inc enemy_path_index, x
dont_need_new_data:

; --------------------------------------------------
; Set aliases used for updating enemy position
; --------------------------------------------------
  path = scratch_03
  enemy_x_velocity = scratch_01
  enemy_y_velocity = scratch_02

; --------------------------------------------------
; Determine if the enemy is required to do any special
; actions on this frame.
; Also check weather the index into the enemy data 
; tables needs to be reset
; --------------------------------------------------
  ldy enemy_path, x
  lda enemy_path_data_action_lo_table, y
  sta path
  lda enemy_path_data_action_hi_table, y
  sta path+1
  
  ldy enemy_path_index, x
  lda (path), y
  cmp #$80
  bne dont_reset_path_index
  lda #$00
  sta enemy_path_index, x
dont_reset_path_index:

; --------------------------------------------------
; Get x speed
; --------------------------------------------------
  ldy enemy_path, x
  lda enemy_path_data_x_lo_table, y
  sta path
  lda enemy_path_data_x_hi_table, y
  sta path+1
  
  ldy enemy_path_index, x
  lda (path), y

  sta enemy_x_velocity

; --------------------------------------------------
; Get y speed
; --------------------------------------------------
  ldy enemy_path, x
  lda enemy_path_data_y_lo_table, y
  sta path
  lda enemy_path_data_y_hi_table, y
  sta path+1
  
  ldy enemy_path_index, x
  lda (path), y

  sta enemy_y_velocity

; --------------------------------------------------
; Set correct animation frame
; --------------------------------------------------
;  lda enemy_x_velocity
;  beq zero
;  bmi left
;  jmp right
;zero:
;  lda #$04
;  sta enemy_frame_number
;  jmp done_sw
;left:
;  lda #$05
;  sta enemy_frame_number
;  jmp done_sw
;right:
;  lda #$06
;  sta enemy_frame_number
;done_sw:

  lda #$04 ; for debug reasons, hard code an animation frame number
  sta enemy_frame_number

; --------------------------------------------------
; Update enemy x position
; --------------------------------------------------
  lda enemy_x_velocity
  bmi MoveLeft
  
MoveRight:
  cmp #$20
  bcs SubPixelRight

  cmp #$00
  beq DoNotChangeSpriteX

FullPixelRight:
  clc
  lda enemy_x_hi, x
  adc enemy_x_velocity
  sta enemy_x_hi, x
  jmp FinishedSettingXPositions
SubPixelRight:
  clc
  lda enemy_x_lo, x
  adc enemy_x_velocity
  sta enemy_x_lo, x

  lda enemy_x_hi, x
  adc #$00
  sta enemy_x_hi, x
  jmp FinishedSettingXPositions

; negate A (two's complement: A = -A)
MoveLeft:
  eor #$FF
  clc
  adc #$01
  sta enemy_x_velocity

  cmp #$20
  bcs SubPixelLeft

  cmp #$00
  beq DoNotChangeSpriteX
FullPixelLeft:
  sec
  lda enemy_x_hi, x
  sbc enemy_x_velocity
  sta enemy_x_hi, x
  jmp FinishedSettingXPositions
SubPixelLeft:
  sec
  lda enemy_x_lo, x
  sbc enemy_x_velocity
  sta enemy_x_lo, x

  lda enemy_x_hi, x
  sbc #$00
  sta enemy_x_hi, x

DoNotChangeSpriteX:

FinishedSettingXPositions:

; --------------------------------------------------
; Update enemy y position
; --------------------------------------------------
  lda enemy_y_velocity
  bmi MoveUp
  
MoveDown:
  cmp #$20
  bcs SubPixelDown

  cmp #$00
  beq FinishedSettingYPositions

FullPixelDown:
  clc
  lda enemy_y_hi, x
  adc enemy_y_velocity
  sta enemy_y_hi, x
  jmp FinishedSettingYPositions
SubPixelDown:
  clc
  lda enemy_y_lo, x
  adc enemy_y_velocity
  sta enemy_y_lo, x

  lda enemy_y_hi, x
  adc #$00
  sta enemy_y_hi, x
  jmp FinishedSettingYPositions

; negate A (two's complement: A = -A)
MoveUp:
  eor #$FF
  clc
  adc #$01
  sta enemy_y_velocity

  cmp #$20
  bcs SubPixelUp

  cmp #$00
  beq FinishedSettingYPositions
FullPixelUp:
  sec
  lda enemy_y_hi, x
  sbc enemy_y_velocity
  sta enemy_y_hi, x
  jmp FinishedSettingYPositions
SubPixelUp:
  sec
  lda enemy_y_lo, x
  sbc enemy_y_velocity
  sta enemy_y_lo, x

  lda enemy_y_hi, x
  sbc #$00
  sta enemy_y_hi, x

FinishedSettingYPositions:

; --------------------------------------------------
; Updates done, now draw
; --------------------------------------------------
  jsr DrawEnemies

done:
  RESTORE_REGISTERS
  rts
.endproc

.proc DrawEnemies
  SAVE_REGISTERS

; --------------------------------------------------
; point to tiles and attributes of appropriate
; graphics
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
  lda enemy_y_hi, x
  sta scratch_01
  lda enemy_x_hi, x
  sta scratch_02
  xpos = scratch_01
  ypos = scratch_02

; --------------------------------------------------
; need enemy_type as a multiple of 16 as the
; enemy_move_down_frames_table is laid out in rows
; of 16 bytes
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
; set bit 7 of enemy flag - enemy is now alive
; --------------------------------------------------
  lda #ENEMY_ALIVE
  sta enemy_flags, x

; --------------------------------------------------
; set initial x and y positions of enemy
; --------------------------------------------------
  lda spawn_enemy_xpos_table, y
  sta enemy_x_hi, x
  lda spawn_enemy_ypos_table, y
  sta enemy_y_hi, x

; --------------------------------------------------
; Set the type of enemy that will spawn
; --------------------------------------------------
  lda spawn_enemy_type_table, y
  sta enemy_type, x

; --------------------------------------------------
; Set the flight path for the enemy
; --------------------------------------------------
  lda spawn_enemy_path_table, y
  sta enemy_path, x

; --------------------------------------------------
; Initialise the index this enemy will use as it reads
; flight path data from its flight path table
; --------------------------------------------------
  lda #0
  sta enemy_path_index, x

  RESTORE_REGISTERS
  rts
.endproc