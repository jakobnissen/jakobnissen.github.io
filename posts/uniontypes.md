# Union vs sum types
_Written 2021-10-06_

Union types and sum types are programming language concepts that have been around for decades, but I think they're getting more popular these years.
The two concepts are closely related but their subtle differences impacts their relative strengths.
This post is an explanation of the concepts and a list of pros and cons of the two.

## Structs are "product types"
Union types, sum types and product types are all _algebraic data types_, which sound super complicated, but the basic concept is actually really simple.

Let's begin somewhere familiar: With an ordinary struct.
A database used by my job contains "cases" who are known by identifiers like this

@@plaintext
```
struct CaseID_V2 {
    year: u16,
    number: u32
}
```
@@

This definition creates a new type `CaseID_V2`.
We can think of a struct like an AND operator: `CaseID_V2` is a new type that is composed of a `u16` AND a `u32`.

What is _type_, actually?

Well, one can think about types as sets of possible values.
Here for `u16`:

$u16 = \{ 0x0000, 0x0001, 0x0002 ... 0xffff \}$

What values of `CaseID_V2` are there?
Well, if a `CaseID_V2` is a `u16` and a `u32`, then the set of possible `CaseID_V2` is simply the Cartesian product of the two types (e.g. all possible combinations of the two, denoted by $\times$):

$$CaseID_{V2} = u16 \times u32$$

And ta-da! That's why structs are called product types. That's really all there is to it.

## Union types
Sometimes though, we want a new type which is not composed of one field AND another, but instead one field OR another.
The same database at my work actually changed its `CaseID` in 2021, for some reason, hence the `_V2` suffix in the previous example.
The old definition looked like this:

@@plaintext
```
struct CaseID_V1 {
    numbers: u32,
    letters: u32 // encoded in base36
}
```
@@

Now, any data type that contains a case ID must be able to have a notion of containing EITHER a `CaseID_V1` OR a `CaseID_V2`.
We call such an either/or type a _union type_.

In pseudocode, it could look like:

@@plaintext
```
union type CaseID {
    CaseID_V1,
    CaseID_V2
}
```
@@

And we can then put _that_ into a struct, if we want:

@@plaintext
```
struct Case {
    id: CaseID,
    creation: Date,
    [ etc. ]
}
```
@@

Why do we call it a union type? Well, similar to reason we call struct product types.
The possible values in the new union type is the _union_ of its members:

$$CaseID = CaseID_{V1} \cup CaseID_{V2}$$

Since its values are either `CaseID_V1` or `CaseID_V2`, clearly the set of possible values are just all the values that are in either set, or equivalently the union of the two sets.

## Union types is good for set operations
Here's a dilemma, though: What if we do this?

@@plaintext
```
union type MyType {
    bool,
    bool
}
```
@@

This says that `MyType` is EITHER a `bool` OR a... `bool`?
How many possible values is this?

$$MyType = \{false, true\} \cup \{false, true\} = \{false, true\} = bool$$

It's still just the set $\{false, true\}$!
In other words, `MyType` is equivalent to `bool`. Or one might even say it _is_ `bool`.

That simplification is pretty neat, because it allows us to express uncertainty about types as union types, and do set operations on those.
For example, suppose you have functions `f`, which returns the union $f(x) = u16 \cup i16$, and `g` which returns $g(x) = u16 \cup u32$ for four possible types total. If you now call either `f` OR `g`, what are your possible return types?

It's simply $f(x) \cup g(x) = u16 \cup i16 \cup u32$, "deduplicated" to just three types.

A similar simplification happens if you union two types where one is a superset of the other.
For example, suppose your language has a type `uint`, which just means "any unsigned integer", no matter its width. In that case $u16 \cup uint = uint$ - after all, the set of values `uint` _contains_ the set `u16`.

