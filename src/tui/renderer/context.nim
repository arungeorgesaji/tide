import std/strutils
import illwill
import core/buffer
import tui/[theme, renderer/colors]
import types

type
  RenderContext* = object
    tb*: TerminalBuffer
    editor*: Editor
    theme*: ColorTheme
    lineNumWidth*: int
    textStartCol*: int
    minimapX*: int
    minimapWidth*: int
    hasMinimap*: bool
    bgColor*: BackgroundColor
    fgColor*: ForegroundColor
    lineNumFgColor*: ForegroundColor
    lineNumBgColor*: BackgroundColor
    currentLineFgColor*: ForegroundColor
    currentLineBgColor*: BackgroundColor
    statusFg*: ForegroundColor
    statusBg*: BackgroundColor
    commentFgColor*: ForegroundColor
    keywordFgColor*: ForegroundColor
    stringFgColor*: ForegroundColor
    numberFgColor*: ForegroundColor

proc initRenderContext*(editor: Editor): RenderContext =
  let theme = editor.themeManager.currentTheme
  let lineCount = editor.buffer.getLineCount()
  let lineNumWidth = if editor.showLineNumbers: max(4, ($lineCount).len + 1) else: 0
  let minimapWidth = 16
  let hasMinimap = editor.minimapEnabled and editor.screenWidth > minimapWidth + 40
  
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

proc clearScreen*(ctx: var RenderContext) =
  for i in 0..<ctx.editor.screenHeight - 1:
    ctx.tb.write(0, i, ctx.fgColor, ctx.bgColor, " ".repeat(ctx.editor.screenWidth))
