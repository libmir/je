JE
=====
Fast JSON to TSV/CSV Extractor.

### Build je

#### Requirements

1. [dub](https://code.dlang.org/getting_started) package manager.
2. D compiler. Options:
  - [LDC](https://github.com/ldc-developers/ldc) (LLVM D Compiler) >= `1.1.0-beta2`
  - [DMD](http://dlang.org/download.html) (DigitalMars D Compiler) >= `2.072.1`

#### Build with the dub package manager

To build project with LDC run following command from `je` project:
```
dub build --build=release-sse42 --compiler=ldmd2
```
or
```
dub build --build=release-native --compiler=ldmd2
```

To build project with DMD run
```
dub build --build=release
```

For more details run `je --help`.
