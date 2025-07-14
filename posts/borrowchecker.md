@def rss = "Rust's borrowchecker comes with real downsides"
@def rss_pubdate = Dates.Date(2025, 07, 17)

# The borrowchecker is what I like the least about Rust
_Written 2025-05-18_

Among the cohort of modern programming languages, Rust is probably the most widely lauded.

The main selling point of Rust is that is manages to combine speed and low-level control with a high level of bug-resistance more commonly referred to as _safety_.
The main innovation of Rust - really, its claim to fame - is its borrowchecker: the part of its compiler that enforces Rust's ownership rules and thereby allows Rust to achieve the same memory safety that garbage collected language enjoy, but with zero runtime cost.   

~~~
The <s>evangelists</s> proponents of Rust have made memory safety the central selling point of Rust, to the extent that the borrowchecker has become a core component of Rust's identity.
~~~
I think the conflation of Rust's safety with the borrowchecker's guarantees is somewhat misguided.
In this post, I want to make two arguments:

1. That the borrowchecker impose _serious_ downsides on Rust, by enforcing poor ergonomics.
2. That the role of the borrowchecker in Rust's safety is overstated.

In fact, my opinion, which I will attempt to substantiate, is that borrowchecker is the worst part of Rust.

### The fundamental problem of the borrowchecker
In a nutshell, the problem with Rust's borrowchecker is that it makes references a pain in the ass.

On an abstract level, the reason for the pain is that the borrowchecker needs to know the lifetimes of all references _at compile time_, and this is simply an unrealistic proposal. Lifetimes are often an inherently runtime property.

On an algorithmic level, the borrowchecker enforces a specific model, or set of rules around ownership, but this model is overly restrictive, and degrade Rust's ergonomics by rejecting far too many well-behaving programs.

At the implementation level, the borrowchecker's current instantiation is incomplete, and often rejects programs that _adhere_ to the model of ownership, even as that model is too restrictive in the first place. 

