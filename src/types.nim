import core/buffer
import tui/[theme, syntax]

type
  EditorMode* = enum
    modeNormal, modeInsert, modeCommand, modeDiff

  UndoAction* = enum
    uaInsertChar, uaDeleteChar, uaInsertLine, uaDeleteLine, uaSetLine

  UndoItem* = object
    action*: UndoAction
    row*, col*: int
    text*: string

  PendingOp* = enum
    opNone, opDelete, opYank

  PopupMode* = enum
    pmNone
    pmThemeSelector
    pmFileBrowser
    pmSearch

  Popup* = object
    mode*: PopupMode
    items*: seq[string]
    selectedIndex*: int
    visible*: bool
    title*: string
    filter*: string
    filterCursor*: int
    previewTheme*: string
    scrollOffset*: int

  Editor* = ref object
    buffer*: Buffer
    mode*: EditorMode
    cursorRow*, cursorCol*: int
    running*: bool
    screenWidth*, screenHeight*: int
    cmdBuffer*: string
    statusMessage*: string
    undoStack*: seq[UndoItem]      
    yankBuffer*: string
    viewportRow*: int  
    viewportCol*: int  
    showLineNumbers*: bool
    themeManager*: ThemeManager
    language*: Language
    syntaxEnabled*: bool = true
    pendingOp*: PendingOp
    popup*: Popup
    count*: int
    tabWidth*: int = 4
    diffBuffer*: seq[string]
    diffOriginalBuffer*: seq[string]
    minimapEnabled*: bool = true
