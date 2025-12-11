import std/strutils
import illwill
import core/buffer
import tui/[syntax, theme]
import types

type
  RenderContext = object
    tb: TerminalBuffer
    editor: Editor
    theme: ColorTheme
    lineNumWidth: int
    textStartCol: int
    minimapX: int
    minimapWidth: int
    hasMinimap: bool
    bgColor: BackgroundColor
    fgColor: ForegroundColor
    lineNumFgColor: ForegroundColor
    lineNumBgColor: BackgroundColor
    currentLineFgColor: ForegroundColor
    currentLineBgColor: BackgroundColor
    statusFg: ForegroundColor
    statusBg: BackgroundColor
    commentFgColor: ForegroundColor
    keywordFgColor: ForegroundColor
    stringFgColor: ForegroundColor
    numberFgColor: ForegroundColor

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

proc renderPopup(editor: Editor, tb: var TerminalBuffer) =
  let theme = editor.themeManager.currentTheme
  let popupBg = parseNamedBgColor(theme.bg)
  let popupFg = parseNamedColor(theme.fg)
  let selectedBg = parseNamedBgColor(theme.currentLineBg)
  let selectedFg = parseNamedColor(theme.currentLineFg)
  let borderFg = parseNamedColor(theme.lineNumFg)
  
  case editor.popup.mode
  of pmThemeSelector:
    let popupWidth = min(40, editor.screenWidth - 4)
    let popupHeight = min(20, editor.screenHeight - 4)
    let popupX = (editor.screenWidth - popupWidth) div 2
    let popupY = (editor.screenHeight - popupHeight) div 2
    
    tb.write(popupX, popupY, borderFg, popupBg, "+" & "-".repeat(popupWidth - 2) & "+")
    for i in 1..<popupHeight-1:
      tb.write(popupX, popupY + i, borderFg, popupBg, "|")
      tb.write(popupX + popupWidth - 1, popupY + i, borderFg, popupBg, "|")
    tb.write(popupX, popupY + popupHeight - 1, borderFg, popupBg, "+" & "-".repeat(popupWidth - 2) & "+")
    
    let title = " Select Theme "
    tb.write(popupX + (popupWidth - title.len) div 2, popupY, borderFg, popupBg, title)
    
    let itemsStartY = popupY + 2
    let maxVisibleItems = popupHeight - 4
    
    for i in 0..<min(editor.popup.items.len - editor.popup.scrollOffset, maxVisibleItems):
      let itemIndex = i + editor.popup.scrollOffset
      let item = editor.popup.items[itemIndex]
      let displayItem = if item.len > popupWidth - 4: 
                         item[0..<(popupWidth - 7)] & "..."
                       else: 
                         item
      
      if itemIndex == editor.popup.selectedIndex:
        tb.write(popupX + 2, itemsStartY + i, selectedFg, selectedBg, "> " & displayItem & " ".repeat(popupWidth - 4 - displayItem.len - 2))
      else:
        tb.write(popupX + 2, itemsStartY + i, popupFg, popupBg, "  " & displayItem & " ".repeat(popupWidth - 4 - displayItem.len - 2))
    
    if editor.popup.filter != "":
      let filterText = "Filter: " & editor.popup.filter
      tb.write(popupX + 2, popupY + popupHeight - 2, popupFg, popupBg, filterText)
    
    let hint = "[Enter] select [Esc] cancel"
    tb.write(popupX + (popupWidth - hint.len) div 2, popupY + popupHeight - 1, borderFg, popupBg, hint)
  
  else:
    discard

proc initRenderContext(editor: Editor): RenderContext =
  let theme = editor.themeManager.currentTheme
  let lineCount = editor.buffer.getLineCount()
  let lineNumWidth = if editor.showLineNumbers: max(4, ($lineCount).len + 1) else: 0
  let minimapWidth = 12
  let hasMinimap = editor.minimapEnabled and editor.screenWidth > minimapWidth + 20
  
  result = RenderContext(
    tb: newTerminalBuffer(editor.screenWidth, editor.screenHeight),
    editor: editor,
    theme: theme,
    lineNumWidth: lineNumWidth,
    textStartCol: if editor.showLineNumbers: lineNumWidth else: 0,
    minimapX: editor.screenWidth - minimapWidth,
    minimapWidth: minimapWidth,
    hasMinimap: hasMinimap,
    bgColor: parseNamedBgColor(theme.bg),
    fgColor: parseNamedColor(theme.fg),
    lineNumFgColor: parseNamedColor(theme.lineNumFg),
    lineNumBgColor: parseNamedBgColor(theme.lineNumBg),
    currentLineFgColor: parseNamedColor(theme.currentLineFg),
    currentLineBgColor: parseNamedBgColor(theme.currentLineBg),
    statusFg: parseNamedColor(theme.statusFg),
    statusBg: parseNamedBgColor(theme.statusBg),
    commentFgColor: parseNamedColor(theme.commentFg),
    keywordFgColor: parseNamedColor(theme.keywordFg),
    stringFgColor: parseNamedColor(theme.stringFg),
    numberFgColor: parseNamedColor(theme.numberFg)
  )

