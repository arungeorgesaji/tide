import std/[json, tables, os, sequtils]
import colors

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

proc toRGB(arr: JsonNode): RGB =
  (arr[0].getInt, arr[1].getInt, arr[2].getInt)

proc themeFromJson(name: string, node: JsonNode): ColorTheme =
  result.name = name
  result.fg = toRGB(node["fg"])
  result.bg = toRGB(node["bg"])
  result.lineNumFg = toRGB(node["lineNumFg"])
  result.lineNumBg = toRGB(node["lineNumBg"])
  result.currentLineFg = toRGB(node["currentLineFg"])
  result.currentLineBg = toRGB(node["currentLineBg"])
  result.statusFg = toRGB(node["statusFg"])
  result.statusBg = toRGB(node["statusBg"])
  result.selectionFg = toRGB(node["selectionFg"])
  result.selectionBg = toRGB(node["selectionBg"])
  result.commentFg = toRGB(node["commentFg"])
  result.keywordFg = toRGB(node["keywordFg"])
  result.stringFg = toRGB(node["stringFg"])
  result.numberFg = toRGB(node["numberFg"])

proc newThemeManager*(path: string): ThemeManager =
  result = ThemeManager(themes: initTable[string, ColorTheme]())

  let data = readFile(path).parseJson()

  for themeName, themeNode in data.pairs:
    let theme = themeFromJson(themeName, themeNode)
    result.themes[themeName] = theme

  if data.len > 0:
    let first = data.keys.toSeq[0]
    result.currentTheme = result.themes[first]


proc setTheme*(tm: ThemeManager, themeName: string): bool =
  if themeName in tm.themes:
    tm.currentTheme = tm.themes[themeName]
    return true
  false
