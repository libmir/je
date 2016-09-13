import std.stdio;
import std.conv;
import std.getopt;
import std.algorithm;
import std.array;
import std.format;
import std.traits;
import std.exception;

import std.digest.digest: digest, makeDigest;
import std.digest.murmurhash: MurmurHash3;

import asdf;
import hll;

alias Hasher = MurmurHash3!(128, 64);

enum countSize = 32; // KB

string[][][] countingOptions;
size_t maxCountingOptionLength;
Asdf[] countingValues;
ubyte[] nullAsdfData = [ubyte(0)];
string[] countArgs;

int main(string[] args)
{
    bool header = true;
    string[] names;
    string[][] options;
    string[] columns;
    size_t chunkSize = 4096;
    string finName;
    string foutName;
    string countFoutName;
    string sep = "\t";
    string newline = "\n";
    string[] counterStrings;
    string[] counterNames;
    string countAlgo;
    arraySep = ",";
    bool raw;
    string fmt;
    try
    {
        auto helpInformation = args.getopt(
            "c|columns", "column names (example: --columns=col_name1:opt1.optl1_2,col_name2:opt3.opt3_9,col_name3_with_the_same_opt,some=fixed_data)", &columns,
            "s|sep", `column separator, default value is "\t"`,  &sep,
            "n|newline", `row separator, default value is "\n"`, &newline,
            "o|output", "Output file name", &foutName,
            "i|input", "Input file name", &finName,
            "r|raw", "Raw output for strings. Removes '\"' braces.", &raw,
            "header", "Add header, default value is 'true'. Header would not be added if --outer option was specified.", &header,
            "chunk-size", "Input chunk size in bytes, default value is " ~ chunkSize.to!string, &chunkSize,
            "out", `user-defined output format (example: --out=$'{"a":"%s": "t":%s}\n')`, &fmt,
            "count", "Counts unique elements using Probabilistic Linear Counting", &counterStrings,
            "count-output", "Output file name for counting", &countFoutName,
            "count-algo", "Counting algorithm (optional)", &countAlgo,
            "count-algo-params", "Counting algorithm parameters (optional)", &countArgs,
            );
        if (helpInformation.helpWanted)
        {
            defaultGetoptPrinter("Parameters:", helpInformation.options);
            return 0;
        }
    }
    catch(Exception e)
    {
        stderr.writeln(e.msg);
        stderr.writeln("Run 'je -h' for more details.");
        return 1;
    }

    if(fmt)
        header = false;

    if (columns.length == 0)
        header = false;
    names = new string[columns.length];
    options = new string[][columns.length];
    auto fixedFlags = new bool[columns.length];
    foreach(i, column; columns)
    {
        auto s = column.findSplit(":");
        if(s[1].length)
        {
            names[i] = s[0];
            options[i] = s[2].split(".");
            continue;
        }
        if (!fmt)
        {
            s = column.findSplit("=");
            if(s[1].length)
            {
                fixedFlags[i] = true;
                names[i] = s[0];
                options[i] = [s[2]];
                continue;
            }
        }
        names[i] = column;
        options[i] = column.split(".");
    }

    auto fin = finName.length ? File(finName) : stdin;
    auto fout = foutName.length ? File(foutName, "w") : stdout;
    auto cout = countFoutName.length ? File(countFoutName, "w") : stdout;

    if(header)
    {
        if(raw)
        {
            foreach(i, name; names)
            {
                fout.write(name);
                fout.write(i == names.length - 1 ? newline : sep);
            }
        }
        else
        {
            fout.writef("%(%s" ~ sep ~ "%)" ~ newline, names);
        }
    }

    if(counterStrings.length)
    {
        counterNames = new string[counterStrings.length];
        foreach(i, ref str; counterStrings)
        {
            auto spl = str.findSplit(":");
            if (spl[1].length)
            {
                str = spl[2];
                counterNames[i] = spl[0];
            }
            else
            {
                counterNames[i] = format("_counter_%s", i + 1);
            }
        }
        countingOptions = counterStrings.map!(a => a.splitter("&").map!(a => a.split(".")).array).array;
        maxCountingOptionLength = countingOptions.map!"a.length".reduce!max;
        countingValues = new Asdf[maxCountingOptionLength];
    }

    Counter counter;
    if (counterStrings.length)
    {
        try
        {
            switch(countAlgo)
            {
                case "timestamp":
                    counter = new TimePartitioner(counterNames);
                    break;
                default:
                    enforce(countAlgo.length == 0, "Unexpected count algorithm: " ~ countAlgo);
                    counter = new DefaultCounter(counterNames);
            }
        }
        catch(Exception e)
        {
            writeln("Failed to create counters:");
            writeln(e.msg);
        }
    }
    else
    {
        counter = new NullCounter;
    }

    ////////////
    auto ltw = fout.lockingTextWriter;
    auto lines = fin.byChunk(chunkSize).parseJsonByLine();
    if (!fmt)
    foreach(line; lines)
    {
        if(line.data.length == 0)
            continue;
        counter.put(line);
        foreach(i, option; options)
        {
            if(fixedFlags[i])
            {
                if(raw)
                    ltw.put(option[0]);
                else
                    formattedWrite(&ltw.put!(const(char)[]), "%(%s%)", option);
            }
            else
            {
                auto val = line[option];
                if(val.data.length)
                {
                    if(raw && val.kind == Asdf.Kind.string)
                    {
                        ltw.put(cast(string) val);
                    }
                    else
                    {
                        val.toString(&ltw.put!(const(char)[]));
                    }
                }
            }
            ltw.put(i == options.length - 1 ? newline : sep);
        }
    }
    else
    {
        auto spec = FormatSpec!char(fmt);
        auto values = new Asdf[options.length];
        foreach(line; lines)
        {
            foreach(i, option; options)
                values[i] = line[option];
            jeFormattedWrite(&ltw.put!(const(char)[]), spec, fmt, values);
        }
    }
    cout.write(counter);
    return 0;
}

