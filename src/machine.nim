import tables, strutils, math
type
  Chip8* = ref Chip8Obj
  Chip8Obj = object
    #4K of memory
    memory*: array[4096, uint8]

    #TODO: Consider using an actual stack, maybe backed by linked list
    stack*: array[16, uint16]
    sp*: uint8

    #V0..VF
    registers*: array[16, uint8]
    #Timers DT & ST
    delayTimer*: uint8
    soundTimer*: uint8
    #Program Counter Register
    pc*: uint16
    #Index Register
    I*: uint16

    #Fetched opcode
    opcode*: uint16

    #State of the keyboard
    keyboard*: array[16, bool]
    #State of the display
    display*: array[32, array[8, uint8]]
    #Draw flag
    draw*: bool

  ops* = Table[uint16, proc(c: Chip8)]

var debug* = false
const fontOffset* = 0x50u16
const romOffset* = 0x200u16

#Really gross font bitmap of 0..F
const fonts: array[80, uint8] = [
  0xF0u8, 0x90u8, 0x90u8, 0x90u8, 0xF0u8, # 0
  0x20u8, 0x60u8, 0x20u8, 0x20u8, 0x70u8, # 1
  0xF0u8, 0x10u8, 0xF0u8, 0x80u8, 0xF0u8, # 2
  0xF0u8, 0x10u8, 0xF0u8, 0x10u8, 0xF0u8, # 3
  0x90u8, 0x90u8, 0xF0u8, 0x10u8, 0x10u8, # 4
  0xF0u8, 0x80u8, 0xF0u8, 0x10u8, 0xF0u8, # 5
  0xF0u8, 0x80u8, 0xF0u8, 0x90u8, 0xF0u8, # 6
  0xF0u8, 0x10u8, 0x20u8, 0x40u8, 0x40u8, # 7
  0xF0u8, 0x90u8, 0xF0u8, 0x90u8, 0xF0u8, # 8
  0xF0u8, 0x90u8, 0xF0u8, 0x10u8, 0xF0u8, # 9
  0xF0u8, 0x90u8, 0xF0u8, 0x90u8, 0x90u8, # A
  0xE0u8, 0x90u8, 0xE0u8, 0x90u8, 0xE0u8, # B
  0xF0u8, 0x80u8, 0x80u8, 0x80u8, 0xF0u8, # C
  0xE0u8, 0x90u8, 0x90u8, 0x90u8, 0xE0u8, # D
  0xF0u8, 0x80u8, 0xF0u8, 0x80u8, 0xF0u8, # E
  0xF0u8, 0x80u8, 0xF0u8, 0x80u8, 0x80u8  # F
]

var instructions*: ops = initTable[uint16, proc(c: Chip8)]()

proc loadFonts(c: Chip8) =
  let fontStart = fontOffset
  for i in 0..<len(fonts):
    c.memory[cast[uint16](i) + fontStart] = fonts[i]

proc newChip8*(): Chip8 =
  math.randomize()
  result = new(Chip8)
  result.I = 0
  result.pc = romOffset
  result.draw = false
  loadFonts(result)

#TODO: Save states

proc loadROM*(c: Chip8, rom: string): bool =
  var f: File
  if f.open(rom):
    result = true
    #From rom offset until the top of memory
    let len = 0xFFFu16 - romOffset
    discard f.readBytes(c.memory, c.pc, len)
    f.close()
  else:
    echo("Failed to open file!")
    result = false

proc fetch*(c: Chip8) =
  #Be careful here, we must make sure these are 16 bit before doing any shifts.
  #We could separate that onto two lines so that it has no chance of happening,
  #but it looks nice as a one liner
  c.opcode = (cast[uint16](c.memory[c.pc]) shl 8) or cast[uint16](c.memory[c.pc + 1])

proc decode*(c: Chip8): proc(c: Chip8) =
  let firstNybble = 0xF000u16 and c.opcode
  if instructions.hasKey(firstNybble):
    result = instructions[firstNybble]
  else:
    echo("Unknown opcode: " & cast[int](c.opcode).toHex(4))
    while true:
      discard
