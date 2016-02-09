import tables, strutils, math, sdl2, times

type
  chip8 = ref Chip8Obj
  Chip8Obj = object
    #4K of memory
    memory: array[4096, uint8]

    #TODO: Consider using an actual stack, maybe backed by linked list
    stack: array[16, uint16]
    sp: uint8

    #V0..VF
    registers: array[16, uint8]
    #Timers DT & ST
    delayTimer: uint8
    soundTimer: uint8
    #Program Counter Register
    pc: uint16
    #Index Register
    I: uint16

    #Fetched opcode
    opcode: uint16

    #State of the keyboard
    keyboard: array[16, bool]
    #State of the display
    display: array[32, array[8, uint8]]
    #Draw flag
    draw: bool

  ops = Table[uint16, proc(c: chip8)]

var debug = false
const fontOffset = 0x50u16
const romOffset = 0x200u16

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

var instructions: ops = initTable[uint16, proc(c: chip8)]()

instructions[0x0000u16] = proc(c: chip8) =
  #Ignore SYS ADDR 0NNN
  if instructions.hasKey(c.opcode):
    instructions[c.opcode and 0x0FFFu16](c)
    c.pc += 2
  else:
    echo("Unknown opcode: " & cast[int](c.opcode).toHex(4))
    while true:
      discard

instructions[0x00E0u16] = proc(c: chip8) =
  #CLS
  if debug:
    echo("CLS")
  for y in 0..<len(c.display):
    for x in 0..<len(c.display[y]):
      c.display[y][x] = 0u8

instructions[0x00EEu16] = proc(c: chip8) =
  #RET
  if debug:
    echo("RET")
  c.pc = c.stack[c.sp]
  dec(c.sp)

instructions[0x1000u16] = proc(c: chip8) =
  #JP NNN, don't increment pc
  if debug:
    echo("JP NNN")
  c.pc = c.opcode and 0x0FFFu16

instructions[0x2000u16] = proc(c: chip8) =
  #Call NNN, don't increment pc
  if debug:
    echo("Call NNN")
  inc(c.sp)
  c.stack[c.sp] = c.pc
  c.pc = c.opcode and 0x0FFFu16


instructions[0x3000u16] = proc(c: chip8) =
  #SE XNN
  if debug:
    echo("SE XNN")
  let xIndex = (c.opcode and 0x0F00u16) shr 8
  let vx = c.registers[xIndex]
  if cast[uint16](vx) == (c.opcode and 0x00FFu16):
    c.pc += 2
  c.pc += 2

instructions[0x4000u16] = proc(c: chip8) =
  #SNE XNN
  if debug:
    echo("SNE XNN")
  let xIndex = (c.opcode and 0x0F00u16) shr 8
  let vx = c.registers[xIndex]
  if cast[uint16](vx) != (c.opcode and 0x00FFu16):
    c.pc += 2
  c.pc += 2

instructions[0x5000u16] = proc(c: chip8) =
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

instructions[0x6000u16] = proc(c: chip8) =
  #LD XNN
  if debug:
    echo("LD XNN")
  let xIndex = (c.opcode and 0x0F00u16) shr 8
  c.registers[xIndex] = c.opcode and 0x00FFu16
  c.pc += 2

instructions[0x7000u16] = proc(c: chip8) =
  #ADD XNN
  if debug:
    echo("ADD XNN")
  let xIndex = (c.opcode and 0x0F00u16) shr 8
  c.registers[xIndex] += c.opcode and 0x00FFu16
  c.pc += 2

instructions[0x8000u16] = proc(c: chip8) =
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

instructions[0x8001u16] = proc(c: chip8) =
  #OR XY1
  if debug:
    echo("OR XY1")
  let xIndex = (c.opcode and 0x0F00u16) shr 8
  let yIndex = (c.opcode and 0x00F0u16) shr 4
  let orValue = c.registers[xIndex] or c.registers[yIndex]
  c.registers[xIndex] = orValue

instructions[0x8002u16] = proc(c: chip8) =
  #AND XY2
  if debug:
    echo("AND XY2")
  let xIndex = (c.opcode and 0x0F00u16) shr 8
  let yIndex = (c.opcode and 0x00F0u16) shr 4
  let andValue = c.registers[xIndex] and c.registers[yIndex]
  c.registers[xIndex] = andValue

instructions[0x8003u16] = proc(c: chip8) =
  #XOR XY3
  if debug:
    echo("XOR XY3")
  let xIndex = (c.opcode and 0x0F00u16) shr 8
  let yIndex = (c.opcode and 0x00F0u16) shr 4
  let xorValue = c.registers[xIndex] xor c.registers[yIndex]
  c.registers[xindex] = xorValue

