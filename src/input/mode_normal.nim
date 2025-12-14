import types
import editor/[undo, viewpoint]
import navigation, search
import core/buffer
import utils/[word_navigation, count]
import illwill

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
    of '/':
      editor.mode = modeSearch
      editor.cmdBuffer = "/"
      editor.searchForward = true 
    of '?':
      editor.mode = modeSearch
      editor.cmdBuffer = "?"
      editor.searchForward = false  
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
      if editor.searchPattern != "":
        let (nextRow, nextCol) = 
          if editor.searchForward:
            editor.findNextOccurrence(editor.searchPattern, editor.cursorRow, editor.cursorCol)
          else:
            editor.findPrevOccurrence(editor.searchPattern, editor.cursorRow, editor.cursorCol)
        
        if nextRow >= 0 and nextCol >= 0:
          editor.cursorRow = nextRow
          editor.cursorCol = nextCol
          editor.statusMessage = "Pattern found at " & $(nextRow+1) & ":" & $(nextCol+1)
        else:
          editor.statusMessage = "Pattern not found"
      else:
        editor.showLineNumbers = not editor.showLineNumbers
    of 'N':
      if editor.searchPattern != "":
        let (prevRow, prevCol) = 
          if editor.searchForward:
            editor.findPrevOccurrence(editor.searchPattern, editor.cursorRow, editor.cursorCol)
          else:
            editor.findNextOccurrence(editor.searchPattern, editor.cursorRow, editor.cursorCol)
        
        if prevRow >= 0 and prevCol >= 0:
          editor.cursorRow = prevRow
          editor.cursorCol = prevCol
          editor.statusMessage = "Pattern found at " & $(prevRow+1) & ":" & $(prevCol+1)
        else:
          editor.statusMessage = "Pattern not found"
    of 'L':  
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
