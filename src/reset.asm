.segment "ZEROPAGE"

.segment "CODE"
.proc reset_handler
  sei
  cld
  ldx #$40
  stx APU
  ldx #$FF
  txs
  inx
  stx PPUCTRL
  stx PPUMASK
  stx IRQ_ENABLE
  bit PPUSTATUS

  lda #$00
  sta sleeping
  sta buttons_held
  sta buttons_pressed
  sta current_enemy
  sta enemy_frame_number
  sta timer

  lda #$FF
  sta enemy_spawn_number
  sta enemy_spawn_index
  sta enemy_spawn_script

  lda #$05
  sta enemy_spawn_wait

  lda #$00
  ldx #$00
ClearEnemyData:
  sta enemy_x, x
  sta enemy_y, x
  sta enemy_type, x
  sta enemy_flags, x
  sta enemy_path, x
  sta enemy_path_index, x
  inx
  cpx #NUMBER_OF_ENEMIES
  bne ClearEnemyData

  WAIT_VBLANK

	ldx #$00
	lda #$FF
clear_oam:
	sta PPUCTRL, x ; set sprite y-positions off the screen
	inx
	inx
	inx
	inx
	bne clear_oam

  WAIT_VBLANK
  
  jmp main
.endproc