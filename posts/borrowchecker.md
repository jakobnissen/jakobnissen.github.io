@def rss = "Rust's borrowchecker comes with real downsides"
@def rss_pubdate = Dates.Date(2025, 05, 18)

# The borrowchecker is what I like the least about Rust
_Written 2025-05-18_

Among the cohort of 2010's programming languages, Rust might be the most widely lauded.
The main innovation of Rust - really, its claim to fame - is its borrowchecker: the part of its compiler that enforces Rust's ownership rules and thereby allows Rust to achieve memory safety with zero runtime cost.   

~~~
The <s>evangelists</s> proponents of Rust have made memory safety the central selling point of Rust, to the extent that the borrowchecker has become a core component of Rust's identity.
~~~

I think that's somewhat misguided.

As notable as the borrowchecker is, I believe the main reason Rust is a great language is not because of its borrowchecker, but because Rust has _broadly_ good taste, and does all the boring things right. 
In this blog post, I will try to persuade you  that Rust's use of a borrowchecker has real, material downsides compared to using a garbage collector.
In fact, my opinion, which I will attempt to substantiate, is that the borrowchecker is the worst part of Rust.

In a nutshell, the problem with Rust's borrowchecker is that it makes references a pain in the ass.

Abstractly, the reason for the pain is that the borrowchecker needs to know the lifetimes of reference _at compile time_, but lifetimes are often a runtime property at a fundamental level.

On an algorithmic level, the borrowchecker enforces a specific model, or set of rules around ownership, and this model is overly restrictive, and incorrectly rejects far too many well-behaving programs.

At the implementation level, the borrowchecker's current instantiation is incomplete, and often rejects programs that adhere to the conceptual ownership rules of Rust. 

Rustaceans claim that you just have to internalize the ownership model, then you will automatically structure your code to conform to the borrowchecker, and the problems go away.
Unfortunately, this hasn't been my experience, and [it seems I'm not alone](https://loglog.games/blog/leaving-rust-gamedev/#once-you-get-good-at-rust-all-of-these-problems-will-go-away).
Rather, I've experienced the borrowchecker as an unending series of stumbling blocks, where a small number of borrowchecker woes re-appear over and over in slightly different guises.

### Examples where the borrowchecker fails
Borrowchecker frustration is like being brokenhearted - you can't easily demonstrate it, you have to suffer it yourself to understand what people are talking about.
That is because the true pain of the borrowchecker is not felt when your small, 20-line demonstration code fails - it's when your existing project requires a small modification to ownership structure, and the borrowchecker then refuses to compile your code.
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

Of course, in this case, the violation is entirely bogus, since the references point to distinct fields of the same struct.
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

Here, the problem is that the borrowchecker can't reason between functions.
To the human reader, it's clear that `increment_counter` doesn't mutate `self.items`, and therefore cannot interfere with looping over the vector, the code is rejected by the borrowchecker.  

The borrowchecker is not only overly conservative when checking loans across functions; it can't reason well about control flow _within_ a function, either:

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


I can hear the arguments: This is just transient, will be improved in the future.
NLL already improved back in 2022[https://blog.rust-lang.org/2022/08/05/nll-by-default/],
Polonius will improve again [https://blog.rust-lang.org/inside-rust/2023/10/06/polonius-update/]

Polonius is from 7 years ago (https://smallcultfollowing.com/babysteps/blog/2018/04/27/an-alias-based-formulation-of-the-borrow-checker/)

But I believe BC will never really be complete, because its job is to reason about your code and algortihms just cannot do that satisfactory
Hence the simile with 'sufficiently smart borrowchecker' - just like compilers continuoisly improve but never seem to really _understand_ your code and rarely can optimise on an algoritmic level, the BC will probably always have edge cases.

And so far, I've hit these a lot.

### Fundamental issues
As I hinted before, it's not only a limited _implementation_ of the abstract ownership model, sometimes this model itself is just wrong for your program.

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

what's the point? No, really?

- References to temporary values, e.g. created in a closure

- E.g. struct with a set of Xs, and then groups as Vector<Set<Xs>> of the same thing.
Can't be done.

- Phylogentic trees? Bidirectional refs, can't be done. [too many linked list blog].
Hard to overstate the extent to which this is simply not an issue in GC languages.

It really is mostly bullshit

Defenders will rush to argue you're merely paying the cost up front - and wouldn't you rather deal with compiler errors than production crashes?
Not my experience. Most BC issues are bullshit.

Random bullshit with false positives for BC - small things, each of which seems like a detail, like stubbing your toe, except you do it all the time.

### Why don't you just...
Held your breath since the last example: You can just derive `Clone` and `Copy`. You can just clone the value and the clone will be optimised away! You can just...

I know. Commonality is that you can work around it. I can always "just".

But there was never a  problem to begin with. Rust gates your functional code behind a lifetime puzzle, and forces you to refactor until you've solved it.
Yes, in the examples above the puzzle solution is trivial, but not always so in real life code

Perversely, precisely because they are challenging, the puzzles can be FUN, which may explain why so many people don't seem to mind.
Instead of thinking about [something in my job], I'm now thinking about how to please the borrowchecker.

Rust insists your program's structure is a house of cards - change one tiny thing, and the entire thing has to be restructured
Beginning to suspect that the problem was never your program's structure, but the largely arbitrary restrictions of Rust.

That is to say, I'm not arguing these problems can't be solved. I'm arguing that it's bullshit how Rust declares it a problem and forces me to solve it.
The usual way of solving them it to refactor your code. Which already sucks, but sometimes that is not enough.

Let's look at some other ways people recommend me solving it.

* Use fewer references and copy the data instead. "Just clone". Good advice - usually allocations are fine and most software can be slow - but it's bizarre that it needs to be done in a HPC language not because the program logic demands it, but because the borrowchecker does.
Of course sometimes that doesn't work because you need to mutate shared objects so cloning is semantically wrong.

* Arc spam. Also known as "managing the world's worst garbage collector", but with none of the convenience.

* Use indices. [explain]. First time I read this advice, I had to do a double take.
The Rust community is committed to compiler-enforced correctness, and built the BC precisely because human's can't be trusted to handle references manually.
When the same borrowchecker makes references unworkable, their solution is to... recommend me manually managing them.

The irony is unreal.
Manually managing references is so hilariously unsafe, the suggestion would be funny if the state of affairs wasn't so sad.

### Good reasons for the BC
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
