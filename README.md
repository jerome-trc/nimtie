<img src="docs/gennyBanner.png">

# Genny - Generate Nim library bindings for many languages

So you made a cool Nim library but you want it to be available to other languages as well. With `genny` you can generate a dynamically linked library with a simple C API and generated bindings for many languages. In some ways its similar to [SWIG](http://www.swig.org/) project for C or [djinni](https://github.com/dropbox/djinni) for C++.


`nimble install genny`

![Github Actions](https://github.com/treeform/genny/workflows/Github%20Actions/badge.svg)

[API reference](https://treeform.github.io/genny)

This library has no dependencies other than the Nim standard library.


See [Pixie's nimble file](https://github.com/treeform/pixie/blob/master/pixie.nimble#L16) for an example of how to compile bindings with `genny`.

## Supported features and languages:

Language      | Method        | Enums  | Objects | Ref Objects | Seqs   | GC |
------------- | ------------- | ------ | ------- | ----------- | ------ | -- |
Nim           | {.importc.}   | ✅     | ✅     | ✅          | ✅    | ✅ |
Python        | ctypes        | ✅     | ✅     | ✅          | ✅    | ✅ |
Node.js       | ffi-napi      | ✅     | ✅     | ✅          | ✅    | no |
C             | .h            | ✅     | ✅     | ✅          | ✅    | no |

## Quest for "nice" language binding.

It would be pretty easy to just export a C API from Nim and have users call the ugly C style methods but that is not our goal with Genny. Instead, we try to generate a "nice" API for each language that feels like it was custom-made. This means, where possible, we:

* Use naming conventions that are familiar in the language (CamelCase, Snake_Case or Kebab-Case).
* Make sure regular `object`s are passed by value and behave simply.
* Make `ref object`s behave like OOP objects with members, methods and constructors.
* Generate helper methods like `==` or `isNull`.
* Export `seq[X]` as something that feels like a native array.
* Export `seq[X]` on a `ref object` behaves like what we call a bound-seq.
* Support the `[]` syntax.
* Support the `.` member syntax.
* Overload math operators `+`, `-`, `*`, `/`.
* Overload `proc`s, where we first unpack them to different C calls with unique prefixes and then repack them back into overloaded methods or functions.
* Pass optional arguments.
* Pass enums and constants.
* Synchronize the binding language's GC and Nim's ARC GC.
* And even copy the comments so that automated tools can use them.

## A bindings interface DSL

Genny provides a DSL that you can use to define how things need to be exported. The DSL is pretty simple to follow:

```nim
import genny, pixie

exportConsts:
  defaultMiterLimit
  autoLineHeight

exportEnums:
  FileFormat
  BlendMode

exportProcs:
  readImage
  readmask
  readTypeface

exportObject Matrix3:
  constructor:
    matrix3
  procs:
    mul(Matrix3, Matrix3)

exportRefObject Mask:
  fields:
    width
    height
  constructor:
    newMask(int, int)
  procs:
    writeFile(Mask, string)
    copy(Mask)
    getValue
    setValue

# Must have this at the end.
writeFiles("bindings/generated", "pixie")
include generated/internal
```

See more in the [pixie bindings](https://github.com/treeform/pixie/blob/master/bindings/bindings.nim)

## Genny is experimental and opinionated

Genny generates a dynamic library C API for your Nim library and generates bindings for that dynamic library in many languages. To do this, things like proc overloads, complex types, sequences, and many other Nim features need to be addressed to make them work over a C interface.

To make that C interface, Genny makes assumptions about what your Nim source looks like and how to give overloaded procedures unique names. This may not work out of the box for every Nim library yet!

## Example uses

This version of Genny was created to generate bindings for [Pixie](https://github.com/treeform/pixie). You can see how Pixie's dynamic library API is exported and the bindings generated [in this file](https://github.com/treeform/pixie/blob/master/bindings/bindings.nim) and the [results here](https://github.com/treeform/pixie-python).

## Nim is great, why other languages?

Nim is a niche language. We believe we can broaden Nim's appeal by creating Nim libraries for other more popular language and have Nim slowly work its way into companies. Maybe after companies see that they already use Nim, they will start writing their own code in it.

## Why add Nim binding support for a Nim library?

"Can't you just import your cool library in Nim?" We thought it was important to test the library in a what we call Nim-C-Nim sandwich. It makes sure everyone uses your library API the same way. This also means you could ship huge Nim libraries as DLLs and use them in your Nim programs without recompiling everything every time.
