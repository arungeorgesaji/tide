import std/[sequtils, strutils]
import types 
import tui/theme
import illwill, tables

proc handlePopupNavigation*(editor: Editor, key: Key) =
  case editor.popup.mode
  of pmThemeSelector:
    let previousIndex = editor.popup.selectedIndex
    
    case key
    of Key.Up:
      if editor.popup.selectedIndex > 0:
        dec(editor.popup.selectedIndex)
        if editor.popup.selectedIndex < editor.popup.scrollOffset:
          editor.popup.scrollOffset = editor.popup.selectedIndex
    
    of Key.Down:
      if editor.popup.selectedIndex < editor.popup.items.high:
        inc(editor.popup.selectedIndex)
        let visibleHeight = min(16, editor.screenHeight - 8) - 4
        if editor.popup.selectedIndex >= editor.popup.scrollOffset + visibleHeight:
          editor.popup.scrollOffset = editor.popup.selectedIndex - visibleHeight + 1
    
    of Key.PageUp:
      editor.popup.selectedIndex = max(0, editor.popup.selectedIndex - 10)
      if editor.popup.selectedIndex < editor.popup.scrollOffset:
        editor.popup.scrollOffset = max(0, editor.popup.selectedIndex)
    
    of Key.PageDown:
      editor.popup.selectedIndex = min(editor.popup.items.high, editor.popup.selectedIndex + 10)
      let visibleHeight = min(16, editor.screenHeight - 8) - 4
      if editor.popup.selectedIndex >= editor.popup.scrollOffset + visibleHeight:
        editor.popup.scrollOffset = min(editor.popup.items.high - visibleHeight + 1, 
                                         editor.popup.selectedIndex - visibleHeight + 1)
    
    of Key.Home:
      editor.popup.selectedIndex = 0
      editor.popup.scrollOffset = 0
    
    of Key.End:
      editor.popup.selectedIndex = editor.popup.items.high
      let visibleHeight = min(16, editor.screenHeight - 8) - 4
      editor.popup.scrollOffset = max(0, editor.popup.items.high - visibleHeight + 1)
    
    of Key.Enter:
      let selectedTheme = editor.popup.items[editor.popup.selectedIndex]
      if editor.themeManager.setTheme(selectedTheme):
        editor.statusMessage = "Theme applied: " & selectedTheme
      editor.popup.visible = false
      editor.popup.previewTheme = ""
    
    of Key.Escape:
      if editor.popup.previewTheme != "":
        discard editor.themeManager.setTheme(editor.popup.previewTheme)
      editor.popup.visible = false
      editor.popup.previewTheme = ""
    
    else:
      if key.ord in 32..126:  
        let ch = chr(key.ord)
        editor.popup.filter &= ch
        var filteredItems: seq[string]
        for themeName in toSeq(editor.themeManager.themes.keys):
          if themeName.toLowerAscii().contains(editor.popup.filter.toLowerAscii()):
            filteredItems.add(themeName)
        editor.popup.items = filteredItems
        editor.popup.selectedIndex = min(editor.popup.selectedIndex, filteredItems.high)
        editor.popup.scrollOffset = 0
      
      elif key == Key.Backspace and editor.popup.filter.len > 0:
        editor.popup.filter.setLen(editor.popup.filter.len - 1)
        if editor.popup.filter == "":
          editor.popup.items = toSeq(editor.themeManager.themes.keys)
        else:
          var filteredItems: seq[string]
          for themeName in toSeq(editor.themeManager.themes.keys):
            if themeName.toLowerAscii().contains(editor.popup.filter.toLowerAscii()):
              filteredItems.add(themeName)
          editor.popup.items = filteredItems
        editor.popup.selectedIndex = min(editor.popup.selectedIndex, editor.popup.items.high)
        editor.popup.scrollOffset = 0
    
    if previousIndex != editor.popup.selectedIndex and editor.popup.items.len > 0:
      let previewTheme = editor.popup.items[editor.popup.selectedIndex]
      discard editor.themeManager.setTheme(previewTheme)
  
  else:
    discard
