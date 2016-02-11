import tables, strutils, math, sdl2, times
import machine, partialmaskops, arithmeticops, branchops, loadstoreops

export machine

proc draw*(c: Chip8, ren: RendererPtr) =
  for y in 0..<len(c.display):
    for x in 0..<len(c.display[y]):
      for bit in 0..7:
        #REMEMBER ENDIANESS
        let xPosition = (x * 8) + (8 - bit)
        var r: Rect
        r.x = cast[cint](xPosition) * 8
        r.y = cast[cint](y) * 8
        r.w = 8
        r.h = 8
        let state: bool = ((c.display[y][x] shr (cast[uint8](bit)) and 0x1u8)) == 0x1
        if state:
          setDrawColor(ren, uint8(255), uint8(255), uint8(255))
          fillRect(ren, r)
        setDrawColor(ren, uint8(0), uint8(0), uint8(0))

proc setStateOfKey*(c: Chip8, key: Scancode, state: bool) =
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

when isMainModule:
  import os
  proc main() =
    let romPath = if paramCount() > 0: paramStr(1) else: "INVADERS"
    #Setup SDL
    var
      win: WindowPtr
      ren: RendererPtr
      evt = sdl2.defaultEvent
    discard init(INIT_EVERYTHING)
    win = createWindow("Chip8 emulator", 100, 100, 512, 256, SDL_WINDOW_SHOWN)
    if win == nil:
      echo("Create window failed! Error: ", getError())
      quit(1)

    ren = createRenderer(win, -1, Renderer_Accelerated)
    if ren == nil:
      echo("Create renderer failed! Error: ", getError())
      quit(1)

    var c = newChip8()
    if c.loadRom(romPath):
      var timeStart = epochTime()
      var timersStart = epochTime()
      let sixtyhz = (1.0/60.0)
      var runGame = true
      while true:
        #Handle Events
        let frameTime = epochTime()
        if frameTime - timeStart < sixtyhz / 20:
          continue
        else:
          timeStart = epochTime()

        #If the sound timer isn't 0 yet...
        if frameTime - timersStart >= sixtyhz:
          timersStart = epochTime()
          #Lower it
          if c.soundTimer > 0u8:
            dec(c.soundTimer)
            if debug:
              echo("Would have played a sound")
          if c.delayTimer > 0u8:
            dec(c.delayTimer)

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

        if frameTime - timeStart >= sixtyhz:
          timeStart = epochTime()

  main()
