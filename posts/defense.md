@def rss = "A polemic critique of 'simple' programming languages and a defense of complicated ones."
@def rss_pubdate = Dates.Date(2021, 01, 23)

# In defense of complicated programming languages
_Written 2022-01-23_

In the winter of 2014/15, I was a university student, who characteristically had too much free time on my hands, and not enough money to keep myself busy in that free time.
Bored and broke, programming was a perfect hobby to pick up. It's free if you already own a computer, and the time investment is not a discouragement when you're fighting boredom.
I chose to learn Python on a recommendation, and I can heartedly forward that recommendation to a beginner:
The learning curve is gentle, and the language is mostly pleasant and without too many distractions when you just need to wrap your head around how a for loop works.
I advanced quickly enough.

There was, however, one concept I struggled deeply with understanding: Classes.
Not the dark magic in the depths of class implementation grimoire, but simply the concept of classes as it appears on its surface.

My learning materials introduced classes with a cliché of this kind:

> Classes allow you to model objects directly in your code.
> Suppose you write some code that concerns your dog, Rex, who can bark. In that case, you could write:
@@pythoncode
```python
class Dog:
    def __init__(self, name, weight_kg):
        self.name = name
        self.weight_kg = weight_kg

    def bark(self):
        print("WOOF!" if self.weight_kg > 25 else "Woof")

```
@@
> You have now defined a `Dog` class and can do operations with your dog by simply writing
@@pythoncode
```python
rex = Dog("Rex", 35)
rex.bark()    
```
@@

Can you spot why the above is a bad introduction to classes to someone who have never encountered the concept? Take a moment and reflect on it.

In video game design there is a saying:
> Show locked doors before you show a key

The idea is that you can't understand a solution without understanding the problem it solves.
If you present the solution first, it can be hard to spot there was ever a problem to begin with. 

That's what my problem was when reading the example of Rex the Dog.
Not that I didn't understand how the code worked, the class in the example sure does look like a 35-kilogram dog named Rex that can bark.
But do you know what also looks like a 35-kilogram dog named Rex that can bark? Two variables and a function:

@@pythoncode
```python
def bark(weight_kg):
    print("WOOF!" if weight_kg > 25 else "Woof")
    
name = "Rex"
weight_kg = 35
bark(weight_kg)
```
@@

Compare the two code snippets above. They are functionally identical.
The latter is much shorter and direct to the point.
To a student who already learned functions and variables, it introduces no new syntax or rules.
And please do pause and reflect on how bizarre and unintuitive Python's class syntax is: `__init__`? Really?
And what is even `self`? Why is a function with no arguments defined as one with one argument?
And what's the functional difference between `bark(weight)` and `dog.bark()`?

In every way then, the second code snippet is better code. And so I assumed I just didn't _get_ classes.
I assumed that, if Python classes had a raison d'être, they _had_ to have some special behaviour I just couldn't see!

Viewing from the present, it's clear I got the assumption wrong.
Sure, classes do unlock some new behaviour that cannot be achieved without the use of classes, but that is not why classes are useful.
In fact, nearly all the classes I write nowadays don't do anything that could not be achieved with built-in types and function calls.

The problem with the example of Rex the Dog is that classes _are not about_ being able to represent your dog.
It's about something completely different. Encapsulation, modularization, abstraction - let's not pick nits about the precise meaning of these terms, they are all about the same thing, really:
Managing complexity of your own code.

## Software is not unlimited
As an artifact, software is quite different from the physical creations of other crafts:
Producing it consumes no raw materials. It requires no specialized tools to manufacture even the highest quality code.
The product has no weight, and its physical distribution is almost effortless.
There is almost no cost to producing millions of copies and shipping them all around the world.

So, without these constrains, is software unbounded, infinite?
No, it is held back by other constrains. Sometimes software is constrained by the physical capability of the machines it runs on, disk space, memory usage or speed of computation.
I don't want to discount these physical constrains: After all, much of what I've written on this blog is about performance.
But mostly, software is bounded by its creation process: Programmers have limited time to create, and especially limited time to maintain, code.

See, maintaining code, for example by fixing bugs, requires the programmer to _understand_ the inner workings of the code in detail.
The more code there is and the higher the complexity, the longer time it takes to understand, and the more bugs the programmer adds due to their failure to comprehend what is happening, or could happen, when the code is running.

It's not that software is cursed by being particularly hard to understand compared to other creative products of labour.
It's the absence of other barriers that allows programmers to _create and create and create_, until we have a thing with more moving parts than any physical device we could ever construct, and keep creating, until we can't keep our own creation in our heads and get slowed down in a mire of complexity and run out of time.

