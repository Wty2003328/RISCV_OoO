    .section .text
    .globl _start
_start:
    li   x1, 0          # counter i = 0
    li   x2, 8          # loop limit

loop:
    addi x1, x1, 1      # i++

    # --- Branch pattern: first 4 times taken, next 4 times not taken ---
    # Compute i mod 8 in x3
    li   x4, 8
    rem  x3, x1, x4

    # if (i mod 8) < 4  → branch taken; else fall‑through
    li   x5, 4
    blt  x3, x5, Taken

NotTaken:
    # mispredict path: we expect fall‑through here
    # (you can poke a write to a magic peripheral or set a marker reg)
    li   x10, 0xDEAD   # marker for not‑taken
    j    Continue

Taken:
    # correct taken path
    li   x10, 0xBEEF   # marker for taken
    j    Continue

Continue:
    # when i == 16, exit
    li   x6, 16
    beq  x1, x6, Exit

    j    loop

Exit:
    # Write to an exit CSR and spin
    li   x7, 1
    slti x0, x0, -256
