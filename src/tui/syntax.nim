import std/[strutils, os]
import theme

type
  TokenType* = enum
    tokText       
    tokKeyword    
    tokString     
    tokNumber     
    tokComment    
    tokOperator   
    tokType       
    tokFunction   
    tokPreprocessor 
  
  Token* = object
    tokenType*: TokenType
    text*: string
  
  Language* = enum
    langNone     
    langNim
    langC
    langCpp
    langPython
    langJavaScript
    langJava
    langRust
    langGo
    langMarkdown
    langJson
    langXml
    langYaml
    langToml
  
  SyntaxHighlighter* = ref object
    language*: Language

const
  commonKeywords = [
    "if", "else", "for", "while", "do", "switch", "case", "break", "continue",
    "return", "def", "function", "class", "struct", "enum", "interface", "import",
    "from", "as", "with", "try", "catch", "finally", "throw", "throws", "new",
    "delete", "public", "private", "protected", "static", "const", "final", "abstract",
    "extends", "implements", "super", "this", "self", "nil", "null", "true", "false",
    "var", "let", "mut", "ref", "ptr", "proc", "func", "method", "iterator",
    "template", "macro", "concept", "where", "when", "of", "is", "in", "notin",
    "and", "or", "not", "xor", "shl", "shr", "div", "mod"
  ]

  typeKeywords = [
    "int", "string", "float", "double", "char", "bool", "void", "byte", "short",
    "long", "unsigned", "signed", "size_t", "ssize_t", "uint8", "uint16", "uint32",
    "uint64", "int8", "int16", "int32", "int64", "float32", "float64", "array",
    "seq", "list", "dict", "map", "set", "vector", "string", "str", "cstring"
  ]

proc detectLanguage*(filename: string): Language =
  let ext = filename.splitFile().ext.toLowerAscii()
  case ext
  of ".nim": langNim
  of ".c": langC
  of ".cpp", ".cc", ".cxx", ".h", ".hpp", ".hxx": langCpp
  of ".py": langPython
  of ".js", ".jsx", ".ts", ".tsx": langJavaScript
  of ".java": langJava
  of ".rs": langRust
  of ".go": langGo
  of ".md", ".markdown": langMarkdown
  of ".json": langJson
  of ".xml", ".html", ".htm": langXml
  of ".yaml", ".yml": langYaml
  of ".toml": langToml
  else: langNone

proc isKeyword(word: string, lang: Language): bool =
  let wordLower = word.toLowerAscii()
  
  if wordLower in commonKeywords:
    return true
  
  if wordLower in typeKeywords:
    return true
  
  case lang
  of langNim:
    let nimKeywords = [
      "proc", "func", "method", "iterator", "template", "macro", "concept",
      "type", "object", "enum", "tuple", "distinct", "ref", "ptr", "var",
      "let", "const", "static", "when", "if", "elif", "else", "case", "of",
      "for", "in", "while", "do", "try", "except", "finally", "raise", "defer",
      "block", "break", "continue", "return", "discard", "asm", "import",
      "include", "from", "export", "using", "mixin", "bind"
    ]
    return wordLower in nimKeywords
  of langPython:
    let pythonKeywords = [
      "def", "class", "lambda", "with", "as", "pass", "del", "global", "nonlocal",
      "assert", "yield", "async", "await", "match", "case"
    ]
    return wordLower in pythonKeywords
  of langC, langCpp:
    let cppKeywords = [
      "auto", "constexpr", "decltype", "explicit", "export", "extern", "friend",
      "inline", "mutable", "namespace", "noexcept", "operator", "private",
      "protected", "public", "register", "reinterpret_cast", "static_cast",
      "template", "thread_local", "typedef", "typename", "using", "virtual",
      "volatile", "wchar_t"
    ]
    return wordLower in cppKeywords
  of langRust:
    let rustKeywords = [
      "fn", "pub", "mod", "use", "crate", "unsafe", "async", "await", "dyn",
      "impl", "trait", "where", "match", "loop", "box", "move", "ref", "mut",
      "const", "static", "super", "extern", "crate", "self", "Self"
    ]
    return wordLower in rustKeywords
  of langGo:
    let goKeywords = [
      "package", "import", "func", "interface", "struct", "map", "chan",
      "range", "select", "defer", "go", "fallthrough", "iota"
    ]
    return wordLower in goKeywords
  else:
    return false

