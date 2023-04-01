//Code from eric
// syntax:
//  # comment
//  label:
//  r<n>
//  0b<xxxx> 0x<xxxx> <xxxx> 'a'
//  add  rt, ra, rb
//  sub  rt, ra, rb
//  mov  rt, i16/label
//  movl rt, i8
//  movh rt, i8
//  jmp  rt
//  jz   rt, ra
//  jnz  rt, ra
//  js   rt, ra
//  jns  rt, ra
//  ld   rt, ra
//  st   rt, ra

const fs = require("fs");

const InstructionType = {
    Label: 0,
    Add: 1,
    Sub: 2,
    Move: 3,
    MoveLow: 4,
    MoveHigh: 5,
    Jump: 6,
    JumpZero: 7,
    JumpNonZero: 8,
    JumpSigned: 9,
    JumpNonSigned: 10,
    Load: 11,
    Store: 12,
};

const ArgumentType = {
    Register: 0,
    Immediate8: 1,
    Immediate16: 2, // includes labels
};

const args1Reg = [ArgumentType.Register];
const args2Reg = [ArgumentType.Register, ArgumentType.Register];
const args3Reg = [ArgumentType.Register, ArgumentType.Register, ArgumentType.Register];
const argsRegImm16 = [ArgumentType.Register, ArgumentType.Immediate16];
const argsRegImm8 = [ArgumentType.Register, ArgumentType.Immediate8];

const argsPerInstruction = {
    [InstructionType.Add]: args3Reg,
    [InstructionType.Sub]: args3Reg,
    [InstructionType.Move]: argsRegImm16,
    [InstructionType.MoveLow]: argsRegImm8,
    [InstructionType.MoveHigh]: argsRegImm8,
    [InstructionType.Jump]: args1Reg,
    [InstructionType.JumpZero]: args2Reg,
    [InstructionType.JumpNonZero]: args2Reg,
    [InstructionType.JumpSigned]: args2Reg,
    [InstructionType.JumpNonSigned]: args2Reg,
    [InstructionType.Load]: args2Reg,
    [InstructionType.Store]: args2Reg,
};

const instructionNames = {
    add: InstructionType.Add,
    sub: InstructionType.Sub,
    mov: InstructionType.Move,
    movl: InstructionType.MoveLow,
    movh: InstructionType.MoveHigh,
    jmp: InstructionType.Jump,
    jz: InstructionType.JumpZero,
    jnz: InstructionType.JumpNonZero,
    js: InstructionType.JumpSigned,
    jns: InstructionType.JumpNonSigned,
    ld: InstructionType.Load,
    st: InstructionType.Store,
};

const panic = message => {
    console.error(message);
    process.exit(1);
};

const isIdentifier = string => /^[a-z_][a-z0-9_]*$/i.test(string);

const escapes = {
    t: "\t",
    n: "\n",
    r: "\r",
    v: "\v",
    f: "\f",
    '"': '"',
    "'": "'",
};
const parseLiteral = (string, bits) => {
    if (string.startsWith("'")) {
        if (
            !string.endsWith("'") ||
            (string[1] === "\\" && string.length !== 4) ||
            (string[1] !== "\\" && string.length !== 3)
        ) {
            panic(`Invalid char: ${string}`);
        }

        let char = string[1];
        if (string[1] === "\\") {
            char = string[2];
            if (escapes.hasOwnProperty(char)) {
                char = escapes[char];
            }
        }

        return char.charCodeAt(0).toString(2).padStart(bits, "0");
    }

    string = string.toLowerCase();

    let value = NaN;
    if (string.startsWith("0x")) {
        value = parseInt(string.slice(2), 16);
    } else if (string.startsWith("0b")) {
        value = parseInt(string.slice(2), 2);
    } else {
        value = parseInt(string, 10);
    }

    if (isNaN(value)) {
        panic(`Invalid literal ${string}`);
    }

    const negative = value < 0;
    if (negative) {
        value = -value;
    }

    let valueStr = value.toString(2);
    if (valueStr.length > bits) {
        panic(`Literal does not fit in 16 bits "${string}"`);
    }

    if (negative) {
        valueStr = valueStr
            .replaceAll("0", "a")
            .replaceAll("1", "0")
            .replaceAll("a", "1");

        valueStr = (parseInt(valueStr, 2) + 1)
            .toString(2)
            .padStart(valueStr.length, "0");
        if (
            valueStr.length > bits + 1 ||
            (valueStr.length === bits && valueStr[0] !== "1")
        ) {
            panic(`Literal does not fit in 16 bits "${string}"`);
        }
    }

    return valueStr.padStart(bits, negative ? "1" : "0");
};

const parse = asm => {
    const usedLabels = new Set();
    const definedLabels = new Set();

    const instructions = asm
        .split("\n")
        .map((l, i) => [l.split("#")[0].trim(), i])
        .filter(l => l[0])
        .map(([line, lineNumber]) => {
            const label = line.split(":");
            if (label.length === 2 && !label[1].trim()) {
                const name = label[0].trim();
                if (!isIdentifier(name)) {
                    panic(`Invalid label name "${name}"`);
                }

                definedLabels.add(name);
                return { type: InstructionType.Label, name, lineNumber };
            }

            const spaceIndex = line.match(/\s/)?.index ?? -1;
            if (spaceIndex === -1) {
                panic(`Instruction without argument: "${line}"`);
            }
            const instruction = line.slice(0, spaceIndex);
            const args = line
                .slice(spaceIndex + 1)
                .trim()
                .split(/\s*,\s*/g);
            if (!instructionNames.hasOwnProperty(instruction)) {
                panic(`Instruction "${instruction}" does not exist`);
            }

            const instructionType = instructionNames[instruction];
            const instructionArgs = argsPerInstruction[instructionType];
            if (args.length !== instructionArgs.length) {
                panic(
                    `Wrong number of arguments given to "${instruction}" instruction: "${line}"`
                );
            }

            const parsedArgs = args.map((a, i) => {
                const type = instructionArgs[i];
                switch (type) {
                    case ArgumentType.Register:
                        const regNumber = /^r(\d+)$/.exec(a);
                        if (
                            regNumber &&
                            regNumber[1] >= 0 &&
                            regNumber[1] < 16
                        ) {
                            return (+regNumber[1]).toString(2).padStart(4, "0");
                        } else {
                            panic(`Invalid register format or number: "${a}"`);
                        }

                    case ArgumentType.Immediate8:
                        return parseLiteral(a, 8);

                    case ArgumentType.Immediate16:
                        if (isIdentifier(a)) {
                            usedLabels.add(a);
                            return { label: true, name: a };
                        } else {
                            const value = parseLiteral(a, 16);
                            return {
                                label: false,
                                value: [value.slice(0, 8), value.slice(8)],
                            };
                        }
                }
            });

            return { type: instructionType, args: parsedArgs, lineNumber };
        });

    usedLabels.forEach(l => {
        if (!definedLabels.has(l)) {
            panic(`Reference to undefined label "${l}"`);
        }
    });

    definedLabels.forEach(l => {
        if (!usedLabels.has(l)) {
            console.log(`Warning: unused label "${l}"`);
        }
    });

    return instructions;
};

const subIns = (rt, ra, rb) => `0000${ra}${rb}${rt}`;
const movlIns = (rt, i) => `1000${i}${rt}`;
const movhIns = (rt, i) => `1001${i}${rt}`;
const jzIns = (rt, ra) => `1110${ra}0000${rt}`;
const jnzIns = (rt, ra) => `1110${ra}0001${rt}`;
const jsIns = (rt, ra) => `1110${ra}0010${rt}`;
const jnsIns = (rt, ra) => `1110${ra}0011${rt}`;
const ldIns = (rt, ra) => `1111${ra}0000${rt}`;
const stIns = (rt, ra) => `1111${ra}0001${rt}`;

const moveIns = (rt, [ih, il]) => {
    const instructions = [movlIns(rt, il)];

    if (ih.replaceAll(il[0], "").length) {
        instructions.push(movhIns(rt, ih));
    }

    return instructions;
};

const instructionsToHex = instructions => {
    let assembled = [];
    const labelPositions = new Map();

    instructions.forEach(instruction => {
        const args = instruction.args || [];
        const lineNumber = instruction.lineNumber;
        const rt = args[0];
        const ra = args[1];
        const rb = args[2];

        switch (instruction.type) {
            case InstructionType.Label:
                const positionBits = (assembled.length * 2)
                    .toString(2)
                    .padStart(16, "0");
                labelPositions.set(instruction.name, [
                    positionBits.slice(0, 8),
                    positionBits.slice(8),
                ]);
                break;

            case InstructionType.Add:
                if (rt === rb && rb === rt) {
                    panic("Cannot add the sum of the same register and output into itself");
                }
                assembled.push([subIns(rt, "0000", ra), lineNumber]);
                assembled.push([subIns(rt, rb, rt), lineNumber]);
                break;

            case InstructionType.Sub:
                assembled.push([subIns(rt, ra, rb), lineNumber]);
                break;

            case InstructionType.Move:
                if (args[1].label) {
                    assembled.push(() =>
                        moveIns(rt, labelPositions.get(args[1].name)).map(i => [i, lineNumber])
                    );
                } else {
                    assembled.push(...moveIns(rt, args[1].value).map(i => [i, lineNumber]));
                }
                break;

            case InstructionType.MoveLow:
                assembled.push([movlIns(rt, instruction.args[1]), lineNumber]);
                break;

            case InstructionType.MoveHigh:
                assembled.push([movhIns(rt, instruction.args[1]), lineNumber]);
                break;

            case InstructionType.Jump:
                assembled.push([jzIns(rt, "0000"), lineNumber]);
                break;

            case InstructionType.JumpZero:
                assembled.push([jzIns(rt, ra), lineNumber]);
                break;

            case InstructionType.JumpNonZero:
                assembled.push([jnzIns(rt, ra), lineNumber]);
                break;

            case InstructionType.JumpSigned:
                assembled.push([jsIns(rt, ra), lineNumber]);
                break;

            case InstructionType.JumpNonSigned:
                assembled.push([jnsIns(rt, ra), lineNumber]);
                break;

            case InstructionType.Load:
                assembled.push([ldIns(rt, ra), lineNumber]);
                break;

            case InstructionType.Store:
                assembled.push([stIns(rt, ra), lineNumber]);
                break;
        }
    });

    assembled = assembled.flatMap(instruction => {
        if (typeof instruction === "function") {
            instruction = instruction();
            if (Array.isArray(instruction)) {
                return instruction.map(([i, lineNumber]) => [parseInt(i, 2), lineNumber]);
            }
        }

        return [[parseInt(instruction[0], 2), instruction[1]]];
    });

    assembled.push([2 ** 16 - 1, assembled[assembled.length - 1][1]]);
    if (assembled.length >= 2 ** 15) {
        panic("Too many instructions for 16 bit addresses");
    }

    return assembled;
};

const originalText = fs.readFileSync(process.stdin.fd, "utf-8");
const lines = originalText.split("\n");
const parsed = parse(originalText);
const assembled = instructionsToHex(parsed);

console.log("@0");
for (let l = 0; l < lines.length; l++) {
    const instructions = assembled.filter(i => i[1] === l);
    if (!instructions.length) {
        if (lines[l]) {
            console.log("     // " + lines[l]);
        } else {
            console.log();
        }
    } else {
        instructions.forEach(([ins], i) => {
            if (i === 0) {
                console.log(`${ins.toString(16).padStart(4, "0")} // ${lines[l]}`);
            } else {
                console.log(ins.toString(16).padStart(4, "0"));
            }
        });
    }
}