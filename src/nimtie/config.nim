type
    BraceStyle* {.pure.} = enum
        sameLine
        newLine

    Naming* {.pure.} = enum
        camelCase
            ## e.g. `loremIpsum`.
        geckoCase
        lowerCase
            ## e.g. `loremipsum`.
        pascalCase
            ## e.g. `LoremIpsum`.
        snakeCase
            ## e.g. `lorem_ipsum`.
        upperCase
            ## e.g. `LOREMIPSUM`.
        upperSnakeCase
            ## e.g. `LOREM_IPSUM`.

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
        cxxCompat*: bool = false
        enumPrefix*: string = ""
        includeGuard*: string = "" ## \
            ## Note that this is not mutually-exclusive with `pragmaOnce`.
        includes*: seq[string] = @["<stdbool.h>", "<stddef.h>", "<stdint.h>",] ## \
            ## Each string is written as-is, so quotes or angle brackets must be included.
        paramNaming*: Naming = Naming.camelCase
        pragmaOnce*: bool = true ## \
            ## Note that this is not mutually-exclusive with `includeGuard`.
        procPrefix*: string = "" ## \
            ## Prepended to the name of every generated function binding.
        procNaming*: Naming = Naming.camelCase ## \
            ## Affects not only renaming of exported routines, but also
            ## generation of names for new routines.
        structPrefix*: string = "" ## \
            ## Prepended to the name of every generated struct declaration.

    Config* {.byref.} = object
        ## Passed to `proc writeFiles`_.
        directory*: string = "."
        header*: string = "" ## \
            ## Added to the very beginning of the file as-is.
        filename*: string = "mylib"
        targets*: Targets = {} ## \
            ## What languages should bindings be generated for?
        trailer*: string = "" ## \
            ## Added to the very end of the file as-is.
        c*: CConfig