And _that's_ why classes are important in Python. They help us get our programs a little more under control as they grow.
I didn't know as a beginner, because I hadn't experienced the complexity of one of my programs snowball out of control.
I had never seen a locked door and so I didn't understand why anyone would want a key.

I've since had the fortune to teach Python to other beginners.
In those courses, I've prioritised tasking the students with a large personal project at the end of the course, even when it means having to make cuts elsewhere in the curriculum.
This provides a unique opportunity when supervising the students to show, not tell, how good coding practices can help untangle their spaghetti code and retake control of their project that is sinking.

## A Python with no classes
What then, would happen if we were to ban classes from Python?

Oh, it would make the language so much _simpler_! As in my example of Rex - what's left would be pure _domain logic_, business logic, the real deal!
Almost no code wasted on boilerplate or ceremony!
There would be less weird syntax to teach, not this roadblock for newbies like myself to get stuck on when learning.
Best of all, there would barely be any loss of functionality, since classes mostly don't get you any new behaviour!

What would also happen, probably, is that users would find the number of variables would get out of control. Until one day, some programmer gets the neat idea that they could reduce the number of variables to keep inside their head if only they grouped variables in a `dict`:

@@pythoncode
```python
def bark(dog_dict):
    print("WOOF!" if dog_dict["weight_kg"] > 25 else "Woof")

rex = {"name": "Rex", "weight_kg": 35}
```
@@

And so they would have accidentally re-introduced classes, only this time the existence of classes would have been implicit in the code, and their behaviour ad hoc defined, their invariants spread all over the source files, and with no language-level tooling or introspection to help the programmer. Classes would still exist, but as implicit patterns.

These kinds of structures emerges spontaneously and constantly, _all over_ code.

Programming languages used to not support functions, but then it was discovered that instructions tended to be grouped in blocks by their functionality, and that conceptualizing it as a function made the code easier to reason about.
The introduction of functions did not make programming more complex, on the contrary, it became simpler in the way that matters.

Languages used to not have structs, but then programmers discovered the usefulness of grouping sets of data into an abstract, higher-order kind of data called a struct.
And again, this feature did not make programs more complex, but made them simpler.

Compared to the languages of those times, modern programming languages are crammed to the brim with features.
I happen to personally like Rust and Julia, both languages that are (in)famously complicated and featureful.

Julia has a complicated type system. Types like `AbstractSet{Union{Nothing, <:Integer}}` are not simple to learn to parse, or trivial to reason about in existing code.
But the structure of this type, and thus its complexity, is merely an instantiation of the programmer's intent about the data it represents.
With a simpler type system, that type would not exist, but the same intent would be there, nonetheless.

Python used to not have a type system rich enough to express a concept like that, and so programmers, when reading Python, had to work out for themselves that a particular variable _implicitly_ conformed to the constrains of that type - if the reader was lucky, this information could be read from code comments, but most often this knowledge could only be gained by keeping inside your head all the implicit assumptions the surrounding code made about the variable.

And it fucking sucked.

Not co-incidentally, recent versions of Python have introduced type hints backed by a complex type system, such that programmer can now express the very same idea as `collections.abc.Set[Option[numbers.Integral]]`.
And despite the complexity of this new type system, Python is better off for it.
In fact, my best experience with Python since learning Julia has been opening up an old Python code base of mine, annotating everything with type hints, and running a type checker on it.

Famously, Rust's compiler enforces the concept of "ownership" - the concept that one piece of data can be responsible for another piece of data.
But Rust did not invent the concept: It's one of the central ideas underpinning object orientation, decades before Rust appeared.
Julia the language has no concept of ownership, and yet the docstring for `FASTA.Record` says:

```
│ Warning
│
│  Note that the ownership of data is transferred to a new record object.
│  Editing the input data will edit the record, and is not advised after
│  construction of the record.
```

See? Julia _does_ have a concept of "ownership", just not, you know, in the actual language.
But a programmer using `FASTA.Record` must keep track of who owns its data, and this mental bookkeeping makes `FASTA.Record` harder to use by making code about it harder to follow.
The complexity of Rust's ownership model is not _added_ to an otherwise simple program, it is merely the compiler being extremely pedantic about your code obeying rules it had to obey anyway.

