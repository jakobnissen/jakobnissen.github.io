@def rss = "A look at a Mojo benchmark for bioinformatics, and Mojo in general."
@def rss_pubdate = Dates.Date(2024, 02, 09)

# Parse, don't validate (in Python)
_Written 2024-02-09_

One of the writings that most influenced me, where she introduced a defining creed of type driven development.
However, she wrote it from a background programming Haskell, differs from my scientific programming w. dynamic languages. That matters because some of the concepts don't translate directly, and also because Haskellers pretty much have already bought into type driven design. 
The lessons are not langugae-specific and still applies to Python (why I find the post useful)

This post is a tribute to the original, a restatement of the same ideas, but from my vantage point.

My programmer career grew up among scientists where almost 
Scientists think a lot abount algorithms and very little about the structure of the data they operate on.
Things are mostly given a type because it's got to have _some_ type. In scientific code it's common to see: [do not following as list]
* values which have different types inside a function while still being the "same" logical thing
* booleans and enums represented as strings ("true", "false")
* 'unusual types', such as a dict with strings as keys and functions as values.

When I review their code, my most common questions are: "WHat type is this value supposed to be",
and "what does this type actually mean in your program?".
I get these blank states, and it's clear they view my question as either some comp sci purity test,
or else an unimportant implementation detail.
That's not what I want to convey at all: I ask it to know what they code is intended to do, and what data the program works on.

Alexis post gave a name to the idea I already knew: "Type driven design".
Like other design principles such as data driven design or object oriented programming, the term itself is almost too broad and vague to be concretely useful.
Recognizing this, the Alexis' post centers around a concrete piece of advice that can be summarized in three words: Parse, don't validate.

This catchy slogan doesn't explain much if you aren't familiar with type driven design, and so the rest of this post will explain what it means.

I love the Python type system. One of the main uses is that it allows your editor to tell you if the function you just wrote does what you think it does.
For, if I wrote the following code:

```python
SCIENTIFIC_NAME_TO_TAXID: dict[str, int] = ... # elided from example

def get_taxid_from_scientific_name(scientific_name: str) -> int:
    # Normalize case, and whitespace
    name = "_".join(scientific_name.strip().split()).lower()
    return SCIENTIFIC_NAME_TO_TAXID.get(name)
```

My editor would immediately flag that the `dict.get` call returns `int | None`, and that the `None` case it not covered.
This type error translates to a logical problem in my code: "What if the caller passed in a species which is mistyped, or is not in the list of known species"?

Let's go even simpler. Suppose I want to create a function that takes the first element of a list. Is that possible? It seems oviously posible - I could make it like this:

```python
def head[T](x: list[T]) -> T:
    return x[0]
```

And indeed, my type checker approves this.
But look carefully - does this function always return the first element of the list? No:

```python
>>> head([])
Traceback (most recent call last):
  File "<python-input-1>", line 1, in <module>
    foo([])
    ~~~^^^^
  File "<python-input-0>", line 2, in foo
    return x[0]
           ~^^^
IndexError: list index out of range
```

If `x` is empty, it doesn't return its first element - it throws an exception and doesn't return at all!
Is this case, the reason the type checker doesn't complain is sneaky: If `x` is not empty, the function returns a `T`, and we're all good. If the list _is_ empty, the lack of function return is inferred as `Never`, and so the return type is `T | Never`... which is the same as just `T`.
In other words, in ther case where `head` throws and does not return, it has _no_ return value, and therefore, the throwing is ignored by the type system.

So surprisingly, we learn that a signature `head(...) -> T` does **not** mean the function always returns a `T`!
We might find it unsatisfying that throwing is invisible to the type system.
After all, as shown by the example with mapping scientific names to taxids, encoding error paths into the type system is helpful for preventing mistakes by the caller.
Can we change `head` to encode the case when `x` is empty? Of course we can!

```python
from dataclasses import dataclass
from typing import Generic, TypeVar

T = TypeVar("T")

# Lightweight wrapper, used to distuingish None (no value found)
# from Some(None) (the value None found)
@dataclass(frozen=True, slots=True)
class Some(Generic[T]):
    value: T

def head[T](x: list[T]) -> Some[T] | None
    return Some(x[0]) if x else None 
```

We can call this pattern "error type".
Note that using an error type is _not_ always preferable to throwing.

If you tried to encode every single error case with a type, a single top-level function call could return hundreds of types, one for each of the ways it might error.
That's clearly not workable; realistically speaking, in a huge amount of error paths, the caller can't really do anything with the error value other than ending the program with an error message.
In those cases, having the callee throw simplifies the program since the caller may assume it's given a `T` and not worry about the error case.

Here, Rust provides an instructive lesson in language design: It has no ability the throw, and uses error types pervasively.
As a consequence, it's idiomatic in Rust apps to use the anyhow crate, which provides a single opaque error type. If this type is encountered, it's passed up through the entire call than, ending the program.
It looks like they have accidentally invented a worse type of exception!

So: When should you choose to throw, and when should you choose the error type approach?
It depends on what the program should do when the error is encountered. If the program should quit with an error message, you might as well throw.

