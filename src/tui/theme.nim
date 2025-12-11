import std/[json, tables, os, sequtils, strutils]
import ../utils/config

const defaultThemesJson = """
{
  "terminal-dark": {
    "name": "terminal-dark",
    "fg": "white",
    "bg": "black",
    "lineNumFg": "lightGray",
    "lineNumBg": "black",
    "currentLineFg": "white",
    "currentLineBg": "darkGray",
    "statusFg": "white",
    "statusBg": "darkGray",
    "selectionFg": "black",
    "selectionBg": "cyan",
    "commentFg": "lightGray",
    "keywordFg": "green",
    "stringFg": "yellow",
    "numberFg": "magenta",
    "diffAdded": "green",
    "diffRemoved": "red",
    "diffModified": "yellow",
    "diffNormal": "white"
  },

  "terminal-light": {
    "name": "terminal-light",
    "fg": "black",
    "bg": "white",
    "lineNumFg": "darkGray",
    "lineNumBg": "white",
    "currentLineFg": "black",
    "currentLineBg": "lightGray",
    "statusFg": "black",
    "statusBg": "lightGray",
    "selectionFg": "white",
    "selectionBg": "blue",
    "commentFg": "darkGray",
    "keywordFg": "red",
    "stringFg": "green",
    "numberFg": "magenta",
    "diffAdded": "green",
    "diffRemoved": "red",
    "diffModified": "yellow",
    "diffNormal": "black"
  },

  "solarized-terminal": {
    "name": "solarized-terminal",
    "fg": "lightGray",
    "bg": "blue",
    "lineNumFg": "cyan",
    "lineNumBg": "blue",
    "currentLineFg": "white",
    "currentLineBg": "darkBlue",
    "statusFg": "white",
    "statusBg": "darkBlue",
    "selectionFg": "blue",
    "selectionBg": "yellow",
    "commentFg": "cyan",
    "keywordFg": "green",
    "stringFg": "magenta",
    "numberFg": "cyan",
    "diffAdded": "green",
    "diffRemoved": "red",
    "diffModified": "yellow",
    "diffNormal": "white"
  },

  "monokai-terminal": {
    "name": "monokai-terminal",
    "fg": "white",
    "bg": "black",
    "lineNumFg": "darkGray",
    "lineNumBg": "black",
    "currentLineFg": "white",
    "currentLineBg": "darkGray",
    "statusFg": "white",
    "statusBg": "darkGray",
    "selectionFg": "black",
    "selectionBg": "magenta",
    "commentFg": "darkGray",
    "keywordFg": "magenta",
    "stringFg": "yellow",
    "numberFg": "blue",
    "diffAdded": "green",
    "diffRemoved": "red",
    "diffModified": "yellow",
    "diffNormal": "white"
  },

  "dracula-terminal": {
    "name": "dracula-terminal",
    "fg": "white",
    "bg": "black",
    "lineNumFg": "blue",
    "lineNumBg": "black",
    "currentLineFg": "white",
    "currentLineBg": "darkGray",
    "statusFg": "white",
    "statusBg": "darkGray",
    "selectionFg": "black",
    "selectionBg": "magenta",
    "commentFg": "blue",
    "keywordFg": "magenta",
    "stringFg": "yellow",
    "numberFg": "magenta",
    "diffAdded": "green",
    "diffRemoved": "red",
    "diffModified": "yellow",
    "diffNormal": "white"
  },

  "gruvbox-terminal": {
    "name": "gruvbox-terminal",
    "fg": "yellow",
    "bg": "black",
    "lineNumFg": "darkGray",
    "lineNumBg": "black",
    "currentLineFg": "yellow",
    "currentLineBg": "darkGray",
    "statusFg": "yellow",
    "statusBg": "darkGray",
    "selectionFg": "black",
    "selectionBg": "yellow",
    "commentFg": "darkGray",
    "keywordFg": "red",
    "stringFg": "green",
    "numberFg": "magenta",
    "diffAdded": "green",
    "diffRemoved": "red",
    "diffModified": "yellow",
    "diffNormal": "white"
  },

  "nord-terminal": {
    "name": "nord-terminal",
    "fg": "white",
    "bg": "blue",
    "lineNumFg": "cyan",
    "lineNumBg": "blue",
    "currentLineFg": "white",
    "currentLineBg": "darkBlue",
    "statusFg": "white",
    "statusBg": "darkBlue",
    "selectionFg": "blue",
    "selectionBg": "cyan",
    "commentFg": "cyan",
    "keywordFg": "cyan",
    "stringFg": "green",
    "numberFg": "yellow",
    "diffAdded": "green",
    "diffRemoved": "red",
    "diffModified": "yellow",
    "diffNormal": "white"
  }
}
"""

type
  ColorTheme* = object
    name*: string
    fg*, bg*: string
    lineNumFg*, lineNumBg*: string
    currentLineFg*, currentLineBg*: string
    statusFg*, statusBg*: string
    selectionFg*, selectionBg*: string
    commentFg*, keywordFg*, stringFg*, numberFg*: string
    diffAdded*, diffRemoved*, diffModified*, diffNormal*: string

  ThemeManager* = ref object
    currentTheme*: ColorTheme
    themes*: Table[string, ColorTheme]

proc ensureThemesFile*() =
  let configDir = getHomeDir() / ".config" / "tide"
  let themesPath = configDir / "themes.json"

  if not dirExists(configDir):
    createDir(configDir)

  if not fileExists(themesPath):
    writeFile(themesPath, defaultThemesJson) 

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
    saveCurrentTheme(tm.currentTheme.name)     
    return true
  false
