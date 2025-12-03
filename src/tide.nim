#!/usr/bin/env -S nim r 

import core/buffer
import tui/terminal
import strutils, os, illwill

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
    screenWidth, screenHeight: int

proc newEditor(filepath: string = ""): Editor =
  result = Editor(
    buffer: newBuffer(filepath),
    terminal: Terminal(),
    mode: modeNormal,
    cursorRow: 0,
    cursorCol: 0,
    running: true,
    screenWidth: 80,
    screenHeight: 24
  )

proc clampCursor(editor: Editor) =
  let lineCount = editor.buffer.getLineCount()
  if lineCount == 0:
    editor.cursorRow = 0
    editor.cursorCol = 0
    return
  
  editor.cursorRow = max(0, min(editor.cursorRow, lineCount - 1))
  
  let currentLine = editor.buffer.getLine(editor.cursorRow)
  editor.cursorCol = max(0, min(editor.cursorCol, currentLine.len))

proc handleNormalMode(editor: Editor, key: KeyEvent) =
  case key.key:
  of keyChar:
    case key.ch:
    of 'i': editor.mode = modeInsert
    of 'h': 
      editor.cursorCol = max(0, editor.cursorCol - 1)
      editor.clampCursor()
    of 'j': 
      editor.cursorRow += 1
      editor.clampCursor()
    of 'k': 
      editor.cursorRow = max(0, editor.cursorRow - 1)
      editor.clampCursor()
    of 'l': 
      editor.cursorCol += 1
      editor.clampCursor()
    of 'q': editor.running = false
    else: discard
  of keyEscape: editor.running = false
  else: discard

proc handleInsertMode(editor: Editor, key: KeyEvent) =
  case key.key:
  of keyEscape: 
    editor.mode = modeNormal
    editor.clampCursor()
  of keyChar:
    if key.ctrl and key.ch == 'c':
      editor.running = false
      return
    
    editor.buffer.insertChar(editor.cursorRow, editor.cursorCol, key.ch)
    editor.cursorCol += 1
    editor.clampCursor()
  of keyBackspace:
    if editor.cursorCol > 0:
      editor.cursorCol -= 1
      editor.buffer.deleteChar(editor.cursorRow, editor.cursorCol)
      editor.clampCursor()
    elif editor.cursorRow > 0:
      editor.cursorRow -= 1
      let prevLine = editor.buffer.getLine(editor.cursorRow)
      editor.cursorCol = prevLine.len
      editor.clampCursor()
  of keyEnter:
    editor.cursorRow += 1
    editor.cursorCol = 0
    editor.clampCursor()
  else: discard

proc render(editor: Editor) =
  let (cols, rows) = editor.terminal.getSize()
  editor.screenWidth = cols
  editor.screenHeight = rows
  
  editor.terminal.clear()
  
  var tb = newTerminalBuffer(cols, rows)
  
  let visibleRows = min(rows - 1, editor.buffer.getLineCount())
  
  for i in 0..<visibleRows:
    let line = editor.buffer.getLine(i)
    let displayLine = if line.len > cols: line[0..<cols] else: line
    tb.write(0, i, displayLine)
  
  let modeStr = case editor.mode:
    of modeNormal: "NORMAL"
    of modeInsert: "INSERT"
    of modeVisual: "VISUAL"
  
  let status = modeStr & " | " & editor.buffer.name & 
               (if editor.buffer.dirty: " [+] " else: " [ ] ") &
               " | " & $(editor.cursorRow+1) & ":" & $(editor.cursorCol+1)
  
  let paddedStatus = status & " ".repeat(max(0, cols - status.len))
  tb.write(0, rows-1, paddedStatus)
  
  if editor.cursorRow < rows-1 and editor.cursorCol < cols:
    tb.setCursorPos(editor.cursorCol, editor.cursorRow)
  
  tb.display()

proc run(editor: Editor) =
  editor.terminal.initTerminal()
  
  try:
    while editor.running:
      editor.render()
      
      let key = editor.terminal.getKeyEvent()
      
      case editor.mode:
      of modeNormal: editor.handleNormalMode(key)
      of modeInsert: editor.handleInsertMode(key)
      of modeVisual: discard
      
      if key.key == keyNone:
        let (newCols, newRows) = editor.terminal.getSize()
        if newCols != editor.screenWidth or newRows != editor.screenHeight:
          editor.screenWidth = newCols
          editor.screenHeight = newRows
  finally:
    editor.terminal.deinitTerminal()

when isMainModule:
  var filename = ""
  if paramCount() > 0:
    filename = paramStr(1)
  
  var editor = newEditor(filename)
  editor.run()
