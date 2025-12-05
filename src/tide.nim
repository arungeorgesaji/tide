#!/usr/bin/env -S nim r

import core/buffer
import tui/theme
import strutils, os, illwill, tables, sequtils, math

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
    viewportRow: int  
    viewportCol: int  
    showLineNumbers: bool
    themeManager: ThemeManager

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
    yankBuffer: "",
    viewportRow: 0,
    viewportCol: 0,
    showLineNumbers: true,
    themeManager: newThemeManager()
  )

proc clampCursor(editor: Editor) =
  editor.cursorRow = editor.cursorRow.clamp(0, max(0, editor.buffer.lines.high))
  let line = editor.buffer.getLine(editor.cursorRow)
  editor.cursorCol = editor.cursorCol.clamp(0, line.len)

proc ensureCursorVisible(editor: Editor) =
  if editor.cursorRow < editor.viewportRow:
    editor.viewportRow = max(0, editor.cursorRow)
  elif editor.cursorRow >= editor.viewportRow + editor.screenHeight - 2:
    editor.viewportRow = editor.cursorRow - editor.screenHeight + 3
  
  if editor.cursorCol < editor.viewportCol:
    editor.viewportCol = max(0, editor.cursorCol)
  elif editor.cursorCol >= editor.viewportCol + editor.screenWidth - 10:  
    editor.viewportCol = editor.cursorCol - editor.screenWidth + 11

proc undo(editor: Editor) =
  if editor.undoStack.len == 0:
    return

  let item = editor.undoStack.pop()

  case item.action
  of uaInsertChar:
    if item.col <= editor.buffer.lines[item.row].high:
      editor.buffer.lines[item.row].delete(item.col .. item.col)
    editor.cursorCol = item.col
  of uaDeleteChar:
    editor.buffer.lines[item.row].insert(item.text, item.col)
    editor.cursorCol = item.col + 1
  of uaInsertLine:
    if item.row < editor.buffer.lines.len:
      editor.buffer.lines.delete(item.row)
    editor.cursorRow = max(0, item.row - 1)
  of uaDeleteLine:
    editor.buffer.lines.insert(item.text, item.row)
    editor.cursorRow = item.row
  of uaSetLine:
    editor.buffer.lines[item.row] = item.text
    editor.cursorRow = item.row

  editor.buffer.dirty = true
  editor.clampCursor()
  editor.ensureCursorVisible()

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
        editor.cursorRow = min(editor.cursorRow, max(0, editor.buffer.lines.high))
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
    of 'n':  
      editor.showLineNumbers = not editor.showLineNumbers
    of 'q':
      editor.running = false
    else: discard
  elif key == Key.Escape:
    editor.running = false
  elif key == Key.PageDown:
    editor.cursorRow = min(editor.buffer.lines.high, editor.cursorRow + editor.screenHeight - 2)
  elif key == Key.PageUp:
    editor.cursorRow = max(0, editor.cursorRow - editor.screenHeight + 2)

  editor.clampCursor()
  editor.ensureCursorVisible()

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
    elif cmd == ":set number" or cmd == ":set nu":
      editor.showLineNumbers = true
    elif cmd == ":set nonumber" or cmd == ":set nonu":
      editor.showLineNumbers = false
    elif cmd.startsWith(":theme "):
      let themeName = cmd[7..^1].strip()
      if editor.themeManager.setTheme(themeName):
        editor.cmdBuffer = ":theme " & themeName & " (applied)"
      else:
        editor.cmdBuffer = ":theme (unknown theme)"
    elif cmd == ":themes":
      var themeList = ""
      for name in editor.themeManager.themes.keys:
        themeList &= name & " "
      editor.cmdBuffer = ":themes: " & themeList
    elif cmd.startsWith(":"):
      editor.cmdBuffer = cmd & " (unknown)"
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
    let originalLine = line
    editor.pushUndo(uaSetLine, editor.cursorRow, 0, originalLine)
    editor.pushUndo(uaInsertLine, editor.cursorRow + 1, 0)
    editor.buffer.setLine(editor.cursorRow, line[0..<col])
    editor.buffer.insertLine(editor.cursorRow + 1, line[col..^1])
    editor.cursorRow += 1
    editor.cursorCol = 0

  of Key.Backspace:
    if editor.cursorCol > 0:
      let deletedChar = editor.buffer.lines[editor.cursorRow][editor.cursorCol - 1]
      editor.pushUndo(uaDeleteChar, editor.cursorRow, editor.cursorCol - 1, $deletedChar)
      editor.cursorCol -= 1
      editor.buffer.deleteChar(editor.cursorRow, editor.cursorCol)
    elif editor.cursorRow > 0:
      let currentLine = editor.buffer.lines[editor.cursorRow]
      let prevLine = editor.buffer.lines[editor.cursorRow - 1]
      editor.pushUndo(uaSetLine, editor.cursorRow - 1, 0, prevLine)
      editor.pushUndo(uaInsertLine, editor.cursorRow, 0, currentLine)
      let prevLen = prevLine.len
      editor.cursorRow -= 1
      editor.cursorCol = prevLen
      editor.buffer.deleteLine(editor.cursorRow + 1)

  else:
    if key.ord in 32..126:  
      let ch = chr(key.ord)
      editor.pushUndo(uaInsertChar, editor.cursorRow, editor.cursorCol, $ch)
      editor.buffer.insertChar(editor.cursorRow, editor.cursorCol, ch)
      editor.cursorCol += 1

  editor.clampCursor()
  editor.ensureCursorVisible()
  editor.buffer.dirty = true

