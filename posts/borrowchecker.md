@def rss = "Rust's borrowchecker comes with real downsides"
@def rss_pubdate = Dates.Date(2025, 05, 18)

# The borrowchecker is what I like the least about Rust
_Written 2025-05-18_

Among the cohort of 2010's programming languages, Rust might be the most widely lauded.
The main innovation of Rust - really, it's claim to fame - is its borrowchecker: the part of its compiler that enforces Rust's ownership rules and thereby allows Rust to achieve memory safety with zero runtime cost.   

The proponents of Rust have made memory safety the central selling point of Rust, to the extent that the borrowchecker has become a core component of Rust's identity.

I think that's somewhat misguided.
As notable as the borrowchecker is, I believe the main reason Rust is a great language is not because of its borrowchecker, but because Rust has _broadly_ good taste, and does all the boring things right. 
In this blog post, I will try to persuade you  that Rust's use of a borrowchecker has real, material downsides compared to using a garbage collector.
In fact, in my opinion, the borrowchecker is the worst part of Rust.
Worse than compile times. Worse than its steep learning curve. 

### Things I really like about Rust
Build system - extremely easy to get started

Great errors and linter, build-in warnings in compiler.
Rasies the floor of Rust code quality - I've never seen RUst code as bad as I've seen Python code.

GADTs which models multiple outcomes extremely well - and the errors (though not perfect).
Having used GADTs, going to a language without them feels like there's a GADT-shaped hole.
It feels so obvious in hindsight it's hard to believe people would make a language without them.

More nebulous: Well designed in the small details - pit of success, hard to misuse.
E.g. from_le_bytes (handles endianness explicitly, vs reinterpret in Julia or Python's)
E.g. mutex where the guard contains the thing to use.

### Enough glazing
Rust's BC makes references a pain in the ass.

On a high level, this is because the borrowchecker needs to know AT COMPILE time when stuff is no longer referenced, but in many programs this intrinsically known at runtime only.

On a middle level, the borrowchecker enforces a specific model of ownership, and this model is overly restrictive and discards too many well-behaving programs.

At a lower level, the borrowchecker is imperfectly implemented, and often rejects programs that doesn't even break the already-strict model.

### My experience - illustrated
Peopel say you just gotta internalize the ownership model, then the programs go way.
I've found this not to be case [ref. the game dev article]
My experience has been an unending series of small stumbling blocks where your code doesn't compile.

Let's look at some examples.

The most clear examples are when the borrowchecker just doesn't do what it's supposed to:


- Borrow one part of a struct, and want to mutate another? No can do

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
From https://medium.com/@lordmoma/partial-borrowing-in-rust-the-struggle-is-real-17db9ed9be1a

- Interprocedural borrows

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
(from https://smallcultfollowing.com/babysteps/blog/2024/06/02/the-borrow-checker-within/)

- Sometimes borrowchecker can't handle if statements correctly

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

More here: https://blog.polybdenum.com/2024/12/21/four-limitations-of-rust-s-borrow-checker.html

### A 'sufficiently smart borrowchecker'
I can hear the arguments: This is just transient, will be improved in the future.
NLL already improved back in 2022[https://blog.rust-lang.org/2022/08/05/nll-by-default/],
Polonius will improve again [https://blog.rust-lang.org/inside-rust/2023/10/06/polonius-update/]

But I believe BC will never really be complete, because its job is to reason about your code and algortihms just cannot do that satisfactory
Hence the simile with 'sufficiently smart borrowchecker' - just like compilers continuoisly improve but never seem to really _understand_ your code and rarely can optimise on an algoritmic level, the BC will probably always have edge cases.

And so far, I've hit these a lot.

### Fundamental issues
As I hinted before, it's not only a limited _implementation_ of the abstract ownership model, sometimes this model itself is just wrong for your program.

Consider: 


```rust
struct Id(u32);

fn main() {
    let id = Id(5);
    let mut v = vec![id];
    println!("{}", id.0);
}
```

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

But there was never a  problem to begin with. Rust forces you to refactor your code, and turns your trivial problem into a lifetime puzzle.
In the examples above the puzzle solution is trivial, but not so in real life code, where they can be quite challenging.

Perversely, because they are challenging, the puzzles can be FUN, which may explain why so many people don't seem to mind.
Instead of thinking about [something in my job], I'm now thinking about how to please the borrowchecker.

Rust insists your program's structure is a house of cards - change one tiny thing, and the entire thing has to be restructured, like unravelling a sweater by pulling a loose thread.
Beginning to suspect that the problem was never your program's structure, but the largely arbitrary restrictions of Rust.

That is to say, I'm not arguing these problems can't be solved. I'm arguing that it's bullshit how Rust declares it a problem and forces me to solve it.

As I said before, the usual way of solving them it to refactor your code. Which already sucks, but sometimes that is not enough.

Let's look at some other ways people recommend me solving it.

* Use fewer references and copy the data instead. "Just clone". Good advice - usually allocations are fine and most software can be slow - but it's bizarre that it needs to be done in a HPC language not because the program demands it, but because the borrowchecker does.
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





