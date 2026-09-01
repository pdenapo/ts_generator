import std.file : write, mkdirRecurse;
import std.path : dirName;
import std.stdio : writeln, stderr;
import std.getopt;
import std.process : executeShell;
import core.stdc.stdlib : exit;
import ts_generator;

enum UserRole
{
    admin,
    user,
    guest
}

enum StrEnum : string
{
    first = "FIRST_VAL",
    second = "SECOND_VAL"
}

struct UserProfile
{
    string nickname;
    int age;
    UserRole role;
}

struct ServerResponse
{
    uint statusCode;
    string message;
    UserProfile user;
    UserProfile[] history;
    StrEnum strKind;
}

void main(string[] args)
{
    bool verify = false;
    auto helpInformation = getopt(args, "verify|v",
            "Verify generated TypeScript syntax with the TypeScript compiler (tsc)", &verify);

    if (helpInformation.helpWanted)
    {
        defaultGetoptPrinter("TypeScript generator basic example application",
                helpInformation.options);
        return;
    }

    // Generate the TS definitions for top-level API models
    string tsDeclarations = generateTypeScript!(ServerResponse)();

    string outputPath = "frontend/src/types/api.d.ts";
    mkdirRecurse(dirName(outputPath));
    write(outputPath, tsDeclarations);
    writeln("TypeScript types successfully exported to ", outputPath, "!");
    writeln("\nGenerated Output:\n");
    writeln(tsDeclarations);

    if (verify)
    {
        writeln("Verifying generated TypeScript syntax with 'tsc --noEmit'...");
        auto result = executeShell("npx -p typescript tsc --noEmit " ~ outputPath);
        if (result.status == 0)
        {
            writeln("✔ TypeScript syntax verification PASSED! (0 errors)");
        }
        else
        {
            stderr.writeln("✘ TypeScript syntax verification FAILED:");
            stderr.writeln(result.output);
            exit(1);
        }
    }
}
