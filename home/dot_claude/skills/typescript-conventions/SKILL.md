---
name: typescript-conventions
description: TypeScript and React design and architecture conventions. Use when writing, editing, reviewing, or refactoring .ts, .tsx, .js, .jsx files, React components, Next.js pages/routes, or when discussing TypeScript or React patterns.
user-invocable: true
disable-model-invocation: false
---

# TypeScript & React

## TypeScript Design

- No `any` -- use `unknown` and narrow, or define a type.
- Use `satisfies` over `as` when possible.
- Exhaustive switch/if with `never` for discriminated unions.
- No enums -- use `as const` objects or string literal unions.
- Prefer interfaces for object shapes, types for unions/intersections.
- Use `import type` for type-only imports.

## React Patterns

- Functional components only. No class components.
- Colocate component, test, and styles in the same directory.
- `use client` only when hooks or browser APIs are needed.
- Prefer server components by default (Next.js App Router).
- Extract custom hooks when logic is reused or complex.
- Avoid prop drilling beyond 2 levels -- use context or composition.

## Formatting & Linting

- Formatter: Prettier
- Linter: ESLint (v9+ flat config)

## Testing

- Vitest or Jest + React Testing Library for components.
- Query by role/label, not test IDs.
- File naming: `foo.test.ts` next to `foo.ts`.
- Prefer describe/it blocks.
