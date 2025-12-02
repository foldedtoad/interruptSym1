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
;   Port A Pin 0 (PA0): Connect to LED (Active High).
;   CA1 (Control):      Connect to Interrupt Source (Switch/Pulse).
;                       (Note: PA1 cannot generate interrupts directly; 
;                        signal must go to CA1).
; -----------------------------------------------------------------------------

.p02                    ; Enable 6502 instructions

.include "sym1.inc"
.include "sym1_ext.inc"
.include "zp_memory.inc"

; -----------------------------------------------------------------------------
; MEMORY LAYOUT & CONSTANTS
; -----------------------------------------------------------------------------

; SYM-1 Monitor Entry Points
MONITOR_WARM = $8003    ; Warm start entry point to return to monitor

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

PA0_MASK_SET = %00000001      ; Mask for Port A Pin 0 (set)
PA0_MASK_CLR = %11111110      ; Mask for Port A Pin 0 (clear)

; -----------------------------------------------------------------------------
;  DATA SEGMENT
; -----------------------------------------------------------------------------
.segment "DATA"

delay_count:
    .byte 0

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
    ; Bit 0 = 1 (Output) -> PA0 is LED
    ; Bit 1-7 = 0 (Input)
    lda #PA0_MASK_SET
    sta VIA_DDRA        

    ; Turn off LED
    lda #PA0_MASK_CLR
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

.if 1
    ldx #<msg_pcr
    ldy #>msg_pcr
    jsr print_msg
    lda VIA_PCR
    jsr OBCRLF 
.endif

    ; 2. Setup Interrupt System
    ; -------------------------
    
    ; Disable write protection using monitor routine
    jsr Clear_Write_Protect  

    ; Point the SYM-1 User IRQ Vector to our ISR
    lda #<ISR_Handler
    sta IRQ_VEC_LO
    lda #>ISR_Handler
    sta IRQ_VEC_HI

    ; Enable Interrupts on VIA
    lda #(IER_ENABLE + IER_CA1_ENA)
    sta VIA_IER

    ; Enable CPU Interrupts
    cli

    ; 3. Main Idle Loop
    ; -----------------
    ; The CPU is free to do other work here.   

.if 1
    ldx #<msg_vector
    ldy #>msg_vector
    jsr print_msg
    lda IRQ_VEC_HI
    jsr OUTBYT
    lda IRQ_VEC_LO
    jsr OBCRLF

    ldx #<msg_ier
    ldy #>msg_ier
    jsr print_msg
    lda VIA_IER
    jsr OBCRLF
.endif

.if 0
IdleLoop:

.if 0
    jsr Pseudo_IRQ
.endif

    jmp IdleLoop        ; Infinite loop doing nothing
.else
    jmp MONITOR_WARM
.endif

; -----------------------------------------------------------------------------
; INTERRUPT SERVICE ROUTINE (ISR)
; -----------------------------------------------------------------------------
ISR_Handler:
    ; Note: The SYM-1 Monitor ROM handler at $FFFE saves the registers
    ; (A, X, Y) onto the stack before jumping here via ($A678).
    ; Stack State: [PCH, PCL, P, A, X, Y] (Top)

    ; Clear Decimal Flag (Good practice in ISRs)
    cld                 

    ; Check if this interrupt came from our VIA CA1
    lda VIA_IFR
    and #IFR_CA1
    beq ExitISR         ; If not CA1, ignore (or jump to next handler)

    ; Explicitly clear the CA1 Interrupt Flag by writing a '1' to its bit in IFR.
    ; This guarantees the interrupt is acknowledged.
    lda #IFR_CA1        ; Load mask %00000010
    sta VIA_IFR         ; Writing 1 clears the bit   

.if 0
    ldx #<msg_ifr
    ldy #>msg_ifr
    jsr print_msg
    lda VIA_IFR
    jsr OBCRLF

    ldx #<msg_ier
    ldy #>msg_ier
    jsr print_msg
    lda VIA_IER
    jsr OBCRLF
.endif

    ; Handle Data & Toggle LED
    jsr Toggle_LED

ExitISR:
    ; Restore registers saved by Monitor ROM
    ; Order must be reverse of save: Pull Y, then X, then A.
    pla 
    tay
    pla 
    tax
    pla

    ; Return from Interrupt
    rti

; -----------------------------------------------------------------------------
; Toggle LED
; -----------------------------------------------------------------------------
Toggle_LED:
    lda VIA_ORA         
    eor #PA0_MASK_SET    ; XOR with %00000001 to flip Bit 0
    sta VIA_ORA
    rts

; -----------------------------------------------------------------------------
; 
; -----------------------------------------------------------------------------
Delay:
    ldx #255
@delay:
    dex
    bne @delay
    rts

; -----------------------------------------------------------------------------
; 
; -----------------------------------------------------------------------------
Pseudo_IRQ:
    lda #255
    sta delay_count
@delay2:
    jsr Delay
    dec delay_count
    bne @delay2

    ldx #<msg_pseudo
    ldy #>msg_pseudo
    jsr print_msg

;    lda #1     ; Generate IRQ
    jsr USRENT ; Do it.
    rts

; -----------------------------------------------------------------------------
; 
; -----------------------------------------------------------------------------
Blink:
    lda #255
    sta delay_count
@delay:
    dec delay_count
    bne @delay
    jsr Toggle_LED
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
msg_pcr:
        .byte "PCR: ", 0
msg_ifr:
        .byte "IFR: ", 0
msg_ier:
        .byte "IER: ", 0
msg_vector:
        .byte "Vector: ", 0 
msg_pseudo:
        .byte "Pseudo_IRQ", 13,10,0
msg_ok:
        .byte "OK", 13, 10, 0
msg_fail:
        .byte "FAILED ", 0

.end                    ; End of assembly