uint jeFormattedWrite(void delegate(const(char)[] data) w, FormatSpec!char spec, string fmt, Asdf[] args)
{
    import std.exception: enforce;
    import std.conv: to;

    // Are we already done with formats? Then just dump each parameter in turn
    uint currentArg = 0;
    while (spec.writeUpToNextSpec(w))
    {
        if (currentArg == args.length && !spec.indexStart)
        {
            // leftover spec?
            enforce(fmt.length == 0, "Orphan format specifier: %" ~ spec.spec);
            break;
        }
        if (spec.width == spec.DYNAMIC)
        {
            throw new Exception("Dynamic widths are not allowed in JE format strings.");
        }
        else if (spec.width < 0)
        {
            // means: get width as a positional parameter
            throw new Exception("Negative widths are not allowed in JE format strings.");
        }
        if (spec.precision == spec.DYNAMIC)
        {
            throw new Exception("Dynamic precisions are not allowed in JE format strings.");
        }
        else if (spec.precision < 0)
        {
            // means: get precision as a positional parameter
            throw new Exception("Negative precisions are not allowed in JE format strings.");
        }
        // Format!
        if (spec.indexStart > 0)
        {
            if (args.length > 0)
            {
                foreach (i; spec.indexStart - 1 .. spec.indexEnd)
                {
                    if (args.length <= i) break;
                    if (args[i].data.length)
                        args[i].toString(w);
                    else
                        w("null");
                }
            }
            if (currentArg < spec.indexEnd) currentArg = spec.indexEnd;
        }
        else
        {
            if (args[currentArg].data.length)
                args[currentArg].toString(w);
            else
                w("null");
            ++currentArg;
        }
    }
    return currentArg;
}

interface Counter
{
    void put(Asdf line);

    void toString(scope void delegate(const(char)[]) sink);
}

class NullCounter : Counter
{
    void put(Asdf line) {}
    void toString(scope void delegate(const(char)[]) sink) {}
}

class DefaultCounter : Counter
{
    HLL[] counters;
    string[] counterNames;

    this(string[] counterNames)
    {
        import core.stdc.stdlib;
        this.counterNames = counterNames;
        counters = uninitializedArray!(HLL[])(countingOptions.length);
        foreach(ref counter; counters)
            dlang_hll_create(counter, 18, 25, &malloc, &realloc, &free);
    }

    ~this()
    {
        foreach(ref counter; counters)
            dlang_hll_destroy(counter);
    }

    void put(Asdf line)
    {
        foreach(i, countingOption; countingOptions)
        {
            auto hasher = makeDigest!Hasher;
            foreach(path; countingOption)
            {
                auto value = line[path];
                hasher.put(value.data.length ? value.data : nullAsdfData);
            }
            auto h2 = cast(ulong[2])hasher.finish();
            auto h = h2[0] ^ h2[1];
            counters[i].put(h);
        }
    }

    void toString(scope void delegate(const(char)[]) sink)
    {
        sink("{");
        foreach (i, ref counter; counters)
        {
            if (i)
                sink(",");
            sink.formattedWrite(`"%s":%s`, counterNames[i], counter.count);
        }
        sink("}\n");
    }
}

class TimePartitioner : Counter
{
    ulong mod;
    DefaultCounter[ulong] counters;
    string[] path;
    string[] counterNames;

    this(string[] counterNames)
    {
        this.counterNames = counterNames;
        enforce(countArgs.length == 2, "Timer partitioner requires eaxctly two parameters: JSON path for timestamp, interval (in seconds).");
        path = countArgs[0].split(".");
        mod = countArgs[1].to!ulong;
    }

    void put(Asdf line)
    {
        auto ts = line[path];
        ulong partition = ts.get(0UL);
        partition -= partition % mod;
    L:
        if(auto p = partition in counters)
        {
            p.put(line);
        }
        else
        {
            counters[partition] = new DefaultCounter(counterNames);
            goto L;
        }
    }

    void toString(scope void delegate(const(char)[]) sink)
    {
        foreach(ts, counterCollection; counters)
        {
            sink("{");
            sink.formattedWrite(`"ts":%s`, ts);
            foreach (i, ref counter; counterCollection.counters)
            {
                sink(",");
                sink.formattedWrite(`"%s":%s`, counterNames[i], counter.count);
            }
            sink("}\n");
        }
    }
}
