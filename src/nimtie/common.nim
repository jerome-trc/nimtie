import std/[macros, strformat, strutils]

import config

const basicTypes* = [
    "bool",
    "int8",
    "uint8",
    "int16",
    "uint16",
    "int32",
    "uint32",
    "int64",
    "uint64",
    "int",
    "uint",
    "float32",
    "float64",
    "float"
]

proc toSnakeCase*(s: string): string =
    ## Converts NimType to nim_type.
    var prevCap = false
    for i, c in s:
        if c in {'A' .. 'Z'}:
            if result.len > 0 and result[^1] != '_' and not prevCap:
                result.add('_')
            prevCap = true
            result.add(c.toLowerAscii())
        else:
            prevCap = false
            result.add(c)


proc toCamelCase*(s: string): string =
    ## Converts nim_type to nimType.
    var cap = false
    var ret = ""

    for i, c in s:
        if c == '_':
            cap = true
        else:
            if cap:
                ret.add(c.toUpperAscii())
                cap = false
            else:
                ret.add(c)

    return ret


proc toCapSnakeCase*(s: string): string =
    ## Converts NimType to NIM_TYPE.
    var prevCap = false
    for i, c in s:
        if c in {'A' .. 'Z'}:
            if result.len > 0 and result[^1] != '_' and not prevCap:
                result.add '_'
            prevCap = true
        else:
            prevCap = false
        result.add c.toUpperAscii()


proc toPascalCase*(s: string): string =
    ## Converts nim_type to NimType.
    var cap = true
    var ret = ""

    for i, c in s:
        if c == '_':
            cap = true
        else:
            if cap:
                ret.add(c.toUpperAscii())
                cap = false
            else:
                ret.add(c)

    return ret


proc toVarCase*(s: string): string =
    ## Converts NimType to nimType.
    var i = 0
    while i < s.len:
        if s[i] notin {'A' .. 'Z'}:
            break

        result.add s[i].toLowerAscii()
        inc i

    if i < s.len:
        result.add s[i .. ^1]


proc renameProc*(cfg: Config, name: string): string =
    case cfg.c.procNaming:
    of Naming.geckoCase: error("unimplemented"); return ""
    of Naming.lowerCase: return name.toLowerAscii()
    of Naming.upperCase: return name.toUpperAscii()
    of Naming.pascalCase: return name.toPascalCase()
    of Naming.camelCase: return name.toCamelCase()
    of Naming.snakeCase: return name.toSnakeCase()
    of Naming.upperSnakeCase: return name.toCapSnakeCase()


proc getSeqName*(sym: NimNode): string =
    if sym.kind == nnkBracketExpr:
        result = &"Seq{sym[1]}"
    else:
        result = &"Seq{sym}"
    result[3] = toUpperAscii(result[3])


proc getName*(sym: NimNode): string =
    if sym.kind == nnkBracketExpr:
        sym.getSeqName()
    else:
        sym.repr


proc raises*(procSym: NimNode): bool =
    for pragma in procSym.getImpl()[4]:
        if pragma.kind == nnkExprColonExpr and pragma[0].repr == "raises":
            return pragma[1].len > 0