proc clearScreen(ctx: var RenderContext) =
  for i in 0..<ctx.editor.screenHeight - 1:
    ctx.tb.write(0, i, ctx.fgColor, ctx.bgColor, " ".repeat(ctx.editor.screenWidth))

proc renderLineNumber(ctx: var RenderContext, lineIdx, screenRow: int) =
  if not ctx.editor.showLineNumbers:
    return
    
  let lineNum = $(lineIdx + 1)
  let isCurrentLine = (lineIdx == ctx.editor.cursorRow)
  
  if isCurrentLine:
    ctx.tb.write(0, screenRow, 
                 ctx.currentLineFgColor, 
                 ctx.currentLineBgColor, 
                 align(lineNum, ctx.lineNumWidth - 1))
    ctx.tb.write(ctx.lineNumWidth - 1, screenRow, 
                 ctx.currentLineFgColor, 
                 ctx.currentLineBgColor, "|")
  else:
    ctx.tb.write(0, screenRow, 
                 ctx.lineNumFgColor, 
                 ctx.lineNumBgColor, 
                 align(lineNum, ctx.lineNumWidth - 1))
    ctx.tb.write(ctx.lineNumWidth - 1, screenRow, 
                 ctx.lineNumFgColor, 
                 ctx.lineNumBgColor, "|")

proc getTokenColor(ctx: RenderContext, tokenType: TokenType): ForegroundColor =
  case tokenType
  of tokKeyword: ctx.keywordFgColor
  of tokString: ctx.stringFgColor
  of tokNumber: ctx.numberFgColor
  of tokComment: ctx.commentFgColor
  of tokOperator: ctx.keywordFgColor
  of tokType: ctx.keywordFgColor
  of tokFunction: ctx.stringFgColor
  else: ctx.fgColor

proc renderDiffLine(ctx: var RenderContext, line: string, lineIdx, screenRow: int) =
  let lineBgColor = if lineIdx == ctx.editor.cursorRow: ctx.currentLineBgColor else: ctx.bgColor
  let diffColor = if line.startsWith("+"):
                    parseNamedColor(ctx.theme.diffAdded)
                  elif line.startsWith("-"):
                    parseNamedColor(ctx.theme.diffRemoved)
                  elif line.startsWith("~"):
                    parseNamedColor(ctx.theme.diffModified)
                  else:
                    parseNamedColor(ctx.theme.diffNormal)
  
  var col = ctx.textStartCol
  for ch in line:
    if col >= ctx.editor.screenWidth: break
    if col >= ctx.textStartCol:
      ctx.tb.write(col, screenRow, diffColor, lineBgColor, $ch)
    inc(col)
  
  while col < ctx.editor.screenWidth:
    ctx.tb.write(col, screenRow, ctx.fgColor, lineBgColor, " ")
    inc(col)

proc renderNormalLine(ctx: var RenderContext, line: string, lineIdx, screenRow: int) =
  let tokens = if ctx.editor.syntaxEnabled and ctx.editor.language != langNone:
                 tokenizeLine(line, ctx.editor.language, true)
               else:
                 tokenizeLine(line, langNone, false)
  
  let lineBgColor = if lineIdx == ctx.editor.cursorRow: ctx.currentLineBgColor else: ctx.bgColor
  var col = ctx.textStartCol
  
  for token in tokens:
    if col >= ctx.editor.screenWidth: break
    
    let tokenColor = ctx.getTokenColor(token.tokenType)
    
    for ch in token.text:
      if col >= ctx.editor.screenWidth: break
      if col >= ctx.textStartCol:
        ctx.tb.write(col, screenRow, tokenColor, lineBgColor, $ch)
      inc(col)
  
  while col < ctx.editor.screenWidth:
    ctx.tb.write(col, screenRow, ctx.fgColor, lineBgColor, " ")
    inc(col)

proc renderTextLine(ctx: var RenderContext, lineIdx, screenRow: int) =
  let line = ctx.editor.buffer.getLine(lineIdx)
  
  ctx.renderLineNumber(lineIdx, screenRow)
  
  if ctx.editor.mode == modeDiff:
    ctx.renderDiffLine(line, lineIdx, screenRow)
  else:
    ctx.renderNormalLine(line, lineIdx, screenRow)

proc renderEmptyLines(ctx: var RenderContext, startRow: int) =
  for i in startRow..<(ctx.editor.screenHeight - 1):
    ctx.tb.write(ctx.textStartCol, i, ctx.lineNumFgColor, ctx.bgColor, "~")

proc buildStatusText(editor: Editor): string =
  case editor.mode
  of modeNormal:
    " NORMAL "
  of modeInsert:
    " INSERT "
  of modeCommand:
    " " & editor.cmdBuffer & " "
  of modeDiff:
    " DIFF "

