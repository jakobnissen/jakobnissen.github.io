@def rss = "You probably don't need to validate UTF-8 strings"
@def rss_pubdate = Dates.Date(2024, 05, 16)

# You probably don't need to validate UTF-8 strings
_Written 2024-05-16_

Strings are important to all programmers, but to us bioinformaticians, they are an absolutely central.
The layout of strings is just a slice of bytes in memory, so you'd think the string data type is not an interesting design space when designing a programming language - but you'd be wrong!
In this post, I'll compare and contrast the design of strings in Rust and Julia.

@@toc-header Table of contents@@
\tableofcontents

## Why not also compare Python's strings?
Python was my first programming language, and is a language I'm deeply familiar with, so it'd be obvious to include Python's `str` in the comparison.
Unfortunately, Python comes from such a different place than Rust or Julia - it was designed in the 1990's, and it was never designed to be used for computationally demanding tasks.
For a thorough explanation of Python's strings, I recommend reading [Victor Skvortsov's deep dive on the subject.](https://tenthousandmeters.com/blog/python-behind-the-scenes-9-how-python-strings-work/)

Perhaps the main difference from Python to Julia and Rust is that the latter languages are from the early 2010's, where the [UTF8 encoding scheme](https://en.wikipedia.org/wiki/UTF-8) had become the dominant string encoding - ~98% of web sites are encoded in UTF8 [according to Wikipedia](https://en.wikipedia.org/wiki/Popularity_of_text_encodings).
As such, when Julia and Rust were designed, it was obvious to represent strings as byte arrays encoded in UTF8.
Explaining UTF8 itself is outside the scope of this post, but I recommend reading up on it if you do any serious string processing in your own code.

## Mutability
In Julia, data types are declared as mutable or immutable types, and `String` is one of the immutable ones.
Mutating strings requires unsafe functions[^1] and may cause undefined behaviour.
The reason Julia strings are immutable is a question of semantics: [A string's value is identical to its content]((https://discourse.julialang.org/t/why-are-strin gs-immutable-historical-records-request/92115/5?u=jakobnissen)).
If strings were mutable and I changed a string from "box" to "fox", it's not the _same_ string that has changed, but instead a new string that was created from the same memory, similarly to how the number 4 and the number 5 are distinct numbers, even though it's possible to mutate a piece of memory from storing a 4 to storing a 5.

In Rust, it is variables and not types which are mutable or immutable, and so `String`s can be mutated though a mutable variable or reference.
Strings also supports dynamic resizing (e.g. `my_string.push`).

Why doesn't Julia have per-variable mutability instead of per-type mutability?
One reason is simplicity: Per-type mutability obviates the need to have two kinds of bindings: `x` and `mut x`.
Another issue is Julia's lack of a borrowchecker: If all data _can_ be mutated through a mutable variable, for the compiler to know if some data is immutable, it needs to know that no other part of the program holds a mutable reference to it, and so the compiler needs to enforce something like Rust's ownership rules.
In contrast, if the values of some types are always immutable, the compiler knows data of that type is immutable no matter who holds references to it.

As always, immutability comes with a performance penalty: Mutating values is generally faster than creating new ones.
This cause a problem when working with immutable types: For efficiency, we want to be able to mutate strings, but for the compiler to treat strings as immutable, we want to never be able to observe them being mutated.
To solve this problem, Julia uses the following interesting pattern in its internals:[^2]

@@juliacode
```julia
mem = unsafe_wrap(Memory{UInt8}, Base._string_n(8))
copyto!(mem, 0x61:0x68)
str = String(mem)
```
@@

In this code:
1. The internal function `Base._string_n(8)` creates a string with 8 bytes of uninitialized memory
2. The `unsafe_wrap` calls returns a `Memory{UInt8}` view of the string.
   Because there are no longer any references to the string after creating `mem` and so the string cannot be observed, mutating `mem` is legal
3. We mutate the memory, in this example using `copyto!`
4. Finally, `String(mem)` creates a string from the memory. Mutating the memory after this call is illegal.

It's not exactly pretty.
Perhaps a better design would expose `_string_n` as public, have `String(::Memory{UInt8})` copy, and introduce `unsafe_takestring(::Memory{UInt8})` to create zero-copy strings from memory.
Or perhaps not. The risks of accidentally stumbling into undefined behaviour territory might make APIs like this a minefield.

## Struct definitions
The [definition of `String` in Rust](https://doc.rust-lang.org/1.78.0/src/alloc/string.rs.html#365) is pretty straightforward: 

@@rustcode
```
pub struct String {
    vec: Vec<u8>,
}
```
@@

The `Vec<u8>` contains the content of the string, encoded in UTF8.
`Vec` is, of course, also implemented in Rust. If I inlined the composition of `Vec` and the composition of those structs etc, then `String` has the following layout:

@@rustcode
```
struct IllustrativeString {
    ptr: *u8,
    capacity: usize,
    len: usize,
}
```
@@

Note that the actual in-memory ordering of fields of Rust structs is an implementation detail decided by the compiler.

More commonly used is the `str` type, which can be considered a string view.
It's almost always (always?) a borrowed reference, so it's mostly seen as `&str`.
This type is built into the Rust compiler, but contains only a pointer and a length.

It's quite the meme that Rust has tonnes of different string types: `String`, `str`, `OsString`, `OsStr`, `CString`, `Cstr` and possibly more.
Part of this complexity comes from Rust having to duplicate every type to have an owned and a borrowed version.
Interestingly, the same borrowchecker which enables Rust to avoid creating types in immutable/mutable pairs, forces Rust to create owned/borrowed pairs of types. 

In Julia, `String` is implemented in C and is one of the few completely opaque types in the language, i.e. its layout can't be introspected from Julia itself.
However, I believe it consists of this data, stored on the heap, in order:
1. The length of the string, in a word-sized integer
2. The UTF8 data of the string itself
3. A trailing null byte, for easier C interop

In Julia, it's passed around as a single pointer to this heap data.
Besides the most basic functionality such as instantiating strings, and getting the number of bytes in the string and a pointer to its content, essentially all operations on strings are defined in Julia code.

## Indexing into strings
In both Rust and Julia, you can slice into strings to get a substring. For example, here, in Julia:

@@juliacode
```
julia> "alphabeta"[3:5]
"pha"
```
@@

These indices are byte indices and the result is a newly allocated `String` (similar to how slicing into an array allocates a new array).
The first and last index must be the starting bytes of characters, else you get a runtime error:

@@juliacode
```
julia> "alpæabeta"[3:5]
ERROR: StringIndexError: invalid index [5], valid nearby indices [4]=>'æ', [6]=>'a'
```
@@

Rust works the same way, except it returns a `&str` and so does not allocate.

Rust and Julia differ in that Julia allows indexing with a scalar to produce a `Char`.
This, too, will fail if the index provided is not the first byte index of a `Char` in the string.
This scheme allows O(1) access to characters, providing the caller knows the byte index of the character.

Rust intentionally does not allow indexing with integers, alledgedly in order to not confuse users into believing the index represent a character index instead of a byte index - but I think that's not a very convincing argument given that slicing already does work using byte indices.

## Accessing the underlying bytes of a string
This is done in two quite different ways in Rust and Julia that are characteristic of the languages:

In Rust, `my_string.as_bytes()` returns the data of the string as a byte slice - `&[u8]`.
Notably, the slice type (`&[T]`) is the most basic type in Rust to represent a view into a contiguous chunk of memory with elements of type `T`.
In fact, when operating on `Vec<T>`, if you don't need to resize the vector, it is idiomatic to write functions that take a slice `&[T]` instead of the vector itself.
Rust will automatically convert (dereference) the vector to a slice when calling the function (because `Vec<T>` implements the trait `Deref<Target = &[T]>`), and in this manner, the function is more generic and will also work on, for example, the bytes of a string.

In contrast, in Julia, `codeunits(my_string)` produces a dedicated `CodeUnits{UInt8, String}` object that wraps `my_string` and is an instance of `AbstractVector{UInt8}`.

Both objects provide zero-cost access to the bytes using a vector-like type.
Where they differ most starkly is how they allow generic user code to operate on this array-like object:

Julia relies on the fact that `CodeUnits` subtypes `AbstractVector`, and that the `CodeUnits` objects therefore can be used with any code that works with generic `AbstractVector` values.
Since many different types in Julia, such as ranges, similarly subtype `AbstractVector`, the user has a strong incentive to write their functions generically enough to accept `AbstractVector`.
In turn, this leads to Julia code being highly composable.
For example, if someone wrote a library with a function that was intended for, say `Vector`, I can most likely plug in a `CodeUnits`, or even a range, and it'll still work.

In this case, Rust enables generic code in the exact opposite manner: Instead of unifying different types with a disparate implementation into a single interface, it allows many different types to share the same data layout: Strings, vectors, paths and more can be represented as a byte slice `&[u8]`.

Compared to the Julia approach, this is much less generic - for example, ranges cannot dereference into a slice, so methods taking `&[T]` won't work on ranges.
On the flip side, because the data layout of a slice is well-defined, it's possible to provide much more optimised code for slices than for an abstract vector - for example, one can call `memchr` on any `&[u8]`, but not on any abstract vector.
Also, the behaviour of a function that takes a single, concrete type - a slice - is easier to reason about than code that may operate on any type that subtypes `AbstractVector`.

## Enforced valid UTF8
Okay, this is the big one: In Rust, strings are always valid UTF8, and attempting to create a string with invalid UTF8 will panic at runtime:

@@rustcode
```
fn main() {
    println!("{}", std::str::from_utf8(b"\xff\x02").unwrap());
}
```
@@

```
thread 'main' panicked at src/main.rs:2:53:
called `Result::unwrap()` on an `Err` value: Utf8Error { valid_up_to: 0, error_len: Some(1) }
```

In contrast, Julia allows invalid UTF8 in strings:

@@juliacode
```
julia> s = String(b"\xff\x02")
"\xff\x02"

julia> isvalid(s)
false
```
@@

In my opinion, this is the most interesting difference between Rust and Julia strings.
These behaviours are very much intentional, and when I've asked around about this design decision, both the Rust and Julia community argue forcefully in favor of the design of their language.

What's up with that difference? Let's dig in!

First, remember the value propositions of the two languages. To put it pointedly:
* Rust treats all code as production-quality code.
  The very existence of quick and dirty code is against Rust's values, so it's no problem if Rust frustrates and hinders your attempts at prototyping - it's only protecting you from sinning.
* Julia treats all code as prototype code, and encourages hacking.
  The language will provide zero help with procuding code that is maintainable and robust, and if you're aiming to do so, the recommendation is simply "be disciplined".

My argument is that the approaches taken by Rust and Julia makes sense given their respective language design goals.
However, I believe Julia's paradigm of "UTF8 by convention" is overall the better design _in most situations_, and probably also would have been better for Rust.

### How do you handle invalid UTF8?
Suppose you are writing a function that needs to read the lines of a text file.
The file is probably UTF8, but how do you know? It could've been saved in another format like latin1, or it could be saved in UTF8, but have been slightly corrupted since then.

What is the design space here?
How _could_ Julia behave, if we were to redesign it from scratch?

One option is to have `String` constructors throw an exception when encountering invalid UTF8.
This would, ironically, create a correctness footgun: Your code would work fine during testing, all up until the moment it (unexpectedly) hits a non-UTF8 file and crashes.
That violates a tenant of good code: If your code crashes unexpectedly, it should be because your code is bad, not because the data you process is bad. 
Also, this approach prevents you from _actually handling non-UTF8_, because simply exiting the program when encountering non-UTF8 is not _handling_ it - you program in fact, does not work with non-UTF8.

Another option is to not crash immediately when encountering non-UTF8, but defer the decision to the user. For example, Julia could return some `MaybeUTF8Bytes` object that then needs to be unwrapped to either error or get a valid UTF8 string.
This is what Rust does. This way, it forces the user to consider the existence of other encodings (or currupted data). This has two issues:

* _First_, it adds extra boilerplate to your code. This might be acceptable in a language like Rust where correctness comes above all, but imagine having to unwrap maybe-strings in a REPL or a notebook when doing interactive data science. Fuck no.

* _Second_, practically speaking, most users are just going to unwrap your maybe-string indiscriminately, anyway. By far most Rust programs I've seen take this approach. The fact that actually _handling_ the error case is so rare makes me feel that very little correctness is gained from the extra ceremony.

The third option is to make the UTF8 check opt-in.
Julia would accept strings with arbitrary (non-UTF8) bytes, and if the user cares to handle the edge case, they would have to run some sort of `isvalid` check themselves.
This is where Julia has landed.
Interestingly, the Zig language takes it even further and says that [strings are just arrays of `u8`](https://github.com/ziglang/zig/issues/234), similar to C.
Julia differs from Zig and C in that its string are a distinct type, which is useful to prevent type confusion, and for specializing some methods for strings, such as displaying them differently.

The advantage of Julia's approach here is clear: Less boilerplate, and by default the ability to handle other encodings.
The disadvantage? Well, perhaps it's not so great as you think:

### You probably don't actually care whether your string is UTF8
> No wait, that doesn't make any sense.
> If you don't verify your string is UTF8, your 'string' could be arbitrary bytes which you can't make sense of.
> How do you meaningfully process data if you don't know its structure?

Here's the thing: I'll grant that you need to know your input bytes are structured, but the structure you care about isn't UTF8.

Let's consider two kinds of program that handles strings:

Some programs are input structure agnostic, such as `cat`, `hexdump`, and `ripgrep`.
They're agnostic because they don't really process strings, but the content of arbitrary files, no matter their format.
Really, they just process byte streams, so here, UTF8 validation is clearly counterproductive.

Speaking of which - if you want to be able to write these kinds of programs, then you probably also want other string types that is not necessarily UTF8.
Rust handles this by also having the extra types `OsString` and `OsStr`, as well as `CString` and `CStr`.
In fact, ripgrep is based on the `bstr` type in Rust - which, just like Julia's strings are non-validated UTF8-by-convention.
The author of ripgrep has written [a blog post about the motivation for `bstr`](https://blog.burntsushi.net/bstr/#motivation-based-on-concepts) which is worth reading and re-iterates some of the same arguments I've put forth here.
Having to use all these strings types are wonderfully rigorous, but also a meme-worthy level of pedanticness, and not exactly a nice user experience for the programmer.

But what about programs which _do_ care about the structure of their input?
An example could be a program which reads a JSON file, or a CSV file, or a tabular output file.
However, in every single case I can think of, programs which read structured data have stricter requirements of their input than being merely UTF8, so UTF8 validation doesn't buy you anything.

For example, JSON is a subset of UTF8, so when parsing JSON, you can't just check for the input being UTF8 - you would need to match the input against a much smaller set of accepted bytes which constitute valid JSON, probably using a state machine or such.
This is also the case when dealing with CSV files, TOML files, TSV files, and every other format in existence.

Practially speaking, every time you read an input file, you either only care about it as a stream of bytes, or else you need to parse it into a format which is more strict than UTF8.
What kind of program could possibly take input data and requires it to be UTF8, but have no more restrictions on its input?
There is one type of program I can think of: Functions whose output is obliged to return UTF8, because its consumer tells you it requires UTF8.
An example would be a JSON parser, where strings in JSON format must be UTF8, but can be arbitrary UTF8.
However, this is UTF8 for the sake of it being UTF8 - they need to be UTF8 because JSON demands they are UTF8, not because of any real-life constrains on the data.

Let me demonstrate what I mean: If you know that a string is UTF8 but _not_ anything else about its format, what useful knowledge have you gained about the string?

* Do you know how to render it? Probably no. UTF8 is so large and sprawling that very few programs can faithfully render all of UTF8.
    - Is this one emoji or several on your system? 👩🏼‍❤️‍💋‍👨🏻
    - Is this char correctly monospaced on your system? `﷽`
    - Does mouse highlighting work correctly for this string in your browser? पन्ह पन्ह त्र र्च कृकृ ड्ड न्हृे إلا بسم الله 

* Do you know at least know how to compute its printed length? No. The length of an UTF8 cannot be determined because it depends on the font, the terminal that renders it, the emoji recognized, and much more.

* Okay, but then do you know how many characters the string is composed of? Also no - it's implementation dependent which groups of codepoints is recognized as extended grapheme clusters (individual characters). Also the definition of a single character is kind of fuzzy around the edges in some languages.
* Okay, but at least you can correctly do some simple transforms of the string? I.e. you can split it by spaces, right? Well, not really - at least it's complicated. The string "ac" contains a zero-width space between the two letters. This is not classified as whitespace by convention, but it's expected that the string must be broken at space when wrapping. In contrast, "a c" contains a non-breaking space - a space where the line must not break. What about "a c"? This contains a paragraph separator and is not split according to Julia's `split`, even though it's a whitespace character. And so on and so forth.
* Let's make it simpler. What about `.to_lowercase()`? Surely, _that_ must work correctly on UTF8? Well, no - a string being UTF8 is not enough to correctly lowercase a string. Is the lowercase of Σ σ or ς? Well, it depends. Does Σ appear as part of a formula, or as Greek prose? And, if it's Greek prose, does the letter occur at the end of a word? What about the lowercase of SS - is it ss or ß? Well, it depends on the structure of the input - is it German or Norwegian?

In fact, I'm struggling with coming up with a single thing that you can correctly and consistently do with UTF8 text that you can't do with a bunch of opaque bytes - not including self-justifying reasons like "you can count the number of UTF8 codepoints in a UTF8 string".

#### Preempting some arguments
> What about a tool like `cut`? In order to cut a line by, say, `\t`, you need to know how `\t` is encoded, but you don't need to know anything else. So, for a tool like `cut`, you need to know exactly that the encoding is UTF8.

Yes, well, or latin1 - the most common encoding scheme after UTF8. Forcing UTF8 would incorrectly reject latin1 files.

Anyway, a more important reason is: Why is `cut` used - i.e. why do you need the second tabular column? Let's say you use it to parse a two-column TSV file using a Unix pipe, like `tail file.tsv -n +2 | cut -f 2 | awk '{s += $1} END {print s}'`.

Well, in that case, if the program needs to validate that it operates on well-formatted data, then _it needs to validate that the file is actually a two-column TSV file_ as is being assumed by the pipline. It's completely insufficient to just validate the input is UTF8.

> If you have a string and don't know it's valid UTF8, simple operations like lowercasing, iterating, and checking the number of codepoints give meaningless, undefined results. This violates the principle that programs should not produce faulty results silently.

That's not right - all of these operations can be perfectly well defined on malformed UTF8 strings.
We can simply decide to not lowercase ill-formed codeunit sequences and not include them when counting codepoints[^3].

Now you could say that that's not _semantically meaningful_ - simply skipping ill-formed sequences may be _correct_ according so some arbitrary ruleset, but if I write a program which tries to uppercase `\xff\xff\x00\xa1`, then nothing _meaningful_ will come out of it - something clearly went wrong.
You'd be right! But it's no less meaningless than trying to uppercase `ҧăɗޒҒ|˫Ǎߑ`, which is perfectly valid UTF8 - again, knowing something is UTF8 does not give it semantic meaning.

### Arguments for enforced UTF8
I can come up with two good reasons for enforcing valid UTF8:
First, Rust's way of returning `Option` or `Result` forces the programmer to at least consider non-UTF8ness. So, enforced UTF8 is beneficial when the programmer:
1. _Wants_ to correctly handle non-UTF8 data, and simultaneously
2. _Would otherwise forget_ that non-UTF8 data exists.
I find that combination rather unlikely though I'm sure it's the case for someone.

The second reason is that the user might call into a library that _actually_ happens to require that a string is valid UTF8, and only UTF8.
I'm not sure what kind of library which reasonably wants that, but perhaps a text rendering library?

## Rust's and Julia's string APIs
I'd be remiss not to compare this aspect of strings, even though it's not really part of the design of the string type itself: The APIs of the functions used to manipulate strings.

Julia's string APIs is pretty good - but as usual, Rust's APIs are _excellent_:

* Rust's APIs consistently take and return `&(mut) str` where possible. This is ergonomic due to the same reason Rust can expose the codeunits of strings as a byte slice: `String` implements `Deref<Target = &str>`.
  This means Rust's string functions are zero-allocation where possible, and work with strings as well as substrings.
  In contrast, Julia's functions _mostly_ return `SubString` where possible, but often doesn't have implementations optimised for taking `SubString`, and too often allocate needlessly.

* Rust have specialized ASCII versions of several functions, e.g. `make_ascii_lowercase`, `split_ascii_whitespace` and `trim_ascii`. Often, users really only work with ASCII, and in those cases, specializing the functions can make them significantly faster.

* The functions `split_once` and `lines` are often useful. Unfortunately, Julia doesn't have non-allocating versions of these.

* The API for mutating strings in Rust is significantly better than in Julia. In Julia, the standard way is to allocate a `Vector{UInt8}`, mutate it, then copy it to a string when it's done. One issue with this is that this requires your string manipulation to happen on the byte level - you can't easily append a character to the vector, for example. Another issue is that it forces multiple allocations since the bytes needs to be copied.

Julia does seem to be slowly catching up to Rust over time. For example, I used to gripe that Julia didn't have [a non-allocating splitter](https://github.com/JuliaLang/julia/pull/39245), [in-place line reading](https://github.com/JuliaLang/julia/pull/48273), [a reverse splitter](https://github.com/JuliaLang/julia/pull/51646), [non-allocating string search methods](https://github.com/JuliaLang/julia/pull/52424), but these have been added the last few years.

## Conclusion
Strings are carefully designed in both Rust and Julia, and while strings are implemented as 'just' a byte array in both languages, there are some small but significant differences in their designs.
Some of the differences stem from overarching language differences - more precisely Rust's borrowchecker, and Julia's abstract types.

Overall, Julia's strings are a more opaque data type that behaves in a special, priviledged manner, compared to strings in Rust. This is somewhat inevitable as Julia is not self-hosted, so the compiler has to be non-Julian at some low level.

A major design difference is that Rust strings are enforced to be valid UTF8, whereas Julia's aren't.
I believe Julia made the better choice here overall, although Rust's extra validation fits well into the language's core values.
Other than this issue, Rust's strings are manipulated through methods with a stellar API, which Julia could learn a lesson or two from.

[^1]: Unlike Rust, Julia doesn't have a conceptual firewall between safe and unsafe code and it's indeed [possible to mutate a string without unsafe code](https://github.com/JuliaLang/julia/issues/54424#issuecomment-2104822357), but this is probably a bug.

[^2]: These are subject to change, as it's Julia's internals. Also, this precise pattern so far only exist in beta releases of Julia, not able stable versions. There is not currently any public API that allows allocation of uninitialized strings.
[^3]: See the Unicode standard version 15.0, chapter 3, section C10 and D89.
