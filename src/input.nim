import std/strutils
import core/buffer
import tui/[theme, syntax]
import utils/[word_navigation, count, config]
import undo, types, viewpoint
import illwill, tables

proc handleNavigationKeys(editor: Editor, key: Key) =
  case key
  of Key.Left:   editor.cursorCol = max(0, editor.cursorCol - 1)
  of Key.Right:  editor.cursorCol += 1
  of Key.Up:     editor.cursorRow = max(0, editor.cursorRow - 1)
  of Key.Down:   editor.cursorRow = min(editor.buffer.lines.high, editor.cursorRow + 1)
  of Key.Home:   editor.cursorCol = 0
  of Key.End:    editor.cursorCol = editor.buffer.getLine(editor.cursorRow).len
  of Key.PageUp:   
    editor.cursorRow = max(0, editor.cursorRow - (editor.screenHeight - 3))
  of Key.PageDown: 
    editor.cursorRow = min(editor.buffer.lines.high, editor.cursorRow + (editor.screenHeight - 3))
  else: return  

  editor.clampCursor()
  editor.ensureCursorVisible()

proc handleNormalMode*(editor: Editor, key: Key) =
  editor.handleNavigationKeys(key) 

  if key in {Key.Left, Key.Right, Key.Up, Key.Down,
             Key.Home, Key.End, Key.PageUp, Key.PageDown}:
    return
  
  if key == Key.Escape:
    editor.pendingOp = opNone
    editor.count = 0
    return
  
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

    if ch in {'0'..'9'}:
      if ch == '0' and editor.count == 0:
        editor.cursorCol = 0
        editor.clampCursor()
        editor.ensureCursorVisible()
        return
      
      editor.count = editor.count * 10 + (ch.ord - '0'.ord)
      return

    case ch
    of 'i': editor.mode = modeInsert
    of 'a': 
      editor.mode = modeInsert
      let line = editor.buffer.getLine(editor.cursorRow)
      if editor.cursorCol < line.len:
        editor.cursorCol += 1
    of 'A':
      editor.mode = modeInsert
      editor.cursorCol = editor.buffer.getLine(editor.cursorRow).len
    of 'o':
      editor.mode = modeInsert
      let newRow = editor.cursorRow + 1
      editor.pushUndo(uaInsertLine, newRow, 0)
      editor.buffer.insertLine(newRow, "")
      editor.cursorRow = newRow
      editor.cursorCol = 0
    of 'O':
      editor.mode = modeInsert
      editor.pushUndo(uaInsertLine, editor.cursorRow, 0)
      editor.buffer.insertLine(editor.cursorRow, "")
      editor.cursorCol = 0
    of 'h':
      let n = editor.takeCount()
      editor.cursorCol = max(0, editor.cursorCol - n)
    of 'l':
      let n = editor.takeCount()
      editor.cursorCol += n
    of 'j':
      let n = editor.takeCount()
      editor.cursorRow = min(editor.buffer.lines.high, editor.cursorRow + n)
    of 'k':
      let n = editor.takeCount()
      editor.cursorRow = max(0, editor.cursorRow - n)
    of 'w':
      let n = editor.takeCount()
      for i in 0..<n:
        editor.moveWordForward()
    of 'b':
      let n = editor.takeCount()
      for i in 0..<n:
        editor.moveWordBackward()
    of 'e':
      let n = editor.takeCount()
      for i in 0..<n:
        editor.moveToEndOfWord()
    of '0':
      editor.cursorCol = 0
    of '$':
      editor.cursorCol = editor.buffer.getLine(editor.cursorRow).len
    of 'g':
      editor.cursorRow = 0
      editor.cursorCol = 0
    of 'G':
      editor.cursorRow = editor.buffer.lines.high
      editor.cursorCol = 0
    of ':':
      editor.mode = modeCommand
      editor.cmdBuffer = ":"
    of 'x':
      let line = editor.buffer.getLine(editor.cursorRow)
      if editor.cursorCol < line.len:
        let deletedChar = line[editor.cursorCol]
        editor.pushUndo(uaDeleteChar, editor.cursorRow, editor.cursorCol, $deletedChar)
        editor.buffer.deleteChar(editor.cursorRow, editor.cursorCol)
    of 'X':
      let line = editor.buffer.getLine(editor.cursorRow)
      if editor.cursorCol > 0:
        let deletedChar = line[editor.cursorCol - 1]
        editor.pushUndo(uaDeleteChar, editor.cursorRow, editor.cursorCol - 1, $deletedChar)
        editor.cursorCol -= 1
        editor.buffer.deleteChar(editor.cursorRow, editor.cursorCol)
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

