.section .text
.globl _start

_start:
    # Edge Case: JAL writes to rd, and the next instruction uses it immediately
    jal x5, target    # x5 = PC + 4 (return address)
    addi x6, x5, 4    # x6 = x5 + 4 (depends on JAL result immediately)

    # Expected:
    # x5 should hold _start + 4 (the return address)
    # x6 should be (_start + 4) + 4 = _start + 8

    # Halt
    addi x1, x0,0xbb
    # slti x0, x0, -256 
    nop

target:
    # This is just a label for JAL to jump to
    slti x0, x0, -256 
    nop
    nop
    nop
    nop
    nop