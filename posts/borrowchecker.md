@def rss = "Rust's borrowchecker comes with real downsides"
@def rss_pubdate = Dates.Date(2025, 05, 18)

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

### Downsides of the borrowchecker
In a nutshell, the problem with Rust's borrowchecker is that it makes references a pain in the ass.

On an abstract level, the reason for the pain is that the borrowchecker needs to know the lifetimes of all references _at compile time_, and this is simply an unrealistic proposal. Lifetimes are often an inherently runtime property.

On an algorithmic level, the borrowchecker enforces a specific model, or set of rules around ownership, but this model is overly restrictive, and degrade Rust's ergonomics by rejecting far too many well-behaving programs.

At the implementation level, the borrowchecker's current instantiation is incomplete, and often rejects programs, even though they adhere to the model of ownership, even as that model is too restrictive. 

Rustaceans claim that you just have to internalize the ownership model, then you will automatically structure your code to conform to the borrowchecker, and the problems go away.
Unfortunately, after using Rust intermittently for a few years, this hasn't been my experience, and [it seems I'm not alone](https://loglog.games/blog/leaving-rust-gamedev/#once-you-get-good-at-rust-all-of-these-problems-will-go-away).
Rather, I've experienced the borrowchecker as an unending series of stumbling blocks, where a small number of borrowchecker woes re-appear over and over in slightly different guises.

### Examples where the borrowchecker fails
Borrowchecker frustration is like being brokenhearted - you can't easily demonstrate it, you have to suffer it yourself to understand what people are talking about.
That is because the true pain of the borrowchecker is not felt when your small, 20-line demonstration snipped fails to compile - it's when your existing project requires a small modification to ownership structure, and the borrowchecker then refuses to compile your code.
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
Nonetheless, the borrowchecker will not compile it.

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

The borrowchecker is not only overly conservative when checking loans across functions; it can't reason well about control flow _within_ a function, either.
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
There is an obvious parallel with the mythical 'sufficiently smart compiler' - just like compilers continuously improve, and yet never seem to really _understand_ your code, and rarely can rewrite it on an algoritmic level, the borrowchecker will probably always fail to accept seemingly obviously correct code.

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
Here, it's a ruleset that provide with no upside and all downside.
The problem here are the ownership rules themselves.
 
In the above case, the restriction doesn't matter because the workaround is obvious.
But my experience has been _regularly_ hitting these fundamental problems where the ownership model does not correspond to the needs of my program.
For example: 

* References to temporary values, e.g. values created in a closure, are forbidden even though it's obvious to a human that the solution is simply to extend the lifetime of the value to its use outside the closure.
* Multiple references: You can't have a struct with a set of things, and then also store the same things in groups in a `Vec<Set<Thing>>`.
* Phylogenetic trees are a _massive pain_ to implement, because each node having bidirectional references is fundamentally in conflict with Rust's concept that data has exactly one owner.

It's hard to overstate how much these problems just _are not a thing_ in garbage collected languages, but purely self-inflicted by Rust's borrowchecker.
You want to build a tree with bidirectional references in Python? Just do the obvious thing, and it works perfectly.
Compare that to the apalling knots you have to tie yourself in to do it in Rust[^1].

All these problems really are _mostly bullshit_. An problem entirely invented by Rust's borrowchecker, which you _absolutely_ will need to deal with when writing Rust.

A common defense of Rust are that the pain Rust's borrowchecker inflicts on you is not _excess pain_, but rather _upfront pain_.
The talking point goes: You have a program with a complicated ownership structure, and Rust merely forces you to be explicit about this.
In doing so, it guarantees memory safety - and wouldn't you rather deal with compiler errors than production crashes?

But that hasn't been my experience. My experience has been that the limitations has _mostly_ been unnecessary and without merit.
A constant tricke of arbitrary frustrations from false positives - small things, each of which seems like a detail, like stubbing your toe, except you are forced to do it all the time.

### Why don't you just...
At this point, people experienced in Rust have held their breath since the last example: "You can just derive `Clone + Copy`!". "You can just clone the value, and the clone will be optimised away!". "You can just..."

I know.
The commonality of these hoops is that you _can_ jump through them. You can, indeed, do work to fix whatever borrowchecker problems you have.

But there was never a  problem to begin with. Rust gates your _perfectly functional code_ behind a lifetime puzzle, and forces you to refactor until you've solved it.
Yes, in the snippets above the puzzle solution is trivial, but not always so in larger-scale, real life code.

Perversely, _because_ the lifetime puzzles are challenging, they can be _fun_.
I believe that partly explains why so many people don't seem to mind them.
Instead of thinking about how to write my code to solve the scientific problem the code is written for, I'm now thinking about how to please the borrowchecker.

Rust insists your program's structure is a house of cards - change one tiny thing, and the entire thing has to scrapped, restructured, and rewritten.
The more Rust experience I gain, the more often I suspect the problem was never my program's structure, but the largely arbitrary restrictions of Rust.

The usual way of obeying the borrowchecker is to refactor your code.
Which is already unwelcome extra work, but sometimes even that is not enough.

Let's look at some other ways people usually recommend me solving borrowchecker problems:

#### Use fewer references and clone data. Or: "Just clone".
This is generally good advice. Usually, a few allocations are fine, and the resulting performance degradation is not an issue.
But it is bizarre that it needs to be done in an otherwise performance-forcused language, not because the program logic demands it, but because the borrowchecker does.

Of course, sometimes cloning doesn't solve the issue, because you really do need to mutate shared objects.

#### `Arc` spam.
Rust's `Arc` type disables some of Rust's ownership rules of the object it wraps, and instead reference counts that specific object.
That means sometimes, the borrowchecker can be appeased by slapping `Arc` on a bunch of data throughout your program.
Or, as I also like to call it "managing the world's worst garbage collector, but with none of the convenience or performance".

#### Use indices instead of references
For example, a bidirected graph's edges can be represented by referencing the vertices by an integer ID, instead of an actual reference.
Since you don't use references, you don't get any issues with the borrowchecker.

The first time someone gave be this advice, I had to do a double take.
The Rust community's _whole thing_ is commitment to compiler-enforced correctness, and they built the borrowchecker on the premise that humans can't be trusted to handle references manually.
When the same borrowchecker makes references unworkable, their solution is to... recommend that I manually manage them, with _zero_ safety and _zero_ language features?!?
The irony is unreal.
Asking people to manually managing references is so hilariously unsafe, the suggestion would be funny if the state of affairs wasn't so sad.

## Rust's safety is only partly due to the borrowchecker

## Okay, the borrowchecker isn't _all bad_


GC is a nonstarter in some applications - but probably a small minority
    - latency (discord blog post ref)
    - memory efficiency
    - memory reuse (that malloc vs gc benchmark)

- note that GCs are more efficient than their reputation, probably Java + Python
    https://bitbashing.io/gc-for-systems-programmers.html

Does occasionally prevent bugs, by enforcing the maxim of no mutating a shared ref.
Data races.

Note that dnagling pointers, use after free, double free is handled by GC,
and buffer overflow is handled by boundschecking.
null pointers are handled by enums, not the BC.

### Conclusion
I switch between Rust, Julia and Python when coding.
The grass is always greener: When I switch from Rust to Julia, I miss Julia's strengths and vice versa.

I miss RUst's enums with exhaustive checks.
I miss traits and the strong guarantees they come with.
I miss rust-analyzer.
I miss leaning so heavy on the type system that refactors feel automatic - I make a change and rust-analyzer lights up, and once I've fixed the type issues, the refactor is done.

I _absolutely_ don't miss the borrowchecker.







## Let me first say some nice things about Rust
Extremely easy to get started. Linter, formatter, build system package manager in one install.

Excellent easy to use package manager. `cargo build`.
Great errors and linter, build-in warnings in compiler.

Rasies the floor of Rust code quality - I've never seen RUst code as bad as I've seen Python code.

ADT which models multiple outcomes extremely well - and the errors (though not perfect).
Having used ADT, going to a language without them feels like there's a ADT-shaped hole.
It feels so obvious in hindsight it's hard to believe people would make a language without them.

More nebulous: Well designed in the small details - pit of success, hard to misuse.
E.g. from_le_bytes (handles endianness explicitly, vs reinterpret in Julia or Python's)
E.g. mutex where the guard contains the thing to use.

[^1]: A famous Rust resource teaches people to write a doubly linked list in Rust, and in doing so demonstrates tonnes of Rust's features, because those are the wild loops Rust programmers have to jump through: https://rust-unofficial.github.io/too-many-lists/. 
