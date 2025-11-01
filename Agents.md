# Agent Guidelines for Julia Development

Guidelines for AI agents working on Julia codebases. Focus on code quality, maintainability, and Julia best practices.

## Table of Contents

1. [Core Principles](#core-principles)
2. [Julia Style Guide](#julia-style-guide)
3. [Type System](#type-system)
4. [Function Design](#function-design)
5. [Documentation](#documentation)
6. [Performance](#performance)
7. [Error Handling](#error-handling)
8. [Design Patterns](#design-patterns)
9. [Engineering Practices](#engineering-practices)

## Core Principles

### 1. Ask Rather Than Guess
**CRITICAL**: When intent is unclear, **always ask** rather than assume. Ask about:
- Function names and signatures
- Algorithm choices
- Data structures and types
- Design decisions
- Edge case handling
- Performance vs. readability trade-offs

### 2. Function Length
- **Target**: 25 lines per function (excluding docstrings)
- **Negotiable** based on context:
  - Complex algorithms may exceed 25 lines
  - Utility functions should be shorter
  - Over 50 lines: almost always refactor
  - Over 35 lines: review for refactoring opportunities
- Each function should do one thing well (Single Responsibility)

### 3. Minimal Code
**CRITICAL**: Write minimal, clear code. Don't state the obvious.

**Don't:**
```julia
# Bad - stating the obvious
# Create a new value
value = 42
# Increment the counter
counter += 1
result = sum(numbers)
return result
```

**Do:**
```julia
# Good - self-explanatory
value = 42
counter += 1
return sum(numbers)

# Good - explain why, not what
# Prefer sqrt over x^0.5 for better numerical stability
result = sqrt(value)
```

**Add comments/clarity only when:**
- Complex algorithms or business logic
- Non-obvious performance optimizations
- Edge cases or special handling
- Workarounds for bugs or limitations

### 4. One Change at a Time
**CRITICAL**: Make small, focused changes for easier review.

- **One concern per change**: Don't mix bug fixes, refactoring, and features
- **Small diffs**: Target 50-100 lines; break large refactorings into steps
- **Separate commits**: Multiple related changes = separate commits/PRs
- **Incremental refactoring**: Add new ? switch ? remove old

**Benefits:** Easier review, lower bug risk, easier revert, clearer history

## Julia Style Guide

### Naming

- **Functions**: `lowercase_with_underscores`
- **Types/Structs**: `PascalCase`
- **Constants**: `UPPERCASE_WITH_UNDERSCORES`
- **Modules**: `PascalCase` (match filename)
- **Type parameters**: `T`, `S`, `U`, `V` (single uppercase letters)

### Formatting

- **Indentation**: 4 spaces (not tabs)
- **Line length**: Prefer < 92 chars, but readability first
- **Spacing**: 
  - Spaces around binary operators: `x + y`, `a && b`
  - No space after unary: `-x`, `!flag`
  - Space after commas: `func(a, b, c)`
  - Space after colons: `x::Int64`
  - No space before colons: `Dict{String, Int}`
- **Trailing commas**: Use in multi-line definitions

### Docstrings and Comments

**Docstrings only for:**
1. Exported functions/types (public API)
2. Complex functions where use is not obvious

```julia
# Exported - always document
"""
    compute_average(values)

Calculate the arithmetic mean of a collection of numbers.
"""
function compute_average(values::Vector{Number})::Float64
end

# Complex internal - document if needed
"""
Apply cumulative sum with overflow protection.
Handles large integers by converting to Float64 when needed.
"""
function safe_cumsum(values::Vector{Int})::Vector{Number}
end

# Simple internal - no docstring needed
function get_first(items::Vector{T})::Union{T, Nothing} where T
    return isempty(items) ? nothing : items[1]
end
```

**Inline comments:**
- Use sparingly, only when purpose isn't obvious
- Explain **why**, not **what**
- TODO/FIXME: Always include context

## Type System

### Type Annotations

- **Public APIs**: Always annotate argument and return types
- **Internal functions**: Types optional but recommended
- **Type stability**: Critical for performance; avoid type instability in hot paths

```julia
# Good - fully typed
function add_numbers(a::Float64, b::Float64)::Float64
    return a + b
end

# Bad - type unstable
function get_value(container, key)
    haskey(container, key) ? container[key] : nothing  # Type unknown
end

# Good - explicitly typed
function get_value(container::Dict{String, Int}, key::String)::Union{Int, Nothing}
    return get(container, key, nothing)
end
```

### Union Types

- Use for optional/nullable values: `Union{Type, Nothing}`
- Avoid `Any`; prefer specific types or structured alternatives

```julia
# Good
name::Union{String, Nothing}

# Bad
settings::Dict{String, Any}

# Better - structured type
struct Settings
    timeout::Union{Int, Nothing}
    retries::Union{Int, Nothing}
end
```

### Parametric Types

Use parametric types for generic code with constraints. **Prefer parametric structs over structs with abstract type fields** for type stability and performance.

**Functions with type parameters:**
```julia
function reverse_items{T}(items::Vector{T})::Vector{T} where T
end

function sum_values{T <: Number}(values::Vector{T})::T where T
end
```

**Structs: Use parametric types instead of abstract type fields**

```julia
# Bad - abstract type field causes type instability
struct Container
    items::Vector{Number}  # Abstract type - slow, type-unstable
end

# Good - parametric type makes struct concrete and type-stable
struct Container{T <: Number}
    items::Vector{T}  # Concrete type - fast, type-stable
end

# Usage
int_container = Container{Int}([1, 2, 3])
float_container = Container{Float64}([1.0, 2.0, 3.0])
```

**When you need to store different types, use Union or separate parametric instances:**

```julia
# Bad - abstract type loses type information
struct Processor
    value::Number  # Type unstable
end

# Good - parametric type preserves type information
struct Processor{T <: Number}
    value::T  # Type stable
end

# If you truly need mixed types at runtime:
struct MixedProcessor
    value::Union{Int, Float64}  # Explicit union, better than Number
end

# Or use separate instances:
int_processor = Processor{Int}(42)
float_processor = Processor{Float64}(3.14)
```

**Benefits of parametric structs:**
- **Type stability**: Compiler knows exact types, better optimization
- **Performance**: No runtime type checking/dispatching
- **Type safety**: Compile-time guarantees about stored types
- **Flexibility**: Same struct works with different concrete types

**Guidelines:**
- Always parameterize structs when fields could have different concrete types
- Avoid abstract types (`Number`, `AbstractArray`, etc.) as field types
- Use parametric types with constraints: `struct Container{T <: Number}`
- Use Union types only when you genuinely need mixed types at runtime

## Function Design

### Signatures

- **Keyword arguments**: Use for 3+ optional parameters
- **Default arguments**: Provide sensible defaults
- **Argument order**: Required ? optional ? keyword

```julia
function transform_values(
    values::Vector{Number};
    scale::Float64 = 1.0,
    offset::Float64 = 0.0,
    inplace::Bool = false,
)::Vector{Number}
end
```

### Function Purity

- Prefer pure functions (no side effects)
- Document side effects clearly if unavoidable

```julia
# Good - pure function
function multiply(a::Number, b::Number)::Number
    return a * b
end

# Document side effects
"""
Modifies `container` in place by appending `value`.
"""
function append!(container::Vector{T}, value::T) where T
    push!(container, value)
end
```

## Documentation

### Module Documentation

Always document modules:

```julia
"""
    ModuleName

Brief description of the module's purpose.

## Features
- Feature 1
- Feature 2

## Main Functions
- [`function1`](@ref): Description

## Examples
```julia
using ModuleName
result = function1(args)
```
"""
module ModuleName
```

### Type Documentation

Only document exported types (or complex internal types):

```julia
"""
    Container{T}

A generic container for values of type T.

# Fields
- `items::Vector{T}`: The stored items

# Examples
```julia
container = Container{Int}([1, 2, 3])
```
"""
struct Container{T}
    items::Vector{T}
end
```

### Function Documentation

Only exported or complex functions:

```julia
"""
    compute_result(input, factor = 1.0)

Calculate result from input using the specified factor.

# Arguments
- `input::Float64`: Input value
- `factor::Float64 = 1.0`: Multiplication factor

# Returns
- `Float64`: Computed result

# Examples
```julia
result = compute_result(10.0, 2.0)
```
"""
function compute_result(input::Float64, factor::Float64 = 1.0)::Float64
    return input * factor
end
```

## Performance

### Allocation Awareness

- Pre-allocate when size is known
- Use views to avoid copying: `@view array[start:end]`
- Avoid global variables in hot paths (use `Ref` or pass as parameter)
- **Use specialized array types for performance:**

```julia
# Good - pre-allocate
results = Vector{Float64}(undef, length(inputs))
for i in eachindex(inputs)
    results[i] = compute(inputs[i])
end

# Use StaticArrays.jl for small, fixed-size arrays (moderate size, typically < 100 elements)
# Stack-allocated, no heap allocation, excellent performance
using StaticArrays
function compute_transform(point::SVector{3, Float64})::SVector{3, Float64}
    # SVector is stack-allocated, much faster than Vector for small sizes
end

# Use FixedSizeArrays.jl for preallocated arrays with known size at compile time
# Better than Vector when size is fixed and known
using FixedSizeArrays
const FIXED_SIZE = 10
results = FixedArray{Float64, (FIXED_SIZE,)}()  # Pre-allocated fixed size

# Use built-in Vector/Array only when:
# - You need to push/append to the array dynamically
# - Performance is not a concern
# - Size is unknown at creation time
```

**Array Type Selection Guide:**
- **StaticArrays.jl** (`SVector`, `SMatrix`, `MVector`, `MMatrix`): For small, fixed-size arrays (< ~100 elements). Stack-allocated, zero heap allocation, excellent performance for small sizes.
- **FixedSizeArrays.jl**: For pre-allocated arrays where size is known at compile time but may be larger than StaticArrays handles efficiently.
- **Built-in `Vector`/`Array`**: Use only when you need dynamic resizing (`push!`, `append!`) or when size is unknown at creation time.

```julia
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

Use `@code_warntype` to check for type instability.

### Broadcasting

Use broadcasting for element-wise operations:

```julia
# Good
squared = values .^ 2
sums = a .+ b
```

## Error Handling

### Exception Types

- Use appropriate exception types
- Provide helpful error messages with context

```julia
# Good - specific exception
if divisor == 0
    throw(DivideError("Cannot divide by zero"))
end

# Good - custom exception
struct ValidationError <: Exception
    message::String
    field::String
end

# Good - helpful message
if length(keys) != length(values)
    throw(ArgumentError(
        "Mismatch: keys has $(length(keys)) elements but values has $(length(values))"
    ))
end
```

### Validation

- Validate inputs in public APIs
- Fail fast with clear error messages

```julia
function divide(a::Float64, b::Float64)::Float64
    if b == 0
        throw(DivideError("Cannot divide by zero: $a / $b"))
    end
    return a / b
end
```

## Design Patterns

### Composition Over Inheritance

**Prefer composition over inheritance.** In Julia, use composition (structs containing other structs) rather than abstract type hierarchies for most use cases.

**Composition (Preferred):**
```julia
# Good - composition with concrete types
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

function process(data, processor::Processor)
    log_message(processor.logger, "Processing...")
    # Process data using processor.config
end

# Good - composition with parametric types (preferred when types vary)
struct Buffer{T}
    data::Vector{T}
    capacity::Int
end

struct Transformer{T}
    buffer::Buffer{T}
    multiplier::Float64
end

# Usage - type-stable composition
int_transformer = Transformer(Buffer{Int}([1, 2, 3], 100), 2.0)
float_transformer = Transformer(Buffer{Float64}([1.0, 2.0], 50), 1.5)
```

**Inheritance (Use Sparingly):**
```julia
# Avoid deep inheritance hierarchies
abstract type Animal end
struct Dog <: Animal end
struct Cat <: Animal end

# Prefer composition for shared behavior
struct Behaviors
    can_speak::Bool
    can_fly::Bool
end

struct Animal
    name::String
    behaviors::Behaviors
end
```

**When to use each:**
- **Composition**: Default choice. Flexible, testable, avoids deep hierarchies.
- **Abstract types**: Use for dispatch-based polymorphism (multiple dispatch), not for code reuse.
- **Inheritance hierarchies**: Only when you truly need is-a relationships and polymorphic dispatch.

**Julia-specific considerations:**
- Julia's multiple dispatch provides polymorphism without inheritance
- Abstract types define interfaces for dispatch, not implementation sharing
- Composition allows runtime flexibility and easier testing
- Use `has_a` (composition) over `is_a` (inheritance) relationships

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

function sort_values(values::Vector{Number}, ::QuickSort)::Vector{Number}
    # Quick sort implementation
end

function sort_values(values::Vector{Number}, ::MergeSort)::Vector{Number}
    # Merge sort implementation
end
```

### Callback Pattern

For flexible data processing:

```julia
function filter_values(
    values::Vector{T};
    predicate::Union{Function, Nothing} = nothing,
)::Vector{T} where T
    predicate === nothing && return values
    result = T[]
    for value in values
        predicate(value) && push!(result, value)
    end
    return result
end
```

### Factory Pattern

For object creation with different types:

```julia
function create_container(type::String)::Vector{Any}
    if type == "int"
        return Vector{Int}()
    elseif type == "float"
        return Vector{Float64}()
    elseif type == "string"
        return Vector{String}()
    else
        throw(ArgumentError("Unknown container type: $type"))
    end
end
```

## Engineering Practices

### Testing

- Write tests for all public APIs
- Test edge cases: empty inputs, boundary values, error conditions
- Use descriptive test names

```julia
@testset "Division function" begin
    @test_throws DivideError divide(10.0, 0.0)
    @test divide(10.0, 2.0) == 5.0
end
```

### Code Reuse (DRY)

Extract common patterns:

```julia
# Bad - repeated pattern
if x > 0 && x < 100 && x % 2 == 0
end

if y > 0 && y < 100 && y % 2 == 0
end

# Good - extracted function
function is_valid_even(x::Int)::Bool
    return x > 0 && x < 100 && x % 2 == 0
end
```

### Dependency Management

- Specify Julia version in Project.toml: `julia = "1.6"`
- Pin dependency versions
- Minimize dependencies
- Document non-standard dependencies

### Code Organization

**File structure:**
- One type per file for large types, or group related types
- Group related functionality

**Export strategy:**
- Export only public API
- Prefix internal functions with `_` or place in internal module
- Use qualified imports when names conflict

**Module structure:**
```julia
module PackageName
    include("types.jl")      # Type definitions
    include("utils.jl")       # Utility functions
    include("io.jl")          # I/O operations
    include("process.jl")     # Processing logic
    include("api.jl")         # Public API
end
```

### Additional Guidelines

**Memory Management:**
- Be aware of memory usage for large datasets
- Consider streaming for very large files
- Use appropriate data structures (Dict vs. Vector)
- Consider StaticArrays.jl for small fixed-size arrays (see [Performance](#performance) section)
- Consider FixedSizeArrays.jl for pre-allocated arrays with known size

**Concurrency:**
- Document thread-safety assumptions
- Use appropriate synchronization if shared state is modified

**API Evolution:**
- Maintain backward compatibility when possible
- Deprecate rather than remove: `Base.@deprecate old_function(args...) new_function(args...)`

## Code Review Checklist

- [ ] Type annotations present for public APIs
- [ ] Documentation complete for exported/complex functions
- [ ] Error handling appropriate
- [ ] No type instability in hot paths
- [ ] Tests cover main functionality and edge cases
- [ ] Function length reasonable (target 25 lines)
- [ ] Code follows naming conventions
- [ ] No unnecessary allocations in loops
- [ ] Input validation where appropriate
- [ ] No redundant comments or obvious statements
- [ ] Code is minimal and self-documenting
- [ ] Changes focused on single concern
- [ ] Diffs kept small and reviewable

## Summary

Agents should:
1. **Always ask** when intent is unclear
2. **Target 25 lines** per function (negotiable)
3. **Write minimal code** - don't state the obvious
4. **One change at a time** - keep diffs small
5. **Follow Julia conventions** - naming, formatting, types
6. **Prefer composition over inheritance** - use struct composition, not deep type hierarchies
7. **Document** exported/complex functions only
8. **Consider performance** - type stability, allocations
9. **Handle errors** gracefully with helpful messages
10. **Write tests** for public APIs
11. **Organize code** logically

**Remember:** Quality over speed. Ask for clarification rather than guessing. Keep code minimal and clear. Make small, focused changes for easier review.
