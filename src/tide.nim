#!/usr/bin/env -S nim r

import core/buffer
import tui/theme, tui/syntax
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

  PendingOp = enum
    opNone, opDelete, opYank

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
    language: Language
    pendingOp: PendingOp

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
    themeManager: newThemeManager(getAppDir() / "themes.json"),
    language: detectLanguage(filepath)
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

    if editor.pendingOp != opNone:
      if ch == 'd' and editor.pendingOp == opDelete:
        if editor.cursorRow < editor.buffer.lines.len:
          editor.yankBuffer = editor.buffer.lines[editor.cursorRow]
          editor.pushUndo(uaDeleteLine, editor.cursorRow, 0, editor.buffer.lines[editor.cursorRow])
          editor.buffer.deleteLine(editor.cursorRow)
          editor.cursorRow = min(editor.cursorRow, max(0, editor.buffer.lines.high))
      elif ch == 'y' and editor.pendingOp == opYank:
        if editor.cursorRow < editor.buffer.lines.len:
          editor.yankBuffer = editor.buffer.lines[editor.cursorRow]
      
      editor.pendingOp = opNone  
      editor.clampCursor()
      editor.ensureCursorVisible()
      return

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
      editor.pendingOp = opDelete  
    of 'y':
      editor.pendingOp = opYank    
    of 'p':
      if editor.yankBuffer != "":
        let pasteRow = editor.cursorRow + 1
        editor.pushUndo(uaInsertLine, pasteRow, 0)
        editor.buffer.insertLine(pasteRow, editor.yankBuffer)
        editor.cursorRow = pasteRow         
        editor.cursorCol = 0
    of 'P':
      if editor.yankBuffer != "":
        let pasteRow = editor.cursorRow
        editor.pushUndo(uaInsertLine, pasteRow, 0)
        editor.buffer.insertLine(pasteRow, editor.yankBuffer)
        editor.cursorRow = pasteRow
        editor.cursorCol = 0
    of 'u':
      editor.undo()
    of 'n':  
      editor.showLineNumbers = not editor.showLineNumbers
    of 'q':
      editor.running = false
    else: discard
  elif key == Key.Escape:
    editor.pendingOp = opNone  
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
    elif cmd == ":syntax on":
      editor.language = detectLanguage(editor.buffer.name)
      editor.cmdBuffer = ":syntax on (enabled)"
    elif cmd == ":syntax off":
      editor.language = langNone
      editor.cmdBuffer = ":syntax off (disabled)"
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

proc getClosestTermColor(r, g, b: int): ForegroundColor =
  let brightness = (r + g + b) div 3
  
  if r > g and r > b:
    if r > 192: return fgRed
    else: return fgRed
  elif g > r and g > b:
    if g > 192: return fgGreen
    else: return fgGreen
  elif b > r and b > g:
    if b > 192: return fgBlue
    else: return fgBlue
  elif r > 150 and g > 150 and b < 100:
    return fgYellow
  elif r > 150 and b > 150 and g < 100:
    return fgMagenta
  elif g > 150 and b > 150 and r < 100:
    return fgCyan
  elif brightness < 64:
    return fgBlack
  elif brightness < 192:
    return fgWhite
  else:
    return fgWhite

proc getClosestTermBgColor(r, g, b: int): BackgroundColor =
  let brightness = (r + g + b) div 3
  
  if r > g and r > b:
    if r > 192: return bgRed
    else: return bgRed
  elif g > r and g > b:
    if g > 192: return bgGreen
    else: return bgGreen
  elif b > r and b > g:
    if b > 192: return bgBlue
    else: return bgBlue
  elif r > 150 and g > 150 and b < 100:
    return bgYellow
  elif r > 150 and b > 150 and g < 100:
    return bgMagenta
  elif g > 150 and b > 150 and r < 100:
    return bgCyan
  elif brightness < 64:
    return bgBlack
  elif brightness < 192:
    return bgWhite
  else:
    return bgWhite

proc parseNamedColor(colorName: string): ForegroundColor =
  case colorName.toLowerAscii()
  of "black": fgBlack
  of "red": fgRed
  of "green": fgGreen
  of "yellow": fgYellow
  of "blue": fgBlue
  of "magenta": fgMagenta
  of "cyan": fgCyan
  of "white": fgWhite
  of "lightgray", "lightgrey": fgWhite
  of "darkgray", "darkgrey": fgBlack
  else: fgWhite 

