import std/[macros, strformat]

import nimtie/config
import nimtie/languages/[c, cpp]

template discard2(f: untyped): untyped =
    when(compiles do: discard f):
        discard f
    else:
        f


proc asStmtList(body: NimNode): seq[NimNode] =
    ## Nim optimizes StmtList, reverse that:
    if body.kind != nnkStmtList:
        result.add(body)
    else:
        for child in body:
            result.add(child)


proc emptyBlockStmt(): NimNode =
    result = quote do:
        block:
            discard
    result[1].del(0)


macro exportConstsUntyped(body: untyped) =
    result = newNimNode(nnkStmtList)
    for ident in body:
        let varSection = quote do:
            var `ident` = `ident`
        result.add varSection


macro exportConstsTyped(cfg: static[Config], body: typed) =
    for varSection in body.asStmtList:
        let sym = varSection[0][0]
        exportConstC(cfg, sym)
        exportConstCpp(sym)


template exportConsts*(cfg: Config, body: untyped) =
    ## Exports a list of constants.
    exportConstsTyped(cfg, exportConstsUntyped(body))


macro exportEnumsUntyped(body: untyped) =
    result = newNimNode(nnkStmtList)
    for i, ident in body:
        let
            name = ident(&"enum{i}")
            varSection = quote do:
                var `name`: `ident`
        result.add varSection


macro exportEnumsTyped(cfg: static[Config], body: typed) =
    for varSection in body.asStmtList:
        let sym = varSection[0][1]
        exportEnumC(cfg, sym)
        exportEnumCpp(sym)


template exportEnums*(cfg: Config, body: untyped) =
    ## Exports a list of enums.
    exportEnumsTyped(cfg, exportEnumsUntyped(body))


proc fieldUntyped(clause, owner: NimNode): NimNode =
    result = emptyBlockStmt()
    result[1].add quote do:
        var
            obj: `owner`
            f = obj.`clause`


proc procUntyped(clause: NimNode): NimNode =
    result = emptyBlockStmt()

    if clause.kind == nnkIdent:
        let
            name = clause
            varSection = quote do:
                var p {.used.} = `name`
        result[1].add(varSection)
    else:
        var
            name = clause[0]
            endStmt = quote do:
                discard2 `name`()

        for i in 1 ..< clause.len:
            var
                argType = clause[i]
                argName = ident(&"arg{i}")
            result[1].add quote do:
                var `argName` {.used.}: `argType`
            endStmt[1].add(argName)

        result[1].add(endStmt)


proc procTypedSym(entry: NimNode): NimNode =
    result =
        if entry[1].kind == nnkVarSection:
      entry[1][0][2]
    else:
      if entry[1][^1].kind != nnkDiscardStmt:
        entry[1][^1][0]
      else:
        entry[1][^1][0][0]


proc procTyped(
    cfg: Config,
    entry: NimNode,
    owner: NimNode = nil,
    prefixes: openarray[NimNode] = []
) =
    let procSym = procTypedSym(entry)
    exportProcC(cfg, procSym, owner, prefixes)
    exportProcCpp(procSym, owner, prefixes)


macro exportProcsUntyped(body: untyped) =
    result = newNimNode(nnkStmtList)
    for clause in body:
        result.add(procUntyped(clause))


macro exportProcsTyped(cfg: static[Config], body: typed) =
    for entry in body.asStmtList:
        procTyped(cfg, entry)


template exportProcs*(cfg: Config, body: untyped) =
    ## Exports a list of procs.
    ## Procs can just be a name `doX` or fully qualified with `doX(int): int`.
    exportProcsTyped(cfg, exportProcsUntyped(body))


macro exportObjectUntyped(sym, body: untyped) =
    result = newNimNode(nnkStmtList)

    let varSection = quote do:
        var obj: `sym`
    result.add varSection

    var
        constructorBlock = emptyBlockStmt()
        procsBlock = emptyBlockStmt()

    for section in body:
        if section.kind == nnkDiscardStmt:
            continue

        case section[0].repr:
        of "constructor":
            constructorBlock[1].add procUntyped(section[1][0])
        of "procs":
            for clause in section[1]:
                procsBlock[1].add procUntyped(clause)
        else:
            error("Invalid section", section)

    result.add constructorBlock
    result.add procsBlock