## Sum types
Sometimes when you program, you don't necessarily want that deduplication.
Suppose you want to make a union type that contains _either_ the year of the Gregorian calendar (stored in a `u16`), or the year according to the Hijri calendar (also stored in a `u16`).
You can't express this as a union type $T = u16 \cup u16 = u16$, because in your case, these two `u16` are _different things_, that just happen to have the same representation, but shouldn't be conflated.

The solution is pretty straightforward: You create two new types that wrap the `u16`s, and serve as a "type tag" so the program knows how to interpret the data. Something like:

@@plaintext
```
struct Year_Gregorian {
    val: u16
}

struct Year_Hijri {
    val: u16
}

union type Year {
    Year_Gregorian,
    Year_Hijri
}
```
@@

This kind of type - a union type with each member tagged - is called a _tagged union_.
It's also called a _sum type_. By now you can guess why it's called a sum type:
The number of values of type `Year` is exactly the sum of its members: $|Year| = |Year_{Gregorian}| + |Year_{Hijri}|$.

Sum types are really useful when you want to be 100% sure you can distinguish all members of your union. 

## Sum types in Rust
Rust calls sum types "enums" (a slight misnomer). You can make pretty complicated sum types very easily:

@@rustcode
```
enum ComplicatedEnum {
    IsEmpty,
    Color(u8, u8, u8),
    Name { given: String, sur: String }
}
```
@@

One interesting catch about Rust's enums is this:
Instead of defining three ordinary types `IsEmpty`, `Color` and `Name`, these three "variants" can only exist as part of an `ComplicatedEnum` and not on their own.
This implies that no value can have the type `IsEmpty`: All values of `ComplicatedEnum` is just of the type `ComplicatedEnum`.

I don't think there is any big theoretical reason for this "forced wrapping" of sum types in Rust, but it has important implications for practical use of Rust's sum types, which I'll get to in a bit.

## Union types in Julia
In Julia, types matches perfectly well with the idea of "types as sets of values":

@@juliacode
```
julia> 5 isa Int # check if 5 is an instance of Int
true

julia> 5 isa Union{Int, String}
true

julia> 5 isa Integer # Integer is a superset of Int
true

julia> 5 isa Union{String, Set, Char}
false

julia> Union{Int, Integer, Char, UInt, Int} # deduplication
Union{Char, Integer}
```
@@

In short, the value `5` belongs to both the types `Int`, `Union{Int, String}`, `Integer`, and an infinite number of other types.

Another difference from Rust is Julia is a dynamic language.
Briefly, in static languages, expressions (e.g. code) has types, but types don't really exist at runtime since they are optimized away and everything is just a binary blob.
In dynamic languages, values have types at runtime, and whatever type the compiler infer before runtime is immaterial: It has no impact on what values or types are actually produced at runtime.

What this means is that, even if the compiler infers some value `x` to be of type `Union{A, B, C}`, at runtime, the type of `x` will be just `A`, `B` or `C`.
Union types don't exist at runtime. They are only used to express the compiler's uncertainty about what is going to happen when the program runs.

## Advantages of Julia's union types over Rust's sum types
Many of the differences between Julia's and Rust's types actually come from the "forced wrapping" of Rust's sum types, not necessarily from the fact they are sum types instead of union types.

#### Backwards compatible changes
If you have an API that expects to be supplied with a `A`, then you can always change it to take a `Union{A, B}` without breakage, because all values of type `A` are also values of type `Union{A, B}`.

Similarly, if your function returns a `Union{A, B}`, you can change it to just return `A` without breakage.

This won't work in Rust: You can't change a function that took an `Option<usize>` to take a `usize` without breaking user's code, nor can you return `usize` where you previously returned `Option<usize>`.

