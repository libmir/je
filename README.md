JE
=====
Fast JSON to TSV/CSV/JSON/User-defined-format Extractor.

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

#### Usage

After building, you can try je like this:
```
./je test.json --columns name:name,asdf:dependencies.asdf --input test.json
```

##### User defined output format
```json
$ cat in.jsonl 
{"a":{"b":"\n"}, "d":2}
{"a":{"b":0}, "d":1}
{"a":{"b":2}}

# query with non-positional style 
$ ./je -c a.b,d -i in.jsonl --out=$'{"a":%s,"t":%s}\n'
{"a":"\n","t":2}
{"a":0,"t":1}
{"a":2,"t":null}

# query with positional style
./je -c a.b,d -i in.jsonl --out=$'{"a":%2$s,"t":%1$s}\n'
{"a":2,"t":"\n"}
{"a":1,"t":0}
{"a":null,"t":2}
##### [Probabilistic Linear Counting](https://github.com/tamediadigital/lincount)

```json
$ cat in.jsonl
{"a":{"b":0}, "d":1}
{"a":{"b":0}, "d":2}
{"a":{"b":"\n"}, "d":1}
{"a":{"b":"\n"}, "d":2}

$je -i in.jsonl --count=a.b --count=d --count="a.b&d"

{"counter":1,"count":2}
{"counter":2,"count":2}
{"counter":3,"count":4}
```

```json
$ cat in.jsonl
{"a":{"b":10.0}, "d":null}
{"a":{"b":10.0}}
{"a":{"b":10.00}, "d":null}
{"a":{"b":10.00}}

$je -i in.jsonl --count=a.b --count=d --count="a.b&d"
{"counter":1,"count":2}
{"counter":2,"count":1}
{"counter":3,"count":2}
```

###### Unix Time-stamp partition
```json
$ cat in.jsonl
{"a":{"ts":1485831253}, "param":0}
{"a":{"ts":1485831254}, "param":1}
{"a":{"ts":1485831255}, "param":1}
{"a":{"ts":1485831400}, "param":0}
{"a":{"ts":1485831401}, "param":1}

$ ./je -i in.jsonl --count=param --count-algo=timestamp --count-algo-params=a.ts,60
{"ts":1485831360,"counter":1,"count":2}
{"ts":1485831240,"counter":1,"count":2}
```
