import ncurses

const
  KEY_F1* {.importc: "KEY_F(1)", header: "<ncurses.h>".}: cint = 265
  KEY_F2* {.importc: "KEY_F(2)", header: "<ncurses.h>".}: cint = 266
  KEY_F3* {.importc: "KEY_F(3)", header: "<ncurses.h>".}: cint = 267
  KEY_F4* {.importc: "KEY_F(4)", header: "<ncurses.h>".}: cint = 268
  KEY_F5* {.importc: "KEY_F(5)", header: "<ncurses.h>".}: cint = 269
  KEY_F6* {.importc: "KEY_F(6)", header: "<ncurses.h>".}: cint = 270
  KEY_F7* {.importc: "KEY_F(7)", header: "<ncurses.h>".}: cint = 271
  KEY_F8* {.importc: "KEY_F(8)", header: "<ncurses.h>".}: cint = 272
  KEY_F9* {.importc: "KEY_F(9)", header: "<ncurses.h>".}: cint = 273
  KEY_F10* {.importc: "KEY_F(10)", header: "<ncurses.h>".}: cint = 274
  KEY_F11* {.importc: "KEY_F(11)", header: "<ncurses.h>".}: cint = 275
  KEY_F12* {.importc: "KEY_F(12)", header: "<ncurses.h>".}: cint = 276

type
  Key* = enum
    keyNone, keyHome, keyEnd, keyEscape, keyEnter, keyTab,
    keyBackspace, keySpace,
    keyUp, keyDown, keyLeft, keyRight, 
    keyPageUp, keyPageDown,
    keyF1, keyF2, keyF3, keyF4, keyF5, keyF6,
    keyF7, keyF8, keyF9, keyF10, keyF11, keyF12,
    keyChar  
  KeyEvent* = object
    key*: Key
    ch*: char
    ctrl*: bool
    alt*: bool
    shift*: bool
  Terminal* = ref object
    initialized: bool
    window: ptr Window  

proc initTerminal*(term: Terminal) =
  if not term.initialized:
    term.window = initscr()  
    discard cbreak()
    discard noecho()
    discard keypad(term.window, true)
    discard curs_set(1)
    term.initialized = true

proc deinitTerminal*(term: Terminal) =
  if term.initialized:
    discard endwin()
    term.initialized = false

proc getKeyEvent*(term: Terminal): KeyEvent =
  let code = getch()

  if code >= 0 and code <= 255:
    result.ch = chr(code)
  else:
    result.ch = '\0'

  case code:
  of 27: result.key = keyEscape
  of 10, 13: result.key = keyEnter
  of 9: result.key = keyTab
  of KEY_BACKSPACE, 127: result.key = keyBackspace
  of KEY_UP: result.key = keyUp
  of KEY_DOWN: result.key = keyDown
  of KEY_LEFT: result.key = keyLeft
  of KEY_RIGHT: result.key = keyRight
  of KEY_HOME: result.key = keyHome
  of KEY_END: result.key = keyEnd
  of KEY_PPAGE: result.key = keyPageUp
  of KEY_NPAGE: result.key = keyPageDown
  of KEY_F1: result.key = keyF1
  of KEY_F2: result.key = keyF2
  of KEY_F3: result.key = keyF3
  of KEY_F4: result.key = keyF4
  of KEY_F5: result.key = keyF5
  of KEY_F6: result.key = keyF6
  of KEY_F7: result.key = keyF7
  of KEY_F8: result.key = keyF8
  of KEY_F9: result.key = keyF9
  of KEY_F10: result.key = keyF10
  of KEY_F11: result.key = keyF11
  of KEY_F12: result.key = keyF12
  else:
    result.key = keyChar

proc getSize*(term: Terminal): (int, int) =
  var rows, cols: cint
  getmaxyx(term.window, rows, cols)
  (rows.int, cols.int)

proc clear*(term: Terminal) =
  discard wclear(term.window)

proc refresh*(term: Terminal) =
  discard wrefresh(term.window)

proc moveCursor*(term: Terminal, row, col: int) =
  discard wmove(term.window, row.cint, col.cint)

proc print*(term: Terminal, row, col: int, text: string) =
  discard mvwprintw(term.window, row.cint, col.cint, text)

proc setColor*(term: Terminal, fg, bg: int) =
  discard

proc drawBox*(term: Terminal, row, col, height, width: int) =
  for r in row..row+height-1:
    term.print(r, col, "│")
    term.print(r, col+width-1, "│")
  for c in col..col+width-1:
    term.print(row, c, "─")
    term.print(row+height-1, c, "─")
  term.print(row, col, "┌")
  term.print(row, col+width-1, "┐")
  term.print(row+height-1, col, "└")
  term.print(row+height-1, col+width-1, "┘")
