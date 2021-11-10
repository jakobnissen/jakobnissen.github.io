@def rss = "A mega-rant about all the things I find bad about Julia."
@def rss_pubdate = Dates.Date(2021, 07, 25)

# What's bad about Julia?
_Written 2021-07-25, updated {{fd_mtime_raw}}_

Julia is my favorite programming language. More than that actually, perhaps I'm a bit of a fanboy. Sometimes, though, the ceaseless celebration of Julia by fans like me can be a bit too much. It papers over legitimate problems in the language, hindering progress. And from an outsider perspective, it's not only insufferable (I would guess), but also obfuscates the true pros and cons of the language. [Learning why you may _not_ want to choose to use a tool](https://matklad.github.io/2020/09/20/why-not-rust.html) is just as important as learning why you may.

This post is about all the major disadvantages of Julia. Some of it will just be rants about things I particularly don't like - hopefully they will be informative, too. A post like this is necessarily subjective. For example, some people believe Julia's lack of a Java-esque OOP is a design mistake. I don't, so the post won't go into that.

@@toc-header Table of contents@@
\tableofcontents

## Compile time latency
The very first thing you learn about Julia is that it's unresponsive. You open your favorite IDE, launch a Julia REPL, start typing... and see a _noticable_ lag before any text appears. As far as first impressions go, that isn't exactly great, especially for a language touted for its speed.

What's happening is that Julia is compiling the code needed for its REPL and its integration with your editor. This "runtime" compilation causes the lag we call _compile time latency_. Hence, the effect is even larger if we pull in new code from external packages: A small script that uses the packages `BioSequences` and `FASTX` may have a 2 second latency, even if the computation itself takes microseconds.

And it can get worse, still. Among Julians, latency is often referred to as TTFP: _Time To First Plot_. Graphical plotting became the posterboy for this problem because plotting involves a large amount of code that does relatively little work. Importing `Plots` and plotting the simplest line plot takes 8 seconds. However, being the posterboy for latency, Plots have gotten a lot of attention and engineering effort to reduce its latency, so it's hardly the worst package. Packages like `Turing` or `ApproxFun` may add half a minute to latency - `Turing` took 40 seconds to start up on my laptop. I've heard of organizations whose codebase is in Julia where it takes 5 minutes to start a Julia process and load their packages.

So: How bad is this, really?

Well, it depends on what you use Julia for. Remember, the latency is a one-time cost every time you start a Julia process. If you're a data scientist who works for hours on end in a Jupyter notebook, ten or even 40 seconds of startup time is merely a small annoyance. I'm in that category, broadly. When I start Julia, it rarely takes less than a few minutes before I shut down - and the Julia programs I run from command line takes minutes to complete, too. But some tasks and use cases rely on running lots of short Julia processes. These simply become impossible. For example, the latency makes Julia a complete non-starter for:

* Simple Unix commandline tools such as `ripgrep` or `ls`
* Settings where responsiveness is key, say software in a self-driving car or airplane
* Small composable scripts, e.g. as used in [Snakemake](https://snakemake.readthedocs.io/en/stable/) workflows

The latency also forces specific workflows for Julia users and developers. When using Python or Rust, you may be used to running some tests from command line, modifying a source file in the editor, then re-running the tests from command line until they work. This workflow is not feasible in Julia, because latency would occur every time you invoked Julia from command line. Instead, you are essentially forced to into _REPL driven development_, where you have a single Julia session you keep open alongside your editor, and interact with Julia (e.g. running tests or code analysis) only thorugh that REPL.

Julias latency _is_ improving, and there _are_ hoops you can jump through to mitigate this problem somewhat. But the problem is fundamentally unsolvable, because it's built into Julia on a basic design level. So, before learning Julia, ask yourself if this is a dealbreaker for you.

## Large memory consumption
This one's pretty easy to demonstrate:

@@shellcode
```plaintext
$ /usr/bin/time -f "%M" julia hello_world.jl
Hello, world!
148724
```
@@

Yep, ~150 MB memory consumption for a hello-world script. Julia's runtime is _enormous_ - these megabytes are not just used by Julias compiler, it apparently pre-allocates BLAS buffers, just in case the user wants to multiply matrices in their hello-world script, you know. Forget the latency, a background consumption of 150 MB completely excludes using Julia for anything but application-level programs running on a PC or a compute cluster. For anything else, be it mobile, embedded, daemon processes, etc, you'll need to use something else.

In fact, even for desktop-level applications, consuming 150 MB on the Julia runtime is pushing it. Think of all the hate Electron gets for wasting resources. _Every_ Julia program is in the same ballpark as Electron in this regard. A command-line calculator written in Julia consumes more memory than the 2003 video game _Command & Conquer: Generals_.

## Julia can't easily integrate into other languages
Another consequence of Julia's massive runtime is that it makes it annoying to call into Julia from other languages. If your Python script needs to rely on Julia, you'll need to pay up front: Both the latency, _and_ the 150-ish megabytes.

Compare this to a static language like C, where you can compile a C lib to a binary that other programs simply calls into. Julians are usually very proud of [the large amount of code sharing and code reuse](https://www.youtube.com/watch?v=kc9HwsxE1OY) in the Julia community, but it's worth noting that this sharing stops abruptly at the language barrier: We might be able to use a Rust library in Julia with little friction, but no-one would use a Julia library if they could avoid it. So if you want to code up some universally used library, you better go with a static language.

## Weak static analysis
This is one point where I've changed perspective after having tried coding Rust. Before learning Rust, when I only knew Python and Julia I would have said something like:

> Sure, static analysis is useful. But to ensure program correctness, you need tests anyway, and these tests will catch the vast majority of what would be compile-time errors. The small safety you lose in a dynamic language is more than made up by the time saved, which you can use to write better tests.

How silly, past me, if only you knew! See, I taught myself Rust by doing the [Advent of Code 2020](https://github.com/jakobnissen/advent2020) in Rust. Being a neophyte, I was so bad at Rust that I had more than one compiler error per line of code on average. _Everything_ was hard. And yet, for about two-thirds of the challenges, the _first_ time the program compiled, it gave the correct answer.

That was astounding to me. Working with Python or Julia, I expected the program to crash. Programs always crash at first, right? Well, they do in Julia until you've found the bugs by hitting them, and fixed them one by one. In fact, for me it was part of the development workflow, iteratively write the solution, run it, watch where it crashes, fix it, repeat. The idea that you could just write the right program on the first try was wild. The experience was _not_ that my program became more safe in the sense that I could ship it without sweat on my brow. No, it was that it _just worked_, and I could completely skip the entire debugging process that is core to the development experience of Julia, because I had gotten all the errors at compile time.

And this was for small scripts. I can only imagine the productivity boosts that static analysis gives you for larger projects when you can safely refactor, because you know immediately if you do something wrong.

Back to Julia: It lies somewhere in between Python and Rust in terms of static analysis and safety. You _can_ add type annotations to your functions, but the errors still only appear at runtime, and it's generally considered un-idiomatic to use too many type annotations, [with good reason](#the_type_system_works_poorly). [Linting](https://github.com/julia-vscode/StaticLint.jl) and [static analysis](https://github.com/aviatesk/JET.jl) for Julia are slowly appearing and improving, but compared to Rust they catch just a small fraction of errors. When writing generic package code where types are mostly indeterminate until runtime, they can't do much type analysis.

Another issue with static analysis in Julia is that, because writing un-inferrable code is a completely valid (if inefficient) coding style, there is a lot of code that simply can't be statically analysed. Similarly, you can have a Julia package whose dynamic style causes tonnes of "issues" according to the static analyzer, which nonetheless work fine. If your package depends on such a package, your static analysis will be flooded with false positives originating from the third-party code.

I'm a big fan of these tools, but honestly, in their current state, you can rely on the linter to catch typos or wrong type signatures, and on the static analyzer to analyze specific function calls you ask it to... but that's about it.

Is it unfair to criticise a _dynamic_ language for not having _static_ analysis? Isn't that implicit? Perhaps. But this post is about the weaknesses of Julia, and no matter how you justify it, poor static analysis is most definitely a weakness.

## The core language is unstable
Julia released 1.0 in 2018, and has been committed to no breakage since then. So how can I say the language is unstable?

Instability isn't just about breaking changes. It's also about bugs and incorrect documentation. And here, Julia is pretty bad. Having used Julia since just before 1.0, I run into bugs in the core language regularly. Not often, but perhaps once every couple of months. I can't recall ever having run into a bug in Python.

If you doubt it, take a look at the [open issues marked as bugs](https://github.com/JuliaLang/julia/issues?q=is%3Aissue+is%3Aopen+label%3Abug). Some of these are transient bugs on master, but there are _many_, _many_ old bugs you can still go in and trigger from the REPL on the stable Julia release. Here's one [I reported about a year ago](https://github.com/JuliaLang/julia/issues/36605), and which still hasn't been fixed:

@@juliacode
```julia
julia> open(read, "/home/jakob/Documents") # yes, a directory
UInt8[]
```
@@

Perhaps you think that reading directories as files is not really a bug, even in a high-level language. In that case, you can try collecting stateful generators:

@@juliacode
```julia
julia> collect((i for i in Iterators.Stateful(1:3)))
2-element Vector{Int64}:
 1
 2
```
@@

Where Julia will silently give the objectively wrong answer. That one has been known for more than one-and-a-half years, and an issue been filed (and looked at) more than a year ago.

The instability goes beyond the core language itself. Most of the times I have made PR to the Julia GitHub repository the past year or so, CI has failed for spurious reasons. In fact, when scrolling through the list of recently merged PRs, every single one of them failed CI and was merged anyway, presumably due to unstable CI.
I know the Julia devops people are working hard on this, but it is worrying that Julia doesn't pass its own tests.

A similar story can be told about Julia's package servers. Most experienced Julians know to set `JULIA_PKG_SERVER=""` if the package server gets slow. This was not documented until recently - the reason we know how to set it is because the package server so often causes trouble. For example, the Eastern US package server have had "major outage" for about 70 of the last 90 days. It's still up and running, it just serves Julia users out-of-date packages.

I don't think it's because the Julia devs are careless. It's just a matter of bugs continuously being discovered because Julia is relatively young software, and because it's a big language with lots of surface for bugs. Perhaps it also comes from a culture where features come first, and tests for correctness come second. As Julia matures and stabilizes post 1.0, the number of bugs have gone down and will continue to do so in the future. But until it does, don't expect mature, stable software when using Julia.

There is, however, also the issue of unstable performance, where Julia is a uniquely awkward situation. Other dynamic languages are slow, and people using them write code expecting them to be slow. Static languages are fast, because the compiler has full type information during the compilation process. If the compiler can't infer the type of something, the program won't compile. Importantly, because an inference failure in static languages causes the compilation to fail, _the compiler's inference is part of the API, and must remain stable_. Not so in Julia.

In Julia, what the compiler knows about your code and the optimizations it does is a pure implementation detail - at long as it produces the correct result. Even in situations where _nothing_ can be inferred about the types Julia will run and produce the correct result, just hundreds of times slower. That means that a compiler change that causes a failure of inference and a 100x performance regression is not a breaking change. So, these happens.

I mean, don't get me wrong, they don't happen _often_, and they usually only affect part of your program, so the regression is rarely that dramatic. The Julia team really tries to avoid regressions like that, and they're usually picked up and fixed on the master branch of Julia before they make it to any release. Still, if you've maintained a few Julia packages, I bet it has happened to you more than once.

## The ecosystem is immature
A more important consequence of Julia being a young, immature language is that the package ecosystem is similarly immature. Compared to the core language, which have a huge number of users, and more developers, the ecosystem settles more slowly. This has several consequences for Julia:

First, compared to established languages, lots of packages are missing. Especially if you work in a niche subject, as most scientists do, you are much more likely to find a Python or R package to fit your needs than a Julia package. This situation will obviously improve over time, but right now, Julia is still quite far behind.

You're also much more likely to find outdated or unmaintained packages in Julia. This is not because Julia packages tend to fall into disrepair more quickly than other languages, I think, but rather because packages which has already existed for 20 years are more likely to last another five more years than packages that have existed for two years. It's only been three years since Julia 1.0 came out, so if you find a blog post from 2015, any posted Julia code is unlikely to work, and the packages have probably released several breaking changes since then. In comparison, the Python package Numpy has been around five times longer than Julia 1.0!

In software ecosystems, it also takes a while for effort to consolidate to well-known packages. In Python, everybody knows, for example, to use `pandas` when working with dataframes. It has become the de-facto standard. And if it is to be dethroned, any contender must compare favorably against `pandas`, which means it must itself be a solid, well-used package. In Julia, it's not too rare to want a functionality and find three packages that do it in slightly different ways, all of them immature and light on features.

Perhaps most critically, the developer tooling surrounding Julia is also immature, with lots of basic functionality missing. This is also a consequence of the ecosystem simply not being mature enough, with too little development effort behind it (notably, no large companies have made large contributions to Julia, unlike every other language I know of). Here are a few examples, haphazardly chosen:

* Julia's built-in `Test` package is barebones, and does not offer setup and teardown of tests, nor the functionality to only run a subset of the full test suite. This is by design, but there does not exist a common go-to testing package that offers what the stdlib package lacks.
* The editor experience is not great with Julia. It's getting better, but with the foremost Julia IDE developed by a few people in their spare time, it has all the crashes, slowness and instability you would expect.
* Static analysis is brand new, and feels like it hasn't yet settled into its final form. It also has no IDE integration.
* There is no common framework for benchmarking and profiling Julia code. In a single session, you may analyze the same function with `BenchmarkTools`, `@allocated`, `Profile`, `JET`, `JETTest`, `@code_native` and `Cthulhu`, which each has to be loaded and launched individually. This issue is particularly notable when a new user faces performance issues and ask a Julia forum "what should I do", and get 10 _different_ answers, each concerning one specific sub-analysis that may cast light on one particular cause of performance problems. This is a huge time sink, and not a great user experience. It should be possible to gather several of these tools in a single analysis package, but it has not yet been done.

## The type system works poorly
This is the most controversial of my problems with Julia. People who don't know Julia have no idea what I mean when I say the subtyping system is bad, and people who _do_ know Julia are unlikely to agree with me. I'll give a brief recap of how the system works for anyone not familiar:

In Julia, types can be either _abstract_ or _concrete_. Abstract types are considered "incomplete". They can have subtypes, but they cannot hold any data fields or be instantiated - they are incomplete, after all. Concrete types can be instantiated and may have data, but cannot be subtyped since they are final. Here is an imaginary example:

@@juliacode
```julia
# Abstract type subtyping BioSequence (itself abstract)
abstract type NucleotideSequence <: BioSequence end

# Concrete types with fields subtyping NucleotideSequence
# cannot be subtyped!
struct DNASequence <: NucleotideSequence
    x::Vector{DNA}
end
```
@@

You can define methods for abstract types, which are inherited by all its subtypes (that is, _behaviour_ can be inherited, but not _data_). But if a concrete type define the same method, that will overwrite the abstract one:

@@juliacode
```julia
# Generic function, is slow
function print(io::IO, seq::NucleotideSequence)
    for i in seq
        print(io, i)
    end
end

# Specialized function, overwrites generic
function print(io::IO, seq::DNASequence)
    write(io, seq.x) # optimized write implementation
end
```
@@

So you can create type hierarchies, implement generic fallback methods, and overwrite them whenever you want. Neat! What's not to like? Well...

### You can't extend existing types with data
Say you implement some useful `MyType`. Another package thinks it's really neat and wants to extend the type. Too bad, that's just not possible - `MyType` is final and can't be extended. If the original author didn't add an abstract supertype for `MyType` you're out of luck. And in all probability, the author didn't. After all, good coders usually follow the [YAGNI](https://en.wikipedia.org/wiki/You_aren%27t_gonna_need_it) principle: Don't pre-emptively implement what you don't need.

In e.g. Python, you are not going to run into types you want to subclass, but can't. You can subclass whatever you damn well please. In Rust, the problem is not even recognizable: Any type you write can freely derive traits and is not at all constrained by where it is placed in the type hierarchy, because there _is_ no type hierarchy.

### Abstract interfaces are unenforced and undiscoverable
Suppose, on the other hand, you find out the author _did_ actually add `AbstractMyType`. Then you can subtype it:

@@juliacode
```julia
struct YourType <: AbstractMyType
    [ stuff ]
end
```
@@

... and now what? What do you need to implement? What does the abstract type require? What does it guarantee? Julia offers absolutely no way of finding out what the abstract interface is, or how you conform to it. In fact, even in Base Julia, fundamental types like `AbstractSet`, `AbstractChannel`, `Number` and `AbstractFloat` are just not documented. What actually _is_ a `Number`, in Julia? I mean, we know what a number is conceptually, but what are you opting in to when you subtype `Number`? What do you promise? Who knows? Do even the core developers know? I doubt it.

A few abstract types in Julia _are_ well documented, most notably `AbstractArray` and its abstract subtypes, and it's probably no coindidence that Julia's array ecosystem is so good. But this is a singular good example, not the general pattern. Ironically, this exception is often held up as an example of why the Julia type system _works well_.

Here is a fun challenge for anyone who thinks "it can't be that bad": Try to implement a `TwoWayDict`, an `AbstractDict` where if `d[a] = b`, then `d[b] = a`. In Python, which has inheritance, this is trivial. You simply subclass `dict`, overwrite a handful of its methods, and everything else works.
In Julia, you have to define its data layout first - of course, you can solve this by simply creating a type that simply wraps a `Dict`, but the real pain of the implementation come when you must somehow figure out everything `AbstractDict` promises (good luck!) and implement that.

### Subtyping is an all-or-nothing thing
Another problem with relying on subtyping for behaviour is that each type can only have one supertype, and it inherits _all_ of its methods. Often, that turns out to not be what you want: New types often has properties of several interfaces: Perhaps they are set-like, iterable, callable, printable, etc. But no, says Julia, pick _one_ thing. To be fair, "iterable", "callable" and "printable" are so generic and broadly useful they are not implemented using subtyping in Julia - but doesn't that say something?

In Rust, these properties are implemented through traits instead. Because each trait is defined independently, each type faces a smorgasbord of possibilities. It can choose _exactly_ what it can support, and nothing more. It also leads to more code reuse, as you can e.g. simply derive `Copy` and get it without having to implement it. It also means there is an incentive to create "smaller" traits. In Julia, if you subtype `AbstractFoo`, you opt in to a potentially huge number of methods. In contrast, it's no problem to create very specific traits that concerns only a few - or one - method.

Julia _does_ have traits, but they're half-baked, not supported on a language level, and haphazardly used. They are usually implemented through multiple dispatch, which is also annoying since it can make it difficult to understand what is actually being called. Julia's broadcasting mechanism, for example, is controlled primarily through traits, and just finding the method ultimately being called is a pain.

Also, since so much of Julia's behaviour is controlled through the type of variables instead of traits, people are tempted to use wrapper types if they want type `A` to be able to behave like type `B`. But those are [a terrible idea](https://github.com/JuliaLang/julia/issues/37790), since it only moves the problem and in fact makes it worse: You now have a new wrapper type you need to implement everything for, and even if you do, the wrapper type is now of type `B`, and doesn't have access to the methods of `A`!

A good example of the subtyping system not working is Julia's standard library `LinearAlgebra`. This package uses both wrapper types and traits to try to overcome the limitations of the type system, and suffers from both the workarounds. But an even clearer example of the failure of the type system is its use of _big unions_, that is, functions whose type signature has arguments of the type "A or B or C or D or E or ...". These typically appear in code when you need to add a method to an object, and then discover that the sets of types you need to implement it for doesn't fit into the type hierarchy as a single supertype. And why would it? Why is it simply assumed that behaviour is strictly [monophyletic?](https://en.wikipedia.org/wiki/Monophyly) Besides being unwieldly, unions are also un-extendable. And even in Base Julia, those unions can get out of control: If you have Julia at hand, try to type in `LinearAlgebra.StridedVecOrMat` and watch the horror. The use of such an abomination is a symptom of an unsolved underlying problem with the type system.

The consensus on idiomatic Julia seem to be slowly drifting away from leaning on its type system to specify constraints, and towards ducktyping and traits. I essentially see this as the community implicitly beginning to acknowledge the problems of the type system and trying to avoid it where possible. All the individual gripes in the post about the system are well known, even if few people would grant the system as whole is poor. It has, however, been remarkably hard to provide good alternatives or solve the individual pain points. As Julia is maturing, there is less and less space to re-invent or enhance something as core as the type system.

I expect that in the future, Julians will move even further towards Python-esque ducktyping. I predict that while there will arise packages that try to address some of these issues, they will be in disagreement about what to do, they will be niche, without good core language support, and therefore not really solve the problem.

## The iterator protocol is weird and too hard to use
### The protocol
By "the iterator protocol", I mean: How does a for loop work? The three languages I'm familiar with, Python, Rust and Julia, all handle this slightly different. In Julia, the following code:

@@juliacode
```julia
for i in x
    # stuff
end
```
@@

lowers into something equivalent to:

@@juliacode
```julia
itval = iterate(x)
while itval !== nothing
    i, state = itval
    # stuff
    itval = iterate(x, state)
end
```
@@

This means that, to implement an iterator, you need to implement `iterate(x)` and `iterate(x, state)`. It should return `nothing` when the iteration is done, and `(i, next_state)` when it still has elements. By the way, you _also_ need to implement a few traits, which Julia does not warn you about if you forget, or implement them wrongly. But [I gripe about that elsewhere](#abstract_interfaces_are_unenforced_and_undiscoverable).

So: Why is it like that? Well, [I'm not the only one to wonder](https://mikeinnes.github.io/2020/06/04/iterate.html). At least one of the reasons it was designed like that is that it makes the `iterate` function and the iterator itself _stateless_, since the state is stored in the local variable passed as an argument to the `iterate` function. It means you can't have bugs like this Python bug:

@@pythoncode
```python
>>> iter = (i+1 for i in range(3))
>>> length = sum(1 for i in iter)
>>> list(iter) # oops!
[]
```
@@

### The problem
First, you _absolutely_ can have the same bug as in Python, because _some_ iterators _are_ stateful! For example, if you read a file:

@@juliacode
```julia
julia> lines = eachline("my_file.txt");

julia> n_lines = count(x -> true, lines);

julia> collect(lines)
String[]
```
@@

And since there is no way of knowing programatically (and certainly not statically) if an iterator is stateful, you better adopt a coding style that assumes all iterators are stateful, anyway.

To be clear, the _problem_ isn't that Julia has stateless iterators. Stateless iterators have advantages, they may in fact be superior and preferable where possible. The real problem is that _iteration is never stateless_ - in a loop, there _must_ always be state. When using stateless iterators, the problem of keeping track of the state is not solved, but simply moved elsewhere. Julia's iterators are "stateless" in the worst possible sense of the word: That the compiler and the language doesn't know about state, and therefore offloads the job of keeping track of it to the programmer. Reasoning about state across time is a famously hard problem in programming, and with Julia's iterators, you get to feel 100% of that pain.

Making the compiler's job easier by offloading work to the programmer is not how high-level languages are supposed to work! The solution, at least not being a Julia developer, seems obvious. Iteration should instead lower to

@@juliacode
```julia
itr = iterator(x)
while (i = next(itr)) !== nothing
    # stuff
end
```
@@

This is how Rust and Python works, approximately. Notice the code is simpler than what Julia acutally lowers to. The big advantage, however, is that the state is stored in the `itr` object, and doesn't need to be manually handled or passed around by the person implementing the iterations. Interestingly, it already solves the problem of stateful iterators that Julia's solution is meant to address, since the iterator is reset on the call to `iterator`.

What are the problems with passing around state with the current approach? Suppose you create an iterator that you need to process in two stages: First, you do some initialization with the first elements of the iterator. Perhaps it's an iterator of lines and you need to skip the header. After that, you iterate over the remaining arguments. You implement this as the functions `parse_header` and `parse_rest` In Julia, _you need to explicitly pass state_ between the functions as an argument - not to mention all the boilerplate code it introduces because `parse_rest` now can't use a for loop to iterate, since that would "restart" the iterator. Well, _maybe_ it would, who knows if it's stateless!

If you're a Julian reading this with scepticism, try implementing an interleaving iterator: It should take any number of iterators `x1, x2, ... xn` and produce a stream of their interleaved values: `x1_1, x2_x1, ... nx_1, x1_2 ... xn_m`. Easy peasy in Python, a headache in Julia because you have to juggle N states manually in the function. Or try re-implementing `zip` or a roundrobin iterator.

## Functional programming primitives are not well designed
I didn't really notice this until I tried Rust, and Julia's `Transducers` package, both of whom implements the foundations of functional programming (by this I mean map, filter etc.) way better than Julia itself does. This issue is not _one single_ design problem, but rather a series of smaller issues about how Julia's iterators are just... generally not that well designed.

`map`, `filter` and `split` are eager, returning `Array`. There is _literally_ no reason for this - it only makes the code slower and less generic. I can't think of a single upside - perhaps other than that it saves you typing `collect` once in a while. Newer versions of Julia introduced `Iterators.map` and `Iterators.filter` which _are_ lazy, but using them means breaking backwards compatibility, and also, you have to use the ugly identifier `Iterators`. And for `split`, there is no such escape hatch - you just have to accept it's slow and unnecessarily allocating.

Functional programming functions like `map` and `filter` can't take functions. That is, I cannot call `map(f)` and get a "mapper" function. I usually "solve" this by defining `imap(f) = x -> Iterators.map(f, x)` in the beginning of my files, but honestly, Julia's iterators should work like this by default.

But Jakob, you say, don't you know about Takafumi Arakaki's amazing `JuliaFolds` ecosystem which reimagines Julia's iterator protocol and functional programming and gives you everything you ask for? Yes I do, and it's the best thing since sliced bread, BUT this basic functionality simply _can't_ be a package. It _needs_ to be in Base Julia. For example, if I use Arakaki's packages to create an "iterator", I can't iterate over it with a normal Julia for loop, because Julia's for loops lower to calls to `Base.iterate`. Also, because `JuliaFolds` is not Julia's default iterator implementation, and therefore sees less usage and development than Julia's built-in iterators, the package suffers from some compiler inference issues and obscure errors.

## Misc gripes
### There is no Path type...
When Julia was first being written, the core devs more or less copied Python's path API directly. Of all the languages you could, you could have picked worse than Python - the language usually has a sane, pleasant API. Unfortunately, for path specifically, Julia also inherited Python's sin of using strings to represent filenames and paths. Since Julia is otherwise pretty good about being strongly typed, this design decision is unfortunate.

"What's the problem", you might ask, "aren't paths just strings applied to the filesystem"? No, they _absolutely aren't_. Paths may be printed like a string, and may even use a string as internal storage, but that is incidental: Paths are _conceptually different_ from strings, and need their own type.
`DateTime`s are represented by an `Int`, but are _not_ integers, and `Char`s are not 32-bit integers even if they can be represented by them. The important thing is not what they look like to the CPU, but how the behave to the programmer. 

Conflating the behaviour of strings and paths just because they look similar is an example of weak typing, causes a bunch of problems:

First, linting and static analysis of paths become limited because you can't specify that a particular value is a path, and that you shouldn't try to convert it to titlecase it or reverse it, or something silly like that. That same lack of information extends to the programmer: The behaviour of an argument annotated as `AbstractPath` is immediately obvious, whereas it's not clear that an `AbstractString` actually represents a path.
I've seen real code where the same value encoded as a `String` could refer to _either_ an URL, or a path, depending on its interpretation, leaving it up to the programmer to keep track of what type the value _really_ was at any given time.

Second, and more importantly, it means lots of functionality simply isn't implemented for paths in Julia, because the developers never had the need, as they could just get away with using strings:
How do you verify a path is validly formatted on your system? How can you tell if a path is relative? These questions, and more, are basically unanswered in Julia, because every developer needs to implement solutions for these issues by themselves, in every application.

In contrast, if there were a single `Path` type, its constructor would be validating, and all the weird and annoying edge cases about paths would need to be encoded into the object at the type level, making it much easier for developers. Again, it's hard not to look at Rust for a great example. Rust's paths are complicated to deal with, because _paths are complicated to deal with_. But the complexity is tackled head-on, and most of the hard stuff had already been done through you.

Last, it's pretty remarkable that the functions that operate on Julia's paths all have names like `isabspath`, `isdirpath`, `joinpath`, `mkpath`, `normpath`, `splitpath` etc - all containing the word `path`. Essentially no other Julia functions are named like that: We have no `transposematrix`, `mulnumber`, `reversestring`, `maparray`.
Why don't we? Because, when you start to encode type information into your function names, it should be obvious that you need a new type.

Speaking of which, what do you do when a function has two plausible meanings depending on whether the argument is a string or a path? For example, the method `countlines(::String)` could either count the lines in the string, or it could treat the string as a path and count the lines in the file at that path. Remarkably, and counter-intuitively, it does the latter. I guess the path-implementation was just finished first, and now the former cannot be implemented because the method is already taken.

"But there's a package for paths!", you say. Right, `FilePathsBase`. How many use it, again? Certainly few enough that it's the nonstandard solution. And as of this moment, I consider the package is too rough around the edges for general use, with e.g. type instability everywhere. For basic things like paths, it's essentially not good enough for there to be a package, unless the package is so standard it might as well be in the standard library.

### ..and no Option type
All languages has to deal with the concept of "this function either gives some result, or no result at all". For example, `findfirst` on arrays returns the first index of an array where some predicate is satisfied - or nothing, if there is no such index. Historically, languages has dealt with an absence of a proper result differently: Return codes, special magic values, or by throwing exceptions that are expected to get caught (e.g. Python's `StopIteration`).

At this point in time, I think it is clear that the best solution to this problem is returning a value with the success encoded in the type system, like e.g. Haskell/Clojure's `Maybe`, or Rust's `Option<T>`. These kinds of types are called _sum types_ (or _tagged unions_). Annoyingly, Julia does not have such types.

Well, it _kind of_ does... sort of. Julia has union types, and it's custom for these failable functions to return `Union{T, Nothing}`. The advantages and disadvantages of union types versus sum types is a whole topic on its own, so I'll just touch on two problems with Julia's approach here.

First, sum types _forces_ the user to deal with potential failure, because the result needs to be unwrapped, whereas union types can hide the error state, such that it seemingly works, until it suddenly doesn't. Which happens a lot in Julia - even Base Julia had, until the advent of static type checking, lots of places where these failure states were not handled. My positive experience with sum types after learning Rust led me to create [ErrorTypes.jl](https://github.com/jakobnissen/ErrorTypes.jl), but being a package, it obviously only works for code that chooses to use it.

Second, sometimes, `nothing` is used as a valid return value in Julia, and then this union-type scheme comes crashing down, because `Union{Nothing, Nothing}` is just `Nothing`! In other words, it is impossible to distinguish between a function returning "no result" and "the result `nothing`". The standard solution when `nothing` can be a valid result is to instead return `Union{Some{T}, Nothing}` as the return value. But of course, the person implementing the function often does not know whether `nothing` can be a valid value!

For example, suppose `d` is a `Dict{Any, Int}`, and I check for odd-numbered values by doing `findfirst(isodd, d)`, and it returns `nothing`. It is impossible to tell if the key `nothing` had an odd value, or if there were no odd-valued keys.
