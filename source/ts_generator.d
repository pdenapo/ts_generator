module ts_generator;

import std.traits;
import std.meta : AliasSeq;
import std.array : Appender;
import std.format : format;
import std.string;
import std.algorithm.searching : canFind;
import std.typecons : Nullable;
import std.datetime : SysTime, DateTime, Date;

// ============================================================================
// UDA Reflection Helpers (Compatible with vibe.d UDAs: @name, @optional, @ignore, @path)
// ============================================================================

private template getFieldName(alias symbol)
{
    static string impl()
    {
        string fieldName = __traits(identifier, symbol);
        static foreach (attr; __traits(getAttributes, symbol))
        {
            {
                static if (__traits(compiles, attr.value))
                {
                    fieldName = attr.value;
                }
                else static if (is(typeof(attr) == string))
                {
                    fieldName = attr;
                }
            }
        }
        return fieldName;
    }

    enum getFieldName = impl();
}

private template isOptionalField(alias symbol)
{
    static bool impl()
    {
        bool isOpt = false;
        static foreach (attr; __traits(getAttributes, symbol))
        {
            {
                static if (__traits(compiles, attr.stringof))
                {
                    string sStr = attr.stringof;
                    if (sStr == "optional" || sStr == "optional()"
                            || sStr == "@optional" || sStr.canFind("optional"))
                    {
                        isOpt = true;
                    }
                }
            }
        }
        return isOpt;
    }

    enum isOptionalField = impl();
}

private template isIgnoredField(alias symbol)
{
    static bool impl()
    {
        bool isIgn = false;
        static foreach (attr; __traits(getAttributes, symbol))
        {
            {
                static if (__traits(compiles, attr.stringof))
                {
                    string sStr = attr.stringof;
                    if (sStr == "ignore" || sStr == "ignore()"
                            || sStr == "@ignore" || sStr.canFind("ignore"))
                    {
                        isIgn = true;
                    }
                }
            }
        }
        return isIgn;
    }

    enum isIgnoredField = impl();
}

private template getRoutePath(alias symbol)
{
    static string impl()
    {
        string route = "";
        static foreach (attr; __traits(getAttributes, symbol))
        {
            {
                static if (__traits(compiles, attr.value))
                {
                    route = attr.value;
                }
                else static if (is(typeof(attr) == string))
                {
                    route = attr;
                }
            }
        }
        if (route.length == 0)
        {
            route = "/" ~ __traits(identifier, symbol);
        }
        return route;
    }

    enum getRoutePath = impl();
}

// ============================================================================
// Type Mapping & Base Type Extraction
// ============================================================================

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
 * Helper template to extract foundational underlying type(s) from composite types.
 */
