import std.file : write, mkdirRecurse;
import std.path : dirName;
import std.stdio : writeln;
import ts_generator;

// Mock / Vibe.d style Serialization UDAs
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

struct path
{
    string value;
}

enum UserStatus
{
    @name("ACTIVE") active,
    @name("SUSPENDED") suspended,
    @name("INACTIVE") inactive
}

struct UserProfile
{
    @name("user_id") int id;
    string username;
    string email;
    @optional string bio;
    @optional string avatarUrl;
    @ignore string internalSecurityToken;
    UserStatus status;
}

struct CreateUserDto
{
    string username;
    string email;
    @optional string bio;
}

struct UpdateUserDto
{
    @optional string username;
    @optional string email;
    @optional string bio;
    @optional UserStatus status;
}

// vibe.web.rest style API interface
interface UserApi
{
    @path("/api/v1/users")
    UserProfile[] getUsers();

    @path("/api/v1/users/:id")
    UserProfile getUser(int id);

    @path("/api/v1/users")
    UserProfile createUser(CreateUserDto dto);

    @path("/api/v1/users/:id")
    UserProfile updateUser(int id, UpdateUserDto dto);

    @path("/api/v1/users/:id")
    void deleteUser(int id);
}

void main()
{
    // Generate both models AND the TypeScript Fetch Client for the API interface
    string code = generateTypeScriptApiClient!(UserApi)();

    string outputPath = "frontend/src/api/client.ts";
    mkdirRecurse(dirName(outputPath));
    write(outputPath, code);

    writeln("vibe.d REST API TypeScript Client exported to ", outputPath, "!");
    writeln("\nGenerated Output Preview:\n");
    writeln(code);
}
