.section .init

_start:
    nop                        
    li x1, 0                   
    li x2, 0
    li x3, 0
    li x4, 0
    li x5, 0
    li x6, 0
    li x7, 0
    li x8, 0
    li x9, 0
    li x10, 0
    li x11, 0
    li x12, 0
    li x13, 0
    li x14, 0
    li x15, 0
    li x16, 0
    li x17, 0
    li x18, 0
    li x19, 0
    li x20, 0
    li x21, 0
    li x22, 0
    li x23, 0
    li x24, 0
    li x25, 0
    li x26, 0
    li x27, 0
    li x28, 0
    li x29, 0
    li x30, 0
    li x31, 0

_initbss:
    auipc x6, 0x7               # x6 = address of static_memblk
    addi  x6, x6, -128
    auipc x7, 0x7               # x7 = address of _bss_vma_end
    addi  x7, x7, 1876
    beq x6, x7, _setup          # if x6 == x7, skip loop

_initbss_loop:
    sw x0, 0(x6)                # *x6 = 0
    addi x6, x6, 4              # x6 += 4
    bltu x6, x7, _initbss_loop  # loop if x6 < x7

_setup:
    auipc x2, 0xd1315           # x2 = stack base
    addi  x2, x2, -160
    add  x8, x2, x0             # x8 = x2
    la   x1, main               # load address of `main` into x1
    jalr x1                     # jump to main

_fini:
    beqz x0, _fini              # infinite loop (halt)
    nop                         # padding with NOPs
    nop
  
    nop
main:
slti x0, x0, -256
