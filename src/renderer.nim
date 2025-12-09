import std/strutils
import illwill
import core/buffer
import tui/syntax
import types

proc getClosestTermColor(r, g, b: int): ForegroundColor =
  let brightness = (r + g + b) div 3
  
  if r > g and r > b:
    if r > 192: return fgRed
    else: return fgRed
  elif g > r and g > b:
    if g > 192: return fgGreen
    else: return fgGreen
  elif b > r and b > g:
    if b > 192: return fgBlue
    else: return fgBlue
  elif r > 150 and g > 150 and b < 100:
    return fgYellow
  elif r > 150 and b > 150 and g < 100:
    return fgMagenta
  elif g > 150 and b > 150 and r < 100:
    return fgCyan
  elif brightness < 64:
    return fgBlack
  elif brightness < 192:
    return fgWhite
  else:
    return fgWhite

proc getClosestTermBgColor(r, g, b: int): BackgroundColor =
  let brightness = (r + g + b) div 3
  
  if r > g and r > b:
    if r > 192: return bgRed
    else: return bgRed
  elif g > r and g > b:
    if g > 192: return bgGreen
    else: return bgGreen
  elif b > r and b > g:
    if b > 192: return bgBlue
    else: return bgBlue
  elif r > 150 and g > 150 and b < 100:
    return bgYellow
  elif r > 150 and b > 150 and g < 100:
    return bgMagenta
  elif g > 150 and b > 150 and r < 100:
    return bgCyan
  elif brightness < 64:
    return bgBlack
  elif brightness < 192:
    return bgWhite
  else:
    return bgWhite

proc parseNamedColor(colorName: string): ForegroundColor =
  case colorName.toLowerAscii()
  of "black": fgBlack
  of "red": fgRed
  of "green": fgGreen
  of "yellow": fgYellow
  of "blue": fgBlue
  of "magenta": fgMagenta
  of "cyan": fgCyan
  of "white": fgWhite
  of "lightgray", "lightgrey": fgWhite
  of "darkgray", "darkgrey": fgBlack
  else: fgWhite 

proc parseNamedBgColor(colorName: string): BackgroundColor =
  case colorName.toLowerAscii()
  of "black": bgBlack
  of "red": bgRed
  of "green": bgGreen
  of "yellow": bgYellow
  of "blue": bgBlue
  of "magenta": bgMagenta
  of "cyan": bgCyan
  of "white": bgWhite
  of "lightgray", "lightgrey": bgWhite
  of "darkgray", "darkgrey": bgBlack
  else: bgBlack

