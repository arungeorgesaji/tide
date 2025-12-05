import colors, tables

type
  RGB* = tuple[r: int, g: int, b: int]

  ColorTheme* = object
    name*: string
    fg*, bg*: RGB
    lineNumFg*, lineNumBg*: RGB
    currentLineFg*, currentLineBg*: RGB 
    statusFg*, statusBg*: RGB 
    selectionFg*, selectionBg*: RGB 
    commentFg*: RGB 
    keywordFg*: RGB 
    stringFg*: RGB 
    numberFg*: RGB 
  
  ThemeManager* = ref object
    currentTheme*: ColorTheme
    themes*: Table[string, ColorTheme]
  
  ColorPair* = tuple[fg: Color, bg: Color]

proc rgb*(r, g, b: range[0..255]): RGB = (r, g, b)

proc newThemeManager*(): ThemeManager =
  result = ThemeManager(
    themes: initTable[string, ColorTheme]()
  )
  
  let solarizedDark = ColorTheme(
    name: "solarized-dark",
    fg: rgb(131, 148, 150),       
    bg: rgb(0, 43, 54),           
    lineNumFg: rgb(88, 110, 117),  
    lineNumBg: rgb(0, 43, 54),     
    currentLineFg: rgb(147, 161, 161), 
    currentLineBg: rgb(7, 54, 66),     
    statusFg: rgb(147, 161, 161),  
    statusBg: rgb(7, 54, 66),      
    selectionFg: rgb(0, 43, 54),  
    selectionBg: rgb(38, 139, 210),
    commentFg: rgb(88, 110, 117),  
    keywordFg: rgb(133, 153, 0),   
    stringFg: rgb(211, 54, 130),   
    numberFg: rgb(42, 161, 152)    
  )
  
  let solarizedLight = ColorTheme(
    name: "solarized-light",
    fg: rgb(101, 123, 131),        
    bg: rgb(253, 246, 227),        
    lineNumFg: rgb(147, 161, 161), 
    lineNumBg: rgb(253, 246, 227), 
    currentLineFg: rgb(101, 123, 131), 
    currentLineBg: rgb(238, 232, 213), 
    statusFg: rgb(101, 123, 131), 
    statusBg: rgb(238, 232, 213), 
    selectionFg: rgb(253, 246, 227), 
    selectionBg: rgb(38, 139, 210),  
    commentFg: rgb(147, 161, 161), 
    keywordFg: rgb(133, 153, 0),   
    stringFg: rgb(211, 54, 130),   
    numberFg: rgb(42, 161, 152)    
  )
  
  let monokai = ColorTheme(
    name: "monokai",
    fg: rgb(248, 248, 242),        
    bg: rgb(39, 40, 34),          
    lineNumFg: rgb(117, 113, 94), 
    lineNumBg: rgb(39, 40, 34),    
    currentLineFg: rgb(248, 248, 242), 
    currentLineBg: rgb(62, 61, 50),    
    statusFg: rgb(248, 248, 242),  
    statusBg: rgb(62, 61, 50),    
    selectionFg: rgb(39, 40, 34),  
    selectionBg: rgb(249, 38, 114),
    commentFg: rgb(117, 113, 94),  
    keywordFg: rgb(249, 38, 114),  
    stringFg: rgb(230, 219, 116),  
    numberFg: rgb(174, 129, 255)   
  )
  
  let dracula = ColorTheme(
    name: "dracula",
    fg: rgb(248, 248, 242),        
    bg: rgb(40, 42, 54),           
    lineNumFg: rgb(98, 114, 164),  
    lineNumBg: rgb(40, 42, 54),    
    currentLineFg: rgb(248, 248, 242), 
    currentLineBg: rgb(68, 71, 90),    
    statusFg: rgb(248, 248, 242),  
    statusBg: rgb(68, 71, 90),    
    selectionFg: rgb(40, 42, 54),  
    selectionBg: rgb(189, 147, 249),
    commentFg: rgb(98, 114, 164),  
    keywordFg: rgb(255, 121, 198), 
    stringFg: rgb(241, 250, 140),  
    numberFg: rgb(189, 147, 249)   
  )
  
  result.themes["solarized-dark"] = solarizedDark
  result.themes["solarized-light"] = solarizedLight
  result.themes["monokai"] = monokai
  result.themes["dracula"] = dracula
  result.themes["default"] = solarizedDark
  
  result.currentTheme = solarizedDark

proc setTheme*(tm: ThemeManager, themeName: string): bool =
  if themeName in tm.themes:
    tm.currentTheme = tm.themes[themeName]
    return true
  return false
