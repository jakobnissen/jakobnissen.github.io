@def rss = "A mega-rant about all the things I find bad about Julia."
@def rss_pubdate = Dates.Date(2022, 12, 7)

# What's great about Julia?
_Written 2022-12-07, updated {{fd_mtime_raw}}_

The first post on this blog was "[What's bad about Julia](https://viralinstruction.com/posts/badjulia/)" - a collection of the worst things about my favourite language, which turned out to be quite the Hacker News bait.
The most commmon responses I got was along the lines of: "If Julia has all these flaws, why not just use another language?".
At the time, I just said that despite its flaws, Julia was still amazing, that it would take another 4,000 word post to elaborate on why, and then I left it at that.

Recently I've been thinking a lot about one of Julia's major drawbacks, and have been drafting up a post that goes in depth about the subject.
But honestly, posting _another_ verbose criticism of Julia would risk giving a misleadingly bad impression of my experience with the lovely language, even if I bracket a wall of criticism with a quick endorsement.
After all, I've chosen to use the language for my daily work about two years ago, and I don't regret that choice in the slightest.

Now is the right time for that 4,000 word post on the _best_ parts of Julia.

@@toc-header Table of contents@@
\tableofcontents

## It's both fast and dynamic
Julia's speed is _the_ first selling point of Julia, and for a reason.
Speed is not the most groundbreaking or novel feature or Julia - that award probably goes to making multiple dispatch the only dispatch paradigm - but it's the aspect that makes using Julia it an un-ignorable option for some use cases.
Simply put, for dynamic languages like Python, R or Perl, there are no good options for performance, only a wide selection of poor choices.
Before moving my work to Julia, I've had the misfortune of being exposed to several of the awkward performance hacks of Python:
* I've shoehorned my program logic to be vectorizable by Numpy, and ran into plenty problems when I reached fundamentally serial code
* I've used Numba and run into its arbitrary limitations to support normal Python code, such as custom classes
* I've used Cython and experienced un-debuggable errors, linker issues on package installation, the inability to distribute my package as source code, and the clunkiness of a separate compilation step in a scripting language.

After having dealt with all those bullshit workarounds, moving my work to Julia was like suddenly breathing in fresh air. I just wrote my code - and optimised it - and then it was as fast as I could want it. And suddenly, all the awkward gymnastics I had been doing simply due to the limitation of Python seemed silly.

That great combination is sometimes phrased as "As easy as Python, as fast as C".
The phrase is a little off, in my opinion - it's not really possible to have a language where you write as carelessly as you do for a casual Python script, and it still runs like optimised C code.
Code can only ever be fast if it's written with [the contraints of computer hardware](https://viralinstruction.com/posts/hardware/) in mind, and idiomatic Python isn't.

A better catchphrase for Julia might be "The best expressiveness / performance tradeoff you have ever seen".
Idiomatic Julia code remains high-level, generic and readable when being optimised - only at the most extreme optimisation, when you have to micro-optimise assembly code or manually unroll loops does the code degrade and begin to appear low-level and clunky.

The gradual and subtle difference between high-level Python-like Julia code and high-performance Julia means that it feels natural to prototype and iterate on inefficient, carelessly thrown together code, and then incrementally optimise only the bottlenecks once performance become an issue.
Often, you'll find only a small fraction of the code actually needs to be optimised for the whole program to run fast. This kind of _gradual performance_ is not something I've seen in the other languages I've coded in. They tend to be _either_ slow but expressive, like Perl and Python, _or_ fast but rigid, like Rust and Zig.

The "dynamic" half of the "fast and dynamic" duo should not be understated, either.
I'm a scientist, which means my job description can be paraphrased as working with stuff I don't understand, trying to make sense of it.
In that context, it's critically important to be able to pivot and iterate on a small script quickly as you test out and explore ideas - preferrably in an interactive manner on a dataset already in memory.

This process is cumbersome and awkward to do with static languages.
Rust, for example, may have a wonderfully expressive type system, but it's also boilerplate heavy, and its borrowchecker makes writing any code that compiles at all quite a time investment.
An investment, which most of the time gives no returns when you're trying to figure how to approach the problem in the first place.
It's also not entirely clear how I would interactively visualise and manipulate a dataset using a static language like Rust.

