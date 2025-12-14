import std/strutils
import ../[types, undo, viewpoint]
import ../core/buffer
import navigation
import illwill

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