proc parseNamedBgColor(colorName: string): BackgroundColor =
  case colorName.toLowerAscii()
  of "black": bgBlack
  of "red": bgRed
  of "green": bgGreen
  of "yellow": bgYellow
  of "blue": bgBlue
  of "magenta": bgMagenta
  of "cyan": bgCyan
  of "white": bgWhite
  of "lightgray", "lightgrey": bgWhite
  of "darkgray", "darkgrey": bgBlack
  else: bgBlack

proc render(editor: Editor) =
  editor.screenWidth = terminalWidth()
  editor.screenHeight = terminalHeight()
  var tb = newTerminalBuffer(editor.screenWidth, editor.screenHeight)
  
  let theme = editor.themeManager.currentTheme
  let lineCount = editor.buffer.getLineCount()
  let lineNumWidth = if editor.showLineNumbers: max(4, ($lineCount).len + 1) else: 0
  
  let bgColor = parseNamedBgColor(theme.bg)
  let fgColor = parseNamedColor(theme.fg)
  let lineNumFgColor = parseNamedColor(theme.lineNumFg)
  let lineNumBgColor = parseNamedBgColor(theme.lineNumBg)
  let currentLineFgColor = parseNamedColor(theme.currentLineFg)
  let currentLineBgColor = parseNamedBgColor(theme.currentLineBg)
  let statusFg = parseNamedColor(theme.statusFg)
  let statusBg = parseNamedBgColor(theme.statusBg)
  
  let commentFgColor = parseNamedColor(theme.commentFg)
  let keywordFgColor = parseNamedColor(theme.keywordFg)
  let stringFgColor = parseNamedColor(theme.stringFg)
  let numberFgColor = parseNamedColor(theme.numberFg)
  
  for i in 0..<editor.screenHeight - 1:
    tb.write(0, i, fgColor, bgColor, " ".repeat(editor.screenWidth))
  
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
                 currentLineFgColor, 
                 currentLineBgColor, 
                 align(lineNum, lineNumWidth - 1))
        tb.write(lineNumWidth - 1, i, 
                 currentLineFgColor, 
                 currentLineBgColor, "│")
      else:
        tb.write(0, i, 
                 lineNumFgColor, 
                 lineNumBgColor, 
                 align(lineNum, lineNumWidth - 1))
        tb.write(lineNumWidth - 1, i, 
                 lineNumFgColor, 
                 lineNumBgColor, "│")
    
    let tokens = tokenizeLine(line, editor.language)
    
    var col = textStartCol
    for token in tokens:
      if col >= editor.screenWidth: break
      
      let tokenColor = case token.tokenType
        of tokKeyword: keywordFgColor
        of tokString: stringFgColor
        of tokNumber: numberFgColor
        of tokComment: commentFgColor
        of tokOperator: keywordFgColor
        of tokType: keywordFgColor
        of tokFunction: stringFgColor
        else: fgColor
      
      let lineBgColor = if lineIdx == editor.cursorRow: currentLineBgColor else: bgColor
      
      for ch in token.text:
        if col >= editor.screenWidth: break
        if col >= textStartCol:  
          tb.write(col, i, tokenColor, lineBgColor, $ch)
        inc(col)
    
    while col < editor.screenWidth:
      let lineBgColor = if lineIdx == editor.cursorRow: currentLineBgColor else: bgColor
      tb.write(col, i, fgColor, lineBgColor, " ")
      inc(col)

  for i in (lineCount - editor.viewportRow)..<(editor.screenHeight - 1):
    let textStartCol = if editor.showLineNumbers: lineNumWidth else: 0
    tb.write(textStartCol, i, lineNumFgColor, bgColor, "~")
  
  let status = case editor.mode
    of modeNormal:
      if editor.pendingOp == opDelete: " DELETE LINE "
      elif editor.pendingOp == opYank: " YANK LINE "
      else: " NORMAL "
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
          tb.write(cursorScreenCol, y, fgCyan, currentLineBgColor, "▏")
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
