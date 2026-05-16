import os 


def load_instruction_from_file(filename: str, default_instruction: str = "Default instruction.") -> str:
    """
    Reads instruction text from a file relative to this script.
    """
    intruction = default_instruction
    try:
        # construct path relative to current script file(__file__)
        filepath = os.path.join(os.path.dirname(__file__), filename)
        with open(filepath,"r", encoding="utf-8") as f:
            instruction = f.read()
        print(f"Successfully loaded instruction from {filename}")

    except FileNotFoundError:
        print(f"WARNING: Instruction file not found:{filepath}. Using default.")

    except Exception as e:
        print(f"ERROR loading instruction file {filepath}:{e}. Using deault.")

    return instruction