## The package manager is amazing
These days, the package manager is probably the most central piece of software written for a programming language, other than the compiler itself.
Here, Julia shines: Pkg.jl is an absolute joy to work with. Even after having used Julia for about 5 years, I'm still occasionally surprised by the thoughtfullness and convenience of Pkg.
Coming from Python, which admittedly has a particularly bad package management story, Pkg is an absolute godsend.

Like the Rust manager Cargo, but unlike, say, Python's Conda, Pkg separates the environment specification (the "project") from the resolved environment (the "manifest").
This allows you do distinguish between direct and indirect dependencies, and means that unused indirect dependencies are automatically removed.
For software engineering, only the project is necessary, and the manifest can be considered ephemeral.
If you're a scientist and want to completely reproduce the environment that the code was originally run with, you can simply command Pkg to instantiate an exact environment from the manifest.

Pkg is also delightfully fast. Resolving environments feel instant, as opposed to the glacially slow Conda that Python offers.
The global "general" registry is downloaded as a single gzipped tarball, and read directly from the zipped tarball, making registry updates way faster than updating Cargo's crates.io. Or, if you want, you can easily toggle Pkg to offline mode and skip updating the index alltogether.
The ease and speed of making environments and installing packages into them encourages users to create many separate environments for each little experiment or task, which in turns leads to smaller environments, which reduces the risk of upgrade deadlock.

Beside specifying a version or a range of versions of a package you want to install, Pkg also allows you to install specific git commits or git branches.
You can seamlessly install packages from remote git repositories, from local files, or from various registries.
I say "various" registries, because Pkg is federated, and allows you to easily and freely mix multiple public and private package registries, even if they have no knowledge of each others and contain different packages with the same names.

The ease of making and using custom registries makes it attractive for even small organisations to maintain their own private registry of Julia packages, instead of using large Julia monorepositories.
For example, in my last job, I created my own registry to keep track of the software used in my department.
This way, different packages in the same code base can pick their own versions of internal packages to use. This makes incremental upgrades, or simultanous development of two interdependent packages, much easier.

The package manager also manages arbitrary binary artifacts, such as compiled libraries and executables.
The BinaryBuilder package allows you to cross-compile the same program to all platforms supported by Julia, and automatically create a small Julia library (jll) package which automatically selects and wraps the correct binary depending on platform, allowing it to be executed with a single Julia function.
This means you can create Julia packages which depend on, say, C++ executables, and still have it automatically installed by Pkg. In my experience it has been much, much easier to create binary packages compared to using Conda.

## Optimising Julia code is pure joy
Julia code is not exactly the _fastest_ compiled language, but it's throughly enjoyable to optimise, meaning that at least the Julia code I write tends to be fast.

There is a reason half my posts are about writing optimised Julia code. The joy comes both from the _gradual performance_ characteristic of Julia I explained above, where you optimise only what you need to, and also from the smooth developer experience of optimising Julia code, where the experience of Julia is second to none.

You can do most optimisations interactively, and _without having to shutdown your running session_. This can be a huge time saver if your code operates on a complex dataset in memory, or relies on state that is complicated to recreate. For example, if you are optimising a single function in a deep call stack, because the language is dynamic, it is easy to just call and benchmark it from the REPL without having to run your whole program.

Suppose you have a program which runs slowly - how would you go about it in Julia?

You might start optimisation with profiling: With the VSCode extension installed, simply call `@profview foo(arg)`, and you get a flamegraph of time spent, with heap allocations and type instability highlighted for all functions in a single overview.
In fact, you can get a profile of an _already running_ process with minimal runtime overhead by sending a `SIGUSR1` signal to the process. 

