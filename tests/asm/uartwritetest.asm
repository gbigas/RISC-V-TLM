    .section ".text.startup"

    # UART base address (change this to match your model)
UART_BASE = 0x50000000
UART_DR   = 0x00
UART_FR   = 0x04
RXFE_BIT  = 4                      # RXFE = 1 when FIFO empty

    .globl _start
_start:
    # Set up stack (if you need it; replace with your linker‑script value)
    li  sp, 0x80000000

    # First print a banner so you see TX working
    #la  a0, banner
    #call print_string

echo_loop:
    # Poll FR for RXFE == 0 (data available)
wait_rx:
    la  t0, UART_BASE        # t0 = UART base
    add t0, t0, UART_FR      # t0 = UART flags addr
    lw  t1, 0(t0)            # t1 = FR
    sll t2, t1, 28          # shift RXFE bit (4) to bit 0
    srl t2, t2, 31          # t2 = 0 if RXFE==1, 1 if RXFE==0
    beqz t2, wait_rx        # if RXFE==1, keep waiting

    # Read DR (RX byte)
    lw  t3, UART_DR(t0)     # t3 = rx_data

    # Echo back immediately (TX)
    #sw  t3, UART_DR(t0)

    j   echo_loop

    # Simple string print subroutine
print_string:
    lb  t0, 0(a0)           # load byte
    beqz t0, print_done     # if '\0', done
    add t1, a0, t0          # dummy use of a0 (you can adjust if needed)
    li  t1, UART_BASE
    add t1, t1, UART_DR
    sw  t0, 0(t1)           # UART putc
    addi a0, a0, 1
    j   print_string
print_done:
    jr  ra                  # return

    .section ".rodata"
banner:
    .string "UART echo test ready. Type in xterm!\r\n"
