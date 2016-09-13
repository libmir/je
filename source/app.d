import std.stdio;
import std.conv;
import std.getopt;
import std.algorithm;
import std.range;

import asdf;

int main(string[] args)
{
    string[] names;
    string[][] options;
    string[] columns;
    size_t chunkSize = 4096;
    string finName;
    string foutName;
    string sep = "\t";
    string newline = "\n";
    arraySep = ",";
    try
    {
        auto helpInformation = args.getopt(
            config.required,
            "c|columns", "column names (example: --columns=colName1:opt1.optl1_2,colName2:opt3.opt3_9,colName3withTheSameOpt)", &columns,
            "s|sep", `column separator, default value is "\t"`,  &sep,
            "n|newline", `row separator, default value is "\n"`, &newline,
            "o|output", "Output file name", &foutName,
            "i|input", "Input file name", &finName,
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

    fout.writef("%(%s" ~ sep ~ "%)" ~ newline, names);
    ////////////
    auto ltw = fout.lockingTextWriter;
    foreach(line; fin.byChunk(chunkSize).parseJsonByLine())
    {
        foreach(i, option; options)
        {
            auto val = line[option];
            if(val.data.length)
                val.toString(&ltw.put!(const(char)[]));
            ltw.put(i == options.length - 1 ? newline : sep);
        }
    }
    return 0;
}
