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
  test "Call":
    let sp = c.sp
    let pc = c.pc
    c.opcode = 0x2ABCu16
    let f = c.decode()
    f(c)
    check c.pc == 0x0ABC
    check c.sp == sp + 1
    check c.stack[c.sp] == pc
