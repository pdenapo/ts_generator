module ts_generator;

import std.traits;
import std.meta : AliasSeq;
import std.array : Appender;
import std.format : format;
import std.typecons : Nullable;
import std.datetime : SysTime, DateTime, Date;

/**
 * Maps a single D type T to its TypeScript equivalent string representation.
 */
public string toTsType(T)()
{
    alias U = Unqual!T;

    // 1. Nullable!V from std.typecons
    static if (is(U : Nullable!V, V))
        return toTsType!V() ~ " | null";
    // 2. Dates / Timestamps mapped to ISO 8601 string representation in JSON
    else static if (is(U == SysTime) || is(U == DateTime) || is(U == Date))
        return "string";
    // 3. Strings & Characters
    else static if (is(U == string) || is(U == wstring) || is(U == dstring) || isSomeChar!U)
        return "string";
    // 4. Booleans
    else static if (isBoolean!U)
        return "boolean";
    // 5. Enums, Structs, and Classes (Referenced by their type name)
    else static if (is(U == enum) || is(U == struct) || is(U == class))
        return U.stringof;
    // 6. Numeric primitives (int, uint, float, double, etc.)
    else static if (isNumeric!U)
        return "number";
    // 7. Dynamic and Static Arrays
    else static if (isArray!U)
        return toTsType!(ForeachType!U)() ~ "[]";
    // 8. Associative Arrays (Dictionaries)
    else static if (isAssociativeArray!U)
        return format("{ [key: string]: %s }", toTsType!(ValueType!U)());
    // Fallback for unsupported types
    else
        return "any";
}

/**
 * Helper template to extract foundational underlying type(s) from composite types
 * (such as arrays, associative arrays, pointers, Nullable wrappers).
 * Used for recursive type discovery.
 */
template BaseTypes(T) {
    alias U = Unqual!T;
    static if (is(U == enum))
        alias BaseTypes = AliasSeq!(U);
    else static if (is(U : Nullable!V, V))
        alias BaseTypes = BaseTypes!V;
    else static if (isPointer!U)
        alias BaseTypes = BaseTypes!(PointerTarget!U);
    else static if (isSomeString!U || is(U == SysTime) || is(U == DateTime) || is(U == Date))
        alias BaseTypes = AliasSeq!();
    else static if (isArray!U)
        alias BaseTypes = BaseTypes!(ForeachType!U);
    else static if (isAssociativeArray!U)
        alias BaseTypes = AliasSeq!(BaseTypes!(KeyType!U), BaseTypes!(ValueType!U));
    else static if (is(U == struct) || is(U == class))
        alias BaseTypes = AliasSeq!(U);
    else
        alias BaseTypes = AliasSeq!();
}

/**
 * Generates TypeScript interface and enum definitions as a string for a given set of D types.
 * Resolves nested structs, classes, and enums automatically.
 */
string generateTypeScript(Types...)()
{
    Appender!string sb;
    bool[string] visited;

    void processType(T)() {
        alias UnqualT = Unqual!T;
        string name = UnqualT.stringof;

        if (name in visited) return;
        visited[name] = true;

        static if (is(UnqualT == enum)) {
            sb.put(format("export enum %s {\n", name));
            static foreach (member; EnumMembers!UnqualT) {
                {
                    alias OrigT = OriginalType!UnqualT;
                    static if (isSomeString!OrigT) {
                        sb.put(format("    %s = \"%s\",\n", __traits(identifier, member), cast(string)member));
                    } else {
                        sb.put(format("    %s = %s,\n", __traits(identifier, member), cast(long)member));
                    }
                }
            }
            sb.put("}\n\n");
        }
        else static if (is(UnqualT == struct) || is(UnqualT == class)) {
            // First, recursively discover and process dependency types used by fields
            static foreach (i, field; UnqualT.tupleof) {
                {
                    alias memType = typeof(field);
                    static foreach (BaseT; BaseTypes!memType) {
                        processType!BaseT();
                    }
                }
            }

            sb.put(format("export interface %s {\n", name));
            static foreach (i, field; UnqualT.tupleof) {
                {
                    alias memType = typeof(field);
                    string fieldName = __traits(identifier, UnqualT.tupleof[i]);
                    string tsType = toTsType!memType();
                    sb.put(format("    %s: %s;\n", fieldName, tsType));
                }
            }
            sb.put("}\n\n");
        }
    }

    static foreach (T; Types) {
        processType!T();
    }

    return sb.data;
}

// ============================================================================
// Unit Tests
// ============================================================================

unittest
{
    // Test primitives mapping
    assert(toTsType!int() == "number");
    assert(toTsType!double() == "number");
    assert(toTsType!string() == "string");
    assert(toTsType!bool() == "boolean");
    assert(toTsType!(int[])() == "number[]");
    assert(toTsType!(string[])() == "string[]");
    assert(toTsType!(int[string])() == "{ [key: string]: number }");
    assert(toTsType!(Nullable!string)() == "string | null");
    assert(toTsType!SysTime() == "string");
}

unittest
{
    import std.string : indexOf;
    import std.algorithm.searching : canFind;

    enum Status { active, inactive }
    enum Color : string { red = "RED", blue = "BLUE" }

    struct Address {
        string street;
        string city;
    }

    struct Person {
        string name;
        int age;
        Status status;
        Color favoriteColor;
        Address address;
        Address[] previousAddresses;
        Nullable!int score;
    }

    string tsOutput = generateTypeScript!Person();

    // Verify enums exported correctly
    assert(tsOutput.length > 0);
    assert(tsOutput.indexOf("export enum Status") != -1);
    assert(tsOutput.indexOf("active = 0") != -1);
    assert(tsOutput.indexOf("export enum Color") != -1);
    assert(tsOutput.indexOf("red = \"RED\"") != -1);

    // Verify interfaces exported correctly
    assert(tsOutput.indexOf("export interface Address") != -1);
    assert(tsOutput.indexOf("street: string;") != -1);
    assert(tsOutput.indexOf("export interface Person") != -1);
    assert(tsOutput.indexOf("favoriteColor: Color;") != -1);
    assert(tsOutput.indexOf("address: Address;") != -1);
    assert(tsOutput.indexOf("previousAddresses: Address[];") != -1);
    assert(tsOutput.indexOf("score: number | null;") != -1);
}
