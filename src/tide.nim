#!/usr/bin/env -S nim r

import editor

when isMainModule:
  let filename = if paramCount() > 0: paramStr(1) else: ""
  newEditor(filename).run()
