import machine
import strutils, tables, math

instructions[0x00EEu16] = proc(c: Chip8) =
  #RET
  if debug:
    echo("RET")
  c.pc = c.stack[c.sp]
  dec(c.sp)

instructions[0x1000u16] = proc(c: Chip8) =
  #JP NNN, don't increment pc
  if debug:
    echo("JP NNN")
  c.pc = c.opcode and 0x0FFFu16

instructions[0x2000u16] = proc(c: Chip8) =
  #Call NNN, don't increment pc
  if debug:
    echo("Call NNN")
  inc(c.sp)
  c.stack[c.sp] = c.pc
  c.pc = c.opcode and 0x0FFFu16


instructions[0x3000u16] = proc(c: Chip8) =
  #SE XNN
  if debug:
    echo("SE XNN")
  let xIndex = (c.opcode and 0x0F00u16) shr 8
  let vx = c.registers[xIndex]
  if cast[uint16](vx) == (c.opcode and 0x00FFu16):
    c.pc += 2
  c.pc += 2

instructions[0x4000u16] = proc(c: Chip8) =
  #SNE XNN
  if debug:
    echo("SNE XNN")
  let xIndex = (c.opcode and 0x0F00u16) shr 8
  let vx = c.registers[xIndex]
  if cast[uint16](vx) != (c.opcode and 0x00FFu16):
    c.pc += 2
  c.pc += 2

instructions[0x5000u16] = proc(c: Chip8) =
  #SE XY0
  if debug:
    echo("SE XY0")
  let xIndex = (c.opcode and 0x0F00u16) shr 8
  let yIndex = (c.opcode and 0x00F0u16) shr 4
  let vx = c.registers[xIndex]
  let vy = c.registers[yIndex]
  if vx == vy:
    c.pc += 2
  c.pc += 2

instructions[0x9000u16] = proc(c: Chip8) =
  #SNE XY0
  if debug:
    echo("SNE XY0")
  let xIndex = (c.opcode and 0x0F00u16) shr 8
  let yIndex = (c.opcode and 0x00F0u16) shr 4
  let x = cast[uint16](c.registers[xIndex])
  let y = cast[uint16](c.registers[yIndex])
  if x != y:
    c.pc += 2
  c.pc += 2

instructions[0xB000u16] = proc(c: Chip8) =
  #JP NNN + V0
  if debug:
    echo("JP NNN + V0")
  c.pc = c.opcode and 0x0FFFu16
  c.pc += c.registers[0]

instructions[0xE09Eu16] = proc(c: Chip8) =
  #SKP X9E
  #If key down, skip next instruction
  if debug:
    echo("SKP X9E")
  let xIndex = (c.opcode and 0x0F00u16) shr 8
  let x = (c.registers[xIndex])
  if c.keyboard[x]:
    c.pc += 2

instructions[0xE0A1u16] = proc(c: Chip8) =
  #SKNP XA1
  #If not key down, skip next instruction
  if debug:
    echo("SKNP XA1")
  let xIndex = (c.opcode and 0x0F00u16) shr 8
  let x = (c.registers[xIndex])
  if not c.keyboard[x]:
    c.pc += 2
