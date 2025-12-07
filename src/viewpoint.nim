import types
import core/buffer

proc clampCursor*(editor: Editor) =
  editor.cursorRow = editor.cursorRow.clamp(0, max(0, editor.buffer.lines.high))
  let line = editor.buffer.getLine(editor.cursorRow)
  editor.cursorCol = editor.cursorCol.clamp(0, line.len)

proc ensureCursorVisible*(editor: Editor) =
  if editor.cursorRow < editor.viewportRow:
    editor.viewportRow = max(0, editor.cursorRow)
  elif editor.cursorRow >= editor.viewportRow + editor.screenHeight - 2:
    editor.viewportRow = editor.cursorRow - editor.screenHeight + 3
  
  if editor.cursorCol < editor.viewportCol:
    editor.viewportCol = max(0, editor.cursorCol)
  elif editor.cursorCol >= editor.viewportCol + editor.screenWidth - 10:  
    editor.viewportCol = editor.cursorCol - editor.screenWidth + 11
