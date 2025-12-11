import std/[strutils, sequtils]

proc computeDiff*(a, b: seq[string]): seq[string] =
  result = @[]

  let lenA = a.len
  let lenB = b.len
  let maxLen = max(lenA, lenB)

  for i in 0..<maxLen:
    if i >= lenA:
      result.add("+ " & b[i])
    elif i >= lenB:
      result.add("- " & a[i])
    elif a[i] != b[i]:
      result.add("~ " & b[i])
    else:
      result.add("  " & a[i])