proc handleCommandMode*(editor: Editor, key: Key) =
  editor.handleNavigationKeys(key) 

  if key in {Key.Left, Key.Right, Key.Up, Key.Down,
             Key.Home, Key.End, Key.PageUp, Key.PageDown}:
    return

  if key == Key.Enter:
    let cmd = editor.cmdBuffer
    if cmd == ":q" or cmd == ":q!":
      editor.running = false
    elif cmd == ":w":
      if editor.buffer.save():
        editor.statusMessage = "File saved"
      else:
        editor.statusMessage = "Error saving file"
    elif cmd == ":wq" or cmd == ":x":
      discard editor.buffer.save()
      editor.running = false
    elif cmd == ":set number" or cmd == ":set nu":
      editor.showLineNumbers = true
      editor.statusMessage = "Line numbers enabled"
    elif cmd == ":set nonumber" or cmd == ":set nonu":
      editor.showLineNumbers = false
      editor.statusMessage = "Line numbers disabled"
    elif cmd.startsWith(":theme "):
      let themeName = cmd[7..^1].strip()
      if editor.themeManager.setTheme(themeName):
        editor.statusMessage = "Theme applied: " & themeName
      else:
        editor.statusMessage = "Unknown theme: " & themeName
    elif cmd == ":themes":
      var themeList = ""
      for name in editor.themeManager.themes.keys:
        themeList &= name & " "
      editor.statusMessage = "Available themes: " & themeList
    elif cmd == ":syntax on":
      editor.syntaxEnabled = true
      editor.language = detectLanguage(editor.buffer.name)
      editor.statusMessage = "Syntax highlighting enabled"
      saveSyntaxEnabled(true)
    elif cmd == ":syntax off":
      editor.syntaxEnabled = false
      editor.language = langNone
      editor.statusMessage = "Syntax highlighting disabled"
      saveSyntaxEnabled(false)
    elif cmd.startsWith(":"):
      editor.statusMessage = "Unknown command: " & cmd
    
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

proc handleInsertMode*(editor: Editor, key: Key) =
  editor.handleNavigationKeys(key) 

  if key in {Key.Left, Key.Right, Key.Up, Key.Down,
             Key.Home, Key.End, Key.PageUp, Key.PageDown}:
    return
 
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
  
  of Key.Tab:
    let spacesToInsert = editor.tabWidth - (editor.cursorCol mod editor.tabWidth)
    let spaces = ' '.repeat(spacesToInsert)
    
    editor.pushUndo(uaInsertChar, editor.cursorRow, editor.cursorCol, spaces)
    
    for ch in spaces:
      editor.buffer.insertChar(editor.cursorRow, editor.cursorCol, ch)
      editor.cursorCol += 1

  of Key.Delete:
    let line = editor.buffer.getLine(editor.cursorRow)
    let col = editor.cursorCol

    if col < line.len:
      let deletedChar = line[col]
      editor.pushUndo(uaDeleteChar, editor.cursorRow, col, $deletedChar)
      editor.buffer.deleteChar(editor.cursorRow, col)

    elif editor.cursorRow < editor.buffer.lines.high:
      let nextLine = editor.buffer.lines[editor.cursorRow + 1]
      editor.pushUndo(uaSetLine, editor.cursorRow, 0, line)
      editor.pushUndo(uaInsertLine, editor.cursorRow + 1, 0, nextLine)

      editor.buffer.setLine(editor.cursorRow, line & nextLine)
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
