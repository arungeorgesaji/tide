import std/[json, os]

const configFileName = "config.json"
let configPath = getHomeDir() / ".config" / "tide" / configFileName

proc saveCurrentTheme*(themeName: string) =
  var data: JsonNode

  if fileExists(configPath):
    data = parseJson(readFile(configPath))
  else:
    data = %*{}   

  data["selectedTheme"] = %* themeName 

  writeFile(configPath, $data)

proc loadSelectedTheme*(): string =
  if fileExists(configPath):
    try:
      let node = readFile(configPath).parseJson()
      return node{"selectedTheme"}.getStr
    except:
      return ""
  return ""

proc saveSyntaxEnabled*(syntaxEnabled: bool) =
  var data: JsonNode

  if fileExists(configPath):
    data = parseJson(readFile(configPath))
  else:
    data = %*{}   

  data["syntaxEnabled"] = %* syntaxEnabled 

  writeFile(configPath, $data)

proc loadSyntaxEnabled*(): bool =
  if fileExists(configPath):
    try:
      let node = readFile(configPath).parseJson()
      if node.hasKey("syntaxEnabled"):
        return node{"syntaxEnabled"}.getBool
      else:
        return true  
    except:
      return true  
  return true  
