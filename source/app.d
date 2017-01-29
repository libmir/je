import std.stdio;
import std.conv;
import std.getopt;
import std.algorithm;
import std.range;
import std.format;
import std.traits;

import asdf;

int main(string[] args)
{
    bool header = true;
    string[] names;
    string[][] options;
    string[] columns;
    size_t chunkSize = 4096;
    string finName;
    string foutName;
    string sep = "\t";
    string newline = "\n";
    arraySep = ",";
    bool raw;
    string fmt;
    try
    {
        auto helpInformation = args.getopt(
            config.required,
            "c|columns", "column names (example: --columns=col_name1:opt1.optl1_2,col_name2:opt3.opt3_9,col_name3_with_the_same_opt,some=fixed_data)", &columns,
            "s|sep", `column separator, default value is "\t"`,  &sep,
            "n|newline", `row separator, default value is "\n"`, &newline,
            "o|output", "Output file name", &foutName,
            "i|input", "Input file name", &finName,
            "r|raw", "Raw output for strings. Removes '\"' braces.", &raw,
            "header", "Add header, default value is 'true'. Header would not be added if --outer option was specified.", &header,
            "chunk-size", "Input chunk size in bytes, default value is " ~ chunkSize.to!string, &chunkSize,
            "out", `user-defined output format (example: --out=$'{"a":"%s": "t":%s}\n')`, &fmt,
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
    ////////////
    auto ltw = fout.lockingTextWriter;
    auto lines = fin.byChunk(chunkSize).parseJsonByLine();
    if (!fmt)
    foreach(line; lines)
    {
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
