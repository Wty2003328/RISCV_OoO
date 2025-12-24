.section .data
.align 6               # ensure enough spacing for cache set alignment
base0: .word 0
base1: .word 0
base2: .word 0
base3: .word 0
evict: .word 0         # spot where we will force an eviction to write back

.section .text
.globl _start
_start:
    # Assume cache index bits are controlled by bits [5:2] (if 32B line size)
    # We'll use addresses with same index, but different tag bits

    # Load base addresses (you may adjust offset for specific set targeting)
    la t0, base0        # line 1 (way 0)
    la t1, base1        # line 2 (way 1)
    la t2, base2        # line 3 (way 2)
    la t3, base3        # line 4 (way 3)
    
    li t4, 0xAAAABBBB   # data to write
    sw t4, 0(t0)        # write to cache line 1
    sw t4, 0(t1)        # write to cache line 2
    sw t4, 0(t2)        # write to cache line 3
    sw t4, 0(t3)        # write to cache line 4 (all 4 ways of set filled)

    # All 4 ways of a set are now dirty in cache

    # Access a new address that maps to same index, different tag (e.g., higher base)
    # Should cause LRU or replacement policy to evict one of above (write-back if dirty)
    la t5, evict
    li t6, 0xDEADBEEF
    sw t6, 0(t5)        # should trigger eviction/writeback of one of previous

    # Now load from original base to verify write-back occurred
    # (in actual testbench, check base0–base3 memory values externally)
    li a0, 0xA
    li a1, 0xB
    li a2, 0xC
    li a3, 0xD
    lw a0, 0(t0)
    lw a1, 0(t1)
    lw a2, 0(t2)
    lw a3, 0(t3)

    # Loop to observe registers or memory state
hang:
    # j hang


    slti x0, x0, -  256        # trap / stop
