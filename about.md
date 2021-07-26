# About

Hello, there! I'm Jakob. This blog is about programming, mostly, and sometimes biology.

## How I got here
When studying in university to become a molecular biologist, I discovered my love for programming during a course in bioinformatics. I became obsessed, and one year later began a PhD in bioinformatics where I could combine my two loves: Genomics and coding.

Even though it was as late as 2016, Python had just replaced Perl as the lingua franca in bioinfo. I quickly developed a strong dislike for Perl and R, and dove headfirst into Python, wanting to learn as much as possible, and wanting to use Python for everything.

While Python was great and flexible, I spent the next year butting my head against the performance wall. See, I worked in metagenomics, a sub-field of bioinfo characterised by large datasets. When developing my main PhD project, [Vamb](https://github.com/RasmussenLab/Vamb), it quickly became clear that "Python for everything" just was not feasible. I really tried though - attempting to master Numpy, Numba and PyTorch and Cython, all in order to squeeze acceptable performance out of Python. Eventually, Vamb ended up using a combination of Numpy, Pytorch and Cython (yes, all three).

In my desperate search for _good_ solutions, I stumbled upon Julia. I didn't like it in the beginning. It was too unlike Python - too _weird_. But boy, could it run fast. After seeing my own clumsy Julia code easily beat my optimized Cython, I tried to give Julia a shot. Eventually, the weirdness wore off and its underlying design beauty began to shine through to me.

Much later, perhaps around early of 2020, I decided I needed to learn a statically compiled language to broaden my skills. I decided Rust would complement Julia well, as the two languages had wildly different design goals. So I gave Rust a go, and had to quit in frustration. Tried again later, and failed again, but somehow it stuck the third time. Unlike Julia, I instantly liked Rust, even when I felt too dumb for it. It was just _too well designed_ to not like. It had all the stuff I didn't like about Julia.

Currently, I use Julia and Python on a daily basis at work, making scientific software.

## Software
Besides this blog, I have made a few things, including:

#### Python

* [Vamb](https://github.com/RasmussenLab/vamb) - variational autoencoders for metagenomic binning

#### Rust
* [Alen](https://github.com/jakobnissen/alen) - simple terminal alignment viewer.

#### Julia
* [ScanByte.jl](https://github.com/jakobnissen/ScanByte.jl) - find a byte in a chunk of memory - fast.
* [StackCollections.jl](https://github.com/jakobnissen/StackCollections.jl) - optimized, fixed-bit collections.
* [MinHash.jl](https://github.com/jakobnissen/MinHash.jl) - efficient, generic minhashing.
* [LibDeflate.jl](https://github.com/jakobnissen/LibDeflate.jl) - bindings to the fast de/compression library libdeflate.
* [CodecBGZF.jl](https://github.com/jakobnissen/CodecBGZF.jl) - read and write BGZF files.
* [ErrorTypes.jl](https://github.com/jakobnissen/ErrorTypes.jl) - Rust-like recoverable error types.
