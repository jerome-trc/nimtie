import std/[macros, strformat, strutils]

import ../[config, common]

var
    enumerations {.compiletime.}: string
    seqs {.compiletime.}: string
    typeDecls {.compiletime.}: string
    typeDefs {.compiletime.}: string
        ## Complete types that rely on `enumerations`, `seqs`, and `typeDecls`.
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
            of "string": "NimString"
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
            of "pointer": "void*"
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
        argStr.add(&"{arg}, ")

    argStr.removeSuffix(", ")

    if args.len < 1:
        procs.add(&"{restype} {procName}(void);\n")
    else:
        procs.add(&"{restype} {procName}({argStr});\n")

    procs.add("\n")


proc dllProc*(
    cfg: Config,
    procName: string,
    args: openarray[(NimNode, NimNode)],
    restype: string
) =
    var argsConverted: seq[string]

    if args.len < 1:
        argsConverted.add("void")
    else:
        for (argName, argType) in args:
            let n = rename(cfg.c.paramNaming, argName.getName())
            argsConverted.add(exportTypeC(cfg, argType, n))

    dllProc(procName, argsConverted, restype)


proc dllProc*(procName: string, restype: string) =
    var a: seq[(string)]
    dllProc(procName, a, restype)


proc exportConstC*(cfg: Config, sym: NimNode) =
    typeDefs.add(&"#define {toCapSnakeCase(sym.repr)} {sym.getImpl()[2].repr}\n")
    typeDefs.add("\n")


proc exportEnumC*(cfg: Config, sym: NimNode) =
    let enumSize = sym.getSize()

    let underlying = case enumSize:
        of 1: "uint8_t"
        of 2: "uint16_t"
        of 4: "uint32_t"
        of 8: "uint64_t"
        else: error(&"enum size cannot be handled: {enumSize}"); ""

    enumerations.add(&"typedef {underlying} {cfg.c.enumPrefix}{sym.repr};\n\n")
    enumerations.add("enum {\n")

    for i, entry in sym.getImpl()[2][1 .. ^1]:
        enumerations.add(&"\t{toCapSnakeCase(sym.repr)}_{toCapSnakeCase(entry.repr)},\n")

    enumerations.add("};\n\n")


proc exportProcC*(
    cfg: Config,
    sym: NimNode,
    owner: NimNode = nil,
    prefixes: openarray[NimNode] = []
) =
    let
        procName = sym.repr
        procNameSnaked = rename(cfg.c.procNaming, procName)
        procType = sym.getTypeInst()
        procParams = procType[0][1 .. ^1]
        procReturn = procType[0][0]

    var apiProcName = ""

    if owner != nil:
        apiProcName.add(&"{toSnakeCase(owner.getName())}_")

    for prefix in prefixes:
        apiProcName.add(&"{toSnakeCase(prefix.getName())}_")

    apiProcName.add(&"{procNameSnaked}")

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

        for line in lines:
            procs.add(&"/// {line}\n")

    var dllParams: seq[(NimNode, NimNode)]

    for param in procParams:
        dllParams.add((param[0], param[1]))

    dllProc(cfg, &"{cfg.c.procPrefix}{apiProcName}", dllParams, exportTypeC(cfg, procReturn))


proc exportObjectC*(cfg: Config, sym: NimNode, constructor: NimNode) =
    let objName = sym.repr

    if cfg.c.braceStyle == BraceStyle.sameLine:
        typeDefs.add(&"typedef struct {objName} " & "{\n")
    else:
        typeDefs.add(&"typedef struct {objName}\n" & "{\n")

    for identDefs in sym.getImpl()[2][2]:
        for property in identDefs[0 .. ^3]:
            let f = rename(cfg.c.fieldNaming, property[1].repr)
            let t = exportTypeC(cfg, identDefs[^2], f)
            typeDefs.add(&"    {t};\n")

    typeDefs.add("} " & &"{objName};\n\n")

    if constructor != nil:
        exportProcC(cfg, constructor)
    else:
        case cfg.c.procNaming:
        of Naming.geckoCase:
            error("unimplemented");
        of Naming.lowerCase:
            procs.add(&"{objName} {cfg.c.procPrefix}{objName.toCamelCase()}new(")
        of Naming.upperCase:
            procs.add(&"{objName} {cfg.c.procPrefix}{objName.toCamelCase()}NEW(")
        of Naming.camelCase:
            procs.add(&"{objName} {cfg.c.procPrefix}{objName.toCamelCase()}New(")
        of Naming.pascalCase:
            procs.add(&"{objName} {cfg.c.procPrefix}{objName.toPascalCase()}New(")
        of Naming.snakeCase:
            procs.add(&"{objName} {cfg.c.procPrefix}{objName.toSnakeCase()}_new(")
        of Naming.upperSnakeCase:
            procs.add(&"{objName} {cfg.c.procPrefix}{objName.toCapSnakeCase()}_NEW(")

        for identDefs in sym.getImpl()[2][2]:
            for property in identDefs[0 .. ^3]:
                procs.add(&"{exportTypeC(cfg, identDefs[^2], toSnakeCase(property[1].repr))}, ")

        procs.removeSuffix(", ")
        procs.add(");\n\n")

    when false: # TODO?
        dllProc(&"$lib_{toSnakeCase(objName)}_eq", [&"{objName} a", &"{objName} b"], "bool")


proc genRefObject(objName: string) =
    typeDefs.add(&"typedef void* {objName};\n\n")

    let unrefLibProc = &"$lib_{toSnakeCase(objName)}_unref"

    dllProc(unrefLibProc, [objName & " " & toSnakeCase(objName)], "void")


