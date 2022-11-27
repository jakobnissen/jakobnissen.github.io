@def rss = "Why Julia has so many bugs and what to do about it"
@def rss_pubdate = Dates.Date(2021, 07, 25)

# Why is Julia so buggy and what can we do about it?
Julia and its ecosystem has a _lot_ of bugs.
Some months ago, long-time Julia user Yuri Vishnevsky wrote a blog post on this, entitled [Why I no longer recommend Julia](https://yuri.is/not-julia/), which made the rounds.
It caused hefty discussion in the Julia community, and four months later, it's still brought up on Hacker News as soon as there is a post about Julia.

Yuri's blog post struck a nerve with me because I have had a similar experience in my ~three years of using Julia daily, and have been having thoughts along the same lines, but the thoughts hadn't materialized until Yuri put words on it.
This blog post is the result of a few of months of mulling it over.

I will not waste any time arguing that Julia is buggy - Yuri already put it so well, so just read his blog post.

Instead, this post will first cover the many interacting reasons _why_ Julia is a buggy language - I believe these experiences are interesting to anyone who cares about programming languages. I will argue that the causes of the problems are threefold:
* The fundamental design of Julia makes correctness hard
* The culture among Julia users puts little emphasis on correctness
* There is a lack of tooling to ensure correct code

The two latter points contain several superficial issues that are quite fixable, so the last part will concern itself with what can be done, both as an individual Julia user, and as a developer of Julia, to make Julia a more solid language going forward.

## The language design makes correctness hard
### Dynamic language
Similar to Python

Clear up: Language, I mean both the language itself, and the ecosystem

### No interfaces, no protocols
    ```julia
    function filter(f::Callable{T, Bool}, x::Iterable{T})::Iterable{T}
        ...
    end
    ```
      is eminently, extremely clear. It makes intension obvious for programmers,
      and also makes much more behaviour checkable

### Language for hackers
* Language emphasizes TIMDOWTDI, hacker-culture and cleverness.
    - Examples? Should they even be here?
    - Find Stefan's point about Perl
    - Many ways to do X

### No clear separation of public and private
* Unclear separation of public and private
    - No pub/priv keywords
    - Language mechanisms:
        - Documentation. But, discourages docs of internals, and it is way too
          easy to accidentally use a nondocumented funciton
        - Export. But, discouraged from `using MyPkg` in code anyway, so how are you
          to know it's exported?
          - Not even clear `using Foo` is bad, know from experience
    - Is accessing fields private? Not even clear
        https://discourse.julialang.org/t/accessing-type-internal-fields-in-package-interfaces/70263
    - Makes to way too easy to accidentally rely on internal behaviour, and makes
      it less clear to authors when they create breaking changes.
    - Preferably some language level syntax to solve this,
    - Alternatively, cultural:
        - TKF: Internal module in package
        - Field access is always private
    - Are the type params of a struct private?

## A culture of hacking, not of correctness
### Made for academics, by academics, not programmers
Patrick Kidger
"Code quality is generally low in Julia packages. (Perhaps because there’s an above-average number of people from academia etc., without any formal training in software development?)
Even in the major well-known well-respected Julia packages, I see obvious cases of unused local variables, dead code branches that can never be reached, etc.

In Python these are things that a linter (or code review!) would catch. And the use of such linters is ubiquitous. (Moreover in something like Rust, the compiler would catch these errors as well.) Meanwhile Julia simply hasn’t reached the same level of professionalism. (I’m not taking shots at anyone in particular here.)
"

"The fundamental problem here is that most Julia packages are written by academics, not professional software developers.

Academic code quality is famously poor, and the Julia ecosystem is no exception"



* Wrong people: Academics, not programmers
	- Not really, there is certainly quite some testing.
	  Maybe I just don't know, I'm an academic, but certainly better than Python in my experience
	- Also not really something we can do something about
	- Also not really something we WANT to do something about
        - The point of Julia is to be good for academics, we can;t have a language
          that only works if used by non-academics

	Actionable: No

### A culture of abstraction and generality
* Seeking generality and abstraction
	- Do we really need ever-growing generalizability?
	- Yeah! We shouldn't "fix" this. It's a major selling point of Julia
    - Somewhat self-serving
    - Not clear Python is that much less duck-typed,
      though not as generic in practice.

### Lax attitude toward correctness
* Lax culture
	- Probably true
	- Examples: Correctness bugs that are identified in Julia, should be straightforward to solve, but just aren't.
    - Example: Low code coverage of Base, which is hard to understand after X years
    - Example: Compare Julia's impressive tooling for performance with tooling for correctness
    - I *think* linting and helper tools is not that popular, because many footguns
      could be prevented by a capable linter, but still appear in the ecosystem,
      and also the linter is not being pushed for as hard as one would hope
* The small things
    * Promotion: What are the rules?
        [[1], [1.0]] vs [(1), (1.0)] also dicts in vects
        Broadcast bitvector
    * You can export names which does not exist
    * You can define methods with unbound type arguments
    * The nightmare of `missing`
        - breaks contracts such as isodd, e.g. VSCode error
    * If we CAN allow it, why not DO allow it?
        - Everything is iterable: for i in 5, isempty, reduce, etc
        - 1[1] works
        - get(1,1,1) works
        - a, b = (1, 2, 3) works
        - ndims(1) works   

    Syntactical chaos:
        @A.b vs A.@b
        return or not in functions
        in vs = in loops

## What can we do?
* Culture shift. Yuri's post and this is part of it.
* Better tooling. We need it much more so than other languages
* Eventually address the design deficiencies of the languiage

### Individual Julia users
* Use the linter
* Use JET
* Use Aqua on their packages
* When writing a package, make a small test case that exercises the functionality
  of your package. Might not be possible for some packages.
    - Run JET on this to check for dynamic dispatch, fix if possible
    - Run JET on it for correctness
    - Use for SnoopPrecompile
* Possibly circlejerky: But: Learn Rust to get a frame of reference.

### Julia developers: Short-term improvements
* Automatically add compat to new packages

* Make a new GitHub tag: "Actionable". That's a bug that is known, reproducible,
  and can straightforwardly be solved.
  Ask community to identify as many actionable bugs as possible, then do not release
  another minor Julia release before these are all fixed.

* Improve linting to catch more common errors like
    * for i in 5
    * using Foo
    * warn again importing non-exported (internal) names
    * exporting non-bound names
    * Functions with unbound type params
    * @A.b instead of A.@b

* Make it a warning to use a package which exports an undefined symbol

#### Registry
* Have various quality checks when registering new packages/versions:
    - Can't export unbounds names
    - Can't export symbols without documentation
    - Can't do `using Foo`
    - Can't have unbound type params

#### Document abstract types
* Every exported abstract type of Base should be thoroughly documented
    - What is assumed about subtypes of this?
    - What do I need to implement for a type of this?
    - Implement an example generic example of this type like GenericString,
      which should be adversarial in common, but wrong assumptions

* Core and non-core devs should make a code coverage working group
    * Base needs to reach 100% code coverage
    * Generic functions should be tested with minimal abstract types
      similar to existing Test.GenericString, see the one above
    * Mutable iterators

#### Julia developers: Long-term solutions
* Consider a way to make it hard to accidentally rely on internals
    * Non-exported names
    * Fields

* Implement some kind of interfaces in Julia which can be statically checked
    * Idea1: Contract for function. All methods of this function must take
      have some signature and return some type
      Contract for type: Must implement X functions (which may be contracted)
    * Idea2: Have a type `Has{A, B, C}` which means a function `a(::B)::C` exists.
      `Has` can be dispathed on. Behaviour similar to Python's ABC.

* Create a low-latency code formatter which makes configuration hard

* Have type-based linting, possibly integrated with syntax linting
    * Dead code branches
    * Unused local variables
    * For un-exported names:
        * Flag methods that are never called
        * Flag struct fields that are never read
		
## Evidence
Own issues that are bugs:
    - #43245
    - #43235
    - #40042
    - #39734
    - #39711
    - #39198
    - #37231
    - #37037
    - #35027        

35027, 43245 and 43235 are particularly bad.
Also organically encountered 35530 1 year + after being reported
Worse, most are still not fixed

Other open bugs
# 45414
# 45340
# 45323
# 45125
# 45085
# 44895
# 44772
# 45165
# 44395
# 43921
# 43882
# 43841
# 43668
# 43050
# 41954
# 41948
# 41798

-- only to 42000
