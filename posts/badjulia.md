# What's bad about Julia?
_Written 2021-07-25, updated {{fd_mtime_raw}}_

Julia is my favorite programming language. More than that actually, perhaps I'm a bit of a fanboy. Sometimes, though, the ceaseless celebration of Julia by fans like me can be a bit too much. It papers over legitimate problems in the language, hindering progress. And from an outsider perspective, it's not only insufferable (I would guess), but also obfuscates the true pros and cons of the language. Learning why you may _not_ want to choose to use a tool is just as important as learning why you may.

This post is about all the major disadvantages of Julia. Some it will just be rants about things I particularly don't like - hopefuly they will be informative, too. A post like this is necessarily subjective: Some people believe Julia's lack of a Java-esque OOP is a design mistake. I don't, so the post won't go into that.

## Table of contents
\tableofcontents

## Compile time latency
The very first thing you learn about Julia is that it's unresponsive. You open the REPL, type in something trivial like `julia> sin(0.96^5)`, and see a _noticable_ lag before the answer appears. As far as first impressions go, that isn't exactly great, especially for a language touted for its speed.

What's happening is that Julia is compiling `sin` - and also much of the code related to the REPL itself - first time you use it. This causes the lag we call _compile time latency_. Hence, the effect is even larger if we pull in new code from external packages: A small script that uses the packages `BioSequences` and `FASTX` may have a 2 second latency, even if the computation itself takes microseconds.

And it can get worse, still. Among Julians, latency is often referred to as TTFP: _Time To First Plot_. Graphical plotting became the posterboy for this problem because plotting involves a large amount of code that does relatively little work. Importing `Plots` and plotting the simplest line plot takes 8 seconds. However, being the posterboy for latency, Plots have gotten a lot of attention and engineering effort to reduce its latency, so it's hardly the worst package. Packages like `Turing` or `ApproxFun` may add half a minute to latency - `Turing` took 40 seconds to start up on my laptop.

So: How bad is this, really?

Well, it depends on what you use Julia for. Remember, the latency is a one-time cost every time you start a Julia process. If you're a data scientist who works for hours on end in a Jupyter notebook, ten or even 40 seconds of startup time is merely a small annoyance. I'm in that category, broadly. When I start Julia, it rarely takes less than a few minutes before I shut down. But some tasks and use cases rely on running lots of short Julia processes. These simply become impossible. For example, the latency makes Julia a complete non-starter for:

* Simple Unix commandline tools such as `cd`, `ripgrep` or `ls`
* Settings where responsiveness is key, say software in a self-driving car or airplane
* Small composable scripts, e.g. as used in [Snakemake](https://snakemake.readthedocs.io/en/stable/) workflows

The latency also forces specific workflows for Julia users and developers. When using Python or Rust, you may be used to running some tests from command line, modifying a source file in the editor, then re-running the tests until they work. This workflow is not feasible in Julia - instead, you are essentially forced to into _REPL driven development_, where you have a single Julia session you keep open while modifying your code and observing the results.

Julias latency _is_ improving, and there _are_ hoops you can jump through to mitigate this problem somewhat. But the problem is fundamentally unsolvable, because it's built into Julia on a basic design level. So, before learning Julia, ask yourself if this is a dealbreaker for you.

## Large memory consumption
This one's pretty easy to demonstrate:

```
$ /usr/bin/time -f "%M" julia hello_world.jl
Hello, world!
231316
```

Yep, 231 MB memory consumption for a hello-world script. Julia's runtime is _enormous_ - these megabytes are not just used by Julias compiler, it apparently pre-allocates BLAS buffers, just in case the user wants to multiply matrices in their hello-world script, you know. Forget the latency, a background consumption of 231 MB completely excludes usign Julia for anything but application-level programs running on a PC or a compute cluster. For anything else, be it mobile, embedded, daemon processes, etc, you'll need to use something else.

## Julia can't easily integrate into other languages
Another consequence of Julia's massive runtime is that it makes it annoying to call into Julia from other languages. If your Python script needs to rely on Julia, you'll need to pay up front: Both the latency, _and_ the 200-something megabytes.

Compare this to a static language like C, where you can compile a C lib to a binary that other programs simply calls into. Julians are usually very proud of the large amount of code sharing and code reuse in the Julia community, but it's worth noting that this sharing stops abruptly at the language barrier: We might be able to use a Rust library, but no-one would use a Julia library if they could avoid it. So if you want to code up some universally used library, you better go with a static language.

## The subtyping system works poorly
* What IS an abstract type - semantics or interface?
 - if semantics, why? what does it give you? what guarantees? provide little benefit
 - if interface: poorly documented, no enforcement.

* One-shot gun.
* You get the good parts AND the bad ones. With traits, there will be more traits so people can pick and choose.

## The iterator protocol is awful

## Weak static analysis

## Unstable language

## Immature ecosystem

## No concrete inheritance
* Example: BiDict - implement in Python through inheritance in Julia though...
* Mention AbstractArray as the single really good abstract interfact 
that keeps getting mentioned
which quickly become extremely complex (issue #37790)

## Unpolished trait system
* Leads to endless wrapping, which again leads to a reliance on traits,
* No easy fix, even in principle. It's unclear what the best approach is.

## Abstract inheritance is not very useful
(expand on the two above points)
* Abstract inheritance (AI) requires you to know beforehand the abstract interface,
but this is often not possible. You can't post-hoc inherit.
- Example: People disagree on what an AbstractChar / Number / AbstractSet even is.
- These are enforced only with docs, which is notoriously unreliable.
* Assumes interfaces are nested like a tree, but this is often not the case.
- When not a tree, forced to use unions / traits, which are half baked
- Example: Big unions, like SparseArrays._StridedOrTriangularMatrix

## Lack of static analysis
* Having tried Rust, it's harder to defend.
* Should be able to be added in a non-breaking way.
* Even something simple as typos dont get caught
* Coupled with latency, that's pretty annoying
* JET does sort of solve the problem, but as long as ecosystem isn't type stable,
any signal drowns in the noise.

## Unstable language
* High number of bugs - look at GitHub
* Personal experience: Often hit edge cases or compiler quirks

## Unstable performance
* Due to type instabilities not being breaking, they can happen.

## Immature ecosystem
* Lack of niche packages in science (e.g. bioinformatics)

