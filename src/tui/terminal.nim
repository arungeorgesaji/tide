import illwill

type
  KeyEvent* = object
    key*: Key        
    ch*: char
    ctrl*: bool
    alt*: bool
    shift*: bool
  Terminal* = ref object
    initialized: bool

proc exitProc() {.noconv.} =
  illwillDeinit()
  showCursor()
  quit(0)

proc initTerminal*(term: Terminal) =
  if not term.initialized:
    illwillInit(fullscreen=true)
    setControlCHook(exitProc)
    hideCursor()
    term.initialized = true

proc deinitTerminal*(term: Terminal) =
  if term.initialized:
    showCursor()
    illwillDeinit()
    term.initialized = false

proc getKeyEvent*(term: Terminal): KeyEvent =
  let key = getKey()  
  case key:
    of Key.None: result.key = Key.None
    of Key.Escape: result.key = Key.Escape
    of Key.Enter: result.key = Key.Enter
    of Key.Tab: result.key = Key.Tab
    of Key.Backspace: result.key = Key.Backspace
    of Key.Space: result.key = Key.Space
    of Key.Up: result.key = Key.Up
    of Key.Down: result.key = Key.Down
    of Key.Left: result.key = Key.Left
    of Key.Right: result.key = Key.Right
    of Key.Home: result.key = Key.Home
    of Key.End: result.key = Key.End
    of Key.PageUp: result.key = Key.PageUp
    of Key.PageDown: result.key = Key.PageDown
    of Key.F1: result.key = Key.F1
    of Key.F2: result.key = Key.F2
    of Key.F3: result.key = Key.F3
    of Key.F4: result.key = Key.F4
    of Key.F5: result.key = Key.F5
    of Key.F6: result.key = Key.F6
    of Key.F7: result.key = Key.F7
    of Key.F8: result.key = Key.F8
    of Key.F9: result.key = Key.F9
    of Key.F10: result.key = Key.F10
    of Key.F11: result.key = Key.F11
    of Key.F12: result.key = Key.F12
    else: result.key = Key.None

proc getSize*(term: Terminal): (int, int) =
  (terminalWidth().int, terminalHeight().int)  

proc clear*(term: Terminal) =
  clear(term)  

proc refresh*(term: Terminal) =
  discard

proc moveCursor*(term: Terminal, row, col: int) =
  var tb = newTerminalBuffer(terminalWidth(), terminalHeight())
  setCursorPos(tb, col, row)
  tb.display()

proc print*(term: Terminal, row, col: int, text: string) =
  var tb = newTerminalBuffer(terminalWidth(), terminalHeight())
  tb.write(col, row, text)
  tb.display()

proc setColor*(term: Terminal, fg, bg: int) =
  setColor(term, fg, bg)  

proc drawBox*(term: Terminal, row, col, height, width: int) =
  drawBox(term, row, col, height, width)  