In the example of `head`, this code is generic and might be used in all kinds of contexts, so we don't know what should happen on the error paths.
We don't even know what our `list[T]` represents, so how could we throw an informative eerror>

So in this example, using the error type is the better design.
It allows the caller to decide how to handle the error - possibly by throwing an exception.

So, problem solved right? Not quite.
Pushing the responsibility of handling the error to the caller can be frustrating and lead antipatterns.
Consider the following example. 

```python
import os
from pathlib import Path

def get_configuration_paths() -> list[Path]:
    dir_string = os.getenv("CONFIG_DIRS")
    if dirs is None or not dirs.strip():
        raise RuntimeError("Env var CONFIG_DIRS not passed or whitespace-only")
    return [Path(i) for i in dir_string.split()]

def main():
    config_paths = get_configuration_paths()
    primary_config = head(config_paths)
    if primary_config is None:
        assert False, "We already validated at least one config path"
    do_stuff(primary_config)
    ...
```

When we get the configuration paths from the environment variable, we check it's set and non-empty.
However, when we _use_ the the paths in `main`, to get the primary path, we still have to handle the error path that we know can't happen.

This is terrible, for several reasons:

1. It's annoying. We already checked at least one config path was passed. Why do we have to check it again?

2. Second, it has a performance cost. While the `is None` check is very cheap, and these kinds of performance considerations don't matter in a language as slow as Python, we could imagine a similar example, where such a check is running in a tight loop in a fast language.

3. Finally, and worst of all, this is a bug waiting to happen! What if `get_configuration_paths` was changed and no longer checked the list was empty? In that case, our "impossible" error becomes not only possible, but probable. In this case, the user will get an incomprehensible error message.

Clearly, the error type approach used by `head` leaves something to be desired.
Somehow, we'd like to to it in a smarter way: We already checked that the list was not empty, and so `head` should _unconditionally_ return its first element, without a risk of throwing, and without returning a senseless `T | None` value, whose type does not reflect the fact that `None` is actually impossible.
How can we do that?

The problem is in our `get_configuration_paths` function. It returns a list which it promises is not empty, but this information is not captured in the type system.
It returns a `list[Path]`, and lists have no guarantees that they are not empty.

The solution is to represent our non-empty list of configs with a type, _which carries the guarantee with it_. For example, we could do:

```python
import os
from pathlib import Path
from dataclasses import dataclass

@dataclass
class ConfigPaths:
    primary: Path
    secondary: list[Path]

def get_configuration_paths() -> ConfigPaths:
    dir_string = os.getenv("CONFIG_DIRS")
    if dirs is None or not dirs.strip():
        raise RuntimeError("Env var CONFIG_DIRS not passed or whitespace-only")
    paths = [Path(i) for i in dir_string.split()]
    return ConfigPaths(paths[0], paths[1:])

def main():
    config_paths = get_configuration_paths()
    do_stuff(config_paths.primary)
```

Note that the redundant check is completely gone! The _original_ check is still there, but only once, right at the point where we obtain the data from the environment variables and do input validation.
Once that check has passed, we now have a `tuple[Path, list[Path]]`, which on a type level _guarantees_ that we have at least one path.

By strengethening the promises of the return type of `get_configuration_paths`, we eliminated all the issues from the previous section:
* The code has no redundant checks so there's no performance cose.
* Furthermore, if `get_configuration_paths` is changed to no longer check if the list is empty, its output type `ConfigPaths` must also change to not contain a `Path`, and so the type checker will alert us immediately, before the code is even run!

Furthermore, should we want a `list`, we can easily make it from a `ConfigPaths`: `paths = [config_paths.primary] + config_paths.secondary`.
However, we the inverse is not true! We the only way we can obtain a `ConfigPaths` from a list of paths is to do another check, which reintroduces the problems mentioned above.

## The power of parsing
You may be wondering what all the words above have to do with the creed "parse, don't validate".
We've been through a discussion of types, but there hasn't been a parsing in sight.

Or has there? In my opinion, the difference between parsing and validation lies entirely in how information is preserved. Consider the difference between this pair of functions:

```python
def validate_non_empty[T](x: list[T]):
    if not x:
        raise ValueError("List cannot be empty")

def parse_non_empty[T](x: list[T]) -> tuple[T, list[T]]:
    if not x:
        raise ValueError("List cannot be empty")
    return x[0], x[1:] 
```

These two functions are almost identical: They both check if the input list is empty, and if it is, thy throw an exception with the same error message.
The diffence lies entirely in the return type: `parse_non_empty` checks for emptiness, and then preserves the information it has gained by returning a type that guarantees at least one element, and hands that information, encoded in the type, back to the caller.
In contrast, `validate_non_empty` does the same check, and gains the same information, but then throws that information away.

Both these functions obey the type checker, but only the `parse_non_empty` takes full advantage of it.
If you see why `parse_non_empty` is preferable, you understand the creed "parse, don't validate".

Still, perhaps you are skeptical of `parse_non_empty`'s name.
Does it really _parse_ anything, or does it just do a check, and then encode the information in the return type?
While the precise definition of a parser is debatable, I believe `parse_non_empty` is a _bona fide_ parser, although albeit a simple one.
