# RISC-V Trace+Timer Test - Exact Output Format Requested
.section .text
.global _start
.equ TIMER,     0x40004000
.equ TIMER_CMP, 0x40004008
.equ TRACE,     0x40000000

.section .bss
.align 12
stack_bottom: .space 4096
stack_top:
ticks: .space 4
start_trace: .space 4
end_trace: .space 4

.section .text

_start:
    la sp, stack_top
    
    # Print config info FIRST
    la a0, msg_config
    jal print_str
    
    # Config: Print timer base addresses
    # TIMER: 0x40004000, CMP: 0x40004008, IRQ: MTIE=0x888
    li t0, 0x40004000    # TIMER base
    mv a0, t0
    jal print_hex32
    
    la a0, msg_comma
    jal print_str
    
    li t0, 0x40004008    # CMP base  
    mv a0, t0
    jal print_hex32
    
    la a0, msg_config_end
    jal print_str

    # Record trace start time
    la t0, TIMER
    lw t1, 0(t0)
    la t2, start_trace
    sw t1, 0(t2)

    # Print "Trace: Hello world!"
    la a0, msg_hello
    jal print_str

    # Record trace end time  
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
    jal print_decimal

    la a0, msg_ns
    jal print_str

    # Clean halt
    li t0, 100000
flush:
    addi t0, t0, -1
    bnez t0, flush
halt: 
    j halt

print_str:
    mv t0, a0
print_char:
    lb t1, 0(t0)
    beqz t1, print_ret
    li t2, TRACE
    sw t1, 0(t2)
    addi t0, t0, 1
    j print_char
print_ret:
    ret

# Print 32-bit decimal (0-9999999)
print_decimal:
    addi sp, sp, -16
    sw ra, 12(sp)
    sw s0, 8(sp)
    mv s0, a0
    
    li t0, 1000000
    blt s0, t0, dec_skip1M
    li a0, 1
    li t1, TRACE
    addi a0, a0, 0x30
    sw a0, 0(t1)
    li t0, 1000000
dec_skip1M:
    # 100k, 10k, 1k, 100, 10, 1...
    li t1, TRACE
    li t2, 10
dec_loop:
    blt s0, t2, dec_final
    remu t3, s0, t2
    divu s0, s0, t2
    addi t3, t3, 0x30
    sb t3, 0(t1)
    j dec_loop
dec_final:
    addi s0, s0, 0x30
    sw s0, 0(t1)
    
    lw ra, 12(sp)
    lw s0, 8(sp)
    addi sp, sp, 16
    ret

print_hex32:
    addi sp, sp, -16
    sw ra, 12(sp)
    sw s0, 8(sp)
    mv s0, a0
    
    li t0, 8             # 8 hex digits
hex_loop:
    srli t1, s0, 28      # Top nibble
    andi t1, t1, 0xF
    addi t1, t1, 0x30
    li t2, 0x39
    bgt t1, t2, hex_abc
    j hex_print
hex_abc:
    addi t1, t1, 7       # A-F
hex_print:
    li t2, TRACE
    sw t1, 0(t2)
    slli s0, s0, 4
    addi t0, t0, -1
    bnez t0, hex_loop
    
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
