import std/strutils
import ../types

proc findNextOccurrence*(editor: Editor, pattern: string, startRow, startCol: int): (int, int) =
  result = (-1, -1)
  var row = startRow
  var col = startCol + 1
  
  for r in row..editor.buffer.lines.high:
    let line = editor.buffer.lines[r]
    let startIdx = if r == row: col else: 0
    
    let found = line.find(pattern, startIdx)
    if found >= 0:
      return (r, found)
  
  for r in 0..startRow:
    let line = editor.buffer.lines[r]
    let startIdx = if r == startRow: 0 else: 0
    let found = line.find(pattern, startIdx)
    if found >= 0 and (r != startRow or found != startCol):
      return (r, found)

proc findPrevOccurrence*(editor: Editor, pattern: string, startRow, startCol: int): (int, int) =
  result = (-1, -1)
  var row = startRow
  
  if startCol > 0:
    let line = editor.buffer.lines[row]
    let found = line.rfind(pattern, 0, startCol - 1)
    if found >= 0:
      return (row, found)
  
  for r in countdown(row - 1, 0):
    let line = editor.buffer.lines[r]
    let found = line.rfind(pattern)
    if found >= 0:
      return (r, found)
  
  for r in countdown(editor.buffer.lines.high, startRow):
    let line = editor.buffer.lines[r]
    if r == startRow:
      if startCol < line.len:
        let found = line.rfind(pattern, startCol + 1, line.len - 1)
        if found >= 0 and found > startCol:
          return (r, found)
    else:
      let found = line.rfind(pattern)
      if found >= 0:
        return (r, found)