Rustaceans claim that you just have to internalize the ownership model, then you will automatically structure your code to conform to the borrowchecker, and the problems go away.
Unfortunately, after using Rust intermittently for a few years, this hasn't been my experience, and [it seems I'm not alone](https://loglog.games/blog/leaving-rust-gamedev/#once-you-get-good-at-rust-all-of-these-problems-will-go-away).
Rather, I've experienced the borrowchecker as an unending series of stumbling blocks, where a small number of borrowchecker woes re-appear over and over in slightly different guises.

### Examples where the borrowchecker fails
Borrowchecker frustration is like being brokenhearted - you can't easily demonstrate it, you have to suffer it yourself to understand what people are talking about.

Borrowchecker pain is not felt when your small, 20-line demonstration snippet fails to compile.
It's when your existing project requires a small modification to ownership structure, and the borrowchecker then refuses to compile your code.
Then, once you pull at the tiny loose fiber in your code's fabric, half of it unspools.

Nonetheless, these tiny examples can still serve to demonstrate the borrowchecker's propensity to reject perfectly fine code.
The most clear examples are when the borrowchecker simply doesn't do what it's supposed to, in that its implementation rejects code that doesn't conceptually violate Rust's ownership rules.

For example, consider this code I got from [a blog post](https://medium.com/@lordmoma/partial-borrowing-in-rust-the-struggle-is-real-17db9ed9be1a):

@@rustcode
```
struct Point {
    x: f64,
    y: f64,
}

impl Point {
    fn x_mut(&mut self) -> &mut f64 {
        &mut self.x
    }

    fn y_mut(&mut self) -> &mut f64 {
        &mut self.y
    }
}

fn main() {
    let mut point = Point { x: 1.0, y: 2.0 };
    let x_ref = point.x_mut();
    let y_ref = point.y_mut();
    *x_ref *= 2.0;
    *y_ref *= 2.0;
}

```
@@

This code won't compile, because the two mutable references `x_ref` and `y_ref` needs to exist simultaenously, which violates Rust's principle that a mutable reference to some data needs to unique at any point.

Of course, in this case, the violation is entirely bogus, since the references point to distinct fields of the same struct, and therefore _don't_ refer to the same data.
That nuance is lost on the borrowchecker, which prevents the code above from compiling.

A similar, but slightly different example occurs in the code below

@@rustcode
```
struct Collection {
    counter: u32,
    items: Vec<u32>,
}

impl Collection {
    fn increment_counter(&mut self) {
        self.counter += 1;
    }
    
    pub fn count_items(&mut self) {
        for _ in &self.items {
            self.increment_counter();
        }    
    }
}
```
@@

To the human reader, it's clear that `increment_counter` doesn't mutate `self.items`, and therefore cannot interfere with looping over the vector.
Therefore, the maxim of the borrowchecker: "Mutation requires exclusivity" is not violated, and the code should compile fine.

Unfortunately, the borrowchecker can't reason across functions, and therefore incorrectly rejects the function.

The borrowchecker is not only overly conservative when checking loans across functions; it can't even reason well about control flow _within_ a function.
The following example is a famous illustration of how it can't properly reason across _branches_, either:

@@rustcode
```
fn get_default<'r, K: Hash + Eq + Copy, V: Default>(
    map: &'r mut HashMap<K, V>,
    key: K,
) -> &'r mut V {
    match map.get_mut(&key) {
        Some(value) => value,
        None => {
            map.insert(key, V::default());
            map.get_mut(&key).unwrap()
        }
    }
}
```
@@

This is rejected due to the two mutable references, despite the program logic guaranteeing that the second reference is only created in the `None` branch, where the first reference is no longer live.

There are more such [unnecessary limitations of the borrowchecker](https://blog.polybdenum.com/2024/12/21/four-limitations-of-rust-s-borrow-checker.html).

## A 'sufficiently smart borrowchecker'
At this point, an Rust apologist might point out that these artificial limitations of the borrowchecker implementation are not fundamental, and might be lifted in the future.
There is some merit to the hope: Rust adopted so called [non-lexical lifetimes](https://blog.rust-lang.org/2022/08/05/nll-by-default/) in 2022, which did improve the borrowchecker's accuracy.
Similarly, a new formulation of the borrowchecker, called [Polonius](https://smallcultfollowing.com/babysteps/blog/2018/04/27/an-alias-based-formulation-of-the-borrow-checker/) is in the works, which will improve accuracy still further.

I remain sceptical. Polonius has been in the works for seven years now, and doesn't seem to be close to completion.
More fundamentally, the borrowchecker will never be 'complete', because its job is to _reason_ about your code and algortihms just cannot do that on a deep level.
There is an obvious parallel with the mythical 'sufficiently smart compiler' - just like compilers continuously improve, and yet never seem to really _understand_ your code, and rarely can rewrite it on an algoritmic level, the borrowchecker will probably always reject seemingly obviously correct code.

### Fundamental issues with the borrowchecker
Above, I demonstrated limitations in the  _implementation_ of the abstract ownership model.
However, sometimes the model itself is just wrong for your program.

Consider: 

@@rustcode
```
struct Id(u32);

fn main() {
    let id = Id(5);
    let mut v = vec![id];
    println!("{}", id.0);
}
```
@@

This is a clear-cut violation of the ownership rules: After `v` is constructed, `id` is moved into `v`, which prevents the function `main` from using `id` on the last line.
There is a sense, then, in which the borrowchecker _ought_ to reject the program. It does fail the ownership rules.

But what's the point of the rules in this case, though?
Here, the ownership rules does not prevent use after free, or double free, or data races, or _any other bug_.
It's perfectly clear to a human that this code is fine and doesn't have any _actual_ ownership issues.
Here, the borrowchecker is an overly pedantic enforcement of a rigid set of rules, which provide no benefit in this case.
 
In the above case, the restriction doesn't matter because the workaround is obvious.
But my experience has been _regularly_ hitting these fundamental problems where the ownership model does not correspond to the needs of my program.
For example: 

* References to temporary values, e.g. values created in a closure, are forbidden even though it's obvious to a human that the solution is simply to extend the lifetime of the value to its use outside the closure.
* Multiple references: You can't have a struct with a set of things, and then also store the same things in groups in a `Vec<Set<Thing>>`.
* Phylogenetic trees are a _massive pain_ to implement, because each node having bidirectional references is fundamentally in conflict with Rust's concept that data has exactly one owner.

It's hard to overstate how much these problems just _are not a thing_ in garbage collected languages, but purely self-inflicted by Rust's borrowchecker.
You want to build a tree with bidirectional references in Python? Just do the obvious thing, and it works perfectly.
Compare that to the apalling knots you have to tie yourself in to do it in Rust[^1].

A common defense of Rust are that the pain Rust's borrowchecker inflicts on you is not _excess pain_, but rather _upfront pain_.
The talking point goes: You have a program with a complicated ownership structure, and Rust merely forces you to be explicit about this.
In doing so, it guarantees memory safety - and wouldn't you rather deal with compiler errors than production crashes?

But that hasn't been my experience. My experience has been that the limitations has _mostly_ been unnecessary and without merit.
All these problems really are _mostly bullshit_. An problem entirely invented by Rust's borrowchecker, which you _absolutely_ and constantly will need to deal with when writing Rust.

### Why don't you just...
At this point, people experienced in Rust have held their breath since the last example: "You can just derive `Clone + Copy`!". "You can just clone the value, and the clone will be optimised away!". "You can just..."

I know.
The commonality of these hoops is that you _can_ jump through them. You can, indeed, do work to fix whatever borrowchecker problems you have.

But there was never a  problem to begin with. Rust gates your _perfectly functional code_ behind a lifetime puzzle, and forces you to refactor until you've solved it.
Yes, in the snippets above the puzzle solution is trivial, but not always so in larger-scale, real life code.

Perversely, _because_ the lifetime puzzles are challenging, they can be _fun_.
I believe that partly explains why so many people don't seem to mind them.
Instead of thinking about how to write my code to solve the scientific problem the code is written for, I have to think about how to please the borrowchecker, which is usually more tractable.

Rust insists your program's structure is a house of cards - change one tiny thing, and the entire thing has to scrapped, restructured, and rewritten.
The more Rust experience I gain, the more often I suspect that is mostly just wrong. For most borrowchecker issues, the problem is not program's structure, but the largely arbitrary restrictions of Rust.

The usual way of obeying the borrowchecker is to refactor your code.
Which is already unwelcome extra work, but sometimes even that is not enough.
Let's look at some other ways people usually recommend me solving borrowchecker problems:

#### Use fewer references and clone data. Or: "Just clone".
This is generally good advice. Usually, extra allocations are fine, and the resulting performance degradation is not an issue.
But it is bizarre that it needs to be done in an otherwise performance-forcused language, not because the program logic demands it, but because the borrowchecker does.

Of course, sometimes cloning doesn't solve the issue, because you really do need to mutate shared objects.

#### `Arc` spam
Rust's `Arc` type disables some of Rust's ownership rules of the object it wraps, and instead reference counts that specific object.
That means sometimes, the borrowchecker can be appeased by slapping `Arc` on a bunch of data throughout your program.
Or, as I also like to call it "managing the world's worst garbage collector, but with none of the convenience or performance".

#### Use indices instead of references
When I first tried implementing a bidirected graph in Rust, I was suggested this pattern.
A bidirected graph's edges can be represented by referencing the vertices by an integer ID, instead of an actual reference.
Since you don't use references this way, you don't get any issues with the borrowchecker.

The first time someone gave be this advice, I had to do a double take.
The Rust community's _whole thing_ is commitment to compiler-enforced correctness, and they built the borrowchecker on the premise that humans can't be trusted to handle references manually.
When the same borrowchecker makes references unworkable, their solution is to... recommend that I manually manage them, with _zero_ safety and _zero_ language support?!?
The irony is unreal.
Asking people to manually manage references is so hilariously unsafe and unergonomic, the suggestion would be funny if it wasn't mostly so sad.

## Rust's safety is only partly due to the borrowchecker
In online discourse, Rust's safety is sometimes equated with its memory safety in particular, which is attributed to the borrowchecker.
Rust's reputation for bug-resistance is deserved, I think, but I believe it's due to Rust's _broadly_ good taste and solid design.
Like performance, correctness dies by a thousand cuts, and Rust is notable for being _consistently_ correctness-focused:

* Its widespread use of enums plus exhaustive pattern matches, including for error states, makes it hard to ignore potential errors
* Its heavy use of custom types to encode a lot of information in the type system, where the compiler can statically prevent mistakes
* Forced use of keyword arguments to construct structs, making it hard to switch up fieldss
* A consistent focus on, and documentation of, edge cases in function APIs.
* Good tooling, e.g. [cargo-semver-checks](https://crates.io/crates/cargo-semver-checks), and a good built-in linter.

More amorphous, but not less important is Rust's strong _cultural affinity_ for correctness.
For example, go to YouTube and click on some Rust conference channel.
You'll see that a large fraction of the talks are on correctness, in some way or another.

I'm certain that a language with the above features, but with a garbage collector instead of a borrowchecker would have the majority of Rust's correctness.
OCaml and Haskell are like that, and they, too, have a strong reputation for safety and correctness. 

## Okay, the borrowchecker isn't _all bad_
As you might have noted by now, _I don't like the borrowchecker_, but even I have to grudgingly admit it has some use cases.

Without a borrowchecker, you're left with either manual memory management, which is annoying and error-prone, or garbage collection[^2].
Garbage collection (GC) also has its downsides:

* Marking and sweeping cause latency spikes which may be unacceptable if your program must have millisecond responsiveness.
* GC happens intermittently, which means garbage accumulates until each collection, and so your program is
  overall less memory efficient 

Those two drawbacks alone could make GC a non-starter.

Then there is the issue of performance, which is not straightforward.
Garbage collection has a bad reputation for performance because most GC languages like Java and Python are _otherwise_ not performance oriented.
When non-GC languages are compared to performance oriented GC languages like Julia and Go, the gap narrows.
And even Julia and Go are decidedly higher level and offer the programmer less control than non-GC languages making the comparison somewhat confounded.

It's [not entirely clear to me GC are always slower than deterministic destruction](https://bitbashing.io/gc-for-systems-programmers.html).
Certainly, there are situations where the GC causes slowdown.
One such situation is  when the program has a large graph objects on the heap that needs to be traversed at every collection,
in which case I've heard a programmer deride a GC as a "heap scanner".
Or, when the program's allocation pattern means it blows the CPU cache between collections, where deterministic destruction would reuse memory in hot cache.
I've seen demonstration Julia code where manually invoding `malloc` / `free` was _six times_ faster than Julia's GC due to this occurring.

On the other hand, a naive implementation of the [binary-trees benchmark](https://benchmarksgame-team.pages.debian.net/benchmarksgame/performance/binarytrees.html)[^3]
is several times faster in Julia than in Rust, because Julia's GC has higher throughput when run in bulk, compared to Rust's deterministic destruction which is invoked individually for each object.
   
### And okay, it _does_ prevent some bugs
A garbage collector will prevent dangling pointers, use after free, and double free bugs.
Buffer overflows are prevented by bounds checking.

But there _are_ some bugs that a borrowchecker is uniquely suited to prevent:
Data races in multithreaded code are elegantly and statically prevented by Rust.
I have never written a large concurrent Rust program, and I'll grant the possibility that the borrowchecker is miraculous for that use case and easily pays for its own clunkiness.
However, async Rust doesn't exacty [have a great reputation](https://bitbashing.io/async-rust.html).

In single-threaded code, statically preventing mutation of externally held references _sounds_ like it would prevent a lot of bugs, but my experience in Julia and Python is that I rarely encounter these bugs.
Your mileage may vary.

There are also some unexpected minor benefits of the borrowchecker that deserves mention: Guaranteeing the compiler that data is immutable unlocks optimisations, and likewise, guaranteeing that mutable data is not aliased enables other optimisations.
The borrowchecker's mechanism can be leveraged for some nice, seemingly unrelated tricks, such as [lock-free mutation of locks](https://doc.rust-lang.org/std/sync/struct.Mutex.html#method.get_mut), and [locks that take up 1 byte of memory](https://crates.io/crates/parking_lot).

### Conclusion
When coding in my day job, I switch between Julia, Python and Rust.
I persistently experience the grass is greener on the other side of the fence: When I switch from Rust to Julia, I miss Rust's strenghts, and vice versa.
When I don't program in Rust, I muss Rust's enums and their exhaustive checks.
I miss traits, and the strong guarantees they come with.
I miss the great tooling, such as rust-analyser.

I switch between Rust, Julia and Python when coding.
The grass is always greener: When I switch from Rust to Julia, I miss Julia's strengths and vice versa.
I miss leaning so heavy on the type system that refactors feel automatic - I make a change and rust-analyzer lights up, and once I've fixed the type issues, the refactor is done.

I _absolutely_ don't miss the borrowchecker.

[^1]: A famous Rust resource teaches people to write a doubly linked list in Rust, and in doing so demonstrates tonnes of Rust's features, because those are the wild loops Rust programmers have to jump through: https://rust-unofficial.github.io/too-many-lists/. 
[^2]: I suppose you could also have reference counting like Swift, which, although it's technically garbage collection, is not what most people mean by that term. And you could have syntactic sugar coating manual memory management, like Zig.
[^3]: The benchmark page lists Rust as being 7x faster than Julia. Amazingly, this is because there are different rules for GC versus non-GC languages. Only the latter are allowed to use custom memory management, and Rust only achieves its performance by using a custom bump allocator. This is perfectly doable in Julia, but arbitrarily banned in the competition. 
