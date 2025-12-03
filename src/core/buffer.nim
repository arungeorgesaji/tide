import os, strutils  

type
  Buffer* = ref object
    lines*: seq[string]
    filepath*: string
    dirty*: bool
    name*: string

proc newBuffer*(filepath: string = ""): Buffer =
  result = Buffer(
    lines: @[""],
    filepath: filepath,
    dirty: false,
    name: if filepath.len > 0: extractFilename(filepath) else: "[No Name]"
  )
  
  if filepath.len > 0 and fileExists(filepath):
    try:
      result.lines = readFile(filepath).splitLines()
      if result.lines.len == 0:
        result.lines = @[""]
    except:
      result.lines = @["[Error reading file]"]

proc save*(buffer: Buffer): bool =
  if buffer.filepath.len == 0:
    return false
  
  try:
    writeFile(buffer.filepath, buffer.lines.join("\n"))
    buffer.dirty = false
    return true
  except:
    return false

proc insertChar*(buffer: Buffer, line, col: int, ch: char) =
  if line >= buffer.lines.len:
    for i in buffer.lines.len..line:
      buffer.lines.add("")
  
  if col >= buffer.lines[line].len:
    buffer.lines[line] &= ' '.repeat(col - buffer.lines[line].len) & $ch
  else:
    buffer.lines[line].insert($ch, col)
  
  buffer.dirty = true

proc deleteChar*(buffer: Buffer, line, col: int) =
  if line < buffer.lines.len and col < buffer.lines[line].len:
    buffer.lines[line].delete(col..col)
    buffer.dirty = true

proc getLineCount*(buffer: Buffer): int =
  buffer.lines.len

proc getLine*(buffer: Buffer, line: int): string =
  if line < buffer.lines.len:
    buffer.lines[line]
  else:
    ""