macro exportObjectTyped(cfg: static[Config], body: typed) =
    let
        sym = body[0][0][1]
        constructorBlock = body[1]
        procsBlock = body[2]

    let constructor =
        if constructorBlock[1].len > 0:
            procTypedSym(constructorBlock[1])
    else:
        nil

    exportObjectC(cfg, sym, constructor)
    exportObjectCpp(sym, constructor)

    if procsBlock[1].len > 0:
        var procsSeen: seq[string]
        for entry in procsBlock[1].asStmtList:
            var
                procSym = procTypedSym(entry)
                prefixes: seq[NimNode]
            if procSym.repr notin procsSeen:
                procsSeen.add procSym.repr
            else:
                let procType = procSym.getTypeInst()
                if procType[0].len > 2:
                    prefixes.add(procType[0][2][1])
            exportProcC(cfg, procSym, sym, prefixes)
            exportProcCpp(procSym, sym, prefixes)

    exportCloseObjectCpp()


template exportObject*(cfg: Config, sym, body: untyped) =
    ## Exports an object, with these sections:
    ## * fields
    ## * constructor
    ## * procs
    exportObjectTyped(cfg, exportObjectUntyped(sym, body))


macro exportSeqUntyped(sym, body: untyped) =
    result = newNimNode(nnkStmtList)

    let varSection = quote do:
        var s: `sym`
    result.add varSection

    for section in body:
        if section.kind == nnkDiscardStmt:
            continue

        case section[0].repr:
        of "procs":
            for clause in section[1]:
                result.add procUntyped(clause)
        else:
            error("Invalid section", section)


macro exportSeqTyped(cfg: static[Config], body: typed) =
    let sym = body.asStmtList()[0][0][1]

    exportSeqC(cfg, sym)
    exportSeqCpp(sym)

    for entry in body.asStmtList()[1 .. ^1]:
        procTyped(cfg, entry, sym)

    exportCloseObjectCpp()


template exportSeq*(cfg: Config, sym, body: untyped) =
    ## Exports a regular sequence.
    ## * procs section
    exportSeqTyped(cfg, exportSeqUntyped(sym, body))


macro exportRefObjectUntyped(sym, body: untyped) =
    result = newNimNode(nnkStmtList)

    let varSection = quote do:
        var refObj: `sym`
    result.add varSection

    var
        fieldsBlock = emptyBlockStmt()
        constructorBlock = emptyBlockStmt()
        procsBlock = emptyBlockStmt()

    for section in body:
        if section.kind == nnkDiscardStmt:
            continue

        case section[0].repr:
        of "fields":
            for field in section[1]:
                fieldsBlock[1].add fieldUntyped(field, sym)
        of "constructor":
            constructorBlock[1].add procUntyped(section[1][0])
        of "procs":
            for clause in section[1]:
                procsBlock[1].add procUntyped(clause)
        else:
            error("Invalid section", section)

    result.add fieldsBlock
    result.add constructorBlock
    result.add procsBlock


macro exportRefObjectTyped(cfg: static[Config], body: typed) =
    let
        sym = body[0][0][1]
        fieldsBlock = body[1]
        constructorBlock = body[2]
        procsBlock = body[3]

    var fields: seq[(string, NimNode)]

    if fieldsBlock[1].len > 0:
        for entry in fieldsBlock[1].asStmtList:
            case entry[1][1][2].kind:
            of nnkCall:
                fields.add((
                    entry[1][1][2][0].repr,
                    entry[1][1][2].getTypeInst()
                ))
            else:
                fields.add((
                    entry[1][1][2][1].repr,
                    entry[1][1][2][1].getTypeInst()
                ))

    let constructor =
        if constructorBlock[1].len > 0:
            procTypedSym(constructorBlock[1])
        else:
            nil

    exportRefObjectC(cfg, sym, fields, constructor)
    exportRefObjectCpp(sym, fields, constructor)

    if procsBlock[1].len > 0:
        var procsSeen: seq[string]

        for entry in procsBlock[1].asStmtList:
            var
                procSym = procTypedSym(entry)
                prefixes: seq[NimNode]
            if procSym.repr notin procsSeen:
                procsSeen.add procSym.repr
            else:
                let procType = procSym.getTypeInst()

                if procType[0].len > 2:
                    prefixes.add(procType[0][2][1])

            exportProcC(cfg, procSym, sym, prefixes)
            exportProcCpp(procSym, sym, prefixes)

    exportCloseObjectCpp()


template exportRefObject*(sym, body: untyped) =
    ## Exports a ref object, with these sections:
    ## * fields
    ## * constructor
    ## * procs
    exportRefObjectTyped(exportRefObjectUntyped(sym, body))


macro writeFiles*(config: static[Config]) =
    if Target.c in config.targets:
        writeC(config)
    if Target.cxx in config.targets:
        writeCpp(config)
