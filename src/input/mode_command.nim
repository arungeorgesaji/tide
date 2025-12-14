import std/[sequtils, strutils, os]
import types
import core/buffer
import utils/[config, diff]
import tui/[theme, syntax]
import navigation
import illwill, tables

proc handleCommandMode*(editor: Editor, key: Key) =
  editor.handleNavigationKeys(key) 

  if key in {Key.Left, Key.Right, Key.Up, Key.Down,
             Key.Home, Key.End, Key.PageUp, Key.PageDown}:
    return

  if key == Key.Enter:
    let cmd = editor.cmdBuffer
    if cmd == ":q" or cmd == ":q!":
      editor.running = false
    elif cmd == ":w":
      if editor.buffer.save():
        editor.statusMessage = "file_saved"
      else:
        editor.statusMessage = "error_saving_file"
    elif cmd == ":wq" or cmd == ":x":
      discard editor.buffer.save()
      editor.running = false
    elif cmd.startsWith(":diff "):
      let parts = cmd.split(" ")
      if parts.len == 3:
        let fileA = parts[1]
        let fileB = parts[2]
        let a = readFile(fileA).splitLines()
        let b = readFile(fileB).splitLines()
        editor.diffOriginalBuffer = editor.buffer.lines
        editor.diffBuffer = computeDiff(a, b)
        editor.buffer.lines = editor.diffBuffer
        editor.mode = modeDiff
        editor.statusMessage = "diff mode enabled"
      else:
        editor.statusMessage = "usage: :diff file1 file2"
    elif cmd == ":nodiff":
      if editor.mode == modeDiff:
        editor.buffer.lines = editor.diffOriginalBuffer
        editor.mode = modeNormal
        editor.statusMessage = "diff mode disabled"
    elif cmd == ":set number" or cmd == ":set nu":
      editor.showLineNumbers = true
      editor.statusMessage = "line_numbers_enabled"
    elif cmd == ":set nonumber" or cmd == ":set nonu":
      editor.showLineNumbers = false
      editor.statusMessage = "line_numbers_disabled"
    elif cmd == ":set wrap":
      editor.lineWrap = true
      editor.statusMessage = "line_wrap_enabled"
    elif cmd == ":set nowrap":
      editor.lineWrap = false
      editor.statusMessage = "line_wrap_disabled"
    elif cmd.startsWith(":theme "):
      let themeName = cmd[7..^1].strip()
      if editor.themeManager.setTheme(themeName):
        editor.statusMessage = "themme_applied: " & themeName
      else:
        editor.statusMessage = "unknown_theme: " & themeName
    elif cmd == ":themes":
      editor.popup.previewTheme = editor.themeManager.currentTheme.name
      editor.popup.mode = pmThemeSelector
      editor.popup.items = toSeq(editor.themeManager.themes.keys)
      editor.popup.selectedIndex = 0
      editor.popup.visible = true
      editor.popup.title = "Select Theme"
      editor.popup.scrollOffset = 0
      editor.popup.filter = ""
      editor.popup.filterCursor = 0
      if editor.popup.items.len > 0:
        discard editor.themeManager.setTheme(editor.popup.items[0])
    elif cmd == ":minimap on":
      editor.minimapEnabled = true
      editor.statusMessage = "minimap_enabled"
      saveMinimapEnabled(true)
    elif cmd == ":minimap off":
      editor.minimapEnabled = false
      editor.statusMessage = "minimap_disabled"
      saveMinimapEnabled(false)
    elif cmd == ":syntax on":
      editor.syntaxEnabled = true
      editor.language = detectLanguage(editor.buffer.name)
      editor.statusMessage = "syntax_highlighting_enabled"
      saveSyntaxEnabled(true)
    elif cmd == ":syntax off":
      editor.syntaxEnabled = false
      editor.language = langNone
      editor.statusMessage = "syntax_highlighting_disabled"
      saveSyntaxEnabled(false)
    elif cmd == ":pwd":
      editor.statusMessage = getCurrentDir()
    elif cmd == ":version" or cmd == ":ver":
      editor.statusMessage = "Tide v1.0"
    elif cmd.startsWith(":"):
      editor.statusMessage = "unknown_command: " & cmd
    
    editor.mode = modeNormal
    editor.cmdBuffer = ""
  elif key == Key.Backspace:
    if editor.cmdBuffer.len > 1:
      editor.cmdBuffer.setLen(editor.cmdBuffer.len - 1)
    else:
      editor.mode = modeNormal
      editor.cmdBuffer = ""
  elif key == Key.Escape:
    editor.mode = modeNormal
    editor.cmdBuffer = ""
  elif key.ord > 0:
    editor.cmdBuffer &= chr(key.ord)
