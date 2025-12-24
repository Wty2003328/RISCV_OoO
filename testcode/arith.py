import random

REGISTERS = [f"x{i}" for i in range(1, 5)]

INSTRUCTIONS = {
    "ADDI": lambda rd, rs1: f"addi {rd}, {rs1}, {random.randint(-2048, 2047)}",
    "SLTI": lambda rd, rs1: f"slti {rd}, {rs1}, {random.randint(-2048, 2047)}",
    "SLTIU": lambda rd, rs1: f"sltiu {rd}, {rs1}, {random.randint(-2048, 2047)}",
    "XORI": lambda rd, rs1: f"xori {rd}, {rs1}, {random.randint(-2048, 2047)}",
    "ORI": lambda rd, rs1: f"ori {rd}, {rs1}, {random.randint(-2048, 2047)}",
    "ANDI": lambda rd, rs1: f"andi {rd}, {rs1}, {random.randint(-2048, 2047)}",
    "SLLI": lambda rd, rs1: f"slli {rd}, {rs1}, {random.randint(0, 31)}",
    "SRLI": lambda rd, rs1: f"srli {rd}, {rs1}, {random.randint(0, 31)}",
    "SRAI": lambda rd, rs1: f"srai {rd}, {rs1}, {random.randint(0, 31)}",

    "ADD": lambda rd, rs1, rs2: f"add {rd}, {rs1}, {rs2}",
    "SUB": lambda rd, rs1, rs2: f"sub {rd}, {rs1}, {rs2}",
    "SLL": lambda rd, rs1, rs2: f"sll {rd}, {rs1}, {rs2}",
    "SLT": lambda rd, rs1, rs2: f"slt {rd}, {rs1}, {rs2}",
    "SLTU": lambda rd, rs1, rs2: f"sltu {rd}, {rs1}, {rs2}",
    "XOR": lambda rd, rs1, rs2: f"xor {rd}, {rs1}, {rs2}",
    "SRL": lambda rd, rs1, rs2: f"srl {rd}, {rs1}, {rs2}",
    "SRA": lambda rd, rs1, rs2: f"sra {rd}, {rs1}, {rs2}",
    "OR": lambda rd, rs1, rs2: f"or {rd}, {rs1}, {rs2}",
    "AND": lambda rd, rs1, rs2: f"and {rd}, {rs1}, {rs2}",

    "LUI": lambda rd: f"lui {rd}, {random.randint(0, 0xFFFFF)}",
    "AUIPC": lambda rd: f"auipc {rd}, {random.randint(0, 0xFFFFF)}",

    "MUL" : lambda rd, rs1, rs2: f"mul {rd}, {rs1}, {rs2}",
    "DIV" : lambda rd, rs1, rs2: f"div {rd}, {rs1}, {rs2}",
    "REM" : lambda rd, rs1, rs2: f"rem {rd}, {rs1}, {rs2}"
}


def generate_instruction_init():
    instr_type = random.choice(list(INSTRUCTIONS.keys()))
    rd = random.choice(REGISTERS)

    if instr_type in ["LUI", "AUIPC"]:
        return INSTRUCTIONS[instr_type](rd)
    elif instr_type in ["ADDI", "SLTI", "SLTIU", "XORI", "ORI", "ANDI", "SLLI", "SRLI", "SRAI"]:
        rs1 = random.choice(REGISTERS)
        return INSTRUCTIONS[instr_type](rd, rs1)
    else:  
        return

def generate_instruction():
    instr_type = random.choice(list(INSTRUCTIONS.keys()))
    rd = random.choice(REGISTERS)

    if instr_type in ["LUI", "AUIPC"]:
        return INSTRUCTIONS[instr_type](rd)
    elif instr_type in ["ADDI", "SLTI", "SLTIU", "XORI", "ORI", "ANDI", "SLLI", "SRLI", "SRAI"]:
        rs1 = random.choice(REGISTERS)
        return INSTRUCTIONS[instr_type](rd, rs1)
    else:  
        rs1, rs2 = random.sample(REGISTERS, 2)
        return INSTRUCTIONS[instr_type](rd, rs1, rs2)

def generate_riscv_program(num_instructions=20):
    with open("riscv_program.s", "w") as f:
        for _ in range(1000):
            instruction = generate_instruction_init()
            if instruction is not None:
                f.write(instruction + "\n")
            # f.write(instruction + "\n")
        for _ in range(num_instructions):
            instruction = generate_instruction()
            # if instruction is not None:
            f.write(instruction + "\n")

            # for _ in range(5):
            #     f.write("addi x0, x0, 0\n")  
        f.write("slti x0, x0, -256" + "\n")


        print(f"{num_instructions} in 'riscv_program.s'.")

if __name__ == "__main__":
    generate_riscv_program(100000)  