import strutils
import core/buffer
import tui/renderer/context
import types
import illwill

proc buildStatusText*(editor: Editor): string =
  case editor.mode
  of modeNormal:
    " NORMAL "
  of modeInsert:
    " INSERT "
  of modeCommand:
    " " & editor.cmdBuffer & " "
  of modeSearch:
    " " & editor.cmdBuffer & " "
  of modeDiff:
    " DIFF "

proc buildFileInfoText*(editor: Editor): string =
  if editor.buffer.dirty:
    "[+] " & editor.buffer.name
  else:
    editor.buffer.name

proc buildPositionText*(editor: Editor): string =
  let lineCount = editor.buffer.getLineCount()
  let percent = if lineCount > 0:
    " " & $(int((editor.cursorRow + 1) / lineCount * 100)) & "%"
  else:
    " 0%"
  " Ln " & $(editor.cursorRow + 1) & ", Col " & $(editor.cursorCol + 1) & percent & " "

proc buildPendingText*(editor: Editor): string =
  let countText = if editor.count > 0: $editor.count else: ""
  let pendingOpText = case editor.pendingOp
    of opDelete: "d"
    of opYank: "y"
    else: ""
  
  if countText != "" or pendingOpText != "":
    " " & countText & pendingOpText & " "
  else:
    ""

proc renderStatusBar*(ctx: var RenderContext) =
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

