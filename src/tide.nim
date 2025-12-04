#!/usr/bin/env -S nim r

import core/buffer
import strutils, os, illwill, tables, sequtils

type
  EditorMode = enum
    modeNormal, modeInsert, modeCommand

  UndoAction = enum
    uaInsertChar, uaDeleteChar, uaInsertLine, uaDeleteLine, uaSetLine

  UndoItem = object
    action: UndoAction
    row, col: int
    text: string

  Editor = ref object
    buffer: Buffer
    mode: EditorMode
    cursorRow, cursorCol: int
    running: bool
    screenWidth, screenHeight: int
    cmdBuffer: string
    undoStack: seq[UndoItem]
    yankBuffer: string

proc pushUndo(editor: Editor, action: UndoAction, row, col: int, text: string = "") =
  editor.undoStack.add(UndoItem(action: action, row: row, col: col, text: text))

proc newEditor(filepath = ""): Editor =
  result = Editor(
    buffer: newBuffer(filepath),
    mode: modeNormal,
    cursorRow: 0,
    cursorCol: 0,
    running: true,
    cmdBuffer: "",
    undoStack: @[],
    yankBuffer: ""
  )

proc clampCursor(editor: Editor) =
  editor.cursorRow = editor.cursorRow.clamp(0, editor.buffer.lines.high)
  let line = editor.buffer.getLine(editor.cursorRow)
  editor.cursorCol = editor.cursorCol.clamp(0, line.len)

proc undo(editor: Editor) =
  if editor.undoStack.len == 0: return
  let item = editor.undoStack.pop()
  case item.action
  of uaInsertChar:
    if item.col < editor.buffer.lines[item.row].len:
      editor.buffer.lines[item.row].delete(item.col .. item.col)
  of uaDeleteChar:
    editor.buffer.lines[item.row].insert(item.text, item.col)
  of uaDeleteLine:
    editor.buffer.lines.insert(item.text, item.row)
  of uaInsertLine:
    if item.row < editor.buffer.lines.len:
      editor.buffer.lines.delete(item.row)
  of uaSetLine:
    editor.buffer.lines[item.row] = item.text
  editor.buffer.dirty = true

proc handleNormalMode(editor: Editor, key: Key) =
  if key.ord >= 0 and key.ord < 256:
    let ch = chr(key.ord)
    case ch
    of 'i': editor.mode = modeInsert
    of 'h': editor.cursorCol = max(0, editor.cursorCol - 1)
    of 'j': editor.cursorRow += 1
    of 'k': editor.cursorRow = max(0, editor.cursorRow - 1)
    of 'l': editor.cursorCol += 1
    of ':':
      editor.mode = modeCommand
      editor.cmdBuffer = ":"
    of 'd':
      let k2 = getKey()
      if k2 == Key.D:  
        editor.pushUndo(uaDeleteLine, editor.cursorRow, 0, editor.buffer.lines[editor.cursorRow])
        editor.buffer.deleteLine(editor.cursorRow)
        editor.cursorRow = min(editor.cursorRow, editor.buffer.lines.high.max(0))
    of 'y':
      let k2 = getKey()
      if k2 == Key.Y: 
        editor.yankBuffer = editor.buffer.lines[editor.cursorRow]
    of 'p':
      if editor.yankBuffer != "":
        editor.pushUndo(uaInsertLine, editor.cursorRow + 1, 0)
        editor.buffer.insertLine(editor.cursorRow + 1, editor.yankBuffer)
        editor.cursorRow += 1
    of 'u':
      editor.undo()
    of 'q':
      editor.running = false
    else: discard
  elif key == Key.Escape:
    editor.running = false

  editor.clampCursor()

proc handleCommandMode(editor: Editor, key: Key) =
  if key == Key.Enter:
    let cmd = editor.cmdBuffer
    if cmd == ":q" or cmd == ":q!":
      editor.running = false
    elif cmd == ":w":
      if editor.buffer.save():
        editor.cmdBuffer = ":w  (wrote)"
      else:
        editor.cmdBuffer = ":w  (error)"
    elif cmd == ":wq" or cmd == ":x":
      discard editor.buffer.save()
      editor.running = false
    editor.mode = modeNormal
    editor.cmdBuffer = ""
  elif key == Key.Backspace:
    if editor.cmdBuffer.len > 1:
      editor.cmdBuffer.setLen(editor.cmdBuffer.len - 1)
    else:
      editor.mode = modeNormal
      editor.cmdBuffer = ""
  elif key == Key.Escape:
    editor.mode = modeNormal
    editor.cmdBuffer = ""
  elif key.ord > 0:
    editor.cmdBuffer &= chr(key.ord)