proc buildFileInfoText(editor: Editor): string =
  if editor.buffer.dirty:
    "[+] " & editor.buffer.name
  else:
    editor.buffer.name

proc buildPositionText(editor: Editor): string =
  let lineCount = editor.buffer.getLineCount()
  let percent = if lineCount > 0:
    " " & $(int((editor.cursorRow + 1) / lineCount * 100)) & "%"
  else:
    " 0%"
  " Ln " & $(editor.cursorRow + 1) & ", Col " & $(editor.cursorCol + 1) & percent & " "

proc buildPendingText(editor: Editor): string =
  let countText = if editor.count > 0: $editor.count else: ""
  let pendingOpText = case editor.pendingOp
    of opDelete: "d"
    of opYank: "y"
    else: ""
  
  if countText != "" or pendingOpText != "":
    " " & countText & pendingOpText & " "
  else:
    ""

proc renderStatusBar(ctx: var RenderContext) =
  let status = buildStatusText(ctx.editor)
  let fileInfo = " " & buildFileInfoText(ctx.editor) & " "
  let position = buildPositionText(ctx.editor)
  let pending = buildPendingText(ctx.editor)
  
  let statusY = ctx.editor.screenHeight - 1
  
  ctx.tb.write(0, statusY, ctx.statusFg, ctx.statusBg, " ".repeat(ctx.editor.screenWidth))
  
  ctx.tb.write(0, statusY, ctx.statusFg, ctx.statusBg, status)
  
  let infoStart = status.len
  ctx.tb.write(infoStart, statusY, ctx.statusFg, ctx.statusBg, fileInfo)
  
  let posStart = ctx.editor.screenWidth - position.len - pending.len
  if posStart > infoStart + fileInfo.len:
    ctx.tb.write(posStart, statusY, ctx.statusFg, ctx.statusBg, position)
    if pending != "":
      ctx.tb.write(ctx.editor.screenWidth - pending.len, statusY, fgBlack, bgYellow, pending)
  
  if ctx.editor.mode == modeNormal and ctx.editor.statusMessage != "":
    let msgStart = status.len + fileInfo.len + 2
    let maxMsgWidth = ctx.editor.screenWidth - msgStart - position.len - pending.len - 2
    
    if maxMsgWidth > 10:
      let displayMsg = if ctx.editor.statusMessage.len > maxMsgWidth:
                         ctx.editor.statusMessage[0..<maxMsgWidth]
                       else:
                         ctx.editor.statusMessage
      ctx.tb.write(msgStart, statusY, fgYellow, ctx.statusBg, displayMsg)

proc renderCursor(ctx: var RenderContext) =
  if ctx.editor.cursorRow < ctx.editor.viewportRow or 
     ctx.editor.cursorRow >= ctx.editor.viewportRow + ctx.editor.screenHeight - 1:
    return
  
  let y = ctx.editor.cursorRow - ctx.editor.viewportRow
  let line = ctx.editor.buffer.getLine(ctx.editor.cursorRow)
  
  let cursorScreenCol = 
    if ctx.editor.showLineNumbers:
      ctx.lineNumWidth + (ctx.editor.cursorCol - ctx.editor.viewportCol)
    else:
      ctx.editor.cursorCol - ctx.editor.viewportCol
  
  if cursorScreenCol < 0 or cursorScreenCol >= ctx.editor.screenWidth:
    return
  
  let ch = if ctx.editor.cursorCol < line.len: line[ctx.editor.cursorCol] else: ' '
  
  case ctx.editor.mode
  of modeNormal, modeDiff:
    ctx.tb.write(cursorScreenCol, y, fgBlack, bgWhite, $ch)
  of modeInsert:
    if ctx.editor.cursorCol < line.len:
      ctx.tb.write(cursorScreenCol, y, fgBlack, bgCyan, $ch)
    else:
      ctx.tb.write(cursorScreenCol, y, fgCyan, ctx.currentLineBgColor, "|")
  of modeCommand:
    ctx.tb.write(cursorScreenCol, y, fgBlack, bgWhite, $ch)

proc render*(editor: Editor) =
  editor.screenWidth = terminalWidth()
  editor.screenHeight = terminalHeight()
  
  var ctx = initRenderContext(editor)
  
  ctx.clearScreen()
  
  let lineCount = editor.buffer.getLineCount()
  let visibleLines = min(editor.screenHeight - 1, lineCount - editor.viewportRow)
  
  for i in 0..<visibleLines:
    let lineIdx = editor.viewportRow + i
    ctx.renderTextLine(lineIdx, i)
  
  ctx.renderEmptyLines(lineCount - editor.viewportRow)
  
  ctx.renderStatusBar()
  
  ctx.renderCursor()
  
  if editor.popup.visible:
    renderPopup(editor, ctx.tb)
  
  ctx.tb.display()
