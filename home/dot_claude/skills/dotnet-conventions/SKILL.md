---
name: dotnet-conventions
description: C# and .NET design and architecture conventions. Use when writing, editing, reviewing, or refactoring .cs, .csproj, .sln files, ASP.NET Core controllers, .NET services, Entity Framework code, or when discussing C# design patterns.
user-invocable: true
disable-model-invocation: false
---

# C# / .NET

## Design

- Records for DTOs, value objects, and immutable data.
- `async/await` all the way down -- never `.Result` or `.Wait()`.
- Prefer pattern matching over type checks and casts.
- Use `sealed` on classes not designed for inheritance.
- Primary constructors where appropriate (.NET 8+).
- File-scoped namespaces.
- Nullable reference types enabled -- no `null!` unless justified.

## Architecture

- Depend on abstractions. Inject interfaces, not concrete classes.
- Thin controllers -- logic belongs in services or handlers.
- Use `IOptions<T>` or `IConfiguration` for config, not hardcoded values.

## Formatting & Linting

- Formatter: `dotnet format`
- Linter: StyleCop.Analyzers

## Testing

- xUnit + FluentAssertions
- One test class per class under test: `FooService` -> `FooServiceTests.cs`.
- `IClassFixture<T>` for shared expensive setup.
- Mock at the interface boundary with NSubstitute or Moq.
- Arrange-Act-Assert structure. One assertion concept per test.
