# Agent Guidelines for Julia Development

Guidelines for AI agents working on Julia codebases.

## At a Glance

- Ask rather than guess. Clarify before coding.
- Make one focused change at a time (< 100 lines).
- Keep code minimal; comments explain why, not what.
- Public APIs: typed, stable, documented; internal code can change.
- Type stability and low allocations in hot paths.
- Always run Runic before committing; keep CI green.
- Tests cover all lines and branches of public APIs.
- Prefer composition and parametric types; avoid abstract fields.
- Use explicit imports and qualified module calls.
- Stream large data; avoid shared mutable state across threads.

## Table of Contents

1. [At a Glance](#at-a-glance)
2. [Critical Principles](#critical-principles)
3. [Daily Workflow](#daily-workflow)
4. [API Design](#api-design)
5. [Function Design](#function-design)
6. [Julia Style Guide](#julia-style-guide)
7. [Type System](#type-system)
8. [Error Handling](#error-handling)
9. [Performance](#performance)
10. [Design Patterns](#design-patterns)
11. [Engineering Practices](#engineering-practices)

## Critical Principles

**Must be followed at all times.**

### 1. Ask Rather Than Guess
**CRITICAL**: When intent is unclear, **always ask** rather than assume.

**Planning Phase:**
**CRITICAL**: In planning phase, clarify requirements before implementing. Do not start until scope and design are clearly understood.

- Ask clarifying questions about requirements, expected behavior, edge cases
- Propose design options and discuss trade-offs before implementing
- Get confirmation on ambiguous aspects
- Define success criteria before coding
- Avoid starting development with vague or incomplete requirements

**Implementation Phase:**
**CRITICAL**: respect edits to your code as much as possible.
- try not to revert changes to your code unless absolutely necessary.
- take any changes to your code as a suggestion, and evaluate them based on the context of the project.
- if the changes are not beneficial, explain why and suggest alternative solutions.

### 2. Minimal Code
**CRITICAL**: Minimal, self-explanatory code. Comments explain why, not what.

```julia
# Bad
# Create a new value
value = 42
result = sum(numbers)
return result

# Good
value = 42
return sum(numbers)

# Good - explain why, not what
# Prefer sqrt over x^0.5 for better numerical stability
result = sqrt(value)
```

Add comments only for: complex algorithms, non-obvious optimizations, edge cases, workarounds.

### 3. One Change at a Time

## Daily Workflow

- Run Runic locally and fix formatting.
- Run tests; ensure all lines/branches for changed public APIs are covered.
- Keep CI green (tests, coverage report generation, docs, optional JET checks).
- Small, focused edits; open PRs with succinct summaries and rationale.

Recommended pre-commit hook:

```bash
#!/usr/bin/env bash
set -euo pipefail
julia --project=. -e 'using Runic; Runic.format!(".")'
```

**CRITICAL**: Make small, focused changes for easier review.

- One concern per change
- Target 50-100 lines per diff
- Separate commits for multiple changes
- Incremental refactoring: Add new → switch → remove old

### 4. Human Changes Precedence

- Human edits override agent suggestions unless contradicting specs/tests.
- If reversing a human change, justify briefly with evidence (tests, docs, spec).
- Keep diffs minimal; do not touch unrelated lines/files.
- Respect locked sections:
  - Julia: `# BEGIN HUMAN` … `# END HUMAN`
  - Markdown: `<!-- BEGIN HUMAN -->` … `<!-- END HUMAN -->`
- Use PRs for agent edits; human reviews. Required checks: Runic, tests, docs, optional JET.
- After human commits, rebase and re-run checks; resolve conflicts with the smallest change.

## API Design

### API Design Principles

- **Public APIs**: Simple, stable, well-documented interfaces
- **Internal functions**: Can be optimized, refactored freely
- **Clear boundaries**: Distinguish public API from implementation details
- **Consistent return types**: Same function should return same type consistently
- **Predictable behavior**: Functions should behave consistently across calls

### Public API Stability

- **Public APIs should be stable** across versions
- **Internal implementations can be optimized or refactored** freely
- **Document breaking changes clearly**
- **Separate public API from internal implementation** clearly

### API Evolution

- **Maintain backward compatibility** when possible
- **Deprecate rather than remove** using `Base.depwarn()` or package-specific deprecation mechanisms
- **Provide migration paths** for breaking changes
- **Use semantic versioning** for packages

## Julia Style Guide

### Function Length

- **Target**: 25 lines per function (excluding docstrings)
- **Negotiable** based on context
- Over 50 lines: almost always refactor
- Over 35 lines: review for refactoring
- Each function should do one thing well

### Naming

- **Functions**: `snake_case` (`compute_value`, `parse_data`)
- **Mutating**: `!` suffix (`sort!`, `push!`)
- **Predicates**: use `is_` prefix or `is...` forms (`isempty`, `isnothing`, `haskey`)
- **Types/Structs**: `PascalCase`
- **Constants**: `SCREAMING_SNAKE_CASE` with `const`
- **Modules**: `PascalCase` (match filename)
- **Type parameters**: Single uppercase (`T`, `S`, `U`, `V`, `N`, `M`)

### Formatting

- **Indentation**: 4 spaces
- **Line length**: Prefer < 92 chars, readability first
- **Spacing**: Spaces around binary ops (`x + y`), no space after unary (`-x`), space after commas/colons (`x::Int64`), no space before colons (`Dict{String, Int}`)
- **Trailing commas**: Use in multi-line definitions

### Documentation

Documentation must be **simple and clean** - both text and formatting.

- Simple text: Clear, straightforward language
- Clean formatting: Consistent, minimal markdown
- Be concise: Get to the point
- Focus on usage: What it does and how to use it

Docstrings only for:
1. Exported functions/types (public API)
2. Complex functions where use is not obvious

```julia
# Exported
"""
    compute_average(values)

Calculate the arithmetic mean of a collection of numbers.
"""
function compute_average(values::Vector{Float64})::Float64
    return sum(values) / length(values)
end

# Simple internal - no docstring needed
function get_first(items::Vector{T})::Union{T, Nothing} where T
    return isempty(items) ? nothing : items[1]
end
```

Formatting:

<!-- **Note:** Due to the inner `jldoctest` code block, the following code block is protected by the `````. -->
`````julia
"""
    divide(a, b)

Divide `a` by `b`.

# Arguments
- `a::Float64`: Numerator
- `b::Float64`: Denominator (must not be zero)

# Returns
- `Float64`: Result of division

# Examples
```jldoctest
julia> result = divide(10.0, 2.0)
5.0
```
"""
`````

- Plain markdown, avoid excessive formatting
- One sentence per line for readability
- Keep examples minimal
- Use simple language
- Remove redundant words

- **Inline comments**: Use sparingly, explain **why** not **what**. TODO/FIXME must include context.

## Type System

### Type Annotations

- **Public APIs**: Always annotate argument and return types
- **Internal functions**: Types optional but recommended
- **Type stability**: Critical for performance

```julia
# Good - fully typed
function add_numbers(a::Float64, b::Float64)::Float64
    return a + b
end

# Bad - type unstable
function get_value(container, key)
    haskey(container, key) ? container[key] : nothing
end

# Good - explicitly typed
function get_value(container::Dict{String, Int}, key::String)::Union{Int, Nothing}
    return get(container, key, nothing)
end
```

### Parametric Types and Union Types

Use parametric types for type stability when type varies but is known at construction:

```julia
# Bad - abstract type causes type instability
struct Container
    items::Vector{Number}  # Slow, type-unstable
end

# Good - parametric type is type-stable
struct Container{T <: Number}
    items::Vector{T}  # Fast, type-stable
end

int_container = Container{Int}([1, 2, 3])
float_container = Container{Float64}([1.0, 2.0, 3.0])
```

Use Union types for optional/nullable values:

```julia
# Good - optional field
name::Union{String, Nothing}

# Bad - avoid Any
settings::Dict{String, Any}

# Better - structured type
struct Settings
    timeout::Union{Int, Nothing}
    retries::Union{Int, Nothing}
end
```

Guidelines:
- **Parametric types**: When type is known at construction, want type stability
- **Union types**: For optional/nullable values or runtime type flexibility
- **Avoid abstract types**: (`Number`, `AbstractArray`) as field types - use parametric instead
- Keep unions small: prefer `Union{A, B}` over `Union{A, B, C, ...}`

### Immutability

Prefer immutable types first, mutable only if required.

- **Default to immutable**: Use `struct` (immutable) as default choice
- **Mutable only when needed**: Use `mutable struct` only when state must change after construction
- **Benefits**: Thread-safe, easier to reason about, better performance

```julia
# Good - immutable by default
struct Point
    x::Float64
    y::Float64
end

# Mutable only when state needs to change
mutable struct Counter
    count::Int
end

function increment!(counter::Counter)
    counter.count += 1
end
```

### Constructors

- **Inner constructors**: Basic validation, performance-conscious
- **Outer constructors**: Reduce code duplication

```julia
struct Point
    x::Float64
    y::Float64

    # Inner constructor - basic validation
    function Point(x::Float64, y::Float64)
        isfinite(x) && isfinite(y) || throw(ArgumentError("Coordinates must be finite"))
        return new(x, y)
    end
end

# Outer constructors - reduce duplication
Point(x::Int, y::Int) = Point(Float64(x), Float64(y))
Point(x::Real, y::Real) = Point(Float64(x), Float64(y))
```

## Function Design

### Signatures

- **Keyword arguments**: Use for 3+ optional parameters
- **Default arguments**: Provide sensible defaults
- **Argument order**: Required → optional → keyword

```julia
function transform_values(
    values::Vector{Float64};
    scale::Float64 = 1.0,
    offset::Float64 = 0.0,
)::Vector{Float64}
end
```

### Function Purity

- Prefer pure functions (no side effects)
- Document side effects clearly if unavoidable

```julia
# Good - pure function
function multiply(a::Float64, b::Float64)::Float64
    return a * b
end

# Document side effects
"""
Modifies `container` in place.
"""
function append!(container::Vector{T}, value::T) where T
    push!(container, value)
end
```

## Performance

### Array Type Selection

1. **StaticArrays.jl** - Small fixed-size arrays (< ~100 elements), stack-allocated
```julia
using StaticArrays: SVector
vector = SVector{3, Float64}(1.0, 2.0, 3.0)

function compute_transform(point::SVector{3, Float64})::SVector{3, Float64}
    # Zero heap allocation, excellent performance
end
```

2. **FixedSizeArrays.jl** - Pre-allocated arrays with known compile-time size
```julia
using FixedSizeArrays: FixedSizeVector

results = FixedSizeVector{Float64}(undef, 2)
for i in 1:2
    results[i] = i
end

function compute_transform(results::FixedSizeVector{Float64, N})::Float64 where N
    # ...
end

```

3. **Vector/Array** - Only when: dynamic resizing needed, size unknown, or performance not a concern

### Allocation Awareness

- Pre-allocate when size is known
- Use views: `@view array[start:end]`
- Avoid global variables in hot paths (use `Ref` or pass as parameter)

```julia
# Good - pre-allocate
results = Vector{Float64}(undef, length(inputs))
for i in eachindex(inputs)
    results[i] = compute(inputs[i])
end

# Avoid globals
function increment(counter::Ref{Int})
    counter[] += 1
end
```

### Type Stability

Ensure type stability in performance-critical code:

```julia
# Type stable
function sum_floats(values::Vector{Float64})::Float64
    total = 0.0  # Float64, not Int
    for v in values
        total += v
    end
    return total
end
```

- Use `@code_warntype` to check for type instability
- Avoid `Any` types in performance-critical paths
- Use type inference-friendly patterns

### Broadcasting

Use broadcasting for element-wise operations:

```julia
squared = values .^ 2
sums = a .+ b
```

 - Use for concise element-wise operations; performance is comparable to well-written loops
 - Handles dimensions via broadcasting rules
 - Use dot syntax (`.+`, `.*`, `.^`) to broadcast operators

### Internal Algorithm Optimization

For internal functions where performance is critical:

- Consider `@inline` only for tiny, proven hot functions after profiling; the compiler generally makes good choices

```julia
@inline function compute_small(data::Float64)::Float64
    return data * 2.0 + 1.0
end
```

- **SIMD-friendly code**: Use operations that vectorize well (simple loops, element-wise ops)
- **Cache-aware**: Access memory sequentially when possible, reuse recently accessed data
- **Avoid function calls in tight loops**: Extract loop bodies, minimize indirection
- **Algorithm complexity**: Choose O(n log n) over O(n²) when data grows large
- **Unroll small loops**: For very small fixed-size loops, consider manual unrolling

```julia
# Good - simple loop, cache-friendly
function sum_vector(data::Vector{Float64})::Float64
    total = 0.0
    @inbounds for i in eachindex(data)
        total += data[i]
    end
    return total
end
```

### Performance Best Practices

- **Measure before optimizing**: Use `@time`, `@btime` (from BenchmarkTools.jl), `@profview` (from ProfileView.jl)

```julia
using BenchmarkTools
@btime compute_result(data)
```

- **Avoid containers with abstract element types**: Use parametric types or structs
- **Pre-allocate outputs**: Allocate before loops, use `sizehint!` for growing arrays
- **Access arrays in column-major order**: Outer loop over columns, inner loop over rows
- **Profile first**: Identify bottlenecks before optimizing
- **Use appropriate algorithms**: Choose algorithms with better complexity when needed
- **Separate concerns**: Optimize internal algorithms separately from public API design

### Memory Management

- **Be aware of memory usage** for large datasets
- **Consider streaming** for very large files
- **Use appropriate data structures**: `Vector` (ordered), `Set` (membership), `Dict` (key-value), `Tuple` (immutable small collections)
- **Release large objects explicitly** when done

### Concurrency

- **Document thread-safety assumptions**
- **Use appropriate synchronization** if shared state is modified
- **Prefer immutable data structures** where possible
- **Use `Threads.@threads`** for parallel computation on independent data
- **Use async IO (`@spawn`, `Task`, `Channel`)** for network/file IO and pipelines where tasks wait on external events
- **Avoid shared mutable state across threads**; if unavoidable, use thread-safe primitives and keep critical sections minimal
- **Partition data** so each thread works on disjoint chunks; prefer immutable inputs and preallocated outputs per thread

### Data and IO Practices

- **Stream large files** instead of loading entirely into memory (iterate records, process incrementally)
- **Bound memory**: use iterators/generators, preallocate buffers, and reuse them
- **Close resources** promptly (files, streams); prefer `do`-blocks to ensure closure
- **Backpressure** with `Channel{T}(capacity)` in producer/consumer designs

## Error Handling

### Exception Types

- Use appropriate exception types
- Provide helpful error messages with context

```julia
# Good
if divisor == 0
    throw(DomainError(divisor, "Cannot divide by zero"))
end

# Custom exception
struct ValidationError <: Exception
    message::String
    field::String
end

# Helpful message
if length(keys) != length(values)
    throw(ArgumentError(
        "Mismatch: keys has $(length(keys)) elements but values has $(length(values))"
    ))
end
```

- **ArgumentError**: Invalid argument value
- **BoundsError**: Index out of bounds
- **TypeError**: Type conversion/assertion error
- **MethodError**: Method doesn't exist
- **ErrorException**: Generic error (use sparingly)

### Validation

- Validate inputs in public APIs
- Fail fast with clear error messages

```julia
function divide(a::Float64, b::Float64)::Float64
    if b == 0
        throw(DomainError(b, "Cannot divide by zero: $a / $b"))
    end
    return a / b
end
```

### Invariants vs User-Facing Errors

- Use `@assert` for internal invariants that should never be violated in correct code
- Use typed exceptions (`ArgumentError`, `DomainError`, or a small set of custom types) for user/input errors
- Error messages must include actionable context (values, sizes, keys)

## Design Patterns

### Composition Over Inheritance

Prefer composition over inheritance. Use structs containing other structs.

```julia
# Good - composition
struct Logger
    level::String
end

struct Config
    timeout::Int
    retries::Int
end

struct Processor
    logger::Logger
    config::Config
end

# Good - composition with parametric types
struct Buffer{T}
    data::Vector{T}
    capacity::Int
end

struct Transformer{T}
    buffer::Buffer{T}
    multiplier::Float64
end
```

**When to use:**
- **Composition**: Default choice. Flexible, testable.
- **Abstract types**: For dispatch-based polymorphism (multiple dispatch), not code reuse
- **Inheritance**: Only when you truly need is-a relationships and polymorphic dispatch

### Builder Pattern

For complex object construction:

```julia
struct ValueBuilder
    base::Union{Int, Nothing}
    multiplier::Union{Float64, Nothing}
end

ValueBuilder() = ValueBuilder(nothing, nothing)

function set_base(builder::ValueBuilder, base::Int)::ValueBuilder
    return ValueBuilder(base, builder.multiplier)
end

function build(builder::ValueBuilder)::Float64
    builder.base === nothing && throw(ArgumentError("Base value required"))
    multiplier = builder.multiplier === nothing ? 1.0 : builder.multiplier
    return builder.base * multiplier
end
```

### Strategy Pattern

For algorithm selection:

```julia
abstract type SortStrategy end
struct QuickSort <: SortStrategy end
struct MergeSort <: SortStrategy end

function sort_values(values::Vector{Float64}, ::QuickSort)::Vector{Float64}
    # Implementation
end

function sort_values(values::Vector{Float64}, ::MergeSort)::Vector{Float64}
    # Implementation
end
```

### Factory Pattern

In Julia, use multiple dispatch for factory patterns:

```julia
# Bad - string-based factory
function create_container(type::String)
    if type == "int"
        return Vector{Int}()
    elseif type == "float"
        return Vector{Float64}()
    else
        throw(ArgumentError("Unknown type: $type"))
    end
end

# Good - dispatch-based factory
struct IntType end
struct FloatType end

create_container(::Type{IntType}) = Vector{Int}()
create_container(::Type{FloatType}) = Vector{Float64}()

# Even better - use type parameters
create_container(::Type{T}) where T = Vector{T}()
```

## Engineering Practices

### Testing

Test every line and branch. No untested code branches allowed.

- Complete coverage: Every line executed by at least one test
- Branch coverage: Test all conditionals (`if/else`, ternary, `&&`, `||`)
- Edge cases: Empty inputs, boundary values, error conditions
- Public APIs: All exported functions must have comprehensive tests

```julia
function divide(a::Float64, b::Float64)::Float64
    if b == 0
        throw(DomainError(b, "Cannot divide by zero"))
    end
    if a < 0
        return -abs(a / b)
    end
    return a / b
end

using Test

@testset "divide - complete coverage" begin
    @test_throws DomainError divide(10.0, 0.0)  # Error branch
    @test divide(10.0, 2.0) == 5.0              # Normal branch
    @test divide(0.0, 5.0) == 0.0               # Zero numerator
    @test divide(-10.0, 2.0) == -5.0            # Negative branch
end
```

- **Test all branches**: `if/else`, ternary, short-circuit, error paths, early returns. Use coverage tools to ensure 100% line and branch coverage.

### CI and Automation

- Run tests on Linux for supported Julia versions (e.g., 1.10 and latest LTS)
- Collect coverage reports
- Run doctests and build docs (Documenter.jl)
- Optionally run formatting and inference checks

Reference workflow (simplified):

```yaml
name: CI
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        julia-version: ["1.10"]
    steps:
      - uses: actions/checkout@v4
      - uses: julia-actions/setup-julia@v2
        with:
          version: ${{ matrix.julia-version }}
      - uses: julia-actions/julia-buildpkg@v1
      - uses: julia-actions/julia-runtest@v1
      - uses: julia-actions/julia-processcoverage@v1
      # upload coverage step optional, integrate with your preferred service
```

### Formatter and Static Analysis

- Use Runic.jl (from the General registry) for formatting. Always run Runic before committing (a pre-commit hook is recommended).
- Optionally run JET.jl in CI for hot paths/static checks.

Example commands:

```bash
julia --project=. -e 'using Pkg; Pkg.add("Runic"); using Runic; Runic.format!(".")'
julia --project=. -e 'using Pkg; Pkg.add("JET"); using JET; report_file("src")'
```

### Type Inference Checks

- Use `Test.@inferred` for public APIs and performance-critical functions
- Consider a CI job that runs a small set of `@inferred` tests or JET.jl analysis

### Run Commands in Project Environment

Always run commands in the appropriate project environment. Prefer running commands over manually editing files.

```bash
# Add dependency - PREFERRED
julia --project=. -e 'using Pkg: Pkg; Pkg.add("PackageName")'

# Activate project and run - PREFERRED
julia --project=. script.jl

# Test project - PREFERRED
julia --project=. -e 'using Pkg: Pkg; Pkg.test()'
```

```julia
# Interactive Julia session - PREFERRED
julia> using Pkg: Pkg
julia> Pkg.activate(".")
julia> Pkg.add("PackageName")
```

- Ensures proper dependency resolution and consistency.

### Dependency Management
See [Run Commands in Project Environment](#run-commands-in-project-environment) for how to add dependencies.

- **Specify Julia version** in Project.toml: `julia = ">=1.10, <2.0"`
- **Pin dependency versions**
- **Minimize dependencies**
- **Document non-standard dependencies**
- **All dependencies must have explicit `using` statements**

Import strategy:

- Prefer explicit module usage for clarity.
- Avoid cluttering the namespace with broad imports you do not use.
- Use `import` only when extending methods of external modules.

```julia
# Good - PREFERRED - bring the module; use qualified call
using Downloads: Downloads
data = Downloads.download("https://example.com/data.json")

# Good - PREFERRED - function import when you need a short name
using Downloads: download
data = download("https://example.com/data.json")

# Bad - implicit dependency and namespace clutter
using Downloads
data = download("https://example.com/data.json")

# Good - method extension requires import
import Downloads: Downloads
function Downloads.download(url::String)::String
    # ... implementation ...
end
```

### Documentation Policy

- Use Documenter.jl for public API docs; keep examples minimal and runnable
- Require doctests for exported APIs and run them in CI
- Build docs in CI to catch link and formatting issues

### Security and Secrets

- Never commit secrets; use CI secret storage (e.g., GitHub Actions secrets)
- Do not print secrets in logs; redact sensitive values
- For tests requiring tokens, gate with environment checks and skip when absent

### Logging

Use Julia's logging macros

```julia
using Logging

# Use in code
function process_data(data::Vector{Float64})
    @info "Processing data" length=length(data)
    # ... processing ...
end

```

- **Use `@info`** for informational messages
- **Use `@warn`** for warnings
- **Use `@error`** for errors (usually before throwing)

- **Include context** with keyword arguments

Use `@debug` for detailed debugging when needed (OFF by default):

```julia
# Define debugging control with conditional `debugging()` function (OFF by default):
debugging() = false
if debugging()
    @debug "Processing data" data=data
end

# Enable when needed by overloading the `debugging()` function
debugging() = true
```

- **Wrap debugging operations** in `if debugging()` checks

### Code Organization

- **File structure**: One type per file for large types, or group related types. Group related functionality.
- **Export strategy**: Export only public API. Prefix internal functions with `_` or place in internal module. Use qualified imports when names conflict.
- **Public vs Internal**: Clearly separate public API (exported, stable, documented) from internal implementation (can change, optimized freely)

Module structure:

```julia
module PackageName
    # Internal implementation
    include("types.jl")      # Type definitions
    include("internal.jl")   # Internal helper functions
    include("algorithms.jl") # Optimized internal algorithms

    # Public API
    include("api.jl")        # Public API - exported functions only

    # Exports
    export public_function, PublicType
end
```

### Package Structure

For Julia packages:

- **Clear public API**: All exports in one place, minimal and stable
- **Version compatibility**: Use compatibility bounds in Project.toml (align with supported Julia versions, e.g., `julia = ">=1.10, <2.0"`)
- **Documentation**: Public API must have docstrings with examples
- **Tests**: Comprehensive test suite covering public API

```julia
module MyPackage

# Internal
include("internal.jl")

# Public API
include("api.jl")

export PublicFunction, PublicType
end
```

### Service Patterns

For long-running services:

- **Configuration**: Externalize config, validate on startup
- **Initialization**: Separate initialization from runtime logic
- **Resource management**: Clean up resources (files, connections, memory)
- **Error handling**: Catch and log errors, don't crash service
- **Graceful shutdown**: Handle interrupts, cleanup on exit

```julia
function run_service(config::Config)
    # Initialize
    resources = initialize(config)

    try
        # Main loop
        while is_running()
            process_requests(resources)
        end
    catch e
        Logging.@error "Service error" exception=e
    finally
        cleanup(resources)  # Always cleanup
    end
end
```

### Code Reuse (DRY)

Extract common patterns to avoid repetition:

```julia
# Bad - repeated pattern
if x > 0 && x < 100 && x % 2 == 0
end

# Good - extracted function
function is_valid_even(x::Int)::Bool
    return x > 0 && x < 100 && x % 2 == 0
end
```

- Identify repeated code blocks
- Extract into reusable functions
- Improves maintainability and reduces bugs

## Code Review Checklist

Critical Principles:
- [ ] Intent clarified before implementation
- [ ] Code is minimal and self-explanatory
- [ ] Single concern per change, diffs < 100 lines

API Design:
- [ ] Public API clearly separated from internal implementation
- [ ] Return types consistent in public APIs
- [ ] Backward compatibility maintained (or properly deprecated)
- [ ] Public API stable and well-documented

Function Design:
- [ ] Function length reasonable (target 25 lines)
- [ ] Keyword arguments used for 3+ optional parameters
- [ ] Side effects documented

Julia Style Guide:
- [ ] Naming conventions followed
- [ ] Formatting consistent (4 spaces, < 92 chars)
- [ ] Documentation simple and clean (for exported/complex functions)

Type System:
- [ ] Type annotations present for public APIs
- [ ] Parametric types used (not abstract type fields)
- [ ] No type instability in hot paths

Error Handling:
- [ ] Appropriate exception types used
- [ ] Input validation in public APIs
- [ ] Clear error messages with context

Performance:
- [ ] Appropriate array types (StaticArrays.jl, FixedSizeArrays.jl, or Vector)
- [ ] No unnecessary allocations in loops
- [ ] Memory managed appropriately
- [ ] Internal algorithms optimized (where applicable)

Engineering Practices:
- [ ] Tests cover 100% of lines and branches
- [ ] All dependencies have explicit `using` statements (qualified imports preferred)
- [ ] Code organization follows conventions
- [ ] Package/service patterns followed (if applicable)
- [ ] CI covers tests, coverage, docs, and formatting checks

## Summary

**Critical principles:**
1. **Ask Rather Than Guess** - especially in planning phase
2. **Minimal Code** - don't state the obvious
3. **One Change at a Time** - keep diffs small

**Key guidelines:**
- **Documentation** - keep it simple and clean
- **Testing** - 100% line and branch coverage
- **Run Commands in Project Environment** - prefer commands over editing files
- Target 25 lines per function (negotiable)
- Follow Julia conventions - naming, formatting, types
- Prefer composition over inheritance
- Use parametric types over abstract type fields
- Consider performance - type stability, allocations, appropriate array types
- Handle errors gracefully
- Organize code logically

**Remember:** Quality over speed. **Discuss and clarify requirements before starting development.** Ask for clarification rather than guessing. Keep code minimal and clear. Make small, focused changes.


