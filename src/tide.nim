#!/usr/bin/env -s nim r 

import core/buffer
import tui/terminal
import strutils, os

type
  EditorMode = enum
    modeNormal
    modeInsert
    modeVisual
  
  Editor = ref object
    buffer: Buffer
    terminal: Terminal
    mode: EditorMode
    cursorRow, cursorCol: int
    running: bool

proc newEditor(filepath: string = ""): Editor =
  result = Editor(
    buffer: newBuffer(filepath),
    terminal: Terminal(),
    mode: modeNormal,
    cursorRow: 0,
    cursorCol: 0,
    running: true
  )

proc handleNormalMode(editor: Editor, key: KeyEvent) =
  case key.key:
  of keyChar:
    case key.ch:
    of 'i', 'I': editor.mode = modeInsert
    of 'h': editor.cursorCol = max(0, editor.cursorCol - 1)
    of 'j': editor.cursorRow = min(editor.buffer.getLineCount() - 1, editor.cursorRow + 1)
    of 'k': editor.cursorRow = max(0, editor.cursorRow - 1)
    of 'l': editor.cursorCol += 1
    of 'q': editor.running = false
    else: discard
  of keyEscape: editor.running = false
  else: discard

proc handleInsertMode(editor: Editor, key: KeyEvent) =
  case key.key:
  of keyEscape: editor.mode = modeNormal
  of keyChar:
    editor.buffer.insertChar(editor.cursorRow, editor.cursorCol, key.ch)
    editor.cursorCol += 1
  of keyBackspace:
    if editor.cursorCol > 0:
      editor.cursorCol -= 1
      editor.buffer.deleteChar(editor.cursorRow, editor.cursorCol)
  of keyEnter:
    editor.cursorRow += 1
    editor.cursorCol = 0
  else: discard

proc render(editor: Editor) =
  let (rows, cols) = editor.terminal.getSize()
  
  editor.terminal.clear()
  
  let startRow = 0
  let endRow = min(rows - 2, editor.buffer.getLineCount() - 1)
  
  for i in 0..endRow:
    let line = editor.buffer.getLine(startRow + i)
    let displayLine = if line.len > cols: line[0..cols-1] else: line
    editor.terminal.print(i, 0, displayLine)
  
  let modeStr = case editor.mode:
    of modeNormal: "NORMAL"
    of modeInsert: "INSERT"
    of modeVisual: "VISUAL"
  
  let status = modeStr & " | " & editor.buffer.name & 
               (if editor.buffer.dirty: " [+] " else: " [ ] ") &
               " | " & $(editor.cursorRow+1) & ":" & $(editor.cursorCol+1)
  
  editor.terminal.print(rows-1, 0, status & " ".repeat(cols - status.len))
  
  editor.terminal.moveCursor(editor.cursorRow, editor.cursorCol)
  
  editor.terminal.refresh()

proc run(editor: Editor) =
  editor.terminal.initTerminal()
  
  while editor.running:
    editor.render()
    
    let key = editor.terminal.getKeyEvent()
    
    case editor.mode:
    of modeNormal: editor.handleNormalMode(key)
    of modeInsert: editor.handleInsertMode(key)
    of modeVisual: discard  
    
    if key.key == keyChar and key.ch == 'z' and key.ctrl:
      editor.terminal.deinitTerminal()
      editor.terminal.initTerminal()
  
  editor.terminal.deinitTerminal()

when isMainModule:
  var filename = ""
  if paramCount() > 0:
    filename = paramStr(1)
  
  var editor = newEditor(filename)
  editor.run()
