; -----------------------------------------------------------------------------
; SYM-1 VIA RESPONSE PROGRAM (UPDATED)
; Target: 6502 CPU (SYM-1 V1.1 Single Board Computer)
; Assembler: ca65 / ld65
;
; Description:
;   This program initializes a 6522 VIA located at $AC00.
;   It uses an interrupt-driven approach to toggle an LED.
;
; Hardware Hookup:
;   VIA Base: $AC00
;   Port A Pin 6 (PA6): Connect to LED (Active High).
;   CA1 (Control):      Connect to Interrupt Source (Switch/Pulse).
; -----------------------------------------------------------------------------

.p02                    ; Enable 6502 instructions

.include "sym1.inc"
.include "sym1_ext.inc"
.include "zp_memory.inc"

; -----------------------------------------------------------------------------
; MEMORY LAYOUT & CONSTANTS
; -----------------------------------------------------------------------------

; SYM-1 Interrupt Vectors (RAM)
IRQ_VEC_LO   = $A678    ; User IRQ Vector Low Byte
IRQ_VEC_HI   = $A679    ; User IRQ Vector High Byte

; VIA Base Address
VIA_BASE     = $AC00

; VIA Register Offsets
VIA_ORB      = VIA_BASE + $00 ; Output Register B
VIA_ORA      = VIA_BASE + $01 ; Output Register A (with handshake)
VIA_DDRB     = VIA_BASE + $02 ; Data Direction Register B
VIA_DDRA     = VIA_BASE + $03 ; Data Direction Register A
VIA_PCR      = VIA_BASE + $0C ; Peripheral Control Register
VIA_IFR      = VIA_BASE + $0D ; Interrupt Flag Register
VIA_IER      = VIA_BASE + $0E ; Interrupt Enable Register

PA6_MASK_SET = %01000000      ; Mask for Port A Pin 6 (set)
PA6_MASK_CLR = %10111111      ; Mask for Port A Pin 6 (clear)

; -----------------------------------------------------------------------------
; CODE SEGMENT
; -----------------------------------------------------------------------------
.segment "CODE"
.org $0200              ; Standard user RAM start on SYM-1

Main:

    ; Print banner
    ldx #<msg_banner
    ldy #>msg_banner
    jsr print_msg

    ; 1. Initialize the VIA
    ; ---------------------
    
    ; Disable VIA Interrupts initially to configure safely
    lda #IER_DISABLE
    sta VIA_IER

    ; Configure Port A Direction
    ; PA6 is LED, all bits set to Input
    lda #PA6_MASK_SET
    sta VIA_DDRA        

    ; Turn off LED
    lda #PA6_MASK_CLR
    sta VIA_ORA

    ; Configure Port B (Not used, set to all Inputs for safety)
    lda #$00
    sta VIA_DDRB

    ; Initialize Output State (Turn LED OFF initially)
    lda #$00
    sta VIA_ORA

    ; Configure Peripheral Control Register (PCR)  
    lda VIA_PCR
    ora #PCR_CA1_NAE   ; Negative Active Edge for CA1

    sta VIA_PCR

    ; 2. Setup Interrupt System
    ; -------------------------
    
    ; Disable write protection using monitor routine
    jsr Clear_Write_Protect  

    ; Point the SYM-1 User IRQ Vector to our ISR
    lda #<ISR_Handler
    sta UIRQVC+0
    lda #>ISR_Handler
    sta UIRQVC+1

    ; Enable Interrupts on VIA
    lda #(IER_ENABLE + IER_CA1_ENA)
    sta VIA_IER

    ; Enable CPU Interrupts
    cli

    ; 3. The CPU is free to do other work here.
    ; ----------------------------------------
  
    jmp WARM    ; SYM-1 Monitor Entry Point

; -----------------------------------------------------------------------------
; INTERRUPT SERVICE ROUTINE (ISR)
; -----------------------------------------------------------------------------
ISR_Handler:
    ; Note: The SYM-1 Monitor ROM handler at $FFFE saves the registers

    ; Clear Decimal Flag (Good practice in ISRs)
    cld  
                  
    ; Check if this interrupt came from our VIA CA1
    lda VIA_IFR
    and #IFR_CA1
    beq ExitISR         ; If not CA1, ignore (or jump to next handler)

    ; Toggle LED
    jsr Toggle_LED

    jsr Debounce 

    lda #IFR_CA1
    sta VIA_IFR         ; Clear Interrupt Flag

ExitISR:
    ; Return from Interrupt
    rti

; -----------------------------------------------------------------------------
; Toggle LED
; -----------------------------------------------------------------------------
Toggle_LED:
    lda VIA_ORA
    eor #PA6_MASK_SET    ; XOR to flip Bit 6
    sta VIA_ORA
    rts

; -----------------------------------------------------------------------------
; Debounce -- introduce a short delay
; -----------------------------------------------------------------------------
Debounce:
    ldy #$00
    ldx #$20
DebounceLoop:
    dey
    bne DebounceLoop
    dex
    bne DebounceLoop
    rts

; -----------------------------------------------------------------------------
; 
; -----------------------------------------------------------------------------
Clear_Write_Protect:
    pha 
    lda OR3A
    ora #$01       ; allow writing to SYSRAM
    sta OR3A
    lda DDR3A
    ora #$01       ; set as output direction
    sta DDR3A
    pla
    rts

; -----------------------------------------------------------------------------
; 
; -----------------------------------------------------------------------------
.if 0
Set_Write_Protect:
    pha 
    lda OR3A
    and #$FE       ; disable writing to SYSRAM
    sta OR3A
    lda DDR3A
    ora #$01       ; set as output direction
    sta DDR3A
    pla
    rts
.endif

;-----------------------------------------------------------------------------
; print_msg - Print null-terminated string
; Inputs: X/Y = pointer to string (lo/hi)
;-----------------------------------------------------------------------------
print_msg:
    stx zp_prt_msg_lo
    sty zp_prt_msg_hi
    ldy #$00
@loop:
    lda (zp_prt_msg_lo),y
    beq @done
    jsr OUTCHR
    iny
     bne @loop
@done:
    rts    

;-----------------------------------------------------------------------------
; Messages
;-----------------------------------------------------------------------------
.segment "RODATA"

msg_banner:
        .byte "SYM-1 Interrupts Demo", 13, 10, 0

.end                    ; End of assembly
