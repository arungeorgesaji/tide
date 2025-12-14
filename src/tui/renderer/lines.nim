import std/strutils
import illwill
import core/buffer
import tui/syntax
import tui/renderer/[context, colors]
import types
import types

proc tokenFgColor*(ctx: RenderContext, tokenType: TokenType): ForegroundColor =
  case tokenType
  of tokKeyword: ctx.keywordFgColor
  of tokString: ctx.stringFgColor
  of tokNumber: ctx.numberFgColor
  of tokComment: ctx.commentFgColor
  of tokOperator: ctx.keywordFgColor
  of tokType: ctx.keywordFgColor
  of tokFunction: ctx.stringFgColor
  else: ctx.fgColor

proc analyzeLineContent*(line: string, language: Language, syntaxEnabled: bool): tuple[hasKeyword: bool, hasString: bool, hasComment: bool, density: float] =
  result.hasKeyword = false
  result.hasString = false
  result.hasComment = false
  
  let trimmed = line.strip()
  if trimmed.len == 0:
    result.density = 0.0
    return
  
  result.density = float(trimmed.len) / float(max(1, line.len))
  
  if syntaxEnabled and language != langNone:
    let tokens = tokenizeLine(line, language, true)
    for token in tokens:
      case token.tokenType
      of tokKeyword, tokType, tokFunction:
        result.hasKeyword = true
      of tokString:
        result.hasString = true
      of tokComment:
        result.hasComment = true
      else:
        discard

proc renderLineNumber*(ctx: var RenderContext, lineIdx, screenRow: int) =
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

proc renderNormalLine*(ctx: var RenderContext, line: string, lineIdx, screenRow: int) =
  let maxCol = if ctx.hasMinimap: ctx.minimapX - 2 else: ctx.editor.screenWidth
  let tokens = if ctx.editor.syntaxEnabled and ctx.editor.language != langNone:
                 tokenizeLine(line, ctx.editor.language, true)
               else:
                 tokenizeLine(line, langNone, false)
  
  let lineBgColor = if lineIdx == ctx.editor.cursorRow: ctx.currentLineBgColor else: ctx.bgColor
  var col = ctx.textStartCol
  
  for token in tokens:
    if col >= maxCol: break
    
    let tokenColor = ctx.tokenFgColor(token.tokenType)
    
    for ch in token.text:
      if col >= maxCol: break
      if col >= ctx.textStartCol:
        ctx.tb.write(col, screenRow, tokenColor, lineBgColor, $ch)
      inc(col)
  
  while col < maxCol:
    ctx.tb.write(col, screenRow, ctx.fgColor, lineBgColor, " ")
    inc(col)

proc renderEmptyLines*(ctx: var RenderContext, startRow: int) =
  let maxCol = if ctx.hasMinimap: ctx.minimapX - 2 else: ctx.editor.screenWidth
  for i in startRow..<(ctx.editor.screenHeight - 1):
    ctx.tb.write(ctx.textStartCol, i, ctx.lineNumFgColor, ctx.bgColor, "~")
    for col in ctx.textStartCol + 1..<maxCol:
      ctx.tb.write(col, i, ctx.fgColor, ctx.bgColor, " ")

proc renderDiffLine*(ctx: var RenderContext, line: string, lineIdx, screenRow: int) =
  let maxCol = if ctx.hasMinimap: ctx.minimapX - 2 else: ctx.editor.screenWidth
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
    if col >= maxCol: break
    if col >= ctx.textStartCol:
      ctx.tb.write(col, screenRow, diffColor, lineBgColor, $ch)
    inc(col)
  
  while col < maxCol:
    ctx.tb.write(col, screenRow, ctx.fgColor, lineBgColor, " ")
    inc(col)


proc renderTextLine*(ctx: var RenderContext, lineIdx, screenRow: int) =
  let line = ctx.editor.buffer.getLine(lineIdx)
  
  ctx.renderLineNumber(lineIdx, screenRow)
  
  if ctx.editor.mode == modeDiff:
    ctx.renderDiffLine(line, lineIdx, screenRow)
  else:
    ctx.renderNormalLine(line, lineIdx, screenRow)
