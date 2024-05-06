type
    BraceStyle* {.pure.} = enum
        sameLine
        newLine

    RenameRule* {.pure.} = enum
        none
        geckoCase
        lowerCase
        upperCase
        pascalCase
        camelCase
        snakeCase
        upperSnakeCase

    Target* {.pure.} = enum
        ## What languages should bindings be generated for?
        c
        cxx
    Targets* = set[Target]
        ## What languages should bindings be generated for?

    CConfig* = object
        ## Configuration for generated C bindings.
        ## Note that some of these settings also apply to generated C++ bindings.
        braceStyle*: BraceStyle = BraceStyle.sameLine
        fixedWidthInt*: bool = true ## \
      ## Whether to use `[u]int##_t` types instead of `int`, `long`, etc.
        includeGuard*: string = "" ## \
      ## Note that this is not mutually-exclusive with `pragmaOnce`.
        includes*: seq[string] = @[] ## \
      ## Each string is written as-is, so quotes or angle brackets must be included.
        pragmaOnce*: bool = true ## \
      ## Note that this is not mutually-exclusive with `includeGuard`.
        procPrefix*: string = "" ## \
      ## Prepended to the name of every generated function binding.
        structPrefix*: string = "" ## \
      ## Prepended to the name of every generated struct declaration.

    Config* = object
        ## Passed to `proc writeFiles`_.
        directory*: string = "."
        filename*: string = "mylib"
        targets*: Targets = {} ## \
      ## What languages should bindings be generated for?
        c*: CConfig
