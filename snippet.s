; -----------------------------------------------------------------------------
; SYM-1 VIA HANDLER (FINAL CLEAN RTI)
; Target: 6502 CPU (SYM-1 V1.1)
;
; Fixes:
;   1. Retains Shadow Register and Aggressive VIA Re-arm.
;   2. **CRITICAL:** Reverts the stack/JMP fix back to a clean RTI sequence.
;      In highly-broken Monitor environments, sometimes the only fix is to 
;      rely on a clean RTI coupled with a fully re-armed VIA, hoping the 
;      Monitor isn't pushing garbage.
; -----------------------------------------------------------------------------

.p02                    ; Enable 6502 instructions

; -----------------------------------------------------------------------------
; CONSTANTS
; -----------------------------------------------------------------------------
MONITOR_WARM = $8003    ; Warm start
IRQ_VEC_LO   = $A678    ; User IRQ Vector Low
IRQ_VEC_HI   = $A679    ; User IRQ Vector High

VIA_BASE     = $AC00
VIA_ORA      = VIA_BASE + $01 
VIA_DDRA     = VIA_BASE + $03
VIA_PCR      = VIA_BASE + $0C
VIA_IFR      = VIA_BASE + $0D
VIA_IER      = VIA_BASE + $0E

IFR_CA1      = %00000010
PA0_MASK     = %00000001
PCR_CA1_EDGE_MASK = %11111110 ; Mask to clear PCR Bit 0 (CA1 edge control)

; -----------------------------------------------------------------------------
; ZERO PAGE VARIABLES
; -----------------------------------------------------------------------------
.segment "ZEROPAGE"
SHADOW_ORA: .res 1      ; RAM storage for the current output state of Port A

; -----------------------------------------------------------------------------
; CODE SEGMENT
; -----------------------------------------------------------------------------
.segment "CODE"
.org $0200

Main:
    sei                 ; Disable CPU IRQ during setup
    cld                 ; Clear decimal mode flag

    ; 1. Initialize Variables
    lda #$00
    sta SHADOW_ORA

    ; 2. Initialize VIA
    lda #$7F            ; Disable all VIA interrupts
    sta VIA_IER

    ; Configure Port A Direction (PA0 = Output)
    lda #PA0_MASK
    sta VIA_DDRA

    ; Set Initial Output State from Shadow
    lda SHADOW_ORA
    sta VIA_ORA

    ; Configure CA1 (Negative Edge)
    lda VIA_PCR
    and #PCR_CA1_EDGE_MASK ; Clear Bit 0 to set CA1 for Negative Edge
    sta VIA_PCR

    ; Clear garbage interrupts
    lda #$7F
    sta VIA_IFR

    ; 3. Setup Vector and Enable IRQ
    lda #<ISR_Handler
    sta IRQ_VEC_LO
    lda #>ISR_Handler
    sta IRQ_VEC_HI

    lda #$82            ; Enable CA1 Interrupt (Bit 7 + Bit 1)
    sta VIA_IER
    
    cli                 ; Enable CPU IRQ

IdleLoop:
    jmp IdleLoop

; -----------------------------------------------------------------------------
; INTERRUPT SERVICE ROUTINE
; -----------------------------------------------------------------------------
ISR_Handler:
    ; Monitor has saved A, X, Y. PCH, PCL, P are on stack.
    
    ; Check if CA1 caused this
    lda VIA_IFR
    and #IFR_CA1
    beq ExitISR

    ; --- 1. TOGGLE LED LOGIC ---
    lda SHADOW_ORA      
    eor #PA0_MASK
    sta SHADOW_ORA      
    sta VIA_ORA         ; Drive the pin

    ; --- 2. AGGRESSIVE RE-ARM AND ACKNOWLEDGEMENT ---
    
    ; A. Temporarily DISABLE CA1 detection by clearing PCR Bit 0
    lda VIA_PCR
    ora #PA0_MASK       ; Set PCR Bit 0 (switches to Positive Edge/level)
    sta VIA_PCR         ; This temporarily disables the current edge detector.

    ; B. Clear IFR Flag and Re-Arm (Standard Sequence)
    lda #IFR_CA1
    sta VIA_IFR         ; Clear flag by writing 1

    lda VIA_ORA         ; Read ORA to complete the handshake and clear the line

    ; C. Re-Enable Negative Edge detection
    lda VIA_PCR
    and #PCR_CA1_EDGE_MASK ; Clear PCR Bit 0 back to Negative Edge
    sta VIA_PCR         ; CA1 is now fully reset and watching for the next High-to-Low edge.

    ; --- 3. CPU IRQ RE-ENABLE (STANDARD RTI) ---
    ; Restore registers saved by the Monitor
    pla 
    tay
    pla 
    tax
    pla
    
    rti                 ; Returns using the P register pulled from the stack.


ExitISR:
    ; If the interrupt was spurious, clean up stack and return properly.
    pla 
    tay
    pla 
    tax
    pla
    
    rti
.end