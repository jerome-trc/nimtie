import std/[macros, strformat, strutils]

import ../config, ../common

var
    types {.compiletime.}: string
    procs {.compiletime.}: string

proc exportTypeC(cfg: Config, sym: NimNode): string =
    if sym.kind == nnkBracketExpr:
        if sym[0].repr == "array":
            let
                entryCount = sym[1].repr
                entryType = exportTypeC(cfg, sym[2])

            result = &"{entryType}[{entryCount}]"
        elif sym[0].repr == "seq":
            result = sym.getSeqName()
        else:
            error(&"Unexpected bracket expression {sym[0].repr}[")
    elif sym.kind == nnkPtrTy:
        result = &"{exportTypeC(cfg, sym[0])}*"
    elif sym.kind == nnkVarTy:
        result = &"{exportTypeC(cfg, sym[0])}*"
    else:
        result = case sym.repr:
            # Nim's types...
            of "bool": "bool"
            of "byte": "uint8_t"
            of "cstring": "char*"
            of "float32": "float"
            of "float64", "float": "double"
            of "int":
                if sizeof(int) == 8: "int64_t"
                elif sizeof(int) == 4: "int32_t"
                else: error("unsupported `int` size"); ""
            of "int8": "int8_t"
            of "int16": "int16_t"
            of "int32": "int32_t"
            of "int64": "int64_t"
            of "uint":
                if sizeof(uint) == 8: "uint64_t"
                elif sizeof(uint) == 4: "uint32_t"
                else: error("unsupported `uint` size"); ""
            of "uint8": "uint8_t"
            of "uint16": "uint16_t"
            of "uint32": "uint32_t"
            of "uint64": "uint64_t"
            of "Rune": "int"
            of "Vec2": "Vector2"
            of "Mat3": "Matrix3"
            of "", "nil": "void"
            of "None": "void"
            # C compatibility types...
            of "cchar": "char"
            of "cdouble": "double"
            of "cfloat": "float"
            of "cint": "int"
            of "clong": "long"
            of "clongdouble": "long double"
            of "clonglong": "long long"
            of "cschar": "signed char"
            of "csize_t": "size_t"
            of "cstringarray": "char**"
            of "cuchar": "unsigned char"
            of "cuint": "unsigned int"
            of "culong": "unsigned long"
            of "culonglong": "unsigned long long"
            of "cushort": "unsigned short"
            else: sym.repr


proc exportTypeC(cfg: Config, sym: NimNode, name: string): string =
    if sym.kind == nnkBracketExpr:
        if sym[0].repr == "array":
            let
                entryCount = sym[1].repr
                entryType = exportTypeC(cfg, sym[2], &"{name}[{entryCount}]")
            result = &"{entryType}"
        elif sym[0].repr == "seq":
            result = sym.getSeqName() & " " & name
        else:
            error(&"Unexpected bracket expression {sym[0].repr}[")
    else:
        result = exportTypeC(cfg, sym) & " " & name


proc dllProc*(procName: string, args: openarray[string], restype: string) =
    var argStr = ""

    for arg in args:
        argStr.add &"{arg}, "

    argStr.removeSuffix ", "
    procs.add &"{restype} {procName}({argStr});\n"
    procs.add "\n"


proc dllProc*(
    cfg: Config,
    procName: string,
    args: openarray[(NimNode, NimNode)],
    restype: string
) =
    var argsConverted: seq[string]

    for (argName, argType) in args:
        argsConverted.add exportTypeC(cfg, argType, toSnakeCase(argName.getName()))

    dllProc(procName, argsConverted, restype)


proc dllProc*(procName: string, restype: string) =
    var a: seq[(string)]
    dllProc(procName, a, restype)


proc exportConstC*(sym: NimNode) =
    types.add &"#define {toCapSnakeCase(sym.repr)} {sym.getImpl()[2].repr}\n"
    types.add "\n"


proc exportEnumC*(sym: NimNode) =
    types.add &"typedef char {sym.repr};\n"

    for i, entry in sym.getImpl()[2][1 .. ^1]:
        types.add &"#define {toCapSnakeCase(entry.repr)} {i}\n"

    types.add "\n"


proc exportProcC*(
    cfg: Config,
    sym: NimNode,
    owner: NimNode = nil,
    prefixes: openarray[NimNode] = []
) =
    let
        procName = sym.repr
        procNameSnaked = toSnakeCase(procName)
        procType = sym.getTypeInst()
        procParams = procType[0][1 .. ^1]
        procReturn = procType[0][0]

    var apiProcName = ""

    if owner != nil:
        apiProcName.add &"{toSnakeCase(owner.getName())}_"

    for prefix in prefixes:
        apiProcName.add &"{toSnakeCase(prefix.getName())}_"

    apiProcName.add &"{procNameSnaked}"

    var defaults: seq[(string, NimNode)]

    for identDefs in sym.getImpl()[3][1 .. ^1]:
        let default = identDefs[^1]
        for entry in identDefs[0 .. ^3]:
            defaults.add((entry.repr, default))

    let comments =
        if sym.getImpl()[6][0].kind == nnkCommentStmt:
            sym.getImpl()[6][0].repr
        elif sym.getImpl[6].kind == nnkAsgn and
            sym.getImpl[6][1].kind == nnkStmtListExpr and
            sym.getImpl[6][1][0].kind == nnkCommentStmt:
            sym.getImpl[6][1][0].repr
        else:
            ""
    if comments != "":
        let lines = comments.replace("## ", "").split("\n")
        procs.add "/**\n"

        for line in lines:
            procs.add &" * {line}\n"

        procs.add " */\n"

    var dllParams: seq[(NimNode, NimNode)]

    for param in procParams:
        dllParams.add((param[0], param[1]))

    dllProc(cfg, &"$lib_{apiProcName}", dllParams, exportTypeC(cfg, procReturn))


