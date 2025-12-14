import std/strutils
import illwill

proc getClosestTermColor*(r, g, b: int): ForegroundColor =
  let brightness = (r + g + b) div 3
  
  if r > g and r > b:
    if r > 192: return fgRed
    else: return fgRed
  elif g > r and g > b:
    if g > 192: return fgGreen
    else: return fgGreen
  elif b > r and b > g:
    if b > 192: return fgBlue
    else: return fgBlue
  elif r > 150 and g > 150 and b < 100:
    return fgYellow
  elif r > 150 and b > 150 and g < 100:
    return fgMagenta
  elif g > 150 and b > 150 and r < 100:
    return fgCyan
  elif brightness < 64:
    return fgBlack
  elif brightness < 192:
    return fgWhite
  else:
    return fgWhite

proc getClosestTermBgColor*(r, g, b: int): BackgroundColor =
  let brightness = (r + g + b) div 3
  
  if r > g and r > b:
    if r > 192: return bgRed
    else: return bgRed
  elif g > r and g > b:
    if g > 192: return bgGreen
    else: return bgGreen
  elif b > r and b > g:
    if b > 192: return bgBlue
    else: return bgBlue
  elif r > 150 and g > 150 and b < 100:
    return bgYellow
  elif r > 150 and b > 150 and g < 100:
    return bgMagenta
  elif g > 150 and b > 150 and r < 100:
    return bgCyan
  elif brightness < 64:
    return bgBlack
  elif brightness < 192:
    return bgWhite
  else:
    return bgWhite

proc parseNamedColor*(colorName: string): ForegroundColor =
  case colorName.toLowerAscii()
  of "black": fgBlack
  of "red": fgRed
  of "green": fgGreen
  of "yellow": fgYellow
  of "blue": fgBlue
  of "magenta": fgMagenta
  of "cyan": fgCyan
  of "white": fgWhite
  of "lightgray", "lightgrey": fgWhite
  of "darkgray", "darkgrey": fgBlack
  else: fgWhite 

proc parseNamedBgColor*(colorName: string): BackgroundColor =
  case colorName.toLowerAscii()
  of "black": bgBlack
  of "red": bgRed
  of "green": bgGreen
  of "yellow": bgYellow
  of "blue": bgBlue
  of "magenta": bgMagenta
  of "cyan": bgCyan
  of "white": bgWhite
  of "lightgray", "lightgrey": bgWhite
  of "darkgray", "darkgrey": bgBlack
  else: bgBlack
