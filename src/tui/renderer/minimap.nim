import core/buffer
import tui/renderer/[context, lines]
import illwill

proc renderMinimap*(ctx: var RenderContext) =
  if not ctx.hasMinimap:
    return
  
  let lineCount = ctx.editor.buffer.getLineCount()
  let minimapHeight = ctx.editor.screenHeight - 1
  let minimapContentWidth = ctx.minimapWidth - 2
  
  for y in 0..<minimapHeight:
    ctx.tb.write(ctx.minimapX - 2, y, ctx.lineNumFgColor, ctx.bgColor, " ")
    ctx.tb.write(ctx.minimapX - 1, y, ctx.lineNumFgColor, ctx.bgColor, "┃")
  
  if lineCount == 0:
    return
  
  let linesPerChar = max(1.0, float(lineCount) / float(minimapHeight))
  let viewportHeight = ctx.editor.screenHeight - 1
  
  for y in 0..<minimapHeight:
    let startLine = int(float(y) * linesPerChar)
    let endLine = min(lineCount - 1, int(float(y + 1) * linesPerChar))
    
    var totalDensity = 0.0
    var keywordCount = 0
    var stringCount = 0
    var commentCount = 0
    var linesSampled = 0
    
    for lineIdx in startLine..min(endLine, lineCount - 1):
      let line = ctx.editor.buffer.getLine(lineIdx)
      let analysis = analyzeLineContent(line, ctx.editor.language, ctx.editor.syntaxEnabled)
      
      totalDensity += analysis.density
      if analysis.hasKeyword: inc(keywordCount)
      if analysis.hasString: inc(stringCount)
      if analysis.hasComment: inc(commentCount)
      inc(linesSampled)
    
    let avgDensity = if linesSampled > 0: totalDensity / float(linesSampled) else: 0.0
    
    let isInViewport = startLine >= ctx.editor.viewportRow and 
                       startLine < ctx.editor.viewportRow + viewportHeight
    
    let hasCursor = ctx.editor.cursorRow >= startLine and ctx.editor.cursorRow <= endLine
    
    for x in 0..<minimapContentWidth:
      var char = " "
      var fg = ctx.lineNumFgColor
      var bg = ctx.bgColor
      
      if x == 0:
        if isInViewport:
          if hasCursor:
            char = "▐"
            fg = fgYellow
            bg = ctx.currentLineBgColor
          else:
            char = "▌"
            fg = ctx.currentLineFgColor
            bg = ctx.currentLineBgColor
        else:
          char = " "
          bg = ctx.bgColor
      
      else:
        if avgDensity > 0.05:
          if commentCount > 0 and x >= minimapContentWidth - 2:
            char = "/"
            fg = ctx.commentFgColor
          elif keywordCount > 0 and x mod 3 == 0:
            if avgDensity > 0.7:
              char = "▓"
            elif avgDensity > 0.4:
              char = "▒"
            else:
              char = "░"
            fg = ctx.keywordFgColor
          elif stringCount > 0 and x mod 3 == 1:
            if avgDensity > 0.6:
              char = "▓"
            elif avgDensity > 0.3:
              char = "▒"
            else:
              char = "░"
            fg = ctx.stringFgColor
          else:
            if avgDensity > 0.8:
              char = "█"
              fg = ctx.fgColor
            elif avgDensity > 0.6:
              char = "▓"
              fg = ctx.fgColor
            elif avgDensity > 0.4:
              char = "▒"
              fg = ctx.lineNumFgColor
            elif avgDensity > 0.2:
              char = "░"
              fg = ctx.lineNumFgColor
            else:
              char = "·"
              fg = ctx.lineNumFgColor
        
        if isInViewport and char != " ":
          bg = ctx.lineNumBgColor
      
      ctx.tb.write(ctx.minimapX + x, y, fg, bg, char)