proc handleInsertMode(editor: Editor, key: Key) =
  case key
  of Key.Escape:
    editor.mode = modeNormal
  of Key.Enter:
    let line = editor.buffer.getLine(editor.cursorRow)
    let col = min(editor.cursorCol, line.len)
    editor.pushUndo(uaSetLine, editor.cursorRow, 0, line)
    editor.buffer.setLine(editor.cursorRow, line[0..<col])
    editor.buffer.insertLine(editor.cursorRow + 1, line[col..^1])
    editor.cursorRow += 1
    editor.cursorCol = 0
  of Key.Backspace:
    if editor.cursorCol > 0:
      editor.pushUndo(uaInsertChar, editor.cursorRow, editor.cursorCol - 1, $editor.buffer.lines[editor.cursorRow][editor.cursorCol - 1])
      editor.cursorCol -= 1
      editor.buffer.deleteChar(editor.cursorRow, editor.cursorCol)
    elif editor.cursorRow > 0:
      let prevLen = editor.buffer.lines[editor.cursorRow - 1].len
      editor.cursorRow -= 1
      editor.cursorCol = prevLen
      editor.buffer.deleteLine(editor.cursorRow + 1)
  else:
    if key.ord in 32..126:
      let ch = chr(key.ord)
      editor.pushUndo(uaDeleteChar, editor.cursorRow, editor.cursorCol, $ch)
      editor.buffer.insertChar(editor.cursorRow, editor.cursorCol, ch)
      editor.cursorCol += 1
  editor.clampCursor()
  editor.buffer.dirty = true

proc render(editor: Editor) =
  editor.screenWidth = terminalWidth()
  editor.screenHeight = terminalHeight()
  var tb = newTerminalBuffer(editor.screenWidth, editor.screenHeight)

  for i in 0..<min(editor.screenHeight-1, editor.buffer.getLineCount()):
    let line = editor.buffer.getLine(i)
    tb.write(0, i, if line.len > editor.screenWidth: line[0..<editor.screenWidth] else: line)

  for i in editor.buffer.getLineCount() ..< editor.screenHeight-1:
    tb.write(0, i, fgCyan, "~")

  let status = case editor.mode
    of modeNormal: " NORMAL "
    of modeInsert: " INSERT "
    of modeCommand: " " & editor.cmdBuffer & " "

  tb.write(0, editor.screenHeight-1, bgWhite, fgBlack, status)
  tb.write(status.len, editor.screenHeight-1, " ".repeat(editor.screenWidth - status.len))

  if editor.cursorRow < editor.screenHeight - 1:
    let x = min(editor.cursorCol, editor.screenWidth - 1)
    let y = editor.cursorRow
    let line = editor.buffer.getLine(editor.cursorRow)
    let ch = if editor.cursorCol < line.len: line[editor.cursorCol] else: ' '

    case editor.mode
    of modeNormal:
      tb.write(x, y, bgWhite, fgBlack, $ch)
    of modeInsert:
      if editor.cursorCol < line.len:
        tb.write(x, y, fgBlack, bgCyan, $ch)
      else:
        tb.write(x, y, fgCyan, "▏")
    of modeCommand:
      tb.write(x, y, bgWhite, fgBlack, $ch)

  tb.display()

proc run(editor: Editor) =
  illwillInit(fullscreen = true)
  hideCursor()
  defer: illwillDeinit(); showCursor()

  while editor.running:
    editor.render()
    let key = getKey()
    if key != Key.None:
      case editor.mode
      of modeNormal: editor.handleNormalMode(key)
      of modeInsert: editor.handleInsertMode(key)
      of modeCommand: editor.handleCommandMode(key)
    else:
      sleep(10)

when isMainModule:
  let filename = if paramCount() > 0: paramStr(1) else: ""
  newEditor(filename).run()
