import strutils
import tui/renderer/colors
import types
import illwill

proc renderPopup*(editor: Editor, tb: var TerminalBuffer) =
  let theme = editor.themeManager.currentTheme
  let popupBg = parseNamedBgColor(theme.bg)
  let popupFg = parseNamedColor(theme.fg)
  let selectedBg = parseNamedBgColor(theme.currentLineBg)
  let selectedFg = parseNamedColor(theme.currentLineFg)
  let borderFg = parseNamedColor(theme.lineNumFg)
  
  case editor.popup.mode
  of pmThemeSelector:
    let popupWidth = min(40, editor.screenWidth - 4)
    let popupHeight = min(20, editor.screenHeight - 4)
    let popupX = (editor.screenWidth - popupWidth) div 2
    let popupY = (editor.screenHeight - popupHeight) div 2
    
    tb.write(popupX, popupY, borderFg, popupBg, "+" & "-".repeat(popupWidth - 2) & "+")
    for i in 1..<popupHeight-1:
      tb.write(popupX, popupY + i, borderFg, popupBg, "|")
      tb.write(popupX + popupWidth - 1, popupY + i, borderFg, popupBg, "|")
    tb.write(popupX, popupY + popupHeight - 1, borderFg, popupBg, "+" & "-".repeat(popupWidth - 2) & "+")
    
    let title = " Select Theme "
    tb.write(popupX + (popupWidth - title.len) div 2, popupY, borderFg, popupBg, title)
    
    let itemsStartY = popupY + 2
    let maxVisibleItems = popupHeight - 4
    
    for i in 0..<min(editor.popup.items.len - editor.popup.scrollOffset, maxVisibleItems):
      let itemIndex = i + editor.popup.scrollOffset
      let item = editor.popup.items[itemIndex]
      let displayItem = if item.len > popupWidth - 4: 
                         item[0..<(popupWidth - 7)] & "..."
                       else: 
                         item
      
      if itemIndex == editor.popup.selectedIndex:
        tb.write(popupX + 2, itemsStartY + i, selectedFg, selectedBg, "> " & displayItem & " ".repeat(popupWidth - 4 - displayItem.len - 2))
      else:
        tb.write(popupX + 2, itemsStartY + i, popupFg, popupBg, "  " & displayItem & " ".repeat(popupWidth - 4 - displayItem.len - 2))
    
    if editor.popup.filter != "":
      let filterText = "Filter: " & editor.popup.filter
      tb.write(popupX + 2, popupY + popupHeight - 2, popupFg, popupBg, filterText)
    
    let hint = "[Enter] select [Esc] cancel"
    tb.write(popupX + (popupWidth - hint.len) div 2, popupY + popupHeight - 1, borderFg, popupBg, hint)
  
  else:
    discard