proc render*(editor: Editor) =
  editor.screenWidth = terminalWidth()
  editor.screenHeight = terminalHeight()
  var tb = newTerminalBuffer(editor.screenWidth, editor.screenHeight)
  
  let theme = editor.themeManager.currentTheme
  let lineCount = editor.buffer.getLineCount()
  let lineNumWidth = if editor.showLineNumbers: max(4, ($lineCount).len + 1) else: 0
  
  let bgColor = parseNamedBgColor(theme.bg)
  let fgColor = parseNamedColor(theme.fg)
  let lineNumFgColor = parseNamedColor(theme.lineNumFg)
  let lineNumBgColor = parseNamedBgColor(theme.lineNumBg)
  let currentLineFgColor = parseNamedColor(theme.currentLineFg)
  let currentLineBgColor = parseNamedBgColor(theme.currentLineBg)
  let statusFg = parseNamedColor(theme.statusFg)
  let statusBg = parseNamedBgColor(theme.statusBg)
  
  let commentFgColor = parseNamedColor(theme.commentFg)
  let keywordFgColor = parseNamedColor(theme.keywordFg)
  let stringFgColor = parseNamedColor(theme.stringFg)
  let numberFgColor = parseNamedColor(theme.numberFg)
  
  for i in 0..<editor.screenHeight - 1:
    tb.write(0, i, fgColor, bgColor, " ".repeat(editor.screenWidth))
  
  for i in 0..<min(editor.screenHeight - 1, lineCount - editor.viewportRow):
    let lineIdx = editor.viewportRow + i
    let line = editor.buffer.getLine(lineIdx)
    
    let textStartCol = if editor.showLineNumbers: lineNumWidth else: 0
    let maxTextWidth = editor.screenWidth - textStartCol - 1
    
    if editor.showLineNumbers:
      let lineNum = $(lineIdx + 1)
      let isCurrentLine = (lineIdx == editor.cursorRow)
      
      if isCurrentLine:
        tb.write(0, i, 
                 currentLineFgColor, 
                 currentLineBgColor, 
                 align(lineNum, lineNumWidth - 1))
        tb.write(lineNumWidth - 1, i, 
                 currentLineFgColor, 
                 currentLineBgColor, "|")
      else:
        tb.write(0, i, 
                 lineNumFgColor, 
                 lineNumBgColor, 
                 align(lineNum, lineNumWidth - 1))
        tb.write(lineNumWidth - 1, i, 
                 lineNumFgColor, 
                 lineNumBgColor, "|")
    
    let tokens = if editor.syntaxEnabled and editor.language != langNone:
               tokenizeLine(line, editor.language, true)
             else:
               tokenizeLine(line, langNone, false)

    var col = textStartCol
    for token in tokens:
      if col >= editor.screenWidth: break
      
      let tokenColor = case token.tokenType
        of tokKeyword: keywordFgColor
        of tokString: stringFgColor
        of tokNumber: numberFgColor
        of tokComment: commentFgColor
        of tokOperator: keywordFgColor
        of tokType: keywordFgColor
        of tokFunction: stringFgColor
        else: fgColor
      
      let lineBgColor = if lineIdx == editor.cursorRow: currentLineBgColor else: bgColor
      
      for ch in token.text:
        if col >= editor.screenWidth: break
        if col >= textStartCol:  
          tb.write(col, i, tokenColor, lineBgColor, $ch)
        inc(col)
    
    while col < editor.screenWidth:
      let lineBgColor = if lineIdx == editor.cursorRow: currentLineBgColor else: bgColor
      tb.write(col, i, fgColor, lineBgColor, " ")
      inc(col)

  for i in (lineCount - editor.viewportRow)..<(editor.screenHeight - 1):
    let textStartCol = if editor.showLineNumbers: lineNumWidth else: 0
    tb.write(textStartCol, i, lineNumFgColor, bgColor, "~")
  
  let status = case editor.mode
    of modeNormal:
      if editor.pendingOp == opDelete: " NORMAL "
      elif editor.pendingOp == opYank: " NORMAL "
      else: " NORMAL "
    of modeInsert: " INSERT "
    of modeCommand: " " & editor.cmdBuffer & " "
  
  let fileInfo = if editor.buffer.dirty: "[+] " & editor.buffer.name else: editor.buffer.name
  let position = "Ln " & $(editor.cursorRow + 1) & ", Col " & $(editor.cursorCol + 1)
  let percent = if lineCount > 0: 
    " " & $(int((editor.cursorRow + 1) / lineCount * 100)) & "%"
  else: " 0%"
  
  let countText = if editor.count > 0: $editor.count else: ""
  let pendingOpText = case editor.pendingOp
    of opDelete: "d"
    of opYank: "y"
    else: ""
  
  let statusWidth = status.len
  let infoText = " " & fileInfo & " "
  let positionText = " " & position & percent & " "
  
  var pendingText = ""
  if countText != "" or pendingOpText != "":
    pendingText = " " & countText & pendingOpText & " "
  
  tb.write(0, editor.screenHeight - 1, statusFg, statusBg, " ".repeat(editor.screenWidth))
  
  tb.write(0, editor.screenHeight - 1, statusFg, statusBg, status)
  
  let infoStart = statusWidth
  tb.write(infoStart, editor.screenHeight - 1, statusFg, statusBg, infoText)
  
  let posStart = editor.screenWidth - positionText.len - pendingText.len
  if posStart > infoStart + infoText.len:  
    tb.write(posStart, editor.screenHeight - 1, statusFg, statusBg, positionText)
    if pendingText != "":
      tb.write(editor.screenWidth - pendingText.len, editor.screenHeight - 1, fgBlack, bgYellow, pendingText)
  
  if editor.cursorRow >= editor.viewportRow and editor.cursorRow < editor.viewportRow + editor.screenHeight - 1:
    let y = editor.cursorRow - editor.viewportRow
    let line = editor.buffer.getLine(editor.cursorRow)
    
    let cursorScreenCol = 
      if editor.showLineNumbers:
        lineNumWidth + (editor.cursorCol - editor.viewportCol)
      else:
        editor.cursorCol - editor.viewportCol
    
    if cursorScreenCol >= 0 and cursorScreenCol < editor.screenWidth:
      let ch = if editor.cursorCol < line.len: line[editor.cursorCol] else: ' '
      
      case editor.mode
      of modeNormal:
        tb.write(cursorScreenCol, y, fgBlack, bgWhite, $ch)
      of modeInsert:
        if editor.cursorCol < line.len:
          tb.write(cursorScreenCol, y, fgBlack, bgCyan, $ch)
        else:
          tb.write(cursorScreenCol, y, fgCyan, currentLineBgColor, "|")
      of modeCommand:
        tb.write(cursorScreenCol, y, fgBlack, bgWhite, $ch)

  tb.display()
