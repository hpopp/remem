# Agent Guide

This is a [Koja](https://kojalang.org) project. Koja is a statically
typed, compiled language with Ruby-inspired syntax, value semantics,
and Erlang-style concurrency.

## Look up documentation

`koja doc search <query>` prints docs for any stdlib or project
symbol. An exact name renders the full doc. A partial name lists
candidates.

The standard library sources are extracted to `~/.koja/stdlib/`,
one directory per compiler build. Read or grep them there when the
docs are not enough.

## Commands

Set `KOJA_DIAGNOSTICS=short` to print each diagnostic on one line.

- `koja check` type checks without compiling
- `koja test` runs `@test` functions from `src/` and `test/`
- `koja run` builds and executes the project
- `koja format` formats the project in place (`--check` to verify)

## Language essentials

- No `let`, `var`, `mut`, or semicolons. Assignment creates a
  variable, and blocks close with `end`.
- No `else if`. Use `cond` for multi-branch conditionals.
- Values never alias. A mutating function takes `self` and returns a
  new value, so rebind the result: `list = list.append(42)`.
- `-> T ! E` declares a fallible function. `try expr` unwraps or
  propagates the error, `fail e` returns an error, and
  `expr rescue e -> handler` handles it inline.
- Files in one package share a namespace. Same-package code needs no
  imports. Use `alias Pkg.Type` to shorten external package paths.