Then, suppose you narrow your performance woes to a certain function `bar`. If it's not immediately obvious why that function runs slow, you might check Julia's type inference using `@code_warntype bar(arg)`,  where any problematic inference is colored red.
Then, if you want to dig deeper, you can examine `bar` in every step of the compilation pipeline:
* `@code_lowered` return Julia's IR of the function's content
* `@code_typed optimize=false` reports Julia's type inference on the IR
* `@code_typed` shows the optimised IR after Julia's own passes such as inlining
* `@code_llvm optimize=false` shows the LLVM IR generated by Julia
* `@code_llvm` shows the optimised LLVM
* `@code_native` shows the native assembly of the function

From here, you can repeatedly modify and run the function, and immediately see the resulting impact on inference and codegen. This makes even micro-optimising Julia code is laughably easy.

Julia is often critisised for its lacklustre developer tooling.
That's true in some areas of development, but certainly not profiling and optimisation.
The many excellent packages useful for optimisation include, beside the ones I've already mentioned, a [memory profiler](https://docs.julialang.org/en/v1/manual/profile/#Memory-allocation-analysis), [inference debugger](https://github.com/JuliaDebug/Cthulhu.jl), [inference issue detector](https://aviatesk.github.io/JET.jl/stable/optanalysis/), [compiler profiler](https://github.com/timholy/SnoopCompile.jl), [benchmarker](https://github.com/JuliaCI/BenchmarkTools.jl), and probably many other tools I've forgotten.

## Multiple dispatch is correct, everything else an approximation
Consider how Python works: `a + b` resolves to `a.__add__(b)`, whereas `b + a` means `b.__add__(a)`.
In other words, the first argument to `+` decides what `+` means - this is what we call single dispatch.

But here's the thing about addition: It's commutative - precisely meaning that there is no order to `a + b` - it's exactly the same as `b + a`.
By what authority does the first - really, just leftmost - argument have to decide the meaning of `+` for all the other arguments?

None, of course. It's an artifact of how Python dispatch works, which has nothing to do with - and indeed, is at odds with how addition is actually defined.

Consider the Python dunder method `__radd__`. Why does this exist? It's a hack, added solely so that you can make an object which defines the meaning of `+` when it's the _second_ argument.
In other words, `__radd__` is a workaround of the limitations of single dispatch. A workaround, which only exists for a handful of hardcoded functions.

Or consider the method `",".join(my_strings)`. Why is this a method of `","`? Surely, we would say that the _array of strings_ is being joined. We would not say that the comma joins the strings.
The (boring) answer is that it's yet another artificial limitation of single dispatch.
Because the `join` method ought to work with all kinds of iterables, there is no single class if iterables it can be tied to, and so the iterable _can't_ be the first element.

It's almost as if it doesn't make sense to define a function based only on one of its arguments.

Why not simply dispatch on every argument?
No need for `__radd__` business, or the forced inversions of arguments to functions like `join`. `+` would simply be defined with - wait for it - _both_ arguments, and `join` could be defined as just another function.

My experience with learning how Julia's dispatch system worked was a weird sense of familiarity:
This is how it was _supposed to work_ all along.
Of _course_ a method should be defined by a function and _its arguments_.

