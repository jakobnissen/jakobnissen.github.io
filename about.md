# About
Hello, there! I'm Jakob. This blog is about programming, mostly, and sometimes biology.

## How I got here
When studying in university to become a molecular biologist, I discovered my love for programming during a course in bioinformatics.
I became obsessed, and one year later began a PhD in bioinformatics where I could combine my two loves: Genomics and coding.

Even though it was as late as 2016, Python had just replaced Perl as the lingua franca in bioinfo.
I quickly developed a dislike for Perl and R, and dove headfirst into Python, wanting to learn as much as possible, and wanting to use Python for everything.

While Python was great and flexible, I spent the next year butting my head against the performance wall.
At that time, I worked in metagenomics, a sub-field of bioinfo characterised by large datasets.
When developing my main PhD project, [Vamb](https://github.com/RasmussenLab/Vamb), it quickly became clear that "Python for everything" just was not feasible. I really tried though - attempting to master Numpy, Numba, PyTorch and Cython, all in order to squeeze acceptable performance out of Python.
Eventually, Vamb ended up using a combination of Numpy, PyTorch and Cython (yes, all three).

In my desperate search for _good_ solutions, I stumbled upon Julia. Boy, could it run fast.
After seeing my own clumsy Julia code easily beat my optimized Cython, I tried to give Julia a shot.
Eventually, the weirdness wore off and its underlying design beauty began to shine through to me.

Much later, perhaps around early of 2020, I decided I needed to learn a statically compiled language to broaden my skills.
Rust would complement Julia well, as the two languages had wildly different design goals.
So I gave Rust a go, and had to quit in frustration.
Tried again later, and failed again, but somehow it stuck the third time.
Unlike Julia, I instantly liked Rust, even when I felt too dumb for it. It was just _too well designed_ to not like.

Currently, I use all three languages on a daily basis at work, making scientific software.

## Software
Besides this blog, I have made a few things, including:

#### Python
* [Vamb](https://github.com/RasmussenLab/vamb) - variational autoencoders for metagenomic binning

#### Rust
* [alen](https://github.com/jakobnissen/alen) - simple terminal alignment viewer.
* [samstrip](https://github.com/jakobnissen/alen) - strip data from SAM files not needed for metagenomic binning

#### Julia
* [BinBencher.jl](https://github.com/jakobnissen/BinBencherBackend.jl) - metagenomic binning benchmarking and analysis software
* [BufferIO.jl](https://github.com/BioJulia/BufferIO.jl) - lower level, performant IO abstractions in Julia
* [MemoryViews.jl](https://github.com/BioJulia/MemoryViews.jl) - low-level view into Memory in Julia
* [BGZFLib.jl](https://github.com/BioJulia/BGZFLib.jl) - read and write BGZF files.
* [Automa.jl](https://github.com/BioJulia/Automa.jl) - regex to Julia compiler and parser generator
* [LibDeflate.jl](https://github.com/jakobnissen/LibDeflate.jl) - bindings to the fast de/compression library libdeflate.
* [BioSequences.jl](https://github.com/BioJulia/BioSequences.jl) - The BioJulia library for DNA, RNA and peptide sequences
* [BioSymbols.jl](https://github.com/BioJulia/BioSymbols.jl) - The core DNA, RNA and amino acid type in Julia
* [Kmers.jl](https://github.com/BioJulia/Kmers.jl) - optimized, static, integer-backed biological sequences
* [FASTX.jl](https://github.com/BioJulia/FASTX.jl) - FASTA and FASTQ parsing in Julia
* [StackCollections.jl](https://github.com/jakobnissen/StackCollections.jl) - optimized, fixed-bit collections.
* [PairwiseMappingFormat.jl](https://github.com/BioJulia/PairwiseMappingFormat.jl) PAF file parser
* [CIGARStrings.jl](https://github.com/BioJulia/CIGARStrings.jl) - Read and write CIGARs in Julia
* [XAMAuxData.jl](https://github.com/BioJulia/XAMAuxData.jl) - read and write SAM, BAM, PAF and GFA auxiliary data
* [ErrorTypes.jl](https://github.com/jakobnissen/ErrorTypes.jl) - Rust-like recoverable error types.
* [MinHash.jl](https://github.com/jakobnissen/MinHash.jl) - efficient, generic minhashing.


