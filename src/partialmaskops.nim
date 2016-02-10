import machine
import tables, strutils

instructions[0x0000u16] = proc(c: Chip8) =
  #Ignore SYS ADDR 0NNN
  if instructions.hasKey(c.opcode):
    instructions[c.opcode and 0x0FFFu16](c)
    c.pc += 2
  else:
    echo("Unknown opcode: " & cast[int](c.opcode).toHex(4))
    while true:
      discard

instructions[0x8000u16] = proc(c: Chip8) =
  #Switch of most significant nybble

  #We have to check this in here, this instruction would overload this entry
  let lastNybble = c.opcode and 0x000Fu16
  if lastNybble == 0x0000u16:
    #LD XY0
    if debug:
      echo("LD XY0")
    let xIndex = (c.opcode and 0x0F00u16) shr 8
    let yIndex = (c.opcode and 0x00F0u16) shr 4
    c.registers[xIndex] = c.registers[yIndex]
  else:
    if instructions.hasKey(c.opcode and 0xF00Fu16):
      instructions[c.opcode and 0xF00Fu16](c)
    else:
      echo("Unknown opcode: " & cast[int](c.opcode).toHex(4))
      while true:
        discard

  #Increment PC
  c.pc += 2

instructions[0xE000u16] = proc(c: Chip8) =
  #Switch of most significant nybble
  let maskedOp = c.opcode and 0xF0FFu16
  if instructions.hasKey(maskedOp):
    instructions[maskedOp](c)
    #Increment PC
    c.pc += 2
  else:
    echo("Unknown opcode: " & cast[int](c.opcode).toHex(4))

instructions[0xF000u16] = proc(c: Chip8) =
  #Switch of most significant nybble
  let maskedOp = c.opcode and 0xF0FFu16
  if instructions.hasKey(maskedOp):
    instructions[maskedOp](c)
    #Increment PC
    c.pc += 2
  else:
    echo("Unknown opcode: " & cast[int](c.opcode).toHex(4))
