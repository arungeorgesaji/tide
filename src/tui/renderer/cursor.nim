import core/buffer
import tui/renderer/context
import illwill

proc renderCursor*(ctx: var RenderContext) =
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
  
  let maxCol = if ctx.hasMinimap: ctx.minimapX - 2 else: ctx.editor.screenWidth
  if cursorScreenCol < 0 or cursorScreenCol >= maxCol:
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
  of modeSearch:
    ctx.tb.write(cursorScreenCol, y, fgBlack, bgYellow, $ch)