#### No need to wrap and unwrap sum types
In Rust, you can't access the variants of a sum type directly because they are always wrapped.
This leads to a _lot_ of boilerplate: Check the long list of methods for [`Option`](https://doc.rust-lang.org/std/option/enum.Option.html) and [`Result`](https://doc.rust-lang.org/std/result/enum.Result.html) which exist just for unwrapping and re-wrapping these types in various circumstances.

With Julia's system it's much easier: You don't unwrap and re-wrap because it's not wrapped in the first place. How do you add 1 to `x` if it's a `Union{Int, UInt}`? Just `x + 1`, like any normal integer.

#### More possibilities for compiler optimization
Just like it's not a breaking change to return a narrower union type or accept a broader one, it's also an allowed compiler change.

Suppose you write a function `f` that returns `Union{A, B}` and you pass it into a function `g` expecting that.
But now, in some code, you call `f` with one of the argument as a constant.
The compiler will then check if that constant argument narrows down the return type of `f`.
Let's say with the constant folded argument `f` is guaranteed to return `A`.
If so, the compiler will then know `g` will be getting an `A`, not a `Union{A, B}` - so now `g` can be further optimized, for example by compiling away all branches that occur if the input is a `B`.

## Advantages of Rust's sum types over Julia's  union types
#### Unwrapping forces you to remember you're dealing with a sum type
Julia's union types may have less boilerplate because you can use them as if they were concrete types - but that's also a dangerous trap.

Consider the Julia function `findfirst`, which returns `Union{Int, Nothing}` versus Rust's `iter.position`, returning `Option<usize>`:
It's easy to forget `findfirst` can return nothing and not handle that case, introducing a bug.
But it's not possible to mistaken an `Option<usize>` for a `usize`, because they're incompatible types and you _must_ unwrap the sum type.

#### Wrapped types are more straightforward and therefore explicit
The intricate set operations possible with union types can also be pretty annoying when you're just trying to code.
For example, suppose `f` is a function returning type `T`. What's the return type of this Rust code?

@@rustcode
```
vec![f()]
```
@@

Yep, it's `Vec<T>`. Now what's the return type of this Julia code?

@@juliacode
```
[f()]
```
@@

`Vector{T}`, obviously! Right? Nope, not necessarily:

@@juliacode
```
julia> f() = rand(Bool) ? 1 : nothing;

julia> g() = [f()];

julia> only(Core.Compiler.return_types(g, ()))
Union{Vector{Int64}, Vector{Nothing}}
```
@@

Instead of a vector of unions, its a union of vectors.
This must necessarily be true when you think about it, but it's just one of these examples where union types can "pull the rug" under you by suddenly doing something clever.

#### No compiler optimizations mean no compiler costs
The Julia compiler optimizations mentioned above enabled by automatic restriction of union types are cute.
But what if you have a union composed of, say 10 variants?
If your language compiles specialized functions for every input type ("monomorphization"), as Julia and Rust does, this can cause an combinatorial explosion which leads to huge compilation times and bloated code.
In fact, in Julia, this gets so bad that the compiler just gives up and emits code that checks the type at runtime if it infers that a value is a union with more than 4 members.

In this case, simply checking which variant you have with if/else statements is much more efficient than clever compiler tricks.
Or even better than if/else statements...

#### Exhaustive pattern matching
Precisely because Rust's sum types don't do these clever type operations, the user can be confident that a sum type with variants `A`, `B` and `C` stays the same type with the same variants.

This enables _exhaustive pattern matching_: Pattern matching that will detect at compile time if you forget any edge cases.
If you've used Rust for more than 5 minutes, you already know this is the best thing since sliced bread.
If not, I _strongly_ recommend you trying it out just so you know _how good_ this would be to have in Your Favorite Language.

## Conclusion
There are advantages to both union types and sum types.
Quite fittingly, union types play to Julia's strengths: They enable expressive (low-boilerplate), generic and fast code.
On the other hand, Rust's sum types enable code with predictable types, and much safer code through forced checking of edge cases.

I'm not convinced this tradeoff between union and sum types is inherent.
I think it may be possible to eat your cake and have it, too, but I'm not yet sure how such a system would look like.

Hopefully, that's a blog post - or a Julia package - for another time!