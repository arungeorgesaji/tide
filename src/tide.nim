#!/usr/bin/env -S nim r 

import core/buffer
import strutils, os, illwill

type
  EditorMode = enum
    modeNormal
    modeInsert
    modeVisual
  
  Editor = ref object
    buffer: Buffer
    mode: EditorMode
    cursorRow, cursorCol: int
    running: bool
    screenWidth, screenHeight: int

proc newEditor(filepath: string = ""): Editor =
  result = Editor(
    buffer: newBuffer(filepath),
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

proc handleNormalMode(editor: Editor, key: Key) =
  if key.ord >= 0 and key.ord < 256:
    let ch = chr(key.ord)
    case ch:
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
  elif key == Key.Escape:
    editor.running = false

proc handleInsertMode(editor: Editor, key: Key) =
  case key:
  of Key.Escape: 
    editor.mode = modeNormal
    editor.clampCursor()
  of Key.Enter:
    editor.cursorRow += 1
    editor.cursorCol = 0
    editor.clampCursor()
  of Key.Backspace:
    if editor.cursorCol > 0:
      editor.cursorCol -= 1
      editor.buffer.deleteChar(editor.cursorRow, editor.cursorCol)
      editor.clampCursor()
    elif editor.cursorRow > 0:
      editor.cursorRow -= 1
      let prevLine = editor.buffer.getLine(editor.cursorRow)
      editor.cursorCol = prevLine.len
      editor.clampCursor()
  else:
    if key.ord >= 0 and key.ord < 256:
      let ch = chr(key.ord)
      if key.ord == 3:
        editor.running = false
        return
      
      editor.buffer.insertChar(editor.cursorRow, editor.cursorCol, ch)
      editor.cursorCol += 1
      editor.clampCursor()

proc render(editor: Editor) =
  editor.screenWidth = terminalWidth()
  editor.screenHeight = terminalHeight()
  
  var tb = newTerminalBuffer(editor.screenWidth, editor.screenHeight)
  
  let visibleRows = min(editor.screenHeight - 1, editor.buffer.getLineCount())
  
  for i in 0..<visibleRows:
    let line = editor.buffer.getLine(i)
    let displayLine = if line.len > editor.screenWidth: 
                        line[0..<editor.screenWidth] 
                      else: 
                        line
    tb.write(0, i, displayLine)
  
  let modeStr = case editor.mode:
    of modeNormal: "NORMAL"
    of modeInsert: "INSERT"
    of modeVisual: "VISUAL"
  
  let status = modeStr & " | " & editor.buffer.name & 
               (if editor.buffer.dirty: " [+] " else: " [ ] ") &
               " | " & $(editor.cursorRow+1) & ":" & $(editor.cursorCol+1)
  
  let paddedStatus = status & " ".repeat(max(0, editor.screenWidth - status.len))
  tb.write(0, editor.screenHeight-1, paddedStatus)
  
  if editor.cursorRow < editor.screenHeight-1 and editor.cursorCol < editor.screenWidth:
    tb.setCursorPos(editor.cursorCol, editor.cursorRow)
  
  tb.display()

proc exitProc() {.noconv.} =
  illwillDeinit()
  showCursor()
  quit(0)

proc run(editor: Editor) =
  illwillInit(fullscreen=true)
  setControlCHook(exitProc)
  hideCursor()
  
  try:
    while editor.running:
      editor.render()
      
      let key = getKey()
      
      case editor.mode:
      of modeNormal: editor.handleNormalMode(key)
      of modeInsert: editor.handleInsertMode(key)
      of modeVisual: discard
      
      if key == Key.None:
        sleep(20)  
  finally:
    illwillDeinit()
    showCursor()

when isMainModule:
  var filename = ""
  if paramCount() > 0:
    filename = paramStr(1)
  
  var editor = newEditor(filename)
  editor.run()
