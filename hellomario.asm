; define a header, not needed for NES, but an emulator
.segment "HEADER"
.byte "NES"
.byte $1a ; 
.byte $02 ; 2 * 16KB PRG ROM
.byte $01 ; 1 * 8KB CHR ROM
.byte %00000001 ; mapper and mirroring
.byte $00
.byte $00
.byte $00
.byte $00
.byte $00, $00, $00, $00, $00 ; filler bytes

; Reset memory?
.segment "ZEROPAGE" ; LSB 0 - FF
world: .res 2

; Where the code starts, purly organizational. Also to intialize the memory for use
.segment "STARTUP"
Reset:
    SEI ; disable all interupts
    CLD ; disable decimel mode, 6502 on NES does not support it

    ; disable sound IRQ so random sounds don't play on startup
    LDX #$40
    STX $4017

    ; initialize the stack register
    LDX #$FF
    TXS

    INX ; #$FF + 1 => 0 beacuse the byte rolls back to #$00

    ; zero out PPU registers
    STX $2000
    STX $2001

    STX $4010 ; disable other sound

:
    BIT $2002
    BPL :- ; if branch, branch back to previous annonymous label, don't use often

    TXA

CLEARMEM:
    STA $0000, X ; $0000 => $00FF aka 0 -> 255. each one is 256 bytes
    STA $0100, X ; $0100 => $01FF
    STA $0300, X ; $0300 => $03FF
    STA $0400, X ; $0400 => $04FF
    STA $0500, X ; $0500 => $05FF
    STA $0600, X ; $0600 => $06FF
    STA $0700, X ; $0700 => $07FF
    LDA #$FF
    STA $0200, X ; this is to store sprites. must refresh every frame due to RAM degrading overtime
    LDA #$00
    INX
    BNE CLEARMEM
; wait for vblank
:
    BIT $2002
    BPL :-

    LDA #$02
    STA $4014
    NOP ; no operation, burns a cycle so PPU has time to intiate memory transfer

    ; $3F00
    LDA #$3F
    STA $2006 ; tells PPU that we starting at this bit and start writing here
    LDA #$00
    STA $2006

    LDX#$00

LoadPalettes:
    LDA PaletteData, X
    STA $2007 ; $3F00, $3F01, $3F02 => $3F1F. loads all 36 colors
    INX
    CPX #$20
    BNE LoadPalettes

    ; Initialize world to point to the world data
    ; low byte to low byte, high byte to high byte
    LDA #<WorldData ; low byte
    STA world
    LDA #>WorldData ; high byte
    STA world+1

    ; setup address in PPU for nametable data
    BIT $2002
    LDA #$20
    STA $2006
    LDA #$00
    STA $2006

    LDX #$00
    LDY #$00
LoadWorld:
    LDA (world), Y
    STA $2007
    INY 
    CPX #$03
    BNE :+
    CPY #$C0
    BEQ DoneLoadingWorld
:
    CPY #$00
    BNE LoadWorld
    INX
    INC world+1
    JMP LoadWorld

DoneLoadingWorld:
    LDX #$00

SetAttributes:
    LDA #$55
    STA $2007
    INX
    CPX #$40
    BNE SetAttributes

    LDX #$00
    LDY #$00

LoadSprites:
    LDA SpriteData, X
    STA $0200, X
    INX 
    CPX #$20
    BNE LoadSprites

 
; Enable Interupts VERY IMPORTANT!!!
    CLI

    LDA #%10010000 ; enable NMI change background to use second char set of tiles ($1000). Tells the PPU to be interupted when a vblank occurs
    STA $2000
    LDA #%00011110 ; turns on drawing for sprites and background for left most 8 pixels
    STA $2001

Loop:
    JMP Loop ;creates an infinite loop

NMI:
    LDA #$02 ; copy sprite data from $0200 to PPU
    STA $4014
    RTI

PaletteData:
  .byte $22,$29,$1A,$0F,$22,$36,$17,$0f,$22,$30,$21,$0f,$22,$27,$17,$0F  ;background palette data
  .byte $22,$16,$27,$18,$22,$1A,$30,$27,$22,$16,$30,$27,$22,$0F,$36,$17  ;sprite palette data

WorldData:
    .incbin "world.bin"

SpriteData:
  .byte $08, $00, $00, $08
  .byte $08, $01, $00, $10
  .byte $10, $02, $00, $08
  .byte $10, $03, $00, $10
  .byte $18, $04, $00, $08
  .byte $18, $05, $00, $10
  .byte $20, $06, $00, $08
  .byte $20, $07, $00, $10

; Vectors for opporation
.segment "VECTORS"
    .word NMI
    .word Reset ; what happens when you hit reset button
    ; 

; tells ca65 where to find the character files
.segment "CHARS"
    .incbin "hellomario.chr"