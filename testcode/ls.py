import random

# Define register names (excluding x0 since it's hardwired to 0 in RISC-V)
REGISTERS = [f"x{i}" for i in range(1, 32)]

# Define address range (32-bit aligned)
ADDRESS_RANGE = (0xAAAAA000, 0xFFFFFFFF)

# Define valid store instructions and their compatible loads
STORE_INSTRUCTIONS = ["SW", "SH", "SB"]
VALID_LOADS = {
    "SW": ["LW", "LH", "LB", "LHU", "LBU"],  # Full word allows any load
    "SH": ["LH", "LHU", "LB", "LBU"],  # Halfword allows smaller loads
    "SB": ["LB", "LBU"],  # Byte store allows only byte loads
}

# Define instruction formats
LOAD_FORMAT = {
    "LW": "lw {rd}, {offset}({rs1})  # Load word",
    "LH": "lh {rd}, {offset}({rs1})  # Load halfword",
    "LB": "lb {rd}, {offset}({rs1})  # Load byte",
    "LHU": "lhu {rd}, {offset}({rs1})  # Load halfword unsigned",
    "LBU": "lbu {rd}, {offset}({rs1})  # Load byte unsigned",
}

STORE_FORMAT = {
    "SW": "sw {rs2}, {offset}({rs1})  # Store word",
    "SH": "sh {rs2}, {offset}({rs1})  # Store halfword",
    "SB": "sb {rs2}, {offset}({rs1})  # Store byte",
}

def generate_aligned_address(instr_type):
    """Generates a 32-bit aligned address within the allowed range based on instruction type."""
    base_address = random.randint(ADDRESS_RANGE[0] >> 12, ADDRESS_RANGE[1] >> 12)  # Get upper 20 bits
    
    if instr_type == "SW":  # Word-aligned
        offset = (random.randint(-2048, 2047) & ~0x3)  # Ensure 4-byte alignment
    elif instr_type == "SH":  # Halfword-aligned
        offset = (random.randint(-2048, 2047) & ~0x1)  # Ensure 2-byte alignment
    else:  # Byte-aligned (SB)
        offset = random.randint(-2048, 2047)

    return base_address, offset

def generate_lui_addi(register, base_address, offset):
    """Generates LUI + ADDI for setting a 32-bit aligned address."""
    return [
        f"lui {register}, {base_address}",  # Load upper 20 bits
        # "nop", "nop", "nop", "nop", "nop",
        f"addi {register}, {register}, {offset}  # Add lower 12-bit aligned offset"
    ]

def generate_store_load_pair():
    """Generates a LUI + ADDI sequence followed by a store and a compatible load at the same address."""
    rd = random.choice(REGISTERS)  # Destination register for the load
    rs1 = random.choice([r for r in REGISTERS if r != rd])  # Base register for the address
    rs2 = random.choice([r for r in REGISTERS if r not in {rd, rs1}])  # Data register for store

    # Step 1: Choose a store instruction
    store_instr = random.choice(STORE_INSTRUCTIONS)

    # Step 2: Choose a compatible load instruction
    load_instr = random.choice(VALID_LOADS[store_instr])  # Ensure valid load-store pair

    # Step 3: Generate aligned address based on store instruction
    base_address, offset = generate_aligned_address(store_instr)

    instructions = []
    
    # Step 4: Generate LUI + ADDI for address calculation
    instructions.extend(generate_lui_addi(rs1, base_address, offset))
    # instructions.extend(["addi x0, x0, 0"] * 5)  # 5 NOPs

    # Step 5: Initialize `rs2` with a value before storing
    imm_value = random.randint(-2048, 2047)& ~0x3  # Random immediate value
    instructions.append(f"addi {rs2}, x0, {imm_value}  # Load immediate value into rs2")
    # instructions.extend(["addi x0, x0, 0"] * 5)  # 5 NOPs

    # Step 6: Store a value from rs2 into the computed address
    store_inst = STORE_FORMAT[store_instr].format(rs2=rs2, rs1=rs1, offset=offset)
    instructions.append(store_inst)

    # Step 7: Add 5 NOPs
    # instructions.extend(["addi x0, x0, 0"] * 5)

    # Step 8: Load the value from the same address into rd
    load_inst = LOAD_FORMAT[load_instr].format(rd=rd, rs1=rs1, offset=offset)
    instructions.append(load_inst)

    # Step 9: Add 5 more NOPs
    # instructions.extend(["addi x0, x0, 0"] * 5)

    return instructions

def generate_riscv_program(num_instructions=20):
    """Generates a RISC-V program with aligned loads and stores."""
    with open("riscv_load_store.s", "w") as f:
        for _ in range(num_instructions):
            instructions = generate_store_load_pair()
            f.write("\n".join(instructions) + "\n")
        f.write("slti x0, x0, -256\n")
        for _ in range(5):
            f.write("nop\n")
        print(f"Generated {num_instructions} store-load pairs in 'riscv_load_store.s'.")

if __name__ == "__main__":
    generate_riscv_program(2000)