import unittest, ../src/chip8

echo("Testing init")
suite "Initialize":
  var c = newChip8()
  test "Program counter":
    check c.pc == 0x200u16
  test "Index":
    check c.I == 0u16
  test "Stack pointer":
    check c.sp == 0
  test "Timers":
    check c.soundTimer == 0
    check c.delayTimer == 0

#TODO: test Bnnn - JP V0, addr
echo("Testing jump, call, and ret")
suite "Jump, Call, and Ret":
  var c = newChip8()
  test "Jump":
    let sp = c.sp
    let sv = c.stack[sp]
    c.opcode = 0x1ABCu16
    let f = c.decode()
    f(c)
    check c.pc == 0x0ABC
    check c.sp == sp
    check c.stack[sp] == sv
  let beforeCallPC = c.pc
  test "Call":
    let sp = c.sp
    let pc = c.pc
    c.opcode = 0x2ABCu16
    let f = c.decode()
    f(c)
    check c.pc == 0x0ABC
    check c.sp == sp + 1
    check c.stack[c.sp] == pc
  test "Ret":
    let sp = c.sp
    c.opcode = 0x00EEu16
    let f = c.decode()
    f(c)
    check c.pc == beforeCallPC + 2
    check c.sp == sp - 1

echo("Skip operations")
suite("Skip instructions"):
  var c = newChip8()
  test"3xkk SE Vx, byte":
    #Check on not equal
    var pc = c.pc
    c.opcode = 0x30FFu16
    let f = c.decode()
    f(c)
    check c.pc == pc + 2
    #Check on equal
    pc = c.pc
    c.opcode = 0x30FFu16
    c.registers[0] = 0xFFu8
    let g = c.decode()
    g(c)
    check c.pc == pc + 4
  test("4xkk SNE Vx, byte"):
    #Check on equal
    var pc = c.pc
    c.opcode = 0x40FFu16
    c.registers[0] = 0xFFu8
    let f = c.decode()
    f(c)
    check c.pc == pc + 2
    #Check on not equal
    pc = c.pc
    c.opcode = 0x40FFu16
    c.registers[0] = 0xF1u8
    let g = c.decode()
    g(c)
    check c.pc == pc + 4
  test("5xy0 SE Vx, Vy"):
    #Check on not equal
    var pc = c.pc
    c.opcode = 0x5010u16
    let f = c.decode()
    c.registers[1] = 0x00u8
    c.registers[0] = 0x01u8
    f(c)
    check c.pc == pc + 2
    #Check on equal
    pc = c.pc
    c.opcode = 0x5010u16
    c.registers[1] = 0x01u8
    c.registers[0] = 0x01u8
    let g = c.decode()
    g(c)
    check c.pc == pc + 4
  test("9xy0 SNE Vx, Vy"):
    #Check on equal
    var pc = c.pc
    c.opcode = 0x9010u16
    let f = c.decode()
    c.registers[1] = 0x00u8
    c.registers[0] = 0x00u8
    f(c)
    check c.pc == pc + 2
    #Check on not equal
    pc = c.pc
    c.opcode = 0x9010u16
    c.registers[1] = 0x01u8
    c.registers[0] = 0x00u8
    let g = c.decode()
    g(c)
    check c.pc == pc + 4

  test("Ex9E SKP Vx"):
    #Check on not equal
    var pc = c.pc
    c.opcode = 0xE19Eu16
    let f = c.decode()
    c.registers[1] = 0x00u8
    c.keyboard[0] = false
    f(c)
    check c.pc == pc + 2
    #Check on equal
    pc = c.pc
    c.opcode = 0xE19Eu16
    c.registers[1] = 0x00u8
    c.keyboard[0] = true
    let g = c.decode()
    g(c)
    check c.pc == pc + 4
  test("ExA1 SKNP Vx"):
    #Check on equal
    var pc = c.pc
    c.opcode = 0xE1A1u16
    let f = c.decode()
    c.registers[1] = 0x00u8
    c.keyboard[0] = true
    f(c)
    check c.pc == pc + 2
    #Check on not equal
    pc = c.pc
    c.opcode = 0xE1A1u16
    c.registers[1] = 0x00u8
    c.keyboard[0] = false
    let g = c.decode()
    g(c)
    check c.pc == pc + 4


#TODO: Finish test suite
echo("Testing arithmetic operations")
suite "Arithmetic operations":
  var c = newChip8()
  test("7xkk ADD Vx, byte"):
    c.opcode = 0x750Fu16
    let r = c.registers[5]
    let f = c.decode()
    f(c)
    check r + 0x00Fu8 == c.registers[5]
    discard
  test("8xy1 OR Vx, Vy"):
    c.opcode = 0x8011u16
    c.registers[0] = 0x0Fu8
    c.registers[1] = 0xF0u8
    let f = c.decode()
    f(c)
    check c.registers[0] == 0xFFu8
  test("8xy2 AND Vx, Vy"):
    c.opcode = 0x8012u16
    c.registers[0] = 0x0Fu8
    c.registers[1] = 0xF0u8
    let f = c.decode()
    f(c)
    check c.registers[0] == 0x00u8
  test("8xy3 XOR Vx, Vy"):
    c.opcode = 0x8013u16
    c.registers[0] = 0x0Fu8
    c.registers[1] = 0xF0u8
    let f = c.decode()
    f(c)
    check c.registers[0] == 0xFFu8
    c.opcode = 0x8013u16
    c.registers[0] = 0x0Fu8
    c.registers[1] = 0x0Fu8
    let g = c.decode()
    g(c)
    check c.registers[0] == 0x00u8
  test("8xy4 ADD Vx, Vy"):
    c.opcode = 0x8014u16
    c.registers[0] = 7u8
    c.registers[1] = 11u8
    let f = c.decode()
    f(c)
    check((c.registers[0] == 18u8) and (c.registers[15] == 0))
    #Check for carry
    c.opcode = 0x8014u16
    c.registers[0] = 255u8
    c.registers[1] = 1u8
    let g = c.decode()
    g(c)
    check((c.registers[0] == 0u8) and (c.registers[15] == 1))
  #TODO: Check Vf for borrow
  test("8xy5 SUB Vx, Vy"):
    c.opcode = 0x8015u16
    c.registers[0] = 11u8
    c.registers[1] = 7u8
    let f = c.decode()
    f(c)
    check((c.registers[0] == 4u8) and (c.registers[15] == 1))
    #Check for carry
    c.opcode = 0x8015u16
    c.registers[0] = 0u8
    c.registers[1] = 1u8
    let g = c.decode()
    g(c)
    check((c.registers[0] == 255u8) and (c.registers[15] == 0))
  test("8xy6 SHR Vx {, Vy}"):
    discard
  test("8xy7 SUBN Vx, Vy"):
    discard
  test("8xyE SHL Vx {, Vy}"):
    discard
  test("Cxkk RND Vx, byte"):
    discard
  test("Dxyn DRW Vx, Vy, nibble"):
    discard
  test("Fx1E ADD I, Vx"):
    discard
