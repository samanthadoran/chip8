import machine
import tables

instructions[0x6000u16] = proc(c: Chip8) =
  #LD XNN
  if debug:
    echo("LD XNN")
  let xIndex = (c.opcode and 0x0F00u16) shr 8
  c.registers[xIndex] = c.opcode and 0x00FFu16
  c.pc += 2

instructions[0xA000u16] = proc(c: Chip8) =
  #LD NNN
  if debug:
    echo("LD NNN")
  c.I = c.opcode and 0x0FFFu16
  c.pc += 2


instructions[0xF007u16] = proc(c: Chip8) =
  #LD Vx, DT X07
  if debug:
    echo("LD VX, DT X07")
  let xIndex = (c.opcode and 0x0F00u16) shr 8
  c.registers[xIndex] = c.delayTimer

instructions[0xF00Au16] = proc(c: Chip8) =
  #LD Vx, K X0A
  if debug:
    echo("LD Vx, K X0A")

  let xIndex = (c.opcode and 0x0F00u16) shr 8
  var activeKey = 255u8
  for i in 0..<len(c.keyboard):
    if c.keyboard[i]:
      activeKey = cast[uint8](i)

  #We need to lower pc by two. This allows us to pretend to 'wait' for a key
  if activeKey == 255:
    c.pc -= 2
  else:
    c.registers[xIndex] = activeKey


instructions[0xF015u16] = proc(c: Chip8) =
  #LD DT, Vx X15
  if debug:
    echo("LD DT, VX X15")
  let xIndex = (c.opcode and 0x0F00u16) shr 8
  let x = (c.registers[xIndex])
  c.delayTimer = x

instructions[0xF018u16] = proc(c: Chip8) =
  #LD ST, Vx X18
  if debug:
    echo("LD ST, Vx X18")
  let xIndex = (c.opcode and 0x0F00u16) shr 8
  let x = (c.registers[xIndex])
  c.soundTimer = x

instructions[0xF029u16] = proc(c: Chip8) =
  #LD F, Vx X29
  if debug:
    echo("LD F, Vx X29")
  let xIndex = (c.opcode and 0x0F00u16) shr 8
  let x = (c.registers[xIndex])
  c.I = c.memory[fontOffset + 5u8 * x]

instructions[0xF033u16] = proc(c: Chip8) =
  #LD B, Vx
  if debug:
    echo("LD B, Vx")
  let xIndex = (c.opcode and 0x0F00u16) shr 8
  let x = (c.registers[xIndex])

  #Set hundreds
  c.memory[c.I] =
    if x >= 100u8:
      x div 100u8
    else:
      0u8

  #Set tens
  c.memory[c.I + 1] =
    if x >= 10u8:
      (x div 10u8) mod 10
    else:
      0u8

  #Set ones
  c.memory[c.I + 2] =
    if x >= 1u8:
      (x mod 100) mod 10
    else:
      0u8

instructions[0xF055u16] = proc(c: Chip8) =
  #LD [I], Vx X55
  if debug:
    echo("LD [I], Vx X55")
  let x = (c.opcode and 0x0F00u16) shr 8
  for i in 0..x:
    c.memory[c.I + i] = c.registers[i]

instructions[0xF065u16] = proc(c: Chip8) =
  #LD Vx, [I]
  if debug:
    echo("LD Vx, [I]")
  let x = (c.opcode and 0x0F00u16) shr 8
  for i in 0..x:
    c.registers[i] = c.memory[c.I + i]