proc exportObjectC*(cfg: Config, sym: NimNode, constructor: NimNode) =
    let objName = sym.repr

    types.add &"typedef struct {objName} " & "{\n"

    for identDefs in sym.getImpl()[2][2]:
        for property in identDefs[0 .. ^3]:
            types.add &"  {exportTypeC(cfg, identDefs[^2], toSnakeCase(property[1].repr))};\n"

    types.add "} " & &"{objName};\n\n"

    if constructor != nil:
        exportProcC(cfg, constructor)
    else:
        procs.add &"{objName} $lib_{toSnakeCase(objName)}("
        for identDefs in sym.getImpl()[2][2]:
            for property in identDefs[0 .. ^3]:
                procs.add &"{exportTypeC(cfg, identDefs[^2], toSnakeCase(property[1].repr))}, "
        procs.removeSuffix ", "
        procs.add ");\n\n"

    dllProc(&"$lib_{toSnakeCase(objName)}_eq", [&"{objName} a", &"{objName} b"], "bool")


proc genRefObject(objName: string) =
    types.add &"typedef long long {objName};\n\n"

    let unrefLibProc = &"$lib_{toSnakeCase(objName)}_unref"

    dllProc(unrefLibProc, [objName & " " & toSnakeCase(objName)], "void")


proc genSeqProcs(cfg: Config, objName, procPrefix, selfSuffix: string, entryType: NimNode) =
    let objArg = objName & " " & toSnakeCase(objName)

    dllProc(&"{procPrefix}_len", [objArg], "long long")
    dllProc(&"{procPrefix}_get", [objArg, "long long index"], exportTypeC(cfg, entryType))
    dllProc(&"{procPrefix}_set", [objArg, "long long index", exportTypeC(cfg,
            entryType, "value")], "void")
    dllProc(&"{procPrefix}_delete", [objArg, "long long index"], "void")
    dllProc(&"{procPrefix}_add", [objArg, exportTypeC(cfg, entryType, "value")], "void")
    dllProc(&"{procPrefix}_clear", [objArg], "void")


proc exportRefObjectC*(
    cfg: Config,
    sym: NimNode,
    fields: seq[(string, NimNode)],
    constructor: NimNode
) =
    let
        objName = sym.repr
        objNameSnaked = toSnakeCase(objName)
        objType = sym.getType()[1].getType()

    genRefObject(objName)

    if constructor != nil:
        let
            constructorLibProc = &"$lib_{toSnakeCase(constructor.repr)}"
            constructorType = constructor.getTypeInst()
            constructorParams = constructorType[0][1 .. ^1]
            constructorRaises = constructor.raises()

        var dllParams: seq[(NimNode, NimNode)]
        for param in constructorParams:
            dllParams.add((param[0], param[1]))
        dllProc(cfg, constructorLibProc, dllParams, objName)

    for (fieldName, fieldType) in fields:
        let fieldNameSnaked = toSnakeCase(fieldName)

        if fieldType.kind != nnkBracketExpr:
            let getProcName = &"$lib_{objNameSnaked}_get_{fieldNameSnaked}"

            let setProcName = &"$lib_{objNameSnaked}_set_{fieldNameSnaked}"

            dllProc(getProcName, [objName & " " & objNameSnaked], exportTypeC(cfg, fieldType))
            dllProc(setProcName, [objName & " " & objNameSnaked, exportTypeC(cfg,
                    fieldType, "value")], exportTypeC(cfg, nil))
        else:
            var helperName = fieldName
            helperName[0] = toUpperAscii(helperName[0])
            let helperClassName = objName & helperName

            genSeqProcs(
                cfg,
                objName,
                &"$lib_{objNameSnaked}_{fieldNameSnaked}",
                &".{toSnakeCase(objName)}",
                fieldType[1]
            )


proc exportSeqC*(cfg: Config, sym: NimNode) =
    let
        seqName = sym.getName()
        seqNameSnaked = toSnakeCase(seqName)

    genRefObject(seqName)

    let newSeqProc = &"$lib_new_{toSnakeCase(seqName)}"

    dllProc(newSeqProc, seqName)

    genSeqProcs(
        cfg,
        sym.getName(),
        &"$lib_{seqNameSnaked}",
        "",
        sym[1]
    )


proc writeC*(cfg: Config) =
    let dir = cfg.directory
    let lib = cfg.filename

    var output = ""

    if cfg.c.pragmaOnce:
        output &= "#pragma once\n\n"

    if cfg.c.includeGuard.len > 0:
        output &= &"#ifndef {cfg.c.includeGuard}\n#define {cfg.c.includeGuard}\n\n"

    output &= types.replace("$lib", cfg.c.structPrefix)
    output &= procs.replace("$lib", cfg.c.procPrefix)

    if cfg.c.includeGuard.len > 0:
        output &= &"#endif // {cfg.c.includeGuard}\n"

    writeFile(&"{dir}/{cfg.filename}.h", output)
