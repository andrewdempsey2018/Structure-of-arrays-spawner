.include "constants.inc"
.include "macros.asm"
.include "header.inc"
.include "reset.asm"
.include "controllers.asm"
.include "enemies.asm"

.segment "ZEROPAGE"
sleeping: .res 1
buttons_held: .res 1
buttons_pressed: .res 1

; --------------------------------------------------
; Scratch area
; --------------------------------------------------
scratch_01: .res 1
scratch_02: .res 1
scratch_03: .res 2
scratch_03_lo = scratch_03
scratch_03_hi = scratch_03+1

; --------------------------------------------------
; xxxxxxxxxxx
; --------------------------------------------------
timer: .res 1

.segment "BSS"

.segment "CODE"

.proc irq_handler
  rti
.endproc

.proc nmi_handler
  SAVE_REGISTERS

  lda #$00
  sta OAMADDR
  lda #$02
  sta OAMDMA
  lda #$00

  jsr read_controller

; --------------------------------------------------
; Timer (if it is >0 then count down)
; --------------------------------------------------
  lda timer
  beq timer_zero
  sec
  sbc #1
  sta timer
timer_zero:

  ;This is the PPU clean up section, so rendering the next frame starts properly.
  lda #%10010000   ; enable NMI, sprites from Pattern Table 0, background from Pattern Table 1
  sta PPUCTRL
  lda #%00011110   ; enable sprites, enable background, no clipping on left side
  sta PPUMASK

  ;;
  lda #$00
  sta sleeping

  RESTORE_REGISTERS
  rti
.endproc

.proc clear_oam
  SAVE_REGISTERS

	ldx #$00
	lda #$F8
@clear_oam:
	sta $0200, x ; set sprite y-positions off the screen
	inx
	inx
	inx
	inx
	bne @clear_oam

  RESTORE_REGISTERS
  rts
.endproc

.proc main

vblankwait1:       ; wait for another vblank before continuing
  bit PPUSTATUS
  WAIT_VBLANK

  ldx PPUSTATUS
  ldx #$3f
  stx PPUADDR
  ldx #$00
  stx PPUADDR

load_palettes:
  lda palettes,X
  sta PPUDATA
  inx
  cpx #$20 ; there are 32 colours to load
  bne load_palettes

  lda #%10010000  ; turn on NMIs, sprites use first pattern table
  sta PPUCTRL
  lda #%00011110  ; turn on screen
  sta PPUMASK

  WAIT_VBLANK

  ; ----------------------------------- ;
  ; init enemies

  ldx #$00
InitEnemies:
  lda start_x, x
  sta enemy_x, x
  lda start_y, x
  sta enemy_y, x
  lda start_type, x
  sta enemy_type, x

  lda #%10000000
  sta enemy_flags, x
  inx
  cpx #$05
  bne InitEnemies

  ;;
  ldx #$01
  lda enemy_flags, x
  ora #ENEMY_MOVING_RIGHT
  sta enemy_flags, x

  ldx #$03
  lda enemy_flags, x
  ora #ENEMY_MOVING_LEFT
  sta enemy_flags, x

  ldx #$04
  lda enemy_flags, x
  ora #ENEMY_MOVING_RIGHT
  sta enemy_flags, x
  ;;
  ; ----------------------------------- ;

mainloop:

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  lda timer
  bne not_done
  dec enemy_spawn_wait
  lda #30
  sta timer
not_done:

  lda enemy_spawn_wait
  bne dont_spawn
  jsr SpawnEnemy
dont_spawn:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

  jsr ProcessEnemeies

done:
  ;loop
  inc sleeping
sleep:
  lda sleeping
  bne sleep

  jmp mainloop
.endproc

.segment "VECTORS"
.addr nmi_handler, reset_handler, irq_handler

.segment "CHR"
.incbin "graphics.chr"

.segment "RODATA"

palettes:
  .byte $0f,$00,$10,$30 ; background
  .byte $0f,$01,$21,$31
  .byte $0f,$06,$16,$26
  .byte $0f,$09,$19,$29

  .byte $0f,$00,$10,$30 ; sprite
  .byte $0f,$01,$21,$31
  .byte $0f,$06,$16,$26
  .byte $0f,$09,$19,$29

; temp data
start_type:
  .byte $00,$00,$00,$00,$00
start_x:
  .byte $10,$40,$80,$B0,$E0
start_y:
  .byte $00,$08,$10,$18,$20
