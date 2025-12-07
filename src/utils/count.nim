import ../types

proc takeCount*(editor: Editor): int =
  let c = if editor.count == 0: 1 else: editor.count
  editor.count = 0
  return c
