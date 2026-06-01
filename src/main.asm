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
; timer - counts from 30-0 in NMI. General purpose use for triggering events
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

; --------------------------------------------------
; This is the PPU clean up section, so rendering the next frame starts properly.
; enable NMI, sprites from Pattern Table 0, background from Pattern Table 1
; enable sprites, enable background, no clipping on left side
; --------------------------------------------------
  lda #%10010000
  sta PPUCTRL
  lda #%00011110
  sta PPUMASK

; --------------------------------------------------
; Loop
; --------------------------------------------------
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

mainloop:

; --------------------------------------------------
; Timer counts down during NMI if it is >30
; When timer=0 reset timer to 30
; --------------------------------------------------
  lda timer
  bne still_counting
  dec enemy_spawn_wait
  lda #30
  sta timer
still_counting:

; --------------------------------------------------
; Spawing enemies
; Begin spawn procedure when enemy_spawn_wait=0
; enemy_spawn_script needs to be multiplied by two as it works with spawn_enemy_qty_wait_table which is structured in bytes of 2
; set x to the number of enemies to spawn
; set enemy_spawn_wait to the time desired to wait for next spawn
; --------------------------------------------------
  lda enemy_spawn_wait
  bne dont_spawn

  inc enemy_spawn_script
  lda enemy_spawn_script
  asl a
  tay
  lda spawn_enemy_qty_wait_table, y
  tax

  iny
  lda spawn_enemy_qty_wait_table, y
  sta enemy_spawn_wait

spawn:
  jsr SpawnEnemy
  dex
  cpx #$00
  bne spawn

dont_spawn:

; --------------------------------------------------
; process enemies
; --------------------------------------------------
  jsr ProcessEnemeies

done:

; --------------------------------------------------
; Game loop
; --------------------------------------------------
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
; --------------------------------------------------
; Palettes - background, sprites
; --------------------------------------------------
palettes:
  .byte $0f,$00,$10,$30
  .byte $0f,$01,$21,$31
  .byte $0f,$06,$16,$26
  .byte $0f,$09,$19,$29

  .byte $0f,$00,$10,$30
  .byte $0f,$01,$21,$31
  .byte $0f,$06,$16,$26
  .byte $0f,$09,$19,$29
