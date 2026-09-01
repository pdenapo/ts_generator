# ts_generator

A lightweight, zero-dependency D library for automatically generating TypeScript interface, enum, and **REST API Client** (`fetch`) code from D `struct`, `class`, `enum`, and `interface` types using compile-time reflection (`__traits` and CTFE).
This library is compatible with vibe.d.

[![DUB Package](https://img.shields.io/dub/v/ts_generator.svg)](https://code.dlang.org/packages/ts_generator)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

---

## Features

- **Compile-Time Generation**: Generates TypeScript code entirely at compile time using D traits and CTFE.
- **vibe.d Serialization UDAs Compatible**:
  - `@name("custom_name")`: Custom field name mapping in TypeScript interfaces.
  - `@optional`: Renders optional fields (`field?: type`).
  - `@ignore`: Excludes private / internal fields from generated TypeScript code.
  - `@byName`: Enum serialization by string member name.
- **REST API Client Generator (`generateTypeScriptApiClient`)**:
  - Automatically inspects D REST interfaces (`vibe.web.rest` compatible).
  - Infers HTTP verbs (`GET`, `POST`, `PUT`, `PATCH`, `DELETE`) and `@path("/api/v1/resource/:id")` endpoints.
  - Generates strongly-typed asynchronous TypeScript API Client classes using native `fetch`.
- **Recursive Type Discovery**: Automatically finds and emits all nested structs, classes, and enums referenced in your fields, return types, or parameters.
- **Nullable & Datetime Support**: Supports `std.typecons.Nullable!T` (`T | null`) and `std.datetime` types (`SysTime`, `DateTime`, `Date` -> `string`).

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

## Usage Examples

### 1. Generating TypeScript Models

```d
import std.file : write, mkdirRecurse;
import ts_generator;

struct optional {}
struct ignore {}
struct name { string value; }

struct UserProfile {
    @name("user_id") int id;
    string username;
    @optional string bio;
    @ignore string internalSecurityToken;
}

void main()
{
    string ts = generateTypeScript!(UserProfile)();
    mkdirRecurse("frontend/src/types");
    write("frontend/src/types/api.d.ts", ts);
}
```

**Output (`frontend/src/types/api.d.ts`):**

```typescript
export interface UserProfile {
    user_id: number;
    username: string;
    bio?: string;
}
```

---

### 2. Generating a Full REST API Fetch Client (`vibe.web.rest` compatible)

```d
import std.file : write, mkdirRecurse;
import ts_generator;

struct path { string value; }
struct optional {}

struct UserProfile {
    int id;
    string username;
    @optional string bio;
}

struct CreateUserDto {
    string username;
    @optional string bio;
}

interface UserApi {
    @path("/api/v1/users")
    UserProfile[] getUsers();

    @path("/api/v1/users/:id")
    UserProfile getUser(int id);

    @path("/api/v1/users")
    UserProfile createUser(CreateUserDto dto);

    @path("/api/v1/users/:id")
    void deleteUser(int id);
}

void main()
{
    // Generates both data models AND the TypeScript API client class
    string code = generateTypeScriptApiClient!(UserApi)();
    
    mkdirRecurse("frontend/src/api");
    write("frontend/src/api/client.ts", code);
}
```

**Output (`frontend/src/api/client.ts`):**

```typescript
export interface UserProfile {
    id: number;
    username: string;
    bio?: string;
}

export interface CreateUserDto {
    username: string;
    bio?: string;
}

export class UserApiClient {
    private baseUrl: string;
    private fetchFn: typeof fetch;

    constructor(baseUrl: string = '', fetchFn: typeof fetch = fetch) {
        this.baseUrl = baseUrl;
        this.fetchFn = fetchFn;
    }

    async getUsers(): Promise<UserProfile[]> {
        const response = await this.fetchFn(`${this.baseUrl}/api/v1/users`, {
            method: 'GET',
            headers: { 'Accept': 'application/json' }
        });
        if (!response.ok) throw new Error(`HTTP error ${response.status}: ${response.statusText}`);
        return await response.json();
    }

    async getUser(id: number): Promise<UserProfile> {
        const response = await this.fetchFn(`${this.baseUrl}/api/v1/users/${id}`, {
            method: 'GET',
            headers: { 'Accept': 'application/json' }
        });
        if (!response.ok) throw new Error(`HTTP error ${response.status}: ${response.statusText}`);
        return await response.json();
    }

    async createUser(dto: CreateUserDto): Promise<UserProfile> {
        const response = await this.fetchFn(`${this.baseUrl}/api/v1/users`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json', 'Accept': 'application/json' },
            body: JSON.stringify(dto)
        });
        if (!response.ok) throw new Error(`HTTP error ${response.status}: ${response.statusText}`);
        return await response.json();
    }

    async deleteUser(id: number): Promise<void> {
        const response = await this.fetchFn(`${this.baseUrl}/api/v1/users/${id}`, {
            method: 'DELETE',
            headers: { 'Accept': 'application/json' }
        });
        if (!response.ok) throw new Error(`HTTP error ${response.status}: ${response.statusText}`);
    }
}
```

---

## Running Tests & Examples

To run unit tests:

```bash
dub test
```

To run the basic example:

```bash
dub run :example
```

To run the vibe.d REST Client example:

```bash
dub run :example_vibe
```

---

## License

[MIT](LICENSE) © Pablo De Nápoli
