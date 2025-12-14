import types
import core/buffer
import editor/viewpoint
import illwill

proc handleNavigationKeys*(editor: Editor, key: Key) =
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