## "A simple language"
That's what it says in big bold letters near the top of the Zig language web page.
Zig is a recent experiment in cutting away all this derided complexity which plagues modern programming languages.
Closures, function traits, operator overloading - programming is hard enough to begin with, why can't we at least program in a _simple_ language, without all that crap?

Zig honestly seems like a cool language, and I'd like to learn it one day, but I can't say its simplicity is its most attractive quality.
Below the header, the website reads:

> Focus on debugging your application rather than debugging your programming language knowledge.

Why would I want that? The entire point of modern language complexity is to _reduce_ the amount of debugging needed for your application, because its complexity is properly managed by the language.

Zig uses manual memory management, and does not have the same compile time guarantees about memory safety as Rust.
Meaning of course that sure, compared to writing Rust code, it's probably simpler to write Zig code that compiles, but crashes at runtime, after which you get the joy of focusing "on debugging your application".

To me this is a trick of words: The difficulty in figuring out how to satisfy e.g. ownership rules in Zig is, by mere convention, debugging the "application", whereas the same difficulty in Rust would be debugging the "programming language".

Zig, of course, is not the first language to explicitly seek simplicity. Go did it before Zig, with much of the same motivation: Get the language out of the way.
And in some way, they were successful. Go is heralded as an easy language to learn.
But on the other hand... well, let me end on the the words of [someone else:](https://fasterthanli.me/articles/i-want-off-mr-golangs-wild-ride)

> Over and over, every piece of documentation for the Go language markets it as "simple".
> This is a lie.
> Or rather, it's a half-truth that conveniently covers up the fact that, when you make something simple, you move complexity elsewhere.

## Post script
A post of the format "In defense of ..." does not have a lot of room for nuance, but of course the issue in this post is not clear cut on way or the other.
"More language features" does not equal "more better", and the detractors of modern language complexity do have points that are worth considering, at least in isolation.

All the language features in the examples above - classes, advanced types, and the borrow checker - have an important trait in common:
They all feel like they _emerge spontaneously from existing code_ independently of whether the language designer has thought about them.
In that sense, they are the best kind of feature; instead of adding new things to worry about, they merely provide a vocabulary and tooling for dealing with already existing problems.

Not all language features are like this.
For example, Julia has four different ways of defining a function, and just as many variations on how a for loop looks.
One can define a type to be a `struct`, `mutable struct`, `abstract type` and `primitive type` (all the former possibly parametric).
Types can be placed in the type hierarchy as either concrete types, abstract types, union types or unionall types.
The _representation_ of types (i.e. type of types) can be either `DataType`, `Union`, `UnionAll`, or `Bottom`.

This complexity is not completely _redundant_ as such, but it sure is a mouthful to learn, and it's to clear to me this design is the cleanest. Surely, it feels like, [this did not need to be so complicated](https://github.com/JuliaLang/julia/issues/29368).

The worst kind of features are duplicated APIs, usually because an old, poorly designed API sticks around only to satisfy backwards compatibility and perhaps a small group of users refusing to stop using it.
I don't have any love for this sort of complexity in a language, and people are right to eschew it.

On an even more fundamental level, however, the detractors are right that even justified complexity in a language does impose a cost on users.
I like Rust, but I can't write it for more than two hours without beginning to wish I wrote Julia instead, because of the compiler frustrating my attempts to just _write some goddamn code that works_.
Even if a strict compiler only enforced the invariants you would otherwise manually enforce, compilers are obtuse, and extremely hard to persuade that no, this anti-pattern is actually appropriate in this situation.
When a program's structure is freely controlled by humans, the humans can choose shortcuts and simple solutions: Rex the Dog could stay just two variables, and there really would be less boilerplate, even if there would also be some land mines.

This post began with me recommending Python to a programming beginner, and not co-incidentally.
Languages already require a large time investment to learn, and a language with _more stuff_ crammed into them, even well-designed stuff, requires an even larger investment.
Large Python projects are infamous for ossifying by being crushed under their own un-manageable weight, but on the flip side, picking up Python requires relatively little.
I certainly would not recommend Rust as anyone's first language.

It's easy to empathize with the dilemma of managers responsible for a team of programmers in a green field project, who face the choice between spending months worth of salary onboarding new recruits who have to learn a hard language, half of who then leave, or instead picking an easier language they can get started on quickly.

So, with disadvantages and advantages to the complexity of modern programming languages, what should one conclude?
I'm afraid there can be no satisfying conclusion to this blog post.
While I don't believe the answer is simply a matter of _opinion_, it's not exactly a matter of _fact_, either. The only resolution is for us as professionals to use our judgement.