instructions[0x8004u16] = proc(c: chip8) =
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

instructions[0x8005u16] = proc(c: chip8) =
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

instructions[0x8006u16] = proc(c: chip8) =
  #SHR XY6
  if debug:
    echo("SHR XY6")
  let xIndex = (c.opcode and 0x0F00u16) shr 8
  let x = cast[uint8](c.registers[xIndex])

  #Set VF?
  c.registers[15] =
    if (x and 0x0001u8) == 0x1u8:
      1u8
    else:
      0u8

  c.registers[xIndex] = x shr 1

instructions[0x8007u16] = proc(c: chip8) =
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

instructions[0x800Eu16] = proc(c: chip8) =
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

instructions[0x9000u16] = proc(c: chip8) =
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

instructions[0xA000u16] = proc(c: chip8) =
  #LD NNN
  if debug:
    echo("LD NNN")
  c.I = c.opcode and 0x0FFFu16
  c.pc += 2

instructions[0xB000u16] = proc(c: chip8) =
  #JP NNN + V0
  if debug:
    echo("JP NNN + V0")
  c.pc = c.opcode and 0x0FFF
  c.pc += c.registers[0]

instructions[0xC000u16] = proc(c: chip8) =
  #RND XKK
  if debug:
    echo("RND XKK")
  let xIndex = (c.opcode and 0x0F00u16) shr 8
  let x = c.registers[xIndex]
  c.registers[xIndex] = x and cast[uint8](random(256))
  c.pc += 2

instructions[0xD000u16] = proc(c: chip8) =
  #DRAW XYN
  c.draw = true
  if debug:
    echo("DRAW XYN")
  let xIndex = (c.opcode and 0x0F00u16) shr 8
  let yIndex = (c.opcode and 0x00F0u16) shr 4
  let bytes = c.opcode and 0x000Fu16
  let x = (c.registers[xIndex])
  let y = (c.registers[yIndex])

  #So, we need to know what x mod 8 is to see how much we need to play with the
  #The bitmap via shifting
  let xM = x mod 8

  #Set collision to be zero initially
  c.registers[15] = 0

  #So, we should shr every byte my xm then shl by 8 - x in the next byte
  for i in 0..<bytes:
    let xdIndex = x div 8
    let ydIndex =
      if y + cast[uint8](i) < 32:
        y + cast[uint8](i)
      else:
        y + cast[uint8](i) - 32u8

    #Keep a copy of the original so we can compare to it
    let original = c.display[ydIndex][xdIndex]
    #Chip 8 displays by xoring the screen
    c.display[ydIndex][xdIndex] = c.display[ydIndex][xdIndex] xor c.memory[c.I + cast[uint16](i)] shr xM

    #If it is different, we will need to update the screen
    if original != c.display[ydIndex][xdIndex]:
      c.draw = true

    #If original AND new isn't the same, we disabled a pixel, thus set collision
    if (original and c.display[ydIndex][xdIndex]) != original:
      c.registers[15] = 1u8

    #If we haven't done this aligned, we need some shl logic
    if xM != 0:

      #We need to start at x = 0
      if x div 8 == 7u8:
        let originalLeftTrick = c.display[ydIndex][0]
        c.display[ydIndex][0] = c.display[ydIndex][0] xor c.memory[c.I + cast[uint16](i)] shl (8u8 - xM)

        #If it is different, we will need to update the screen
        if originalLeftTrick != c.display[ydIndex][0]:
          c.draw = true

        #If original AND new isn't the same, we disabled a pixel, thus set collision
        if (originalLeftTrick and c.display[ydIndex][0]) != original:
          c.registers[15] = 1u8

      #We aren't wrapping around to the left, just add one
      else:
        let originalLeftTrick = c.display[ydIndex][xdIndex + 1]
        c.display[y][(x div 8) + 1] = c.display[ydIndex][(x div 8) + 1] xor c.memory[c.I + cast[uint16](i)] shl (8u8 - xM)

        #If it is different, we will need to update the screen
        if originalLeftTrick != c.display[ydIndex][xdIndex + 1]:
          c.draw = true

        #If original AND new isn't the same, we disabled a pixel, thus set collision
        if (originalLeftTrick and c.display[ydIndex][xdIndex + 1]) != original:
          c.registers[15] = 1u8

  c.pc += 2

instructions[0xE000u16] = proc(c: chip8) =
  #Switch of most significant nybble
  let maskedOp = c.opcode and 0xF0FFu16
  if instructions.hasKey(maskedOp):
    instructions[maskedOp](c)
    #Increment PC
    c.pc += 2
  else:
    echo("Unknown opcode: " & cast[int](c.opcode).toHex(4))


