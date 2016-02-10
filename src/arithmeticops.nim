import machine
import strutils, tables, math

instructions[0x00E0u16] = proc(c: Chip8) =
  #CLS
  if debug:
    echo("CLS")
  for y in 0..<len(c.display):
    for x in 0..<len(c.display[y]):
      c.display[y][x] = 0u8

instructions[0x7000u16] = proc(c: Chip8) =
  #ADD XNN
  if debug:
    echo("ADD XNN")
  let xIndex = (c.opcode and 0x0F00u16) shr 8
  c.registers[xIndex] += c.opcode and 0x00FFu16
  c.pc += 2

instructions[0x8000u16] = proc(c: Chip8) =
  #Switch of most significant nybble
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

instructions[0x8001u16] = proc(c: Chip8) =
  #OR XY1
  if debug:
    echo("OR XY1")
  let xIndex = (c.opcode and 0x0F00u16) shr 8
  let yIndex = (c.opcode and 0x00F0u16) shr 4
  let orValue = c.registers[xIndex] or c.registers[yIndex]
  c.registers[xIndex] = orValue

instructions[0x8002u16] = proc(c: Chip8) =
  #AND XY2
  if debug:
    echo("AND XY2")
  let xIndex = (c.opcode and 0x0F00u16) shr 8
  let yIndex = (c.opcode and 0x00F0u16) shr 4
  let andValue = c.registers[xIndex] and c.registers[yIndex]
  c.registers[xIndex] = andValue

instructions[0x8003u16] = proc(c: Chip8) =
  #XOR XY3
  if debug:
    echo("XOR XY3")
  let xIndex = (c.opcode and 0x0F00u16) shr 8
  let yIndex = (c.opcode and 0x00F0u16) shr 4
  let xorValue = c.registers[xIndex] xor c.registers[yIndex]
  c.registers[xindex] = xorValue

instructions[0x8004u16] = proc(c: Chip8) =
  #ADD XY4
  if debug:
    echo("ADD XY4")
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

instructions[0x8005u16] = proc(c: Chip8) =
  #SUB XY5
  if debug:
    echo("SUB XY5")
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

instructions[0x8006u16] = proc(c: Chip8) =
  #SHR XY6
  if debug:
    echo("SHR XY6")
  let xIndex = (c.opcode and 0x0F00u16) shr 8
  let x = cast[uint8](c.registers[xIndex])

  #Set VF?
  c.registers[15] =
    if (x and 0x01u8) == 0x1u8:
      1u8
    else:
      0u8

  c.registers[xIndex] = x shr 1

instructions[0x8007u16] = proc(c: Chip8) =
  #SUBN XY7
  if debug:
    echo("SUBN XY7")
  let xIndex = (c.opcode and 0x0F00u16) shr 8
  let yIndex = (c.opcode and 0x00F0u16) shr 4
  let x = cast[uint16](c.registers[xIndex])
  let y = cast[uint16](c.registers[yIndex])
  c.registers[xIndex] = cast[uint8](y - x)

  #Set borrow?
  c.registers[15] =
    if y > x:
      1u8
    else:
      0u8

instructions[0x800Eu16] = proc(c: Chip8) =
  #SHL XYE
  if debug:
    echo("SHL XYE")
  let xIndex = (c.opcode and 0x0F00u16) shr 8
  let x = cast[uint8](c.registers[xIndex])

  #Set VF?
  c.registers[15] =
    if (x shr 7) == 0x1u8:
      1u8
    else:
      0u8

  c.registers[xIndex] = x shl 1

instructions[0xC000u16] = proc(c: Chip8) =
  #RND XKK
  if debug:
    echo("RND XKK")
  let xIndex = (c.opcode and 0x0F00u16) shr 8
  let x = c.registers[xIndex]
  c.registers[xIndex] = x and cast[uint8](random(256))
  c.pc += 2

instructions[0xD000u16] = proc(c: Chip8) =
  #DRAW XYN
  if debug:
    echo("DRAW XYN")
  let xIndex = (c.opcode and 0x0F00u16) shr 8
  let yIndex = (c.opcode and 0x00F0u16) shr 4
  let bytes = c.opcode and 0x000Fu16
  var xPos = (c.registers[xIndex])
  let yPos = (c.registers[yIndex])
  c.draw = true
  c.registers[15] = 0

  for yAdd in 0..<bytes:
    let yLoopPos = (yPos + cast[uint8](yAdd)) mod 32
    let xLoopPos = (xPos div 8) mod 8

    #Make it into a DWORD for sanity
    let DWORD: uint16 = (cast[uint16](c.memory[c.I + cast[uint16](yAdd)]) shl 8) shr (xPos and 0x7u8)
    let upperWord: uint8 = cast[uint8](DWORD shr 8)
    let lowerWord: uint8 = cast[uint8](DWORD)

    #Upper word
    let original = c.display[yLoopPos][xLoopPos]
    c.display[yLoopPos][xLoopPos] =
      c.display[yLoopPos][xLoopPos] xor upperWord

    if (original and c.display[yLoopPos][xLoopPos]) != original:
      c.registers[15] = 1

    #Lower word
    let originalLower = c.display[yLoopPos][(xLoopPos + 1) mod 8]
    c.display[yLoopPos][(xLoopPos + 1) mod 8] =
      c.display[yLoopPos][(xLoopPos + 1) mod 8] xor lowerWord

    if(originalLower and c.display[yLoopPos][(xLoopPos + 1) mod 8]) != originalLower:
      c.registers[15] = 1

  c.pc += 2

instructions[0xF01Eu16] = proc(c: Chip8) =
  #ADD I, Vx X1E
  if debug:
    echo("ADD I, Vx X1E")
  let xIndex = (c.opcode and 0x0F00u16) shr 8
  let x = (c.registers[xIndex])
  c.I += x
