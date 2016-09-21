import std.stdio;
import std.conv;
import std.getopt;
import std.algorithm;
import std.range;

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
    try
    {
        auto helpInformation = args.getopt(
            config.required,
            "c|columns", "column names (example: --columns=colName1:opt1.optl1_2,colName2:opt3.opt3_9,colName3withTheSameOpt)", &columns,
            "s|sep", `column separator, default value is "\t"`,  &sep,
            "n|newline", `row separator, default value is "\n"`, &newline,
            "o|output", "Output file name", &foutName,
            "i|input", "Input file name", &finName,
            "r|raw", "Raw output for strings. R22emoves '\"' braces.", &raw,
            "header", "Add header, default value is 'true'", &header,
            "chunk-size", "Input chunk size in bytes, defult valut is " ~ chunkSize.to!string, &chunkSize,
            );
        if (helpInformation.helpWanted)
        {
            defaultGetoptPrinter("Parameters:", helpInformation.options);
            return 0;
        }
    }
    catch(Exception e)
    {
        writeln(e.msg);
        writeln("Run 'je -h' for more details.");
        return 1;
    }

    names = new string[columns.length];
    options = new string[][columns.length];
    foreach(i, column; columns)
    {
        auto s = column.findSplit(":");
        if(s[1].length)
        {
            names[i] = s[0];
            options[i] = s[2].split(".");
        }
        else
        {
            names[i] = column;
            options[i] = column.split(".");
        }
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
    foreach(line; fin.byChunk(chunkSize).parseJsonByLine())
    {
        foreach(i, option; options)
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
            ltw.put(i == options.length - 1 ? newline : sep);
        }
    }
    return 0;
}