instructions[0xE09Eu16] = proc(c: chip8) =
  #SKP X9E
  #If key down, skip next instruction
  if debug:
    echo("SKP X9E")
  let xIndex = (c.opcode and 0x0F00u16) shr 8
  let x = (c.registers[xIndex])
  if c.keyboard[x]:
    c.pc += 2

instructions[0xE0A1u16] = proc(c: chip8) =
  #SKNP XA1
  #If not key down, skip next instruction
  if debug:
    echo("SKNP XA1")
  let xIndex = (c.opcode and 0x0F00u16) shr 8
  let x = (c.registers[xIndex])
  if not c.keyboard[x]:
    c.pc += 2

instructions[0xF000u16] = proc(c: chip8) =
  #Switch of most significant nybble
  let maskedOp = c.opcode and 0xF0FFu16
  if instructions.hasKey(maskedOp):
    instructions[maskedOp](c)
    #Increment PC
    c.pc += 2
  else:
    echo("Unknown opcode: " & cast[int](c.opcode).toHex(4))

instructions[0xF007u16] = proc(c: chip8) =
  #LD Vx, DT X07
  if debug:
    echo("LD VX, DT X07")
  let xIndex = (c.opcode and 0x0F00u16) shr 8
  c.registers[xIndex] = c.delayTimer

instructions[0xF00Au16] = proc(c: chip8) =
  #LD Vx, K X0A
  if debug:
    echo("LD Vx, K X0A")

  let xIndex = (c.opcode and 0x0F00u16) shr 8
  var activeKey = 255u8
  for i in 0..<len(c.keyboard):
    if c.keyboard[i]:
      activeKey = cast[uint8](i)
      break

  #We need to lower pc by two. This allows us to pretend to 'wait' for a key
  if activeKey != 255:
    c.pc -= 2
  else:
    c.registers[xIndex] = activeKey


instructions[0xF015u16] = proc(c: chip8) =
  #LD DT, Vx X15
  if debug:
    echo("LD DT, VX X15")
  let xIndex = (c.opcode and 0x0F00u16) shr 8
  let x = (c.registers[xIndex])
  c.delayTimer = x

instructions[0xF018u16] = proc(c: chip8) =
  #LD ST, Vx X18
  if debug:
    echo("LD ST, Vx X18")
  let xIndex = (c.opcode and 0x0F00u16) shr 8
  let x = (c.registers[xIndex])
  c.soundTimer = x

instructions[0xF01Eu16] = proc(c: chip8) =
  #ADD I, Vx X1E
  if debug:
    echo("ADD I, Vx X1E")
  let xIndex = (c.opcode and 0x0F00u16) shr 8
  let x = (c.registers[xIndex])
  c.I += x

instructions[0xF029u16] = proc(c: chip8) =
  #LD F, Vx X29
  if debug:
    echo("LD F, Vx X29")
  let xIndex = (c.opcode and 0x0F00u16) shr 8
  let x = (c.registers[xIndex])
  c.I = c.memory[fontOffset + 5u8 * x]

instructions[0xF033u16] = proc(c: chip8) =
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

instructions[0xF055u16] = proc(c: chip8) =
  #LD [I], Vx X55
  if debug:
    echo("LD [I], Vx X55")
  let x = (c.opcode and 0x0F00u16) shr 8
  for i in 0..x:
    c.memory[c.I + i] = c.registers[i]

instructions[0xF065u16] = proc(c: chip8) =
  #LD Vx, [I]
  if debug:
    echo("LD Vx, [I]")
  let x = (c.opcode and 0x0F00u16) shr 8
  for i in 0..x:
    c.registers[i] = c.memory[c.I + i]

proc loadFonts(c: chip8) =
  let fontStart = fontOffset
  for i in 0..<len(fonts):
    c.memory[cast[uint16](i) + fontStart] = fonts[i]

proc newChip8(): chip8 =
  math.randomize()
  result = new(chip8)
  result.I = 0
  result.pc = romOffset
  result.draw = false
  loadFonts(result)

#TODO: Save states

proc loadROM(c: chip8, rom: string): bool =
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

proc fetch(c: chip8) =
  #Be careful here, we must make sure these are 16 bit before doing any shifts.
  #We could separate that onto two lines so that it has no chance of happening,
  #but it looks nice as a one liner
  c.opcode = (cast[uint16](c.memory[c.pc]) shl 8) or cast[uint16](c.memory[c.pc + 1])