proc tokenizeLine*(line: string, lang: Language, syntaxEnabled = true): seq[Token] =
  if not syntaxEnabled:
    return @[Token(tokenType: tokText, text: line)]

  var tokens: seq[Token]
  var i = 0
  let n = line.len
  
  while i < n:
    let ch = line[i]
    
    if ch in Whitespace:
      var whitespace = ""
      while i < n and line[i] in Whitespace:
        whitespace.add(line[i])
        inc i
      if whitespace.len > 0:
        tokens.add(Token(tokenType: tokText, text: whitespace))
      continue
    
    case lang
    of langNim:
      if i + 1 < n and line[i] == '#' and line[i+1] != '[':
        var comment = ""
        while i < n:
          comment.add(line[i])
          inc i
        tokens.add(Token(tokenType: tokComment, text: comment))
        continue
    of langC, langCpp, langJava, langRust, langGo, langJavaScript:
      if i + 1 < n and line[i] == '/' and line[i+1] == '/':
        var comment = ""
        while i < n:
          comment.add(line[i])
          inc i
        tokens.add(Token(tokenType: tokComment, text: comment))
        continue
      elif i + 1 < n and line[i] == '/' and line[i+1] == '*':
        var comment = ""
        while i < n and not (line[i] == '*' and i+1 < n and line[i+1] == '/'):
          comment.add(line[i])
          inc i
        if i < n:
          comment.add('*')
          comment.add('/')
          i += 2
        tokens.add(Token(tokenType: tokComment, text: comment))
        continue
    of langPython:
      if line[i] == '#':
        var comment = ""
        while i < n:
          comment.add(line[i])
          inc i
        tokens.add(Token(tokenType: tokComment, text: comment))
        continue
    else:
      discard
    
    if ch == '"' or ch == '\'':
      var str = $ch
      inc i
      var escaped = false
      while i < n:
        let current = line[i]
        str.add(current)
        if not escaped and current == ch:
          inc i
          break
        escaped = not escaped and current == '\\'
        inc i
      tokens.add(Token(tokenType: tokString, text: str))
      continue
    
    if ch in Digits or (ch == '.' and i+1 < n and line[i+1] in Digits):
      var num = ""
      var hasDot = ch == '.'
      while i < n and (line[i] in Digits or line[i] == '.' or 
                      (i == num.len and line[i] in {'x', 'X', 'b', 'B', 'o', 'O', 'e', 'E', '-', '+'})):
        if line[i] == '.':
          if hasDot: break
          hasDot = true
        num.add(line[i])
        inc i
      if num.len > 0:
        tokens.add(Token(tokenType: tokNumber, text: num))
        continue
    
    const operators = "+-*/%=!<>|&^~?:.,;()[]{}"
    if ch in operators:
      var op = $ch
      inc i
      while i < n and line[i] in operators and (op & line[i]) in ["==", "!=", "<=", ">=", "&&", "||", "->", "=>", "+=", "-=", "*=", "/=", "%="]:
        op.add(line[i])
        inc i
      tokens.add(Token(tokenType: tokOperator, text: op))
      continue
    
    if ch.isAlphaAscii or ch == '_':
      var word = ""
      while i < n and (line[i].isAlphaNumeric or line[i] == '_'):
        word.add(line[i])
        inc i
      
      if isKeyword(word, lang):
        tokens.add(Token(tokenType: tokKeyword, text: word))
      elif word in typeKeywords:
        tokens.add(Token(tokenType: tokType, text: word))
      else:
        if i < n and line[i] == '(':
          tokens.add(Token(tokenType: tokFunction, text: word))
        else:
          tokens.add(Token(tokenType: tokText, text: word))
      continue
    
    var text = $ch
    inc i
    tokens.add(Token(tokenType: tokText, text: text))
  
  return tokens

proc getTokenColor*(tokenType: TokenType, theme: ColorTheme): string =
  case tokenType
  of tokKeyword: theme.keywordFg
  of tokString: theme.stringFg
  of tokNumber: theme.numberFg
  of tokComment: theme.commentFg
  of tokOperator: theme.keywordFg  
  of tokType: theme.keywordFg      
  of tokFunction: theme.stringFg   
  of tokPreprocessor: theme.commentFg
  else: theme.fg  