template BaseTypes(T)
{
    alias U = Unqual!T;
    static if (is(U == enum))
        alias BaseTypes = AliasSeq!(U);
    else static if (is(U : Nullable!V, V))
        alias BaseTypes = BaseTypes!V;
    else static if (isPointer!U)
        alias BaseTypes = BaseTypes!(PointerTarget!U);
    else static if (isSomeString!U || is(U == SysTime) || is(U == DateTime)
            || is(U == Date) || is(U == void))
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
 * Respects vibe.d serialization UDAs (@name, @optional, @ignore).
 */
public string generateTypeScript(Types...)()
{
    Appender!string sb;
    bool[string] visited;

    void processType(T)()
    {
        alias UnqualT = Unqual!T;
        string name = UnqualT.stringof;

        if (name in visited)
            return;
        visited[name] = true;

        static if (is(UnqualT == enum))
        {
            sb.put(format("export enum %s {\n", name));
            static foreach (member; EnumMembers!UnqualT)
            {
                {
                    alias OrigT = OriginalType!UnqualT;
                    string memberName = getFieldName!member;
                    static if (isSomeString!OrigT)
                    {
                        sb.put(format("    %s = \"%s\",\n", memberName, cast(string) member));
                    }
                    else
                    {
                        sb.put(format("    %s = %s,\n", memberName, cast(long) member));
                    }
                }
            }
            sb.put("}\n\n");
        }
        else static if (is(UnqualT == struct) || is(UnqualT == class))
        {
            // First, recursively discover and process dependency types used by fields
            static foreach (i, field; UnqualT.tupleof)
            {
                {
                    static if (!isIgnoredField!(UnqualT.tupleof[i]))
                    {
                        alias memType = typeof(field);
                        static foreach (BaseT; BaseTypes!memType)
                        {
                            processType!BaseT();
                        }
                    }
                }
            }

            sb.put(format("export interface %s {\n", name));
            static foreach (i, field; UnqualT.tupleof)
            {
                {
                    static if (!isIgnoredField!(UnqualT.tupleof[i]))
                    {
                        alias memType = typeof(field);
                        string fieldName = getFieldName!(UnqualT.tupleof[i]);
                        bool isOpt = isOptionalField!(UnqualT.tupleof[i]);
                        string optChar = isOpt ? "?" : "";
                        string tsType = toTsType!memType();
                        sb.put(format("    %s%s: %s;\n", fieldName, optChar, tsType));
                    }
                }
            }
            sb.put("}\n\n");
        }
    }

    static foreach (T; Types)
    {
        processType!T();
    }

    return sb.data;
}

// ============================================================================
// REST API Interface -> TypeScript Fetch Client Generator
// ============================================================================

private string inferHttpVerb(string methodName)()
{
    string lower = methodName.toLower();
    if (lower.startsWith("get") || lower.startsWith("query") || lower.startsWith("find"))
        return "GET";
    if (lower.startsWith("post") || lower.startsWith("create") || lower.startsWith("add"))
        return "POST";
    if (lower.startsWith("put") || lower.startsWith("update") || lower.startsWith("set"))
        return "PUT";
    if (lower.startsWith("patch"))
        return "PATCH";
    if (lower.startsWith("delete") || lower.startsWith("remove"))
        return "DELETE";
    return "POST";
}

/**
 * Generates both TypeScript data model interfaces AND an asynchronous TypeScript API client class
 * using native `fetch` for D REST interfaces (vibe.web.rest compatible).
 */
public string generateTypeScriptApiClient(Apis...)()
{
    Appender!string sb;
    bool[string] visited;

    void processType(T)()
    {
        alias UnqualT = Unqual!T;
        string name = UnqualT.stringof;

        if (name in visited)
            return;
        visited[name] = true;

        static if (is(UnqualT == enum))
        {
            sb.put(format("export enum %s {\n", name));
            static foreach (member; EnumMembers!UnqualT)
            {
                {
                    alias OrigT = OriginalType!UnqualT;
                    string memberName = getFieldName!member;
                    static if (isSomeString!OrigT)
                    {
                        sb.put(format("    %s = \"%s\",\n", memberName, cast(string) member));
                    }
                    else
                    {
                        sb.put(format("    %s = %s,\n", memberName, cast(long) member));
                    }
                }
            }
            sb.put("}\n\n");
        }
        else static if (is(UnqualT == struct) || is(UnqualT == class))
        {
            static foreach (i, field; UnqualT.tupleof)
            {
                {
                    static if (!isIgnoredField!(UnqualT.tupleof[i]))
                    {
                        alias memType = typeof(field);
                        static foreach (BaseT; BaseTypes!memType)
                        {
                            processType!BaseT();
                        }
                    }
                }
            }

            sb.put(format("export interface %s {\n", name));
            static foreach (i, field; UnqualT.tupleof)
            {
                {
                    static if (!isIgnoredField!(UnqualT.tupleof[i]))
                    {
                        alias memType = typeof(field);
                        string fieldName = getFieldName!(UnqualT.tupleof[i]);
                        bool isOpt = isOptionalField!(UnqualT.tupleof[i]);
                        string optChar = isOpt ? "?" : "";
                        string tsType = toTsType!memType();
                        sb.put(format("    %s%s: %s;\n", fieldName, optChar, tsType));
                    }
                }
            }
            sb.put("}\n\n");
        }
    }

    // 1. Discover all model types used across all API interface methods
    static foreach (Api; Apis)
    {
        {
            static foreach (member; __traits(allMembers, Api))
            {
                {
                    alias method = __traits(getMember, Api, member);
                    static if (isFunction!method)
                    {
                        alias RetT = ReturnType!method;
                        alias ParamTypes = Parameters!method;

                        static foreach (BaseT; BaseTypes!RetT)
                        {
                            processType!BaseT();
                        }
                        static foreach (P; ParamTypes)
                        {
                            static foreach (BaseT; BaseTypes!P)
                            {
                                processType!BaseT();
                            }
                        }
                    }
                }
            }
        }
    }

    // 2. Generate TypeScript API Client classes
    static foreach (Api; Apis)
    {
        {
            string className = Api.stringof ~ "Client";
            sb.put(format("export class %s {\n", className));
            sb.put("    private baseUrl: string;\n");
            sb.put("    private fetchFn: typeof fetch;\n\n");
            sb.put("    constructor(baseUrl: string = '', fetchFn: typeof fetch = fetch) {\n");
            sb.put("        this.baseUrl = baseUrl;\n");
            sb.put("        this.fetchFn = fetchFn;\n");
            sb.put("    }\n\n");

            static foreach (member; __traits(allMembers, Api))
            {
                {
                    alias method = __traits(getMember, Api, member);
                    static if (isFunction!method)
                    {
                        alias RetT = ReturnType!method;
                        alias ParamTypes = Parameters!method;
                        alias paramNames = ParameterIdentifierTuple!method;

                        string verb = inferHttpVerb!member();
                        string routePath = getRoutePath!method;

                        Appender!string paramsSb;
                        string bodyParamName = "";

                        static foreach (i, P; ParamTypes)
                        {
                            {
                                if (i > 0)
                                    paramsSb.put(", ");
                                string pName = paramNames[i];
                                paramsSb.put(pName);
                                paramsSb.put(": ");
                                paramsSb.put(toTsType!P());

                                static if (is(Unqual!P == struct) || is(Unqual!P == class))
                                {
                                    bodyParamName = pName;
                                }
                            }
                        }

                        // Convert :param to ${param} in routePath
                        string formattedPath = routePath;
                        static foreach (i, P; ParamTypes)
                        {
                            {
                                string pName = paramNames[i];
                                formattedPath = formattedPath.replace(":" ~ pName, "${" ~ pName
                                        ~ "}");
                            }
                        }

                        string returnTsType = (is(RetT == void)) ? "void" : toTsType!RetT();
                        sb.put(format("    async %s(%s): Promise<%s> {\n",
                                member, paramsSb.data, returnTsType));

                        string headers = (bodyParamName.length > 0) ? "{ 'Content-Type': 'application/json', 'Accept': 'application/json' }" : "{ 'Accept': 'application/json' }";

                        string bodyString = (bodyParamName.length > 0) ? format(
                                ",\n            body: JSON.stringify(%s)", bodyParamName) : "";

                        sb.put(format("        const response = await this.fetchFn(`${this.baseUrl}%s`, {\n",
                                formattedPath));
                        sb.put(format("            method: '%s',\n", verb));
                        sb.put(format("            headers: %s%s\n", headers, bodyString));
                        sb.put("        });\n");
                        sb.put("        if (!response.ok) {\n");
                        sb.put(
                                "            throw new Error(`HTTP error ${response.status}: ${response.statusText}`);\n");
                        sb.put("        }\n");

                        static if (!is(RetT == void))
                        {
                            sb.put("        return await response.json();\n");
                        }
                        sb.put("    }\n\n");
                    }
                }
            }
            sb.put("}\n\n");
        }
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

    struct optional
    {
    }

    struct ignore
    {
    }

    struct name
    {
        string value;
    }

    struct UserWithUDAs
    {
        @name("user_id") int id;
        string username;
        @optional string bio;
        @ignore string internalSecret;
    }

    string tsOutput = generateTypeScript!UserWithUDAs();

    assert(tsOutput.indexOf("user_id: number;") != -1);
    assert(tsOutput.indexOf("username: string;") != -1);
    assert(tsOutput.indexOf("bio?: string;") != -1);
    assert(tsOutput.indexOf("internalSecret") == -1); // Excluded!
}

unittest
{
    import std.string : indexOf;

    struct path
    {
        string value;
    }

    struct Item
    {
        int id;
        string title;
    }

    struct CreateItemDto
    {
        string title;
    }

    interface ItemApi
    {
        @path("/api/items")
        Item[] getItems();

        @path("/api/items/:id")
        Item getItem(int id);

        @path("/api/items")
        Item createItem(CreateItemDto dto);

        @path("/api/items/:id")
        void deleteItem(int id);
    }

    string tsOutput = generateTypeScriptApiClient!ItemApi();

    assert(tsOutput.indexOf("export interface Item") != -1);
    assert(tsOutput.indexOf("export interface CreateItemDto") != -1);
    assert(tsOutput.indexOf("export class ItemApiClient") != -1);
    assert(tsOutput.indexOf("async getItems(): Promise<Item[]>") != -1);
    assert(tsOutput.indexOf("async getItem(id: number): Promise<Item>") != -1);
    assert(tsOutput.indexOf("async createItem(dto: CreateItemDto): Promise<Item>") != -1);
    assert(tsOutput.indexOf("async deleteItem(id: number): Promise<void>") != -1);
}
