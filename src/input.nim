import std/[sequtils, strutils]
import core/buffer
import tui/[theme, syntax]
import utils/[word_navigation, count, config, diff]
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
    editor.statusMessage = ""
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
        editor.statusMessage = "file_saved"
      else:
        editor.statusMessage = "error_saving_file"
    elif cmd == ":wq" or cmd == ":x":
      discard editor.buffer.save()
      editor.running = false
    elif cmd.startsWith(":diff "):
      let parts = cmd.split(" ")
      if parts.len == 3:
        let fileA = parts[1]
        let fileB = parts[2]
        let a = readFile(fileA).splitLines()
        let b = readFile(fileB).splitLines()
        editor.diffOriginalBuffer = editor.buffer.lines
        editor.diffBuffer = computeDiff(a, b)
        editor.buffer.lines = editor.diffBuffer
        editor.mode = modeDiff
        editor.statusMessage = "diff mode enabled"
      else:
        editor.statusMessage = "usage: :diff file1 file2"
    elif cmd == ":nodiff":
      if editor.mode == modeDiff:
        editor.buffer.lines = editor.diffOriginalBuffer
        editor.mode = modeNormal
        editor.statusMessage = "diff mode disabled"
    elif cmd == ":set number" or cmd == ":set nu":
      editor.showLineNumbers = true
      editor.statusMessage = "line_numbers_enabled"
    elif cmd == ":set nonumber" or cmd == ":set nonu":
      editor.showLineNumbers = false
      editor.statusMessage = "line_numbers_disabled"
    elif cmd.startsWith(":theme "):
      let themeName = cmd[7..^1].strip()
      if editor.themeManager.setTheme(themeName):
        editor.statusMessage = "themme_applied: " & themeName
      else:
        editor.statusMessage = "unknown_theme: " & themeName
    elif cmd == ":themes":
      editor.popup.previewTheme = editor.themeManager.currentTheme.name
      editor.popup.mode = pmThemeSelector
      editor.popup.items = toSeq(editor.themeManager.themes.keys)
      editor.popup.selectedIndex = 0
      editor.popup.visible = true
      editor.popup.title = "Select Theme"
      editor.popup.scrollOffset = 0
      editor.popup.filter = ""
      editor.popup.filterCursor = 0
      if editor.popup.items.len > 0:
        discard editor.themeManager.setTheme(editor.popup.items[0])
    elif cmd == ":syntax on":
      editor.syntaxEnabled = true
      editor.language = detectLanguage(editor.buffer.name)
      editor.statusMessage = "syntax_highlighting_enabled"
      saveSyntaxEnabled(true)
    elif cmd == ":syntax off":
      editor.syntaxEnabled = false
      editor.language = langNone
      editor.statusMessage = "syntax_highlighting_disabled"
      saveSyntaxEnabled(false)
    elif cmd.startsWith(":"):
      editor.statusMessage = "unknown_command: " & cmd
    
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
  if editor.mode == modeDiff:
    editor.statusMessage = "cannot edit in diff mode"
    editor.mode = modeNormal
    return

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


proc handlePopupNavigation*(editor: Editor, key: Key) =
  case editor.popup.mode
  of pmThemeSelector:
    let previousIndex = editor.popup.selectedIndex
    
    case key
    of Key.Up:
      if editor.popup.selectedIndex > 0:
        dec(editor.popup.selectedIndex)
        if editor.popup.selectedIndex < editor.popup.scrollOffset:
          editor.popup.scrollOffset = editor.popup.selectedIndex
    
    of Key.Down:
      if editor.popup.selectedIndex < editor.popup.items.high:
        inc(editor.popup.selectedIndex)
        let visibleHeight = min(16, editor.screenHeight - 8) - 4
        if editor.popup.selectedIndex >= editor.popup.scrollOffset + visibleHeight:
          editor.popup.scrollOffset = editor.popup.selectedIndex - visibleHeight + 1
    
    of Key.PageUp:
      editor.popup.selectedIndex = max(0, editor.popup.selectedIndex - 10)
      if editor.popup.selectedIndex < editor.popup.scrollOffset:
        editor.popup.scrollOffset = max(0, editor.popup.selectedIndex)
    
    of Key.PageDown:
      editor.popup.selectedIndex = min(editor.popup.items.high, editor.popup.selectedIndex + 10)
      let visibleHeight = min(16, editor.screenHeight - 8) - 4
      if editor.popup.selectedIndex >= editor.popup.scrollOffset + visibleHeight:
        editor.popup.scrollOffset = min(editor.popup.items.high - visibleHeight + 1, 
                                         editor.popup.selectedIndex - visibleHeight + 1)
    
    of Key.Home:
      editor.popup.selectedIndex = 0
      editor.popup.scrollOffset = 0
    
    of Key.End:
      editor.popup.selectedIndex = editor.popup.items.high
      let visibleHeight = min(16, editor.screenHeight - 8) - 4
      editor.popup.scrollOffset = max(0, editor.popup.items.high - visibleHeight + 1)
    
    of Key.Enter:
      let selectedTheme = editor.popup.items[editor.popup.selectedIndex]
      if editor.themeManager.setTheme(selectedTheme):
        editor.statusMessage = "Theme applied: " & selectedTheme
      editor.popup.visible = false
      editor.popup.previewTheme = ""
    
    of Key.Escape:
      if editor.popup.previewTheme != "":
        discard editor.themeManager.setTheme(editor.popup.previewTheme)
      editor.popup.visible = false
      editor.popup.previewTheme = ""
    
    else:
      if key.ord in 32..126:  
        let ch = chr(key.ord)
        editor.popup.filter &= ch
        var filteredItems: seq[string]
        for themeName in toSeq(editor.themeManager.themes.keys):
          if themeName.toLowerAscii().contains(editor.popup.filter.toLowerAscii()):
            filteredItems.add(themeName)
        editor.popup.items = filteredItems
        editor.popup.selectedIndex = min(editor.popup.selectedIndex, filteredItems.high)
        editor.popup.scrollOffset = 0
      
      elif key == Key.Backspace and editor.popup.filter.len > 0:
        editor.popup.filter.setLen(editor.popup.filter.len - 1)
        if editor.popup.filter == "":
          editor.popup.items = toSeq(editor.themeManager.themes.keys)
        else:
          var filteredItems: seq[string]
          for themeName in toSeq(editor.themeManager.themes.keys):
            if themeName.toLowerAscii().contains(editor.popup.filter.toLowerAscii()):
              filteredItems.add(themeName)
          editor.popup.items = filteredItems
        editor.popup.selectedIndex = min(editor.popup.selectedIndex, editor.popup.items.high)
        editor.popup.scrollOffset = 0
    
    if previousIndex != editor.popup.selectedIndex and editor.popup.items.len > 0:
      let previewTheme = editor.popup.items[editor.popup.selectedIndex]
      discard editor.themeManager.setTheme(previewTheme)
  
  else:
    discard
