import unittest, ../chip8

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

echo("Branch operations")
suite("Branching instructions"):
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
