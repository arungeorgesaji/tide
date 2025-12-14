import types
import search
import illwill

proc handleSearchMode*(editor: Editor, key: Key) =
  if key == Key.Escape:
    editor.mode = modeNormal
    editor.cmdBuffer = ""
    return
  
  if key == Key.Enter:
    if editor.cmdBuffer.len > 1:
      editor.searchPattern = editor.cmdBuffer[1..^1]
      
      let (foundRow, foundCol) = 
        if editor.searchForward:
          editor.findNextOccurrence(editor.searchPattern, editor.cursorRow, editor.cursorCol)
        else:
          editor.findPrevOccurrence(editor.searchPattern, editor.cursorRow, editor.cursorCol)
      
      if foundRow >= 0 and foundCol >= 0:
        editor.cursorRow = foundRow
        editor.cursorCol = foundCol
        let direction = if editor.searchForward: "forward" else: "backward"
        editor.statusMessage = "Pattern found at " & $(foundRow+1) & ":" & $(foundCol+1) & " (" & direction & ")"
      else:
        editor.statusMessage = "Pattern not found: " & editor.searchPattern
    editor.mode = modeNormal
    editor.cmdBuffer = ""
  elif key == Key.Backspace:
    if editor.cmdBuffer.len > 1:
      editor.cmdBuffer.setLen(editor.cmdBuffer.len - 1)
    else:
      editor.mode = modeNormal
      editor.cmdBuffer = ""
  elif key.ord > 0:
    editor.cmdBuffer &= chr(key.ord)
