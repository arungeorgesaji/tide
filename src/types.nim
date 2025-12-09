import core/buffer
import tui/[theme, syntax]

type
  EditorMode* = enum
    modeNormal, modeInsert, modeCommand

  UndoAction* = enum
    uaInsertChar, uaDeleteChar, uaInsertLine, uaDeleteLine, uaSetLine

  UndoItem* = object
    action*: UndoAction
    row*, col*: int
    text*: string

  PendingOp* = enum
    opNone, opDelete, opYank

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
    count*: int
    tabWidth*: int = 4
