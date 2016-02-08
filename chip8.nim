import tables, strutils
type
  chip8 = ref Chip8Obj
  Chip8Obj = object
    memory: array[4096, uint8]
    stack: array[16, uint16]
    sp: uint16
    registers: array[16, uint8]
    I: uint16
    pc: uint16
    opcode: uint16
    delayTimer: uint16
    soundTimer: uint16
  ops = Table[uint16, proc(c: chip8)]

var instructions: ops = initTable[uint16, proc(c: chip8)]()

instructions[0x0000u16] = proc(c: chip8) =
  #Ignore SYS ADDR 0NNN
  if c.opcode == 0x00EEu16 or c.opcode == 0x000E:
    instructions[c.opcode](c)

instructions[0x00E0u16] = proc(c: chip8) =
  #CLS
  c.pc += 2
  discard

instructions[0x00EEu16] = proc(c: chip8) =
  #RET
  c.pc = c.stack[c.sp]
  dec(c.sp)
  c.pc += 2

instructions[0x1000u16] = proc(c: chip8) =
  #JP NNN, don't increment pc
  c.pc = c.opcode and 0x0FFFu16

instructions[0x2000u16] = proc(c: chip8) =
  #Call NNN, don't increment pc
  inc(c.sp)
  c.stack[c.sp] = c.pc
  c.pc = c.opcode and 0x0FFFu16


instructions[0x3000u16] = proc(c: chip8) =
  #SE XNN
  let vx = c.registers[c.opcode and 0x0F00u16]
  if cast[uint16](vx) == (c.opcode and 0x00FFu16):
    c.pc += 2
  c.pc += 2

instructions[0x4000u16] = proc(c: chip8) =
  #SNE XNN
  let vx = c.registers[c.opcode and 0x0F00u16]
  if cast[uint16](vx) != (c.opcode and 0x00FFu16):
    c.pc += 2
  c.pc += 2

instructions[0x5000u16] = proc(c: chip8) =
  #SE XY0
  let vx = c.registers[c.opcode and 0x0F00u16]
  let vy = c.registers[c.opcode and 0x00F0u16]
  if vx == vy:
    c.pc += 2
  c.pc += 2

instructions[0x6000u16] = proc(c: chip8) =
  #LD XNN
  c.registers[c.opcode and 0x0F00u16] = c.opcode and 0x00FFu16
  c.pc += 2

instructions[0x7000u16] = proc(c: chip8) =
  #ADD XNN
  c.registers[c.opcode and 0x0F00u16] += c.opcode and 0x00FFu16
  c.pc += 2

instructions[0x8000u16] = proc(c: chip8) =
  let lastNybble = c.opcode and 0x000Fu16
  if lastNybble == 0x0000u16:
    #LD XY0
    let xIndex = (c.opcode and 0x0F00u16) shr 8
    let yIndex = (c.opcode and 0x00F0u16) shr 4
    c.registers[xIndex] = c.registers[yIndex]
    #Don't forget to do this here!
    c.pc += 2
  else:
    instructions[c.opcode and 0xF00Fu16](c)

instructions[0x8001u16] = proc(c: chip8) =
  #OR XY1
  let xIndex = (c.opcode and 0x0F00u16) shr 8
  let yIndex = (c.opcode and 0x00F0u16) shr 4
  let orValue = c.registers[xIndex] or c.registers[yIndex]
  c.registers[c.opcode and 0x0F00u16] = orValue
  c.pc += 2

instructions[0x8002u16] = proc(c: chip8) =
  #AND XY2
  let xIndex = (c.opcode and 0x0F00u16) shr 8
  let yIndex = (c.opcode and 0x00F0u16) shr 4
  let andValue = c.registers[xIndex] and c.registers[yIndex]
  c.registers[c.opcode and 0x0F00u16] = andValue
  c.pc += 2

instructions[0x8003u16] = proc(c: chip8) =
  #XOR XY3
  let xIndex = (c.opcode and 0x0F00u16) shr 8
  let yIndex = (c.opcode and 0x00F0u16) shr 4
  let xorValue = c.registers[xIndex] xor c.registers[yIndex]
  c.registers[c.opcode and 0x0F00u16] = xorValue
  c.pc += 2

instructions[0x8004u16] = proc(c: chip8) =
  #ADD XY4
  let xIndex = (c.opcode and 0x0F00u16) shr 8
  let yIndex = (c.opcode and 0x00F0u16) shr 4
  let x = cast[uint16](c.registers[xIndex])
  let y = cast[uint16](c.registers[yIndex])
  c.registers[xIndex] = cast[uint8](x + y)

  #Set carry?
  c.registers[15] =
    if x + y > 255u16:
      1u8
    else:
      0u8

  c.pc += 2

instructions[0x8005u16] = proc(c: chip8) =
  #SUB XY5
  let xIndex = (c.opcode and 0x0F00u16) shr 8
  let yIndex = (c.opcode and 0x00F0u16) shr 4
  let x = cast[uint16](c.registers[xIndex])
  let y = cast[uint16](c.registers[yIndex])
  c.registers[xIndex] = cast[uint8](x - y)

  #Set borrow?
  c.registers[15] =
    if x > y:
      1u8
    else:
      0u8

  c.pc += 2

instructions[0x9000u16] = proc(c: chip8) =
  discard

instructions[0xA000u16] = proc(c: chip8) =
  discard

instructions[0xB000u16] = proc(c: chip8) =
  discard

instructions[0xC000u16] = proc(c: chip8) =
  discard

instructions[0xD000u16] = proc(c: chip8) =
  discard

instructions[0xE000u16] = proc(c: chip8) =
  discard

instructions[0xF000u16] = proc(c: chip8) =
  discard


proc newChip8(): chip8 =
  result = new(chip8)
  result.I = 0
  result.pc = 0x200

proc fetch(c: chip8) =
  c.opcode = (c.memory[c.pc] shl 8) or c.memory[c.pc + 1]

proc decode(c: chip8): proc(c: chip8) =
  let firstNybble = 0xF000u16 and c.opcode
  if instructions.hasKey(firstNybble):
    result = instructions[firstNybble]
  else:
    echo("Unknown opcode: " & cast[int](c.opcode).toHex(4))
    while true:
      discard

proc main() =
  var c = newChip8()
  while false:
    c.fetch()
    let instruction = c.decode()
    instruction(c)

main()