proc rgbToFgColor(rgb: RGB): ForegroundColor =
  let brightness = (rgb.r + rgb.g + rgb.b) div 3
  if brightness < 64: return fgBlack
  elif brightness < 128: return fgRed
  elif brightness < 192: return fgGreen
  else: return fgWhite

proc rgbToBgColor(rgb: RGB): BackgroundColor =
  let brightness = (rgb.r + rgb.g + rgb.b) div 3
  if brightness < 64: return bgBlack
  elif brightness < 128: return bgRed
  elif brightness < 192: return bgGreen
  else: return bgWhite

proc render(editor: Editor) =
  editor.screenWidth = terminalWidth()
  editor.screenHeight = terminalHeight()
  var tb = newTerminalBuffer(editor.screenWidth, editor.screenHeight)
  
  let theme = editor.themeManager.currentTheme
  let lineCount = editor.buffer.getLineCount()
  let lineNumWidth = if editor.showLineNumbers: max(4, ($lineCount).len + 1) else: 0
  
  for i in 0..<min(editor.screenHeight - 1, lineCount - editor.viewportRow):
    let lineIdx = editor.viewportRow + i
    let line = editor.buffer.getLine(lineIdx)
    
    let textStartCol = if editor.showLineNumbers: lineNumWidth else: 0
    let maxTextWidth = editor.screenWidth - textStartCol - 1
    
    if editor.showLineNumbers:
      let lineNum = $(lineIdx + 1)
      let isCurrentLine = (lineIdx == editor.cursorRow)
      
      if isCurrentLine:
        tb.write(0, i, 
                 rgbToFgColor(theme.currentLineFg), 
                 rgbToBgColor(theme.currentLineBg), 
                 align(lineNum, lineNumWidth - 1))
        tb.write(lineNumWidth - 1, i, 
                 rgbToFgColor(theme.currentLineFg), 
                 rgbToBgColor(theme.currentLineBg), "│")
      else:
        tb.write(0, i, 
                 rgbToFgColor(theme.lineNumFg), 
                 align(lineNum, lineNumWidth - 1))
        tb.write(lineNumWidth - 1, i, 
                 rgbToFgColor(theme.lineNumFg), "│")
    
    if editor.viewportCol < line.len:
      let visibleText = line[editor.viewportCol..<min(line.len, editor.viewportCol + maxTextWidth)]
      tb.write(textStartCol, i, rgbToFgColor(theme.fg), visibleText)
    
    let textLen = if editor.viewportCol < line.len: 
        min(line.len - editor.viewportCol, maxTextWidth)
      else: 0
    if textLen < maxTextWidth:
      tb.write(textStartCol + textLen, i, " ".repeat(maxTextWidth - textLen))

  for i in (lineCount - editor.viewportRow)..<(editor.screenHeight - 1):
    let textStartCol = if editor.showLineNumbers: lineNumWidth else: 0
    tb.write(textStartCol, i, rgbToFgColor(theme.lineNumFg), "~")
  
  let status = case editor.mode
    of modeNormal: " NORMAL "
    of modeInsert: " INSERT "
    of modeCommand: " " & editor.cmdBuffer & " "
  
  let fileInfo = if editor.buffer.dirty: "[+] " & editor.buffer.name else: editor.buffer.name
  let position = "Ln " & $(editor.cursorRow + 1) & ", Col " & $(editor.cursorCol + 1)
  let percent = if lineCount > 0: 
    " " & $(int((editor.cursorRow + 1) / lineCount * 100)) & "%"
  else: " 0%"
  
  let statusWidth = status.len
  let infoText = " " & fileInfo & " "
  let positionText = " " & position & percent & " "
  
  let statusFg = rgbToFgColor(theme.statusFg)
  let statusBg = rgbToBgColor(theme.statusBg)
  
  tb.write(0, editor.screenHeight - 1, statusFg, statusBg, " ".repeat(editor.screenWidth))
  
  tb.write(0, editor.screenHeight - 1, statusFg, statusBg, status)
  
  let infoStart = statusWidth
  tb.write(infoStart, editor.screenHeight - 1, statusFg, statusBg, infoText)
  
  let posStart = editor.screenWidth - positionText.len
  if posStart > infoStart + infoText.len:  
    tb.write(posStart, editor.screenHeight - 1, statusFg, statusBg, positionText)
  
  if editor.cursorRow >= editor.viewportRow and editor.cursorRow < editor.viewportRow + editor.screenHeight - 1:
    let y = editor.cursorRow - editor.viewportRow
    let line = editor.buffer.getLine(editor.cursorRow)
    
    let cursorScreenCol = 
      if editor.showLineNumbers:
        lineNumWidth + (editor.cursorCol - editor.viewportCol)
      else:
        editor.cursorCol - editor.viewportCol
    
    if cursorScreenCol >= 0 and cursorScreenCol < editor.screenWidth:
      let ch = if editor.cursorCol < line.len: line[editor.cursorCol] else: ' '
      
      case editor.mode
      of modeNormal:
        tb.write(cursorScreenCol, y, fgBlack, bgWhite, $ch)
      of modeInsert:
        if editor.cursorCol < line.len:
          tb.write(cursorScreenCol, y, fgBlack, bgCyan, $ch)
        else:
          tb.write(cursorScreenCol, y, fgCyan, "▏")
      of modeCommand:
        tb.write(cursorScreenCol, y, fgBlack, bgWhite, $ch)

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