proc decode(c: chip8): proc(c: chip8) =
  let firstNybble = 0xF000u16 and c.opcode
  if instructions.hasKey(firstNybble):
    result = instructions[firstNybble]
  else:
    echo("Unknown opcode: " & cast[int](c.opcode).toHex(4))
    while true:
      discard

proc draw(c: chip8, ren: RendererPtr) =
  for y in 0..<len(c.display):
    for x in 0..<len(c.display[y]):
      for bit in 0..7:
        let xPosition = (x * 8) + bit
        var r: Rect
        r.x = cast[cint](xPosition) * 8
        r.y = cast[cint](y) * 8
        r.w = 8
        r.h = 8
        let state: bool = ((c.display[y][x] shr cast[uint8](bit)) and 0x1u8) == 0x1
        if state:
          setDrawColor(ren, uint8(255), uint8(255), uint8(255))
          fillRect(ren, r)
        setDrawColor(ren, uint8(0), uint8(0), uint8(0))

proc setStateOfKey(c: chip8, key: Scancode, state: bool) =
  case key
  #1
  of SDL_SCANCODE_1:
    c.keyboard[0] = state
  #2
  of SDL_SCANCODE_2:
    c.keyboard[1] = state
  #3
  of SDL_SCANCODE_3:
    c.keyboard[2] = state
  #4
  of SDL_SCANCODE_4:
    c.keyboard[3] = state
  #Q
  of SDL_SCANCODE_Q:
    c.keyboard[4] = state
  #W
  of SDL_SCANCODE_W:
    c.keyboard[5] = state
  #E
  of SDL_SCANCODE_E:
    c.keyboard[6] = state
  #R
  of SDL_SCANCODE_R:
    c.keyboard[7] = state
  #A
  of SDL_SCANCODE_A:
    c.keyboard[8] = state
  #S
  of SDL_SCANCODE_S:
    c.keyboard[9] = state
  #D
  of SDL_SCANCODE_D:
    c.keyboard[10] = state
  #F
  of SDL_SCANCODE_F:
    c.keyboard[11] = state
  #Z
  of SDL_SCANCODE_Z:
    c.keyboard[12] = state
  #X
  of SDL_SCANCODE_X:
    c.keyboard[13] = state
  #C
  of SDL_SCANCODE_C:
    c.keyboard[14] = state
  #V
  of SDL_SCANCODE_V:
    c.keyboard[15] = state
  else:
    discard

proc main() =
  #Setup SDL
  var
    win: WindowPtr
    ren: RendererPtr
    evt = sdl2.defaultEvent
  discard init(INIT_EVERYTHING)
  win = createWindow("chip8 emulator", 100, 100, 1280, 720, SDL_WINDOW_SHOWN)
  if win == nil:
    echo("Create window failed! Error: ", getError())
    quit(1)

  ren = createRenderer(win, -1, Renderer_Accelerated)
  if ren == nil:
    echo("Create renderer failed! Error: ", getError())
    quit(1)

  var c = newChip8()
  if c.loadRom("INVADERS"):
    var timeStart = epochTime()
    let sixtyhz = (1.0/60.0)
    var runGame = true
    while true:
      #Handle Events
      let frameTime = epochTime()
      if frameTime - timeStart < sixtyhz / 10:
        continue
      while pollEvent(evt):
        if evt.kind == QuitEvent:
          runGame = false
          break

        if evt.kind == KeyDown:
          var keyboardEvent = cast[KeyboardEventPtr](addr(evt))
          let key = keyboardEvent.keysym.scancode
          c.setStateOfKey(key, true)

        if evt.kind == KeyUp:
          var keyboardEvent = cast[KeyboardEventPtr](addr(evt))
          let key = keyboardEvent.keysym.scancode
          c.setStateOfKey(key, false)

      if not runGame:
        break

      #Fetch
      c.fetch()
      #Decode
      let instruction = c.decode()
      if debug:
        echo("\nOPCODE: ", cast[int](c.opcode).toHex(4))
      #Execute
      instruction(c)

      #If the draw flag is set...
      if c.draw:
        #Unset it
        c.draw = false
        #Draw the screen
        ren.clear
        draw(c, ren)
        ren.present

      #If the sound timer isn't 0 yet...
      if c.soundTimer != 0u8 and frameTime - timeStart >= sixtyhz:
        #Lower it
        dec(c.soundTimer)
        #And play a sound
        if debug:
          echo("Would have played a sound")

      #If the delay timer isn't 0 yet...
      if c.delayTimer != 0u8 and frameTime - timeStart >= sixtyhz:
        dec(c.delayTimer)

      if frameTime - timeStart >= sixtyhz:
        timeStart = epochTime()

main()
