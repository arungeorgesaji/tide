import core/buffer
import types, undo, viewpoint, renderer, input
import tui/theme, tui/syntax
import illwill, os, strutils

proc newEditor*(filepath = ""): Editor =
  result = Editor(
    buffer: newBuffer(filepath),
    mode: modeNormal,
    cursorRow: 0,
    cursorCol: 0,
    running: true,
    cmdBuffer: "",
    undoStack: @[],
    yankBuffer: "",
    viewportRow: 0,
    viewportCol: 0,
    showLineNumbers: true,
    themeManager: newThemeManager(getAppDir() / "themes.json"),
    language: detectLanguage(filepath)
  )

proc run*(editor: Editor) =
  illwillInit(fullscreen = true)
  hideCursor()
  defer: illwillDeinit(); showCursor()

  while editor.running:
    editor.render()
    let key = getKey()
    if key != Key.None:
      case editor.mode
      of modeNormal: editor.handleNormalMode(key)
      of modeInsert: editor.handleInsertMode(key)
      of modeCommand: editor.handleCommandMode(key)
    else:
      sleep(10)