proc genSeqProcs(cfg: Config, objName, procPrefix: string, entryType: NimNode) =
    let objArg = objName & " " & toSnakeCase(objName)

    dllProc(&"{procPrefix}_len", [objArg], "size_t")
    dllProc(&"{procPrefix}_get", [objArg, "size_t index"], exportTypeC(cfg, entryType))
    dllProc(&"{procPrefix}_set", [objArg, "size_t index", exportTypeC(cfg, entryType, "value")], "void")
    dllProc(&"{procPrefix}_delete", [objArg, "size_t index"], "void")
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
        objType {.used.} = sym.getType()[1].getType()

    if constructor != nil:
        let
            constructorLibProc = &"$lib_{toSnakeCase(constructor.repr)}"
            constructorType = constructor.getTypeInst()
            constructorParams = constructorType[0][1 .. ^1]
            constructorRaises {.used.} = constructor.raises()

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
            let helperClassName {.used.} = objName & helperName

            genSeqProcs(
                cfg,
                objName,
                &"$lib_{objNameSnaked}_{fieldNameSnaked}",
                fieldType[1]
            )


proc exportSeqC*(cfg: Config, sym: NimNode) =
    let seqName = sym.getName()
    let lenName = rename(cfg.c.fieldNaming, "len")
    let dataName = rename(cfg.c.fieldNaming, "d")
    let payloadName = rename(cfg.c.fieldNaming, "p")

    if cfg.c.braceStyle == BraceStyle.sameLine:
        seqs.add &"""
typedef struct _Seq{sym[1].repr} {{
    NimInt {lenName};
    struct {{ NimInt cap; {sym[1].repr} {dataName}[]; }}* {payloadName};
}} Seq{sym[1].repr};

"""
    else:
        seqs.add &"""
typedef struct _Seq{sym[1].repr}
{{
    NimInt {lenName};
    struct {{ NimInt cap; {sym[1].repr} {dataName}[]; }}* {payloadName};
}} Seq{sym[1].repr};

"""

    let seqProcPrefix = case cfg.c.procNaming:
        of Naming.geckoCase:
            error("unimplemented"); ""
        of Naming.lowerCase:
            &"{cfg.c.procPrefix}{seqName.toLowerAscii()}"
        of Naming.upperCase:
            &"{cfg.c.procPrefix}{seqName.toUpperAscii()}"
        of Naming.camelCase:
            &"{cfg.c.procPrefix}{seqName.toCamelCase()}"
        of Naming.pascalCase:
            &"{cfg.c.procPrefix}{seqName.toPascalCase()}"
        of Naming.snakeCase:
            &"{cfg.c.procPrefix}{seqName.toSnakeCase()}"
        of Naming.upperSnakeCase:
            &"{cfg.c.procPrefix}{seqName.toCapSnakeCase()}"

    case cfg.c.procNaming:
        of Naming.geckoCase:
            error("unimplemented");
        of Naming.lowerCase:
            dllProc(seqProcPrefix & "new", seqName)
        of Naming.upperCase:
            dllProc(seqProcPrefix & "NEW", seqName)
        of Naming.camelCase, Naming.pascalCase:
           dllProc(seqProcPrefix & "New", seqName)
        of Naming.snakeCase:
            dllProc(seqProcPrefix & "_new", seqName)
        of Naming.upperSnakeCase:
            dllProc(seqProcPrefix & "_NEW", seqName)

    genSeqProcs(
        cfg,
        sym.getName(),
        seqProcPrefix,
        sym[1]
    )


const externCSameLineBrace = """
#ifdef __cplusplus
extern "C" {
#endif

"""

const externCNewLineBrace = """
#ifdef __cplusplus
extern "C"
{
#endif

"""

const externCClosing = """
#ifdef __cplusplus
}
#endif
"""

proc writeC*(cfg: Config) =
    let dir = cfg.directory

    var output = cfg.header

    if cfg.c.pragmaOnce:
        output &= "#pragma once\n\n"

    if cfg.c.includeGuard.len > 0:
        output &= &"#ifndef {cfg.c.includeGuard}\n#define {cfg.c.includeGuard}\n\n"

    for incl in cfg.c.includes:
        output &= &"#include {incl}\n"

    if cfg.c.includes.len > 0:
        output &= "\n"

    output &= cfg.c.afterIncludes

    when sizeof(int) == 8:
        output &= "typedef int64_t NimInt;\n\n"
    elif sizeof(int) == 4:
        output &= "typedef int32_t NimInt;\n\n"
    else:
        {.fatal: "unsupported integer size".}

    let lenName = rename(cfg.c.fieldNaming, "len")
    let dataName = rename(cfg.c.fieldNaming, "d")
    let payloadName = rename(cfg.c.fieldNaming, "p")

    if cfg.c.braceStyle == BraceStyle.sameLine:
        output &= &"""
typedef struct _NimString {{
    NimInt {lenName};
    struct {{ NimInt cap; char {dataName}[]; }}* {payloadName};
}} NimString;

"""
    else:
        output &= &"""
typedef struct _NimString
{{
    NimInt {lenName};
    struct {{ NimInt cap; char {dataName}[]; }}* {payloadName};
}} NimString;

"""

    output &= enumerations
    output &= seqs
    output &= typeDecls
    output &= typeDefs.replace("$lib", cfg.c.structPrefix)

    if cfg.c.cxxCompat:
        if cfg.c.braceStyle == BraceStyle.sameLine:
            output &= externCSameLineBrace
        else:
            output &= externCNewLineBrace

    output &= procs.replace("$lib", cfg.c.procPrefix)

    if cfg.c.cxxCompat:
        output &= externCClosing

    if cfg.c.includeGuard.len > 0:
        output &= &"#endif // {cfg.c.includeGuard}\n"

    output &= cfg.trailer

    writeFile(&"{dir}/{cfg.filename}.h", output)
