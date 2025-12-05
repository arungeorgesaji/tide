import std/[json, tables, os, sequtils, strutils]

const configFileName = "config.json"
let configPath = getAppDir() / configFileName

type
  ColorTheme* = object
    name*: string
    fg*, bg*: string
    lineNumFg*, lineNumBg*: string
    currentLineFg*, currentLineBg*: string
    statusFg*, statusBg*: string
    selectionFg*, selectionBg*: string
    commentFg*, keywordFg*, stringFg*, numberFg*: string

  ThemeManager* = ref object
    currentTheme*: ColorTheme
    themes*: Table[string, ColorTheme]

proc themeFromJson(name: string, node: JsonNode): ColorTheme =
  result.name = name
  result.fg = node["fg"].getStr
  result.bg = node["bg"].getStr
  result.lineNumFg = node["lineNumFg"].getStr
  result.lineNumBg = node["lineNumBg"].getStr
  result.currentLineFg = node["currentLineFg"].getStr
  result.currentLineBg = node["currentLineBg"].getStr
  result.statusFg = node["statusFg"].getStr
  result.statusBg = node["statusBg"].getStr
  result.selectionFg = node["selectionFg"].getStr
  result.selectionBg = node["selectionBg"].getStr
  result.commentFg = node["commentFg"].getStr
  result.keywordFg = node["keywordFg"].getStr
  result.stringFg = node["stringFg"].getStr
  result.numberFg = node["numberFg"].getStr

proc saveCurrentTheme*(tm: ThemeManager) =
  let node = %*{
    "selectedTheme": tm.currentTheme.name
  }
  writeFile(configPath, $node)

proc loadSelectedTheme(): string =
  if fileExists(configPath):
    try:
      let node = readFile(configPath).parseJson()
      return node{"selectedTheme"}.getStr
    except:
      return ""
  return ""

proc newThemeManager*(path: string): ThemeManager =
  result = ThemeManager(themes: initTable[string, ColorTheme]())

  let data = readFile(path).parseJson()

  for themeName, themeNode in data.pairs:
    let theme = themeFromJson(themeName, themeNode)
    result.themes[themeName] = theme

  let saved = loadSelectedTheme()
  if saved != "" and saved in result.themes:
    result.currentTheme = result.themes[saved]
  else:
    let first = data.keys.toSeq[0]
    result.currentTheme = result.themes[first]

proc setTheme*(tm: ThemeManager, themeName: string): bool =
  if themeName in tm.themes:
    tm.currentTheme = tm.themes[themeName]
    tm.saveCurrentTheme()     
    return true
  false
