@def rss = "Why Julia has so many bugs and what to do about it"
@def rss_pubdate = Dates.Date(2021, 07, 25)

# Why is Julia so buggy and what can we do about it?
Julia and its ecosystem has a _lot_ of bugs.
Some months ago, long-time Julia user Yuri Vishnevsky wrote a blog post on this, entitled [Why I no longer recommend Julia](https://yuri.is/not-julia/), which made the rounds.
It caused hefty discussion in the Julia community, and presumably made a lot of outsiders cautious about trying out Julia for their projects.

Yuri's blog post struck a nerve with me because I have had a similar experience in my ~three years of using Julia daily. I've been having thoughts along the same lines, but hadn't been able to materialise them until Yuri put words it into words.
This blog post is the result of a few of months of mulling it over.

I will not waste any time presenting evidence that Julia actually is buggy - Yuri already put it so well, so just read his blog post.

First, let me clear up a point of confusion. In response to Yuri's original post, lots of effort was spent arguing that Yuri didn't expose problems, in Julia the _language_, but rather packages in the Julia _ecosystem_.
It's a pointless distinction: _Both_ the language and the ecosystem is full of bugs, for the same underlying reasons. This blog post is about what I belive these underlying reasons for unreliable code are. They might be of interest to anyone who cares about programming languages in general. I argue that the causes of the problems are threefold:
* The fundamental design of Julia makes correctness hard
* The culture among Julia users puts little emphasis on correctness
* There is a lack of tooling to ensure correct code

The two latter points contain several superficial issues that are quite fixable, so the last part will concern itself with what can be done, both as an individual Julia user, and as a developer of Julia, to make Julia a more solid language going forward.

## The language design makes correctness hard
### Julia is a dynamic language
This is a classic point when programmers discuss languages: Code written in status languages tend to have fewer defect, because an ahead-of-time compiler prevent type bugs, and can act as a strict linter. This is especially true for languages intensionally built to be bug-resistant, like Ada and Rust.

Here, Julia is in the same boat as Python. There are generally no guarantees about anything (except syntax errors) before runtime. This means typos, reference to undefined variables and many other simple problems are simply not detected in Julia before they are hit at runtime. In my experience, these silly and utterly preventable bugs constitute a major fraction of all Julia bugs I encounter in the wild.

### No interfaces, no protocols
I also mentioned this issue in another blog post under the section ["The type system works poorly"](https://viralinstruction.com/posts/badjulia/#the_type_system_works_poorly). Essentially, when you write a function signature in Julia, you have two choices:

Either use only concrete types, in which case the function is not generic, and needlessly constrained. This is generally considered unidiomatic Julia.

Your other option, unfortunately, is to throw all guarantees overboard, by using abstract types. In Julia, abstract types have no rules and no interfaces. In fact, they often don't have documentation or even a coherent idea of what they are. For example, I have still to figure out what the `IO` type _actually is_, despite it being used extensively througout idiomatic Julia code.

It could be different. For example, Python has adopted [protocols](https://peps.python.org/pep-0544/), a kind of static ducktyping, such that any type that implements `__iter__` is of the type `Iterable`, and any type that implements `__call__` is of type `Callable`.

Such "behaviour"-based types, as opposed to Julia's type that can almost be described as onthological, are extremely useful. For example, if I provide the following psudo-Julia code:

```julia
function filter(predicate::Callable{T, Bool}, itr::Iterable{T})::Iterable{T}
    ...
end
```

It is eminently clear what this code accepts and what it produces - both to the programmer, and to the compiler that can enforce these promises. Too bad the code doesn't actually work since there is no concept of a callable or an iterable in Julia. Instead, the code would have to look like this:

```julia
function filter(predicate, itr)
    ...
end
```

### Julia is a language for hackers
In the ["what's great about Julia"](https://viralinstruction.com/posts/goodjulia/) post, I argue that Julia is fun to use, and include the following quote from language co-creater Stefan Karpinski:

> [..] one thing that's kind of hard to put your finger on that I always loved about Perl is that it's just FUN to use. People have told me that Julia is fun in the same way that Perl is. I think this has something to do with the language letting you do subversive things that might be dangerous or questionable but which work and let you play with the computer in interesting ways.

Unfortunately, this cuts both ways. Julia is indeed fun, but it also subtly encourage a culture where everything is a hack upon a hack, where [There Is More Than One Way To Do It](https://en.wikipedia.org/wiki/There%27s_more_than_one_way_to_do_it), and where "clever" code is celebrated.

It's the same thing with Perl, really. It's all fun and games when you're writing it. But when you have to read it, modify it, maintain it or you depend on it working predicably, the fun suddenly fades away as you find yourself in an un-navigable quagmire.

# WHY VS WHY NOT INCLUDE A FEATURE

### No clear separation of public and private
If you want the ability to develop a body of code that is being depended on by someone else, the only solution is to separate your code into parts which you promise not to change, such that it can be relied on (the API, or the public code), and parts where you make no promises, such that you can change it (the internals, or the private code).

In Julia, there is no way of marking which code is public and which is private. The (quite predictable) consequence is that users frequently end up relying on a piece of code believing it to be public, only for the maintainer to release incompatible changes in what they consider to be internal code.

Now to be clear - Julia doesn't _prevent_ you from writing in your documentation that this or that behaviour is public or private. How could it? Hence, some people dismiss this problem with "Read The Fine Manual".

Let's be real here: People usually don't read the whole documentation. And when they do, they often either misunderstand it, or forget it after a few months. Writing your code such that it is unreliable unless your users reads, understands and follows documentation is only very slightly better than always making your code consistently unreliable.

Julia _does_ provide the `export` keyword, which controls which names are brought into your namespace. This is often used to mark public names. Unfortunately, this is merely a suggestion not universally followed, not even by Base Julia itself. As the Julia documentation states:

> It is common to export names which form part of the API (application programming interface). [ ... ]  However, since qualified names always make identifiers accessible, this is just an option for organizing APIs: unlike other languages, Julia has no facilities for truly hiding module internals.

The mention of `export` brings me to a related problem: Nearly all Julia tutorials and examples explain that you can use a package MyPkg with the `using` keyword: `using MyPkg`. This will bring all exported names from MyPkg into scope.

Quite unfortunately, this also means that if a new version of MyPkg exports a new name which clashes with an existing name, the name cannot be resolved, and your code will crash. In other words, with the idiomatic approach to importing modules, nonbreaking changes in your dependencies can break your code!

Experienced Julians will counter by saying that you should never do `using MyPkg` in your code, only use selective imports by writing `using MyPkg: MyPkg, foo bar` so you control which names is brought into scope. Why, then, does essentially *every* teaching material and example use case show `using MyPkg`?

Selective imports, of course, make it impossible to determine which names are exported from your dependencies. And remember, most packages use the export system to signal what code is public!

It's also telling that [there is no consensus in the community whether struct fields are private or not](https://discourse.julialang.org/t/accessing-type-internal-fields-in-package-interfaces/70263). You'll find some people saying it's "bad form" to mess with struct fields of dependencies, but others who expose an API that forces you to read struct fields directly.

## A culture of hacking, not of correctness
### Made for academics, by academics
Julia is first and foremost designed to cater to scientist and engineer programmers.
As a scientist, I must say it does so beautifully!
As a natural consequence... let me quote [Patrick Kidger](https://discourse.julialang.org/t/state-of-machine-learning-in-julia/74385/4):

>Code quality is generally low in Julia packages. (Perhaps because there’s an above-average number of people from academia etc., without any formal training in software development?)
> Even in the major well-known well-respected Julia packages, I see obvious cases of unused local variables, dead code branches that can never be reached, etc.
> In Python these are things that a linter (or code review!) would catch. And the use of such linters is ubiquitous. (Moreover in something like Rust, the compiler would catch these errors as well.) Meanwhile Julia simply hasn’t reached the same level of professionalism.

In a [related blog post](https://kidger.site/thoughts/jax-vs-julia/), he writes:

> The fundamental problem here is that most Julia packages are written by academics, not professional software developers. Academic code quality is famously poor, and the Julia ecosystem is no exception

I suppose there is some truth to that.
For what it's worth, the code quality I see among scientific Julians is far better than that from scientist Pythonistas. This should not be surprising - the scientists who pick up a much less popular programming language are likely to be programming affectionados.

It's also not clear it's something the Julia community _ought to do something about_.
The whole point of Julia is being a good language for academics; it makes no sense to blame its users for being academics. If writing correct Julia code is so hard that academics can't do it, we should make it easier to write correct code, not alienate the target audience.
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
