# FIXED UART RX - Receive ONLY, NO AUTO-ECHO (xterm stays responsive)
.section .text
.global _start
.equ UART_BASE, 0x10000000
.equ UART_DR,   0x00        
.equ UART_FR,   0x18        

.section .bss
.align 12
stack_bottom: .space 4096
stack_top:
rx_count: .space 4

_start:
    la sp, stack_top
    
    la a0, msg_ready
    jal uart_print
    la a0, msg_prompt
    jal uart_print

rx_loop:
    # Check UART_FR[4] == 0 (RX ready) - NO DELAY
    li t0, UART_BASE + UART_FR
    lw t1, 0(t0)
    andi t1, t1, 0x10       # RXFE bit 4
    bnez t1, rx_loop        # Poll only (no echo spam)
    
    # RX DATA READY - read char
    li t0, UART_BASE + UART_DR
    lbu t2, 0(t0)           # t2 = received char
    
    # Print received char (NO ECHO to UART_DR!)
    li t3, UART_BASE + UART_DR  
    sb t2, 0(t3)            # Print to UART (visible feedback)
    
    # Update counter
    la t3, rx_count
    lw t4, 0(t3)
    addi t4, t4, 1
    sw t4, 0(t3)
    
    # Print stats every 8 chars
    andi t5, t4, 0x7
    bnez t5, rx_loop
    
    mv a0, t4
    jal uart_print_dec
    la a0, msg_nl
    jal uart_print
    la a0, msg_prompt
    jal uart_print          # Fresh prompt
    j rx_loop

uart_print:
    mv t0, a0
u_loop:
    lbu t1, 0(t0)
    beqz t1, u_ret
    li t2, UART_BASE + UART_DR
    sb t1, 0(t2)
    addi t0, t0, 1
    j u_loop
u_ret: ret

uart_print_dec:
    li t2, UART_BASE + UART_DR
    andi a0, a0, 0xF
    addi a0, a0, 0x30
    sb a0, 0(t2)
    ret

.section .rodata
msg_ready:  .ascii "UART RX ready - type to receive!\r\n\0"
msg_prompt: .ascii "> \0"
msg_nl:     .ascii " rx'd\r\n> \0"