I don't think it's a coincidence that it feels so natural. After all, multiple dispatch (MD) is a natural solution to [the expression problem](https://en.wikipedia.org/wiki/Expression_problem) which so many languages suffer from.
The adoptation of MD has been defining for Julia, in a way that was not clear to the developers when the language was concieved.
For example, it has turned out that MD has [enabled a shocking amount of code reuse in the Julia ecosystem](https://www.youtube.com/watch?v=kc9HwsxE1OY).

Sometimes, multiple dispatch (MD) and single dispatch (SD) will behave the same, because the first argument happens to be sufficient to determine the right method.
And sometimes, when you're aquianted with MD, you'll notice when coding in a SD language you sometimes have to twist your functions to make it fit into the SD mold.
It's never the other way around: Because MD is a natural generalization of SD, you never wish you had SD when you code in an MD language.

## The Julia REPL is amazing
Python has had a REPL for 30 years. So why does it still suck? Python's REPL is the REPL equivalent of [the `ed` editor](https://www.gnu.org/fun/jokes/ed-msg.en.html). You might _technically_ be able to write code in it, but that's about all the good there is to say about it.

Did you accidentally indent by hitting the space button 11 times instead of 12 in the block you just wrote in the REPL? Sorry, Python won't run that because reasons.
Want to rerun the block above? Have fun re-typing it one line at a time.
Want to edit single line above the one you just wrote? Edit your expectations.

Compare to Julia's REPL, which feels like a proper editor:
It has advanced tab-completion, including of system paths and keys of a dictionary. 
It allows navigating and editing entire blocks of code at a time.
You can edit these blocks with several convenient editor-like keybindings.
If you don't like the keybindings, they're customisable, of course.

And in fact, since the REPL is simply a stdlib package with an interface, it's easily extensible.
For example, I use the package `OhMyREPL`, which extends the default REPL to have syntax highlighting and a REPL history browser with fuzzy search.

Julia sometimes get flak for having poor documentation. But let's compare the documentation you get in the Python REPL vs what you get in Julia:
In Python, you have the `help` function:

```
>>> help(set)
class set(object)
 |  set() -> new empty set object
 |  set(iterable) -> new set object
 |
 |  Build an unordered collection of unique elements.
 |
 |  Methods defined here:

 [ list of methods ]
```

Which returns characteristically terse summaries.
Compare to Julia, which has a dedicated `help` mode in the REPL:

```julia
help?> Set
search: Set setenv setdiff setdiff! setfield! setindex! setglobal! setrounding setproperty!

  Set{T} <: AbstractSet{T}


  Sets are mutable containers that provide fast membership testing.

  Sets have efficient implementations of set operations such as in, union and intersect.
  Elements in a Set are unique, as determined by the elements' definition of isequal.
  The order of elements in a Set is an implementation detail and cannot be relied on.

  See also: AbstractSet, BitSet, Dict, push!, empty!, union!, in, isequal

  Examples
  ≡≡≡≡≡≡≡≡≡≡

  julia> s = Set("aaBca")
  Set{Char} with 3 elements:
    'a'
    'c'
    'B'

  julia> push!(s, 'b')
  Set{Char} with 4 elements:
    'a'
    'c'
    'b'
    'B'

  julia> s = Set([NaN, 0.0, 1.0, 2.0]);

  julia> -0.0 in s # isequal(0.0, -0.0) is false
  false

  julia> NaN in s # isequal(NaN, NaN) is true
  true
```

The docstring for `Set` - unlike's Python's - shows:
* Similarly-named types and methods, in case you mistyped your query
* A one-line summary with the type and its supertype
* A more thorough description
* A list of related functions and types
* Examples, which are tested

Unlike Python, it does not show a comprehensive list of methods.
Remember - in Julia, methods are not tied to single classes.

But then again, Julia's REPL is actually helpful, so you can simply query these from the REPL. For example, if you want to get all the methods of `Set` and its supertypes, you can use `methodswith`:
```julia
julia> methodswith(Set, supertypes=true)
[1] <(a::AbstractSet, b::AbstractSet) @ Base abstractset.jl:484
[2] <=(a::AbstractSet, b::AbstractSet) @ Base abstractset.jl:485
[3] ==(a::AbstractSet, b::AbstractSet) @ Base abstractset.jl:481
[4] allequal(c::Union{AbstractDict, AbstractSet}) @ Base set.jl:535
[5] allunique(::Union{AbstractDict, AbstractSet}) @ Base set.jl:475
[ etc ]
```

You can search for objects in Julia and all loaded packages that uses a certain string or regex in their docstring,
simply by typing the string or regex in help mode:
```
help?> r" (Abstract)?Set"
Base.KeyError
Base.union!
Base.setcpuaffinity
Base.Set
Base.Cmd
Base.replace!
```

You can also run shell commands directly from the REPL by switching to shell mode:
```
shell> ls
404.md  about.md  _assets  config.md  _css  index.md  _layout  _libs  Manifest.toml  posts  Project.toml  _rss  __site  todo.md  utils.jl

julia>
```

When I used Python to do my day-to-day work, I used Jupyter Notebooks.
I thought I liked notebooks - [but I don't, really](https://www.youtube.com/watch?v=7jiPeIFXb6U). I simply couldn't be productive in the Python REPL, because is so manifestly awful.
These days, I do all my Julia work in an editor connected to the REPL.

## Strong ecosystem tooling consensus
Nowadays, there are a lot of demands on modern programming languages.
It's not enough to simply provide a working compiler: People want editor plugins with syntax highlighting,
a profiler and benchmarking software, a debugger, a static type checker, a large stdlib,
a documentation system with doctests that can generate a searchable HTML site,
a test framework with CI hooks and code coverage, a feature-rich package manager, and much else. All for free, of course.

The advantage of all these demands is that when a new language materializes, there is already a standard approach to all these things:
In Julia, there is a single default test framework, a default way of running CI, and one go-to documentation system: `Documenter`. As a user, it makes it easy to just use what everyone else uses.
This leads to best practices being more widely adopted.

For example, most Julia packages tends to be well-tested and documented:
* 88% of packages has documentation, 33% of packages has more than 10% of their content be documentation
* 89% of registered Julia packages has at least 10 lines of tests
* 95% of packages has registered CI

Pretty good numbers, considering that this is for _all_ registered Julia packages, including beginner programmers' packages. I'm not sure how these numbers look for e.g. PyPI, but I'd be surprised if they were anywhere close to as good.

The picture does not fit with the Julia's reputation for having poor documentation, so what's up with that?

In my view, Julia has this reputation because it has far fewer huge flagship packages like PyTorch or Numpy, which again is simply because Julia is much younger, less popular, and with less corporate backing.
So, people naturally compare the documentation of PyTorch - a huge flagship package authored by Facebook (reportedly worked on by 300 paid developers at one time!) with 1.5 million lines C and C++ code and 1 million lines of Python code - with Flux.jl, a 10,000 LOC package, maintained by a handful of people, most of whom are not paid to do so.
Obviously, they find Flux's documentation lacklustre in comparison.

## Multithreading is easy
In my experience, multithreading in Julia - unlike _some other dynamic languages_ - is usually as easy as slapping `@threads` in front of a for loop, which will cause each iteration to be scheduled in a separate thread.

```julia
julia> @threads for i in 1:16
           print(i, ',') # IO is thread-safe
       end
1,2,13,14,5,11,7,12,6,9,10,8,15,16,3,4,
```

For programs with a more complicated control flow structure, Julia exposes low-level threading primitives through a convenient and flexible interface.
Julia uses "green threading", which means the language runtime manages multiple virtual threads (in Julia called tasks) on top of the operating system.
Avoiding OS-overhead makes spawning tasks lightweight, so thousands or millions can be spawned with no particular performance implications.
For example, it takes only 2 seconds to spawn and finish 1 million tasks which all atomically modify the same integer:

```julia
julia> @time begin
           atom = Atomic{Int}()
           local task
           for i in 1:1_000_000
               task = @spawn atomic_add!(atom, 1)
           end
           wait(task)
           atom[]
       end
  2.033598 seconds (8.00 M allocations: 503.630 MiB, 33.43% gc time, 0.43% compilation time)
1000000
```

I don't know much about the intricasies of multithreading, so I couldn't tell you if Julia's approach to multithreading is groundbreaking or well designed.
What I _can_ tell you, is that in Julia, it is _so easy_ to use multiple threads effectively, that even though I don't feel that confident writing complex multithreaded code, most my performance sensitive scripts are multithreaded where it's obvious to do so.

## The type system works well
There's a section on my original "What's bad about Julia" blogpost called "The type system works poorly".
It's the one place where I most regret being imprecise. What I gripe about in that post is Julia's system of abstract types and subtyping, and I stand by my condemnation of that.
But there is more to a type system than subtyping, and in so many other ways, Julia's type system is great.

The type system is nice and _expressive_ with its union types, generic types, variadic types and all that other jazz, but having a nice, expressive type system is hardly special for modern languages.
What feels special about the Julia type system is that it manages to be both strict and excellent at dealing with uncertaincy.

Dynamic languages often don't have a real type system. For example, Python's type system only exists in your IDE's type checker, not really at runtime.
If I do a typecast or type assertion in Python, it will be ignored at runtime.
In contrast, in Julia, these type operations are enforced.
This means it's possible to, for example, assert that "this variable really _must_ be this type, even if the compiler can't do type inference here". If you're wrong, it throws an exception. If you're right, compiler will take advantage of the knowledge given by the type assert and produce more efficient code.

Julia also allows you to query the compiler for types at compile time.
Unlike third-party type checkers, the answer is guaranteed to be correct (to the extent the compiler is), and the querying can can leverage all the inference and tricks of the compiler.

So, Julia has a type system quite recognisable by users of modern, static languages. At the same time, unlike most static languages, Julia does not require types to be known at compile time.
When trying out a quick experiment, or iterating on a half-baked idea, it's completely fine to hammer out code where the compiler has no idea what is going on.

This combination of both enforcing types where required, and being comfortable with type uncertainty makes _gradual typing_ natural, such that the user can get the best of both the dynamic and static world:
You can quickly iterate on untyped or poorly inferred code, and then when you settle down on a design, it takes only small changes to lock down the types. Once the compiler can completely infer the program, you can use Julia's own compiler to statically analyse your entire program and find errors.

Analogous to Julia's favourable position w.r.t.  gradual performance, Julia is uniquely suited for a kind of gradual safety, where a program can begin its development as dynamically typed with few guarantees, and be incrementally hardened against type errors and other logical errors as the program matures.
Gradual safety would give Julia a unique and compelling selling point: Just like Julia has already broken the tradeoff between expressiveness and speed, it will hopefully also in the future break the tradeoff between expressiveness and safety, where other languages are forced to choose.

Julia is not yet ready for this gradual safety, because we lack the tooling to exploit the inherent ability of Julia code to be statically checked.
This tooling is a long-term goal of the core developers, and I'm confident the situation will improve the following years, as it already has improved the last few years.

## It just keeps getting better
For better and worse, Julia is not yet an old, established language. The "better" side is that Julia is being actively developed, so there are still many improvements on the horizon which hopefully will make Julia an even nicer language in the next few years.

The improvements mentioned below are not of the hypothetical "sufficiently smart compiler" kind which may never arrive. Even though the developers are also looking at some speculative cutting-edge compiler technologies, I'll not write about them here.
Instead, the improvements below are merely the adoptation of already existing technologies into Julia. Adopdation, which I'm confident will happen eventually.

Julia latency will continue to improve. First, by being able to cache native code between sessions. Later, by enabling multithreading in the compiler, and possibly a tiered JIT that enables code to start quick using an interpreter, and incrementally hot-load optimised code being compiled in a background process. I expect the latency of most large packages will fall by 10x in the next two to three years due to only the improvements already on the way.

It's not currently possible to compile static binaries from inferrible Julia code, but Julia is fundamentally a compiled language, and there is no deep reason you shouldn't be able to compile Julia code to an executable binary instead of into RAM. Indeed, work to enable static compilation to produce large Go-like binaries which include the runtime and garbage collector has already been underway for some time.

## It's weirdly fun
There's something nebulous about the language that makes it really fun to write code in. Maybe it's that it's easy to get started with, and highly expressive such that you quickly get working code between your fingers to play with, similar to Python.

Or maybe it's that, once you do have working code, you don't need to leave it at simply _working_, but you can optimise to your heart contend. I'm not the first to notice how Julia provides an addictive slippery slope to learn high-performance computing.

Honestly, it's not clear to me just _why_ Julia is so fun to use, but I found it expressed well by one of the Julia co-creators Stefan Karpinski:

> I did a lot of Perl programming back in the day, which probably serves more as a "what not to do" example than anything else, in terms of language design, but one thing that's kind of hard to put your finger on that I always loved about Perl is that it's just FUN to use. People have told me that Julia is fun in the same way that Perl is. I think this has something to do with the language letting you do subversive things that might be dangerous or questionable but which work and let you play with the computer in interesting ways.

That sums up the experience of Julia quite well. It's eminently hackable, expressive, and enjoyable, but sometimes too clever for its own good.
