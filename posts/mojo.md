@def rss = "A look at a Mojo benchmark for bioinformatics, and Mojo in general."
@def rss_pubdate = Dates.Date(2024, 02, 09)

# A look at the Mojo language for bioinformatics
_Written 2024-02-09_

A few days ago, [a blog post](https://www.modular.com/blog/outperforming-rust-benchmarks-with-mojo)
was posted on the website of [Modular](https://www.modular.com/blog/outperforming-rust-benchmarks-with-mojo),
the company behind the new high-performance programming language [Mojo](https://www.modular.com/max/mojo).

The post made the case for using Mojo in bioinformatics due to Mojo's dual features of being high-level language with high performance,
and the blog author substantiated the case by presenting two benchmarks related to the processing of [FASTQ files](https://en.wikipedia.org/wiki/FASTQ_format),
showing impressive speed.

As a bioinformatician who is obsessed with high-performance, high-level programming, that's right in my wheelhouse! I decided to dig deeper into the benchmark, and this post is about what I found out.

@@toc-header Table of contents@@
\tableofcontents

## What's the blog post on about?
The basic premise of the post is that the field of bioinformatics is struggling to handle its increasingly large datasets.
These datasets are so large that they have to be processed programmatically,
but programming is the field is split between high-level dynamic languages used to do the actual data analysis,
and the high-performance, static languages that Python calls into to do the computation underlying the analysis. As the post states:

> This creates a two-world problem where bioinformaticians who are not skilled in low-level languages,
> are prohibited from understanding, customizing, and implementing low-level operations.

The blog post goes on to suggest Mojo could bridge the gap between the two worlds, by being a "Pythonic", but fast language.

I have a lot more to say on the topic of the two-language problem in bioinformatics, so much that I'll reserve it for another blog post.
In summary, I wholeheartedly agree with that analysis, except that I'd encourage using Julia rather than Mojo.

The post then describes how the author implemented a benchmark in Mojo and managed to beat a fairly optimised Rust library.
That certainly made me curious, so I cloned [the git repo with the Mojo code](https://github.com/MoSafi2/MojoFastTrim)[^1] and took a look myself.

## On Mojo
After cloning the repo, the first step is to download and install Mojo:

@@shellcode
```plaintext
$ curl https://get.modular.com | sh - && \
modular auth [MY AUTHENTICATION CODE]
[...]
Sorry, this system is not recognized. Please visit https://www.modular.com/mojo to learn about supported platforms. You can also build and run a Mojo container by following instructions at https://github.com/modularml/mojo
```
@@

Well, that's disappointing. Apparently, Mojo currently only runs on Ubuntu and MacOS, and I run neither.
So, I can't _run_ any Mojo code, but must rely on just _reading_ the code.
Fortunately, the code is quite simple, and only a few hundred lines of code.

### First impressions
At first glance, it's clear that _Mojo isn't anything like Python_.
Here are some things that I found in the few hundred lines of the supposedly Pythonic language:

* Generic functions parameterized by type parameters: `fn foo[x: T](arg: Int)`
* Speaking of which, two distinct function definitions: `def foo` vs `fn foo`
* ...and different kinds of integers, here `Int` as opposed to `int`
* Mutable vs immutable variables, initialized by `var x: T = y` vs `let x: T = y`
* Also, type declarations before assignment, C-style: `let foo: T`
* _Mandatory_ type declarations in type signatures: `fn foo(x: Int)`
* Mutability declaration of arguments via the `inout` keyword: `fn foo(inout self)`
* The ability of a function to raise errors must be marked with the `raises` keyword
* Data can be stored in `struct`s as well as `class`es.
* Compiler directives, notably `@always_inline` to control inlining heuristics

Mojo apparently even implements a [Rust-style borrow checker](https://docs.modular.com/mojo/programming-manual.html), though I couldn't tell from just reading the code.

Does this strike you as the features of a high-level, dynamic language?

On one hand, the presence of low-level features is reassuring.
When Mojo was initially announced, I didn't quite understand what Mojo was supposed to be.
Was it supposed to be a faster Python implementation, like PyPy?
Or perhaps a compiler to optimise selected parts of Python, like Numba?
That left a lot of questions with me about how they were going to pull that off given that neither PyPy nor Numba can reliably produce fast code.

Well, it looks like it's neither - instead, it's a _different, static language_ that presumably aims to provide excellent interoperation with Python.
That's a _much_ more doable proposal! There is no reason to doubt that a static language can reliably generate fast code.
And it could still provide great value for Pythonistas by essentially being a better version of Cython that they can selectively reach for when they have a need for speed.
Especially so if Mojo can provide a kind of gradual performance where users from a Python background can gradually and selectively opt into each of these features as they get more familiar with lower level computing.

On the other hand, it's also a much less exciting vision to provide a fast static language with good interop, compared to smashing [Ousterhout's dichotomy](https://en.wikipedia.org/wiki/Ousterhout%27s_dichotomy) by providing a dynamic language that is also fast.
It does make me question the use case somewhat.
After all, static languages can already interoperate with Python relatively easily, e.g. with Rust's crate PyO3.
Presumably, Mojo's interop is going to be even easier. But is the improved interop going to outweigh the benefits that come from designing a language to be ergonomic on its own terms?

On that point, I don't really buy the idea that Mojo benefits terribly much from being "Pythonic" - which presumably means that its syntax is inspired by Python.
What's the claim here, really? That it'd be _too hard_ for people to learn the superficial syntax of a new language, while it'd simultaneously be _easy_ for people to learn about function monomorphization, copy- vs borrow semantics, compiler directives and much more?

The main intended application of Mojo appears to be deep learning, which has struggled with the same 'two-language problem' as bioinformatics, since models are prototyped in Python but all the tensor operations are written in C++ or CUDA.
It's not clear to me how Mojo is going to change the game there, though. It doesn't seem like Mojo can replace a framework like PyTorch, since those are at entirely different levels of the stack.
Can it integrate into PyTorch, such that tensor gradients are preserved across Mojo functions? That would allow users to keep using PyTorch while implementing a single custom kernel in Mojo. But it's seems unlikely Mojo is compatible with PyTorch's C++ interface.
Perhaps Mojo is aimed at being a language suitable for developing new, future frameworks from scratch when people are ready to ditch the existing Python ecosystem? But if that's the goal, you might as well ditch Python entirely and all its 35-year old baggage and come to Julia for a clean start.

Let me also say some nice things about Mojo.

First, judging by the language features I listed above it should be clear that Mojo is extremely serious about performance.
This is not some PyPy-like attempt to speed up vanilla Python _somewhat_, this is an attempt to make a language that is _actually fast_.
Second, Mojo's built-in SIMD capabilities are enviable. It might make a big difference if developers are pushed towards writing SIMD-friendly code by default.
Also, keep in mind I probably just don't understand the intended use case of Mojo. I haven't paid _that_ close attention to how Mojo is intended to be used, and I probably won't, until I can get my hands on Mojo and run it on my own computer.

## DNA sequencing: The birds-eye view
Before we get back to the benchmark, we need to understand _why_ the work done in the benchmark is meaningful. Well, we don't _need to_, but I find it interesting because it's my field of research, so let's take a detour into DNA sequencing.

Most people know that biological inheritance is controlled by DNA[^2].
DNA is a linear polymer  molecule of consisting of _nucleotides_ stringed together in a chain, with each nucleotide containing one of four distinct _bases_ which are abbreviated A, C, G or T. A DNA molecule can therefore be faithfully represented by a sequence of symbols, e.g. a string such as `TAGGCTATGCC`. Thus, DNA is a type of _digital_ storage that controls much of how living organisms are built and how we behave. Reading the sequence of a physical sample containing DNA molecules is called _sequencing_, and is done by machines called  _sequencers_.

Incidentally, the applicability of the field of bioinformatics stem from these facts: 1. That much of molecular biology can be explained by the polymer molecule DNA (and RNA and protein), 2. That these polymers are easily and faithfully represented in a computer, and 3. That it's possible to construct sequencers which can computerize massive amounts of these polymers cheaply. Biochemistry on Earth didn't _have_ to be this amenable to analysis, and we're very lucky that it happened to be so.

There are different competing sequencers with different characteristics, but let's focus on the machines produced by the company Illumina, which currently dominate with around 80% market share.
Illumina sequencers uses a chemical reaction to read DNA linearly from one end of the molecule. The output of reading one molecule of DNA is termed a _read_. Due to imperfections in the chemistry, the chemical reaction deteriorates to unreadability after around 150 bases, putting an upper limit on read length that is far too low to sequence full DNA molecules, which in humans are on the order of 100 million bases (100 Mbp) in length.
To overcome this limitation, the DNA is broken apart to smaller fragments of around 500 bp, e.g. using ultrasound, and tens of millions of these fragments are then sequenced in parallel. Because we expect the sample to contain many near-identical DNA molecules that are fragmented independently and randomly, we can reconstruct the entire original sequence by merging partially overlapping reads, if only we sequence sufficiently many reads from each sample to ensure uniform coverage of the original sequence.

The number of reads is typically expressed in _depth of coverage_ (or just _depth_), which is the average number of times each position in the original DNA molecule is present across all sequenced reads. A typical experiment might target ~2 % of the human genome's total size of 3 Gbp and aim for a depth of 100x, producing around 5 Gbp of data. With a read length of 150 bp, this is around 35 million reads.

Sequencers typically output the reads in the FASTQ format, which is a simple ASCII-encoded format[^3].
One read in FASTQ format looks like this:

```plaintext
@HWI-ST180_0186:3:1:1484:1936#GGCTAC/2
GAGATCTCCAGCATCTGGGCGAGCGCGGCCTGACTGAACCCGCGTTCGCTCCGGAGTTGACGAAGGCGCCCTCAAACGTACGTTTTTGACACGTCGCGAG
+
defegg___adefbdhfdadbeffffggfgggaeaf_cffga\_a_babbZbbXdddT_\c_cccca_TbBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB
```

That is:
* A read is always composed of four lines.
* The top line starts with `@` and contain a unique identifier of the read. It has no other restrictions. In the example read above, the name encodes a bunch of metadata about where the read originated.
* The next line contain the DNA sequence.
* The third line starts with a `+` and then may optionally repeat the same string as after the `@` on the first line
* The fourth header line contains the quality. This line must be the same length as the DNA sequence. It gives the estimated probability that the given DNA nucleotide is wrong. There are different encoding schemes, but by far the most common is Phred+33, where the error probability is:

$$p = 10^\frac{33 - c}{10}$$

Where $c$ is the ASCII value of the symbol in the quality line.

A FASTQ file is then simply the concatenation of multiple reads like the one above.
Since a research project may contain terabytes of FASTQ files, having a fast parser is important.

## The FASTQ benchmark
The Mojo blog post implements two benchmarks - I will only focus on one of them here. That's the FASTQ parsing benchmark, which is taken from one of [the biofast benchmarks](https://github.com/lh3/biofast).
The task is simple: Given a 1.4 GB FASTQ file with ~5.5M reads, count the number of reads, number of bases, and number of quality characters, by using a parser to loop over the individual reads in the file.

Currently, the Needletail parser, written in Rust, tops the benchmark. On my four year old laptop, it rips through the file in 458 ms, about 3.05 GB/s. In comparison, my own `FASTX.jl` parser written in Julia is under half the speed, taking 986 ms (1.42 GB/s). I'll get back to discrepancy later.

### The mojo implementation
Since I can't time the Mojo implementation myself, I'll use the numbers from their git repo. It lists Needletail taking 0.27s versus 0.21s for Mojo on a more modern, faster machine than my own. If we assume Mojo ran with the same relative speed versus Rust on my machine, it'd clock in at 356 ms (3.92 GB/s).

Nearly four GB/s is crazy fast. How does it do it? Let's dive into the Mojo code.

The `main()` function is defined as:

```
fn main() raises:
    let vars = argv()
    var parser = FastParser(vars[1], 64 * KB)

    # Parse all records in one pass, Fastest
    parser.parse_all()
    print(parser.parsing_stats)

    [some outcommented code...]
```

Where nearly all the work happens in `FastParser.parse_all`. That is defined as

```
fn parse_all(inout self) raises:
    while True:
        self.parse_chunk(self._current_chunk, start=0, end=self._chunk_last_index)
        try:
            self.fill_buffer()
            self.check_EOF()
        except:
            break
```

The `fill_buffer` function seeks to the right location in the underlying file, then fills the internal buffer of `FastParser`. Either that or `self.check_EOF` can raise a (non-specific) `Error` on EOF, which breaks the loop in `parse_all`.

I'm not crazy about the mandatory seeking of `fill_buffer`. This happens if there are extra unused bytes in the buffer. Instead of copying them to the beginning of the buffer, the reader rewinds the underlying stream and simply re-reads the bytes from the stream - but what if the parser wraps a non-seekable stream? In any case that's not important - it could probably be solved with almost no performance cost.

The function `parse_chunk` parses all the reads in the current buffer. Its definition is:

```plaintext
@always_inline
fn parse_chunk(inout self, chunk: Tensor[DType.int8], start: Int, end: Int) raises:
    let read: RecordCoord
    var pos = 0
    while True:
        try:
            read = self.parse_read(pos, chunk)
            self.parsing_stats.tally(read)
        except:
            raise Error("failed read")
        if pos >= end - start:
            break
```

Here, the `.tally(read)` method increments the read number and number of bases seen. The cost of that is insignificant. The exception is expected to be raised when the buffer reaches the end, such that the remaining part of the buffer only contains a partial read.

Also note the lack of any kind of error handling here. No matter why `parse_chunk` throws, it's caught in `parse_all` and terminates the reading without propagating the error or examining what kind of error it is. The same issue is repeated further down the call chain.

Most work here happens in `parse_read` where the real parsing happens:

```plaintext
@always_inline
fn parse_read(
    self, inout pos: Int, chunk: Tensor[DType.int8]
) raises -> RecordCoord:
    let start = pos
    let line1 = get_next_line_index(chunk, pos)
    let line2 = get_next_line_index(chunk, line1 + 1)
    let line3 = get_next_line_index(chunk, line2 + 1)
    let line4 = get_next_line_index(chunk, line3 + 1)
    pos = line4 + 1
    return RecordCoord(start, line1, line2, line3, line4)
```

That's the secret sauce, really. Each read is parsed by scanning four times to the next newline, then emitting the positions of the newlines with zero validation of any kind.

I'm sorry but this is not a serious parser.
To be fair, the repo is pretty clear that:

> Disclaimer: MojoFastTrim🔥 is for demonstration purposes only and shouldn't be used as part of bioinformatic pipelines

However, in my opinion, this lack of validation (really, lack of _parsing_ in any meaningful sense) means that the performance between this parser and Needletail is incomparable. So what exactly does it demonstrate? You get to claim your implementation is faster than someone else if you do the same task in less time, but not if you skip half the job.

Anyway, `get_next_line_index` is kind of neat. First, it statically checks if SIMD is enabled. If so, it calls `find_chr_next_occurance_simd`, which is essentially an implementation of [`memchr`](https://man7.org/linux/man-pages/man3/memchr.3.html). It's implemented as:

```plaintext
@always_inline
fn find_chr_next_occurance_simd[
    T: DType
](in_tensor: Tensor[T], chr: Int, start: Int = 0) -> Int:
    """
    Function to find the next occurance of character using SIMD instruction.
    The function assumes that the tensor is always in-bounds. any bound checks should be in the calling function.
    """
    let len = in_tensor.num_elements() - start
    let aligned = start + math.align_down(len, simd_width)

    for s in range(start, aligned, simd_width):
        let v = in_tensor.simd_load[simd_width](s)
        let mask = v == chr
        if mask.reduce_or():
            return s + arg_true(mask)

    for i in range(aligned, in_tensor.num_elements()):
        if in_tensor[i] == chr:
            return i

    return -1
```

Here we see Mojo's nice SIMD abstractions. First it uses `math.align_down` to get the last index from which it's safe to load a SIMD vector. The `simd_width` is automatically computed as `simdwidthof[DType.int8]()` and is presumably a compile time constant, so I assume its value is constant folded.
I think that's pretty cool.

In the first loop, each vector (`mask`) is then loaded and compared to the byte `chr`. If any of the bytes are true, then `arg_true` is called (which loops over the vector to find the first true).
I'm guessing this loops compiles effectively to a `vmovdqu` load instruction, and the reduction can be expressed as `vpcmpeqb` (compare vector to byte), `vpmovmskb` (extract upper bits of each byte in vector to a 32-bit integer), and then a comparison to zero.

The function `arg_true` could be compiled to a single `tzcnt` instruction, but when I tried to emulate it in Julia I couldn't get the compiler to realise that, though that may just be Julia not having the right SIMD abstractions.

Finally, the last elements of the chunk which can't be safely SIMD loaded are handled in the last loop. This is much less frequently hit, around once every 250 reads.

### A detour: How much should parsers validate?
The Mojo parser does zero validation and will even accept random bytes as input, which I think everyone can agree is not acceptable for real-life situations.
But how much validation _should_ a parser do? That's honestly a hard question to answer, and the performance you can expect from parsers hinges on the answer to that question.

Let's return to comparing Needletail and the FASTQ parser I maintain, FASTX.jl.
Needletail uses a quite similar algorithm to the Mojo parser: It uses a buffered reader and memchr's to find newlines before returning a record containing a view directly into the file buffer. However, it also handles `\r\n` newlines, and validates that the first and third lines begin with `@` and `+`, respectively, and that the seq and qual lines have the same length.
That's certainly more validation than the Mojo parser, but is it enough? If the quality line contains pure `\x00` bytes, how is this a valid FASTQ file? What if the header is `"@\r\v\r"`?

My own parser validates more - that the quality line is a printable ASCII character, that the sequence are ASCII letters, and that the second header is identical to the first.
That's achieved through parsing the file with a state machine, which can therefore be much stricter. It's also partially the reason it's slower than Needletail[^4].

On one side of the argument, one could say it's nice to provide as much validation as possible - suppose someone reads in a FASTQ file with non-ASCII sequences using Needletail, and the parser wrongly claims the seq and quality lines have a different number of symbols because they are encoded in a different number of bytes. That error is no good and will leave the user scratching their heads when they count the sequence and quality lengths and verifies that they match.
Wouldn't it be nicer to instead have the parser check that the input is ASCII?

Also in that favour - when do we ever need to parse files at 3 GB/s? What could we possibly _do_ to the files that will be anywhere near that speed? Surely dropping to 2 or even 1 GB/s will have essentially no impact on the overall speed of a real life analysis.

The other side of the argument is that parsers should do as _little_ validation as possible. For example, my parser spends time checking that the first and third headers of FASTQ reads are identical, because the format says so.
But what if a user has a record where they're not?
Does it really help the user to have their program crash with otherwise perfectly fine records? After all, a sensible idiom of parsing goes "be liberal in what you accept, and conservative in what you send". Maybe parsers ought to do as little validation as they can get away with while still ensuring they don't give garbage answers.

One could also say that during the course of a project, the same file might be read tens of times, but it really only needs to be validated once.
If the validation is a separate step from the parsing, it can be skipped all but the first time the file is read. In [a Reddit comment](https://www.reddit.com/r/rust/comments/1al8cuc/comment/kpgjkkd/?utm_source=share&utm_medium=web3x&utm_name=web3xcss&utm_term=1&utm_content=share_button) the maintainer of Needletail say they have an external tool to validate FASTQ files for this reason.
That's also reasonable, but it does strike me as un-Rust like to opt-in to validation, especially when the cost is so low - after all, my parser still does more than 1 GB/s.

### Matching the implementation in Julia
My claim is that Mojo's high speed in this benchmarks comes from the implementation and not from Mojo being particularly fast.
To back it up, I [ported the implementation to Julia](https://github.com/jakobnissen/MojoFQBenchmark) with all the same lack of error handling or validation. It's currently 78 lines of code, but to be fair, it does only the absolutely minimal necessary to complete the FASTQ benchmark.

It "parses" the file in 200 ms (6.98 GB/s), 78% faster than Mojo's (imputed) speed.
That's pretty fucking fast. `cat input.fq > /dev/null` takes 122 ms for comparison.

I think there is only one real conclusion here:

🔥🔥🔥JULIA🔥🔥🔥 IS FASTER THAN MOJO🔥!!!!111

Just kidding. I don't know why my implementation is faster - I don't strictly _know_ that it's even faster since I can't run Mojo on my own machine.
Maybe it's the fact that my implementation doesn't seek the underlying file, or maybe 200 ms is fast enough that Python's startup time begin to matter. If I include the time for Julia to start up and compile the script, my implementation takes 354 ms total, on the same level as Mojo's.

One interesting observation is that replacing the manual `memchr` implementation with a call to glibc's `memchr` slows it down by about 25%, despite glibc's `memchr` being around 70% faster when used on long haystacks. Julia's ccall has close to zero overhead, so I'm not sure what's up with that.

Maybe it's that `memchr` doesn't inline, whereas the manual implementation is forcefully inlined into `parse_read`. If so, this might explain most of the performance difference to Needletail. Removing the `@inline` directive from my Julia code slows it down about 20%.
Interestingly, setting `lto = "thin"` and `codegen-units = 1` in my Cargo.toml file reduces the runtime of Needletail to 357 ms, matching Mojo's imputed runtime nearly exactly.

These differences are trivialities. I don't know why my Julia implementation is twice as fast as Needletail, but subtracting the lack of validation, I doubt it's something substantial.
There are often real important reasons why some languages are faster than others - whether they provide good zero-cost abstractions for high-level data types, whether they provide good multithreading and SIMD support, how well they support generics and how well libraries compose together, how defensive vs adventurous they make programmers, and much else.
I don't think this Mojo implementation shows any of this.

## Closing thoughts
I don't want to coldly dismiss the Mojo blog post. After all, its two main points are essentially right: That bioinformatics needs a language to bridge high-level and high-performance programming, and that Mojo is capable of producing fast code. I don't put too much value in the actual reported numbers in the benchmark, but they don't matter in the big picture.
It's also feels a little like overkill to go to this length to tear apart a blog post from from a guy who is just excited about what Mojo could bring to bioinformatics.
It's just his bad luck that there are people like me out there - a bioinformatician who is passionate about high performance computing for science, maintain my own FASTQ parsing library, and is particularly sceptical about Mojo.

Introspecting, I think I'm a little oversensitive to Mojo's marketing hype. Ostensibly because the original Mojo announcements (and also this Mojo blog post), made a lot of bold claims that could be construed as hyperbolic, while keeping the compiler to themselves, giving it the smell of vaporware. But if I'm being honest with myself, it's probably because I'm so invested in the prospect of Julia for bioinformatics.

To me, Julia seems like _such an obvious_ solution to the two-language problem in bioinformatics (and in deep learning). All the hard problems with bridging speed and dynamism have essentially been solved in Julia.
At the same time, the language remains niche, mostly because it still has too many rough edges and usability issues, such as latency, the inability to statically analyse Julia or compile executable binaries.
But these issues are not fundamental to the language - they're rather in the category of ordinary engineering problems. Solving them is mostly "just" a matter of putting in tens of thousands of professional dev hours, which is a matter of getting tens of millions of euros to pay for hiring people to do the job.

It does grate me then, when _someone else_ manages to raise 100M dollars on the premise of reinventing the wheel to solve the exact same problem, but from a worse starting point because they start from zero _and_ they want to retain Python compatibility. Think of what money like that could do to Julia!

A bigger person than me might have an attitude of 'let a thousand flowers bloom' to solve the two language problem, and, sure, it's probable that Julia will learn from Mojo as Mojo already has learned from Julia. But I can't help the feeling that the two languages compete in a zero-sum game, at least to some extent.
When I talk to my colleagues, half of them have no interest in high performance computing, and most others have resigned themselves to only doing the analyses that existing C libraries allow them to do, believing that writing new low-level routines is the job of someone else, probably computer scientists.
Because they're not programming language nerds like me, they will use the tools that are at hand, without caring about their technical merit. If more money is spent on sanding the edges off a technically worse solution, then they will stick with it until the end of time, and not demand something better.

Does Mojo bring real value to the Python ecosystem? To me it's still too early to tell.
I'm glad someone of the calibre of Chris Lattner is working on breaking the two-language barrier, but I wished he had joined forces with those who have been solving the problem the last decade in Julia-land.

## Addendum
_Added 2024-04-01_

After its original publication, this post has made the rounds on various forums. In this part, I want to address some responses.

### You claim the Mojo code doesn't do any validation, but it does.
The commit I read was 42ba5bc. This commit didn't do any validation.

While the `record_coord.mojo` did contain a `.validate(self, chunk)` method, this method was not called by the `FastParser.parse_all` function.
This is the function mentioned in the README.md under the "Usage" section, as well as the function called in `main.mojo`.

The benchmarking section said the following:

> * The snippet provided in the \`\`\`needletail_test\`\`\` folder was compiled
> [ content elided .... ]
> * FASTQ record parsing, including header verification, tracking total nucleotide and record counts using the \`\`\`FastParser\`\`\` module.

It's entirely possible that the original Mojo post used timings obtained from running `parser.next()` in a loop, which _does_ validate the records - the "Benchmarks" section does not say exactly _what function_ from the `FastParser` module was used.

However, I feel it's unfair to blame me for looking at the published code and assuming that's the code that was being run.

Also, note that the MojoFastTrim repo, and the Mojo blog post has been _changed_ since I wrote my post.
The changes to the repo includes added validation to the `parse_all` function, and adding a new `benchmark` directory to make the benchmarking instructions clearer.
The changes to the post include adding a link to the updated repo.

At any rate, it's worth keeping in mind that:
* Even with the `validate` function, the Mojo implementation does less validation than Needletail. For example, it doesn't handle file IO errors at all, or handle reads longer than the buffer, or handle Windows line endings.

* However, Needletail doesn't do a ton of validation, either. For example, it doesn't check that the sequences and qualities are ASCII, which the code assumes. For example, this is an excerpt from the Needletail code, which where the check that is commented out is that the quality line must be bytes between `!` and `~`:

```rust
        // TODO: we don't do that every time because it's a ~90% performance penalty.
        // TODO: mention it on the README
        // And we can further validate quality chars
        // and the vast majority of files don't have this issue
        // let qual_len = self
        //     .buf_pos
        //     .qual(&buf)
        //     .iter()
        //     .filter(|c| *c >= &b'!' && *c <= &b'~')
        //     .count();
```

* See the next section on how much overhead the `.validate` function incurs. It's not much.

### A post about benchmarking, without running the Mojo code? Seriously?
It's not necessary to run Mojo on my own machine to show that Mojo's speed is due to its implementation.
This post 100% grants that Mojo's implementation is exactly as much faster than Needletail as is claimed on the MojoFastTrim repository.
All I have to show is that I get at least as large an improvement over Needletail as they claim Mojo does, by implementing the same algorithm in Julia.

> But that's a different machine! How can we know your Julia implementation is fast on machines in general?

If it all comes down to which machine it's run on, I might as well claim that the Mojo post doesn't prove anything because it's not run on my machine. See how it works?

At the _very least_, I've shown that the Mojo implementation is _insufficient evidence_ that the reason the Mojo implementation is fast is due to features unique to Mojo which Julia (or Rust) doesn't have.
If it's really due to Mojo's groundbreaking compiler advances, why is my Julia implementation relatively faster compared to Needletail?

But _fine._ I downloaded a VM and installed Julia and Mojo in it.
Hmm, but what was the CLI for the Mojo program? Let's see:

```
$ ./fast_parser
Segmentation fault (core dumped)
```

Fun fun fun. Anyway Here are my timings, all run in the same box on the later commit 38bb68:
* My Julia code: 213 ms
* The provided Mojo code with validation: 332 ms
* The provided Mojo code without validation: 320 ms
* Needletail + w. `lto` and `codegen_units=1`: 356 ms
* Needletail: 471 ms

So yeah, the point stands.

[^1]: I've looked at commit 42ba5bc. The repository has been updated since, so the code listed in this blog post might be out of date by the time you read this.
[^2]: I've found that when you mention that DNA is the basis of heritability, people will appear from thin air and argue about epigenetics. But I believe epigenetics is a rounding error compared to the DNA sequence when we talk about heritability and the medium of evolution. I don't doubt that e.g. chromatin accessibility is an important parameter in cells, but let's not conflate the biological state of a cell with a _heiritable signal_ which is stable enough to be acted on over evolutionary time.
[^3]: Some programmers wonder why DNA is usually saved encoded in plaintext. Isn't that inefficient, considering the cost of storage for terabyte-sized DNA datasets? Nope. It's usually stored gzip-compressed at decompressed on the fly when used. DNA compresses well, and the plaintext format allows extra metadata to be written directly into the file, as well as being much easier to parse. There are some more efficient formats, like CRAM, which are used in some large-scale projects, but in my subfield of microbial metagenomics, I can't recall ever having worked with a CRAM file.
[^4]: Only partially the reason - Needletail has two more reasons it's faster. First, Rust's `memchr` crate used by Needletail is much more optimised than Julia's Automa.jl used by FASTX.jl, and Automa.jl probably can't be optimised to the same level because Julia doesn't support platform-specific SIMD code yet. Second, Rust's borrowchecker makes it safe for Needletail to return a view into the active file buffer. This would be totally reckless in Julia, so we need to copy the bytes out to a separate buffer first (we actually need to do _two copies_ of each byte, since Julia's IO is buffered by default, using an inaccessible buffer).
