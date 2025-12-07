import ../types
import strutils

proc isWordChar(c: char): bool =
  return c.isAlphaNumeric() or c == '_'

proc moveWordForward*(editor: Editor) =
  var row = editor.cursorRow
  var col = editor.cursorCol

  if row > editor.buffer.lines.high: return

  var line = editor.buffer.lines[row]

  if col < line.len and isWordChar(line[col]):
    while col < line.len and isWordChar(line[col]):
      col += 1

  while col < line.len and not isWordChar(line[col]):
    col += 1

  while col >= line.len and row < editor.buffer.lines.high:
    row += 1
    line = editor.buffer.lines[row]
    col = 0
    if line.len > 0: break

  editor.cursorRow = row
  editor.cursorCol = col


proc moveWordBackward*(editor: Editor) =
  var row = editor.cursorRow
  var col = editor.cursorCol

  if row > editor.buffer.lines.high: return

  if col == 0 and row > 0:
    row -= 1
    col = editor.buffer.lines[row].len

  var line = editor.buffer.lines[row]
  if col > line.len: col = line.len

  while col > 0 and not isWordChar(line[col-1]):
    col -= 1

  while col > 0 and isWordChar(line[col-1]):
    col -= 1

  editor.cursorRow = row
  editor.cursorCol = col


proc moveToEndOfWord*(editor: Editor) =
  var row = editor.cursorRow
  var col = editor.cursorCol

  if row > editor.buffer.lines.high: return
  var line = editor.buffer.lines[row]

  while col < line.len and not isWordChar(line[col]):
    col += 1

  while col < line.len and isWordChar(line[col]):
    col += 1

  if col > 0: col -= 1

  editor.cursorRow = row
  editor.cursorCol = col
