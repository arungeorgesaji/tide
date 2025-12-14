import illwill
import types
import core/buffer
import tui/renderer/[context, lines, minimap, status, cursor, popup]

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
  ctx.renderMinimap()
  ctx.renderStatusBar()
  ctx.renderCursor()
  
  if editor.popup.visible:
    renderPopup(editor, ctx.tb)
  
  ctx.tb.display()
