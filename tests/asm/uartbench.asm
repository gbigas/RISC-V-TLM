# RISC-V UART+Timer Test - EXACT Same Output Format but UART instead of Trace
.section .text
.global _start
.equ UART_BASE, 0x50000000   # UART base (RISC-V-TLM standard)
.equ UART_DR,   0x00         # Data Register offset  
.equ TIMER,     0x40004000
.equ TIMER_CMP, 0x40004008
.equ TRACE,     0x40000000   # UNUSED - UART only

.section .bss
.align 12
stack_bottom: .space 4096
stack_top:
start_trace: .space 4
end_trace: .space 4

.section .text

_start:
    la sp, stack_top
    
    # Print config info FIRST (UART)
    la a0, msg_config
    jal uart_print_str
    
    # Config: Print timer base addresses
    li t0, 0x40004000    # TIMER base
    mv a0, t0
    jal uart_print_hex32
    
    la a0, msg_comma
    jal uart_print_str
    
    li t0, 0x40004008    # CMP base  
    mv a0, t0
    jal uart_print_hex32
    
    la a0, msg_config_end
    jal uart_print_str

    # Record UART print start time
    la t0, TIMER
    lw t1, 0(t0)
    la t2, start_trace
    sw t1, 0(t2)

    # Print "Trace: Hello world!" to UART
    la a0, msg_hello
    jal uart_print_str

    # Record UART print end time  
    la t0, TIMER
    lw t1, 0(t0)
    la t2, end_trace
    sw t1, 0(t2)

    # Calculate & print timing
    la t0, end_trace
    lw t1, 0(t0)
    la t0, start_trace
    lw t2, 0(t0)
    sub a0, t1, t2       # delta_ns
    jal uart_print_decimal

    la a0, msg_ns
    jal uart_print_str

    # Clean halt
    li t0, 100000
flush:
    addi t0, t0, -1
    bnez t0, flush
halt: 
    j halt

# UART Print String (replaces print_str)
uart_print_str:
    mv t0, a0
uart_char_loop:
    lb t1, 0(t0)
    beqz t1, uart_ret
    li t2, UART_BASE + UART_DR
    sw t1, 0(t2)         # UART_DR write sends char
    addi t0, t0, 1
    j uart_char_loop
uart_ret:
    ret

# UART Print 32-bit decimal (replaces print_decimal)
uart_print_decimal:
    addi sp, sp, -16
    sw ra, 12(sp)
    sw s0, 8(sp)
    mv s0, a0
    
    li t0, 1000000
    blt s0, t0, dec_skip1M
    li t1, 1
    li t2, UART_BASE + UART_DR
    addi t1, t1, 0x30
    sw t1, 0(t2)
    li t0, 1000000
dec_skip1M:
    
    li t2, UART_BASE + UART_DR
    li t3, 10
dec_loop:
    blt s0, t3, dec_final
    remu t1, s0, t3
    divu s0, s0, t3
    addi t1, t1, 0x30
    sw t1, 0(t2)
    j dec_loop
dec_final:
    addi s0, s0, 0x30
    sw s0, 0(t2)
    
    lw ra, 12(sp)
    lw s0, 8(sp)
    addi sp, sp, 16
    ret

# UART Print 32-bit hex (replaces print_hex32)
uart_print_hex32:
    addi sp, sp, -16
    sw ra, 12(sp)
    sw s0, 8(sp)
    mv s0, a0
    
    li t0, 8             # 8 hex digits
uart_hex_loop:
    srli t1, s0, 28      # Top nibble
    andi t1, t1, 0xF
    addi t1, t1, 0x30
    li t3, 0x39
    bgt t1, t3, uart_hex_abc
    j uart_hex_print
uart_hex_abc:
    addi t1, t1, 7       # A-F
uart_hex_print:
    li t3, UART_BASE + UART_DR
    sw t1, 0(t3)
    slli s0, s0, 4
    addi t0, t0, -1
    bnez t0, uart_hex_loop
    
    lw ra, 12(sp)
    lw s0, 8(sp)
    addi sp, sp, 16
    ret

.section .rodata
msg_config:      .ascii "config info for timer: 0x\0"
msg_comma:       .ascii ", 0x\0"
msg_config_end:  .ascii " MTIE=0x888\n\0"
msg_hello:       .ascii "Hello world!\n\0"
msg_ns:          .ascii " ns\n\0"
