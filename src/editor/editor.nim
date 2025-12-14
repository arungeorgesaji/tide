import core/buffer
import types 
import input/[mode_normal, mode_insert, mode_command, mode_search, popup_navigation]
import tui/[theme, syntax, renderer/render]
import utils/config
import illwill, os

proc newEditor*(filepath = ""): Editor =
  ensureThemesFile() 

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
    themeManager: newThemeManager(getHomeDir() / ".config" / "tide" / "themes.json"),
    language: detectLanguage(filepath),
    syntaxEnabled: loadSyntaxEnabled(),
    minimapEnabled: loadMinimapEnabled()
  )

proc run*(editor: Editor) =
  illwillInit(fullscreen = true)
  hideCursor()
  defer: illwillDeinit(); showCursor()

  while editor.running:
    editor.render()
    let key = getKey()

    if key != Key.None:
      if editor.popup.visible:
        editor.handlePopupNavigation(key)
      else: 
        case editor.mode
        of modeNormal: editor.handleNormalMode(key)
        of modeInsert: editor.handleInsertMode(key)
        of modeCommand: editor.handleCommandMode(key)
        of modeSearch: editor.handleSearchMode(key)
        of modeDiff: discard
    else:
      sleep(10)
