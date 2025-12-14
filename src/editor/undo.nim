import ../types 
import viewpoint
import strutils

proc pushUndo*(editor: Editor, action: UndoAction, row, col: int, text: string = "") =
  editor.undoStack.add(UndoItem(action: action, row: row, col: col, text: text))

proc undo*(editor: Editor) =
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
