# ts_generator

A lightweight, zero-dependency D library for automatically generating TypeScript interface and enum definitions from D `struct`, `class`, and `enum` types using compile-time reflection (`__traits` and CTFE).

[![DUB Package](https://img.shields.io/dub/v/ts_generator.svg)](https://code.dlang.org/packages/ts_generator)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

---

## Features

- **Compile-Time Generation**: Generates TypeScript code entirely at compile time using D traits and CTFE.
- **Recursive Type Discovery**: Automatically finds and emits nested structs, classes, and enums referenced in your fields.
- **D Enum Support**: Handles integer enums (`export enum ...`) and custom string enums (`export enum ...`).
- **Nullable Support**: Translates `std.typecons.Nullable!T` fields to TypeScript union type `T | null`.
- **Date & Time**: Automatically maps `std.datetime` types (`SysTime`, `DateTime`, `Date`) to ISO string representations (`string`).
- **Collections**: Supports single & multi-dimensional dynamic/static arrays (`T[]`) and associative arrays (`{ [key: string]: Value }`).
- **Clean Field Reflection**: Uses `UnqualT.tupleof` to only reflect instance data fields, ignoring methods, constructors, constants, and static members.

---

## Installation

Add `ts_generator` to your `dub.json`:

```json
"dependencies": {
    "ts_generator": "~>1.0.0"
}
```

Or run:

```bash
dub add ts_generator
```

---

## Quick Example

### 1. Define D Types and Export

```d
import std.file : write, mkdirRecurse;
import std.path : dirName;
import ts_generator;

enum UserRole {
    admin,
    user,
    guest
}

enum StrEnum : string {
    first = "FIRST_VAL",
    second = "SECOND_VAL"
}

struct UserProfile {
    string nickname;
    int age;
    UserRole role;
}

struct ServerResponse {
    uint statusCode;
    string message;
    UserProfile user;
    UserProfile[] history;
    StrEnum strKind;
}

void main()
{
    // Generate TypeScript type declarations
    string ts = generateTypeScript!(ServerResponse)();

    // Export to frontend file
    mkdirRecurse("frontend/src/types");
    write("frontend/src/types/api.d.ts", ts);
}
```

### 2. Output (`frontend/src/types/api.d.ts`)

```typescript
export enum UserRole {
    admin = 0,
    user = 1,
    guest = 2,
}

export interface UserProfile {
    nickname: string;
    age: number;
    role: UserRole;
}

export enum StrEnum {
    first = "FIRST_VAL",
    second = "SECOND_VAL",
}

export interface ServerResponse {
    statusCode: number;
    message: string;
    user: UserProfile;
    history: UserProfile[];
    strKind: StrEnum;
}
```

---

## Supported Type Mapping

| D Type | TypeScript Equivalent |
|---|---|
| `string`, `wstring`, `dstring`, `char` | `string` |
| `bool` | `boolean` |
| `int`, `uint`, `long`, `float`, `double`, etc. | `number` |
| `SysTime`, `DateTime`, `Date` | `string` |
| `Nullable!T` | `T \| null` |
| `T[]` | `T[]` |
| `V[K]` | `{ [key: string]: V }` |
| `enum` (numeric) | `export enum EnumName { member = 0, ... }` |
| `enum` (string) | `export enum EnumName { member = "val", ... }` |
| `struct`, `class` | `export interface Name { ... }` |

---

## Running Tests & Examples

To run unit tests:

```bash
dub test
```

To run the included example app:

```bash
dub run :example
```

---

## Publishing to DUB Registry

To publish new releases to [code.dlang.org](https://code.dlang.org/):

1. Tag the release in git:
   ```bash
   git tag v1.0.0
   git push origin v1.0.0
   ```
2. Register the repository at [https://code.dlang.org/publish](https://code.dlang.org/publish).

---

## License

[MIT](LICENSE) © Pablo De Nápoli
