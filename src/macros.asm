.macro WAIT_VBLANK
@loop:
  bit PPUSTATUS
  bpl @loop
.endmacro

.macro SAVE_REGISTERS
  php
  pha
  txa
  pha
  tya
  pha
.endmacro

.macro RESTORE_REGISTERS
  pla
  tay
  pla
  tax
  pla
  plp
.endmacro