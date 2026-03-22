# uart_test.S - Fixed RISC-V UART Test
.section .text
.global _start

.equ UART_BASE, 0x50000000
.equ UART_DR,   0x00      # Data Register offset
.equ UART_FR,   0x18      # Flag Register offset
.equ UART_CR,   0x30      # Control Register offset

_start:
    # Load UART base into register
    li t0, UART_BASE
    
    # Enable UART (CR = 0x301)
    li t1, 0x301
    sw t1, UART_CR(t0)
    
wait_tx:
    # Poll TX empty: lw t1, UART_FR(t0) & 0x20
    lw t1, UART_FR(t0)
    andi t1, t1, 0x20
    beqz t1, wait_tx
    
    # Send "Hello UART!\n"
    li a0, 'H'
    sw a0, UART_DR(t0)
    
    li a0, 'e'
    sw a0, UART_DR(t0)
    
    li a0, 'l'
    sw a0, UART_DR(t0)
    sw a0, UART_DR(t0)
    
    li a0, 'o'
    sw a0, UART_DR(t0)
    
    li a0, ' '
    sw a0, UART_DR(t0)
    
    li a0, 'U'
    sw a0, UART_DR(t0)
    li a0, 'A'
    sw a0, UART_DR(t0)
    li a0, 'R'
    sw a0, UART_DR(t0)
    li a0, 'T'
    sw a0, UART_DR(t0)
    li a0, '!'
    sw a0, UART_DR(t0)
    li a0, '\n'
    sw a0, UART_DR(t0)

loop:
    j loop          # Infinite loop
