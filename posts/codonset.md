# Implementing reverse translation

I quite like writing high-performance bioinformatics code.
It's just so satisfying when you get the abstractions _just right_ to express a biological idea elegantly in code.

Recently, I came across a biological problem which is particularly nice to implement.
It's nice because it's small and simple, contains some real biology, and shows how choosing good abstractions can lead to generic and yet efficient code.

This post is a kind of live "coding session". Or, not live, just a coding session.
There is no grand point to be made - just a walkthrough of a satisfying implementation.

## Background
The basic flow of genetic information is identical for all living cells on earth[^1] :
The genome is stored as DNA, a chemically stable molecule fit for long-term storage.
When in use, temporary copies of relevant parts of the DNA genome are made, copies made from RNA; a more chemically active and useful molecule than DNA, but therefore shorter-lived.
RNA can be thought of as a string composed of 4 molecules: A, C, G, and U, called _bases_.
The information in RNA comes entirely from the order of its bases[^2].
This way, RNA is digital information stored in base 4.
Through an elaborate mechanism called _translation_, the information in the RNA copies are used by the cell to manufacture proteins.

During translation, the RNA string is fed like a tape into a nanomachine called a _ribosome_.
The ribosome reads three RNA bases at a time, then moves the RNA string three bases and reads the next three.
Each RNA 3-gram, called a _codon_, is mapped to an amino acid by the ribosome.
For example, the RNA molecule `UCCGAUAAU` is read and mapped like this:

```plaintext
UCC -> Serine (S)
GAU -> Aspartic acid (D)
AAU -> Asparagine (N)
```

, and thus translated to the amino acid chain `SDN`.
Amino acid chains are called proteins, and besides being a major factor in reaping sick gainz in the gym, proteins are a major component of life forms on Earth.
The "mapping function" from codons to the 20 different amino acids[^3] is called _the genetic code_.
You might have realized that there being 20 amino acids has an implication for the genetic code:
Since there are $4^3 = 64$ different codons and only 20 amino acids, some amino acids must be coded for by multiple codons, so-called _degeneracy_.
Part of the reason for degeneracy is [wobble base pairs](https://en.wikipedia.org/wiki/Wobble_base_pair):
The physical mechanism used by the ribosome to match codons with amino acids is not precise due to the physical construction of the ribosome, causing some codons to match with the "wrong", or rather, imperfectly specified amino acid.

As a side note, I find it interesting to which extend the genetic code is arbitrary, and to which extend it is constrained by physical processes like wobbling.
While I'm not too much into the literature on this topic, the consensus seem to be that while there are some constraints, the huge amount of possible genetic codes would make it exceedingly unlikely that the same, or almost same, genetic code evolved twice independently.
And yet, all life forms use the same genetic code, from anteaters to subterranean bacteria.
This is pretty good evidence that all life on earth descends from a single common ancestor.

Well, the same code is used by _almost_ all organisms. As always in biology, there are [exceptions](https://en.wikipedia.org/wiki/List_of_genetic_codes), but these are truly exceptional, and the deviations from the standard genetic code are minor.

Evolutionarily, it makes sense that the genetic code is nearly universal.
Any mutation that changes the genetic code itself is equivalent to changing every single gene in the genome at once - surely such a mutation must be immediately lethal.
Hence, once a genetic code appeared in some proto-organism, and its entire genome came to use it, it became fixed and unable to evolve.
It's likely that the standard genetic code has been unchanged for billions of years, since the most advanced life form on Earth was far simpler than a current bacterium.

## Reverse translation
Anyway, back to computers.
So, nature _translates_ RNA to protein.
We don't know of any natural process that does the opposite - translates amino acids to RNA, and it probably doesn't exist - but it can sometimes be useful to do this kind of reverse translation _in silico_ when analyzing biological sequences.
How do we implement it in software?

The first observation is that an amino acid can't be reverse translated to a single codon.
Because the genetic code is degenerate, an amino acid can possibly map onto multiple codons. For example, the amino acid glutamine (Q) can map to `CAA` or `CAG`.
Hence, we must map amino acids to _sets_ of codons instead of single codons.

The second observation is that there are multiple different genetic codes.
Instead of writing multiple implementations of reverse translation, one for each genetic code, we should be able to make some kind of object representing a genetic code and refer to that when doing reverse translation.

For our implementation, we should lean on the package `BioSequences.jl`. It already implements types for RNA, amino acids, biological sequences, and even genetic codes and translation.
It doesn't have any reverse translation functionality, though - that's what we're here for!

### Implementing the CodonSet
Reverse translating an amino acid should yield a `CodonSet`.
Since there are $4^3 = 64$ codons, we can encode a `CodonSet` in a 64-bit integer, with each bit from least to most significant representing a codon in alphabetical order from `AAA` to `UUU`.
Conveniently, the internal representation `BioSequences.jl` uses for fixed-length nucleic acid sequences like codons are 64-bit integers:
The codons `AAA` to `UUU` are represented by the numbers 0 to 63.
This is great news! CPUs are optimized for operating on bits of integers, so we should be able to use this fact to create _very_ efficient code for our `CodonSets`.

@@juliacode
```plaintext
using BioSequences

struct CodonSet <: AbstractSet{RNACodon}
    x::UInt64
end
CodonSet() = CodonSet(UInt64(0))
```
@@

We subtyped `AbstractSet`, so we need to implement quite a few methods for it to work properly a,d feel like a real set type to the user.
First two basic functions:
The length of a `CodonSet` is the number of set bits in the integer. This can be counted using a single `popcntq` CPU instruction, available with the Base function `count_ones`:

@@juliacode
```plaintext
Base.length(x::CodonSet) = count_ones(x.x)
```
@@

We would also like to add elements to our set.
Since we're creating an immutable set type, let's implement `push` instead of `Base.push!`.
To add e.g. `UGG`, we need to convert `UGG` to an integer `n`. Then, we set the n'th bit.
We exploit the fact that the code `x << (n & 63)` compiles to a single `shlxq` instruction.
We do the inverse operation for `in`, doing `x >>> (n & 63)`, and taking advantage of the built-in `isodd` function.

@@juliacode
```plaintext
function push(s::CodonSet, x::RNACodon)
    CodonSet(s.x | (UInt64(1) << (reinterpret(UInt64, x) & 63)))
end

Base.in(c::RNACodon, s::CodonSet) = isodd(s.x >>> (reinterpret(UInt64, c) & 63))
```
@@

We can easily see the code it compiles to:

@@juliacode
```plaintext
julia> x = CodonSet(55);

julia> @code_native debuginfo=:none push(x, mer"AAA"r)
        .text
        movq    (%rdi), %rax
        btsq    %rsi, %rax
        retq
        nopl    (%rax,%rax)

julia> @code_native debuginfo=:none mer"AAA"r in x
        .text
        movq    (%rsi), %rax
        btq     %rdi, %rax
        setb    %al
        retq
        nopl    (%rax,%rax)
```
@@

Incredibly, LLVM optimizes `push` to a single `btsq` instruction, and `in` to `btq` + `setb`!
This makes sense when you think about it: `btsq` is literally "bit-set quad" - it sets the bit directly, just like `btq` is "bit-test" for membership testing.

We'll also need to iterate over the elements of the set.
Unfortunately, implementing iterators in Julia is a little tricky.
One need to create a function that takes `iter, state` and returns `item, new_state` if the iterator is not done and `nothing` otherwise.
For iteration N, we need to return the position of the N'th least significant set bit in the integer.

For this we can use the `tzcntq` CPU instruction, which is handily available in Julia through the `trailing_zeros` function, combined with the old C trick of `x & (x-1)` to clear the least significant bit:

@@juliacode
```plaintext
function Base.iterate(x::CodonSet, s::UInt64=x.x)
    iszero(s) ? nothing : (reinterpret(RNACodon, trailing_zeros(s)), s & (s-1))
end
```
@@

These primitives allows us to implement its higher-level behaviour.
For example, we of course want to be able to construct a `CodonSet` from any iterable of `RNACodon`, no matter its type.
This can be expressed concisely using the second-order function `foldl`:

@@juliacode
```plaintext
CodonSet(itr) = foldl(push, itr, init=CodonSet())
```
@@

`foldl` reduces over an iterable, mapping a function, here `push` to each element and an accumulator.
In other words, this code is equivalent to:

@@juliacode
```plaintext
function CodonSet(itr)
    y = CodonSet()
    for i in itr
        y = push(y, i)
    end
    y
end
```
@@

### Implementing set operations
We can't have a codon set without implementing basic set operations.
Let's begin with `union`, also known in Julia as `∪`.
This function should take any number of `CodonSet` and construct a new set with elements from any of the inputs.
In the internal representation, we need to take the union of the set bits in the integer.
This is just the bitwise or!

@@juliacode
```plaintext
function Base.union(a::CodonSet, b::Vararg{CodonSet})
    mapreduce(i -> i.x, |, b, init=a.x)
end
```
@@

`intersect` is analogous to `union`, but the resulting set must only contain elements which are present in all of the inputs.
But... that's just like `union`, but with bitwise and (function `&`) instead of `|`.
And likewise for the n-ary symmetric difference, which is bitwise xor (`⊻`).

We could write this same implementation three times - or, since this in Julia, we can use use metaprogramming and write a loop which creates the code that defines all these functions in one go:

@@juliacode
```plaintext
for (name, f) in [(:union, |), (:intersect, &), (:symdiff, ⊻)]
    @eval function Base.$(name)(a::CodonSet, b::Vararg{CodonSet}) 
        CodonSet(mapreduce(i -> i.x, $f, b, init=a.x))
    end
end
```
@@

The n-ary set complement, $A ∖ (B \cup ...)$, or `setdiff` in Julia, can be implemented using the just-defined `union`, and then a bitwise "and" and "not" instruction:
Literally "everything in A and not in B":

@@juliacode
```plaintext
Base.setdiff(a::CodonSet, b::Vararg{CodonSet}) = CodonSet(a.x & ~(union(b...).x))
```
@@

How does all this indirection with higher order functions like `mapfoldl` affect efficiency?
Let's check it by defining a more complicated function which uses `setdiff`, `union` (`∪`) and `symdiff` on five sets all in one:

@@juliacode
```plaintext
julia> f(a, b, c, d, e) = setdiff(a, b ∪ c, intersect(e, a, b));

julia> @code_native debuginfo=:none g(s, s, s, s, s)
        .text
        movq    (%rdx), %rax
        orq     (%rsi), %rax
        andnq   (%rdi), %rax, %rax
        retq
        nopl    (%rax)
```
@@

The backend compiler, LLVM, inlines pretty aggressively, so we end with just two CPU instructions.
It correctly realizes that $A ∖ ((b \cup c) \cup (e \cap a \cap b)) = A ∖ (b \cup c)$, and uses only one CPU instruction for each of these two set operations.
Not bad!

A few more simple methods for our type:

@@juliacode
```plaintext
Base.isempty(s::CodonSet) = iszero(s.x)
Base.issubset(a::CodonSet, b::CodonSet) = isempty(setdiff(a, b))
delete(s::CodonSet, x::RNACodon) = setdiff(s, CodonSet((x,)))
Base.filter(f, s::CodonSet) = CodonSet(Iterators.filter(f, s))
```
@@

## ReverseGeneticCode
With a `CodonSet` type we can serve our users with good conscience, let's move to defining reverse translation itself.
First though, we need to define the genetic code... didn't `BioSequences` already have that object?

@@juliacode
```plaintext
julia> dump(BioSequences.GeneticCode)
BioSequences.GeneticCode <: AbstractDict{Mer{RNAAlphabet{2}, 3}, AminoAcid}
  name::String
  tbl::Vector{AminoAcid}
```
@@

It's a glorified lookup-table: Each input codon is reinterpreted as an integer and used to look up the corresponding amino acid the vector.
We *could* use the existing `GeneticCode` object to do reverse translation, but for each amino acid, we would have to traverse the vector and find all the codons that code for that particular amino acid.
Instead, let's make a new object:

@@juliacode
```plaintext
const N_AA = length(alphabet(AminoAcid))

struct ReverseGeneticCode <: AbstractDict{AminoAcid, CodonSet}
    name::String
    sets::NTuple{N_AA, CodonSet}
end
```
@@

Since the "vector"'s length is known at compile time, and it's manageably small, it should be an `NTuple`.
The final translation interface we want is:

@@juliacode
```plaintext
Base.getindex(c::ReverseGeneticCode, a::AminoAcid) = c.sets[reinterpret(UInt8, a) + 1]

function reverse_translate!(
    v::Vector{CodonSet},
    seq::AminoAcidSeq,
    code=rev_standard_genetic_code
)
    resize!(v, length(seq))
    @inbounds for i in eachindex(v)
        v[i] = code[seq[i]]
    end
    v
end

function reverse_translate(seq::AminoAcidSeq, code=rev_standard_genetic_code)
    reverse_translate!(Vector{CodonSet}(undef, length(seq)), seq, code)
end
```
@@

So we just need a way to define the reverse genetic codes.
We could pour over [a curated list of genetic codes](https://en.wikipedia.org/wiki/List_of_genetic_codes), but why not simply generate the reverse codes from the codes already in `BioSequences`?
For each "forward" code, we traverse its internal table to get `(AminoAcid, RNACodon)` pairs, and use it to build a reverse code:

@@juliacode
```plaintext
function ReverseGeneticCode(x::BioSequences.GeneticCode)
    ind(aa::AminoAcid) = reinterpret(UInt8, aa) + 1

    sets = fill(CodonSet(), N_AA)
    for i in Int64(0):Int64(63)
        aa = x.tbl[i + 1]
        sets[ind(aa)] = push(sets[ind(aa)], reinterpret(RNACodon, i))
    end

    ReverseGeneticCode(x.name, Tuple(sets))
end
```
@@

Let's check it out:

@@juliacode
```plaintext
julia> reverse_translate(
    aa"SDN",
    ReverseGeneticCode(BioSequences.standard_genetic_code)
)
3-element Vector{CodonSet}:
 CodonSet(0x00f0000000000a00)
 CodonSet(0x0000000a00000000)
 CodonSet(0x000000000000000a)
```
@@

Neat.

Now to make _all_ the reverse genetic codes in one loop:
We can make a loop which inspects all variables in `BioSequences`, and, if they are `GeneticCode` objects, define a `const` equivalent reverse code with the same name with `rev_` prepended:

@@juliacode
```plaintext
for symbol in names(BioSequences, all=true)
    Base.isdeprecated(BioSequences, symbol) && continue
    isdefined(BioSequences, symbol) || continue
    thing = getproperty(BioSequences, symbol)
    thing isa BioSequences.GeneticCode || continue
    @eval const $(Symbol(:rev_, symbol)) = ReverseGeneticCode($thing)
end
```
@@

And... we're done!
You can find the code (with slight modifications not terribly relevant) [here (click)](https://github.com/jakobnissen/play/blob/master/revtrans.jl).

> Just one second! `N_AA == 28`. But you've only dealt with the 20 amino acids of the genetic code so far!

Okay, okay. Let's see what the others are:

@@juliacode
```plaintext
julia> setdiff(alphabet(AminoAcid),
               BioSequences.standard_genetic_code.tbl
              )
7-element Vector{AminoAcid}:
 AA_O
 AA_U
 AA_B
 AA_J
 AA_Z
 AA_X
 AA_Gap
```
@@

`AA_O` and `AA_U` are pyrrolysine and selenocysteine:
Special amino acids that are encoded by the cell dynamically overloading the genetic code in a trick called _translational recoding_.
For example, pyrrolysine is encoded by overloading the `UAG` codon, which normally encodes the "amber" STOP codon - a signal that the ribosome should abort translation.
Selenocysteine is encoded by overloading `UGA`.

The mechanisms for when exactly translational recoding happens are complex, but fortunately that doesn't matter in this particular case.
Since _every_ pyrrolysine come from `UAG`, `UAG` is the only possible reverse translation.
Note that this also means our reverse genetic codes are not exactly inverse of the corresponding forward genetic code, since `UAG` in the forward direction is assumed to always code for STOP due to the exceptional nature of translational recoding.

We can add these two special cases to the `ReverseGeneticCode` constructor:

@@juliacode
```plaintext
# In constructor
    sets[ind(AA_U)] = CodonSet((mer"UGA"r,))
    sets[ind(AA_O)] = CodonSet((mer"UAG"r,))
```
@@

The amino acids `AA_B`, `AA_J`, `AA_Z` and `AA_X` each signify _ambiguous_ amino acids:
`J` means "`L` or `I`".
These two amino acids have near-identical chemical structure, and identical molecular mass which can make them hard to tell apart in experiments.
Hence, a symbol for "it could be `I` or `L`, we don't know" is useful.
`Z` and `B` follows the same logic for `D/N` and `E/Q`, respectively.
Finally, `X` means "any amino acid".

So, we add special cases for those in the constructor - `AA_B` clearly just reverse translates to the union of whatever `AA_D` and `AA_N` reverse translates to, and `AA_X` reverse translates to everything:

@@juliacode
```plaintext
# In constructor
    # Ambiguous amino acids
    for (n, (a, b)) in [(AA_B, (AA_D, AA_N)), (AA_J, (AA_I, AA_L)), (AA_Z, (AA_E, AA_Q))]
        sets[ind(n)] = sets[ind(a)] ∪ sets[ind(b)]
    end

    # AA_X codes for all amino acids
    sets[ind(AA_X)] = CodonSet(typemax(UInt64))
```
@@

For the final two missing amino acids, `AA_Term` is the STOP signal - these are already part of the normal genetic code and don't need special handling.
Finally, `AA_Gap` means the _absence_ of an amino acid.
It's questionable whether an absence should _really_ be an amino acid object in `BioSequences`, in cases where one might find either something or nothing, it's usually better to store it as `Union{T, Nothing}`... but in this case, there are real use cases for encoding "no amino acid" as an `AminoAcid`. However, "no amino acid" certainly can't be reverse-translated, so we should special case it to error. To do this, we need to modify an earlier function:

@@juliacode
```plaintext
function Base.getindex(s::ReverseGeneticCode, a::AminoAcid)
    if reinterpret(UInt8, a) > (N_AA - 2) # cannot translate gap or invalid acid
        error("Cannot reverse translate element: ", a)
    end
    @inbounds s.sets[reinterpret(UInt8, a) + 1]
end
```
@@

As a last treat, let's benchmark our reverse translation function:


@@juliacode
```plaintext
julia> using BenchmarkTools

julia> aa = randaaseq(10_000); # random AA seq

julia> v = Vector{CodonSet}(undef, length(aa));

julia> @btime reverse_translate!(v, aa);
  7.256 μs (0 allocations: 0 bytes)
```
@@

726 picoseconds per amino acid!
That's probably as fast as it's possible to go while still checking for valid data, unless one writes a carefully hand-vectorized implementation.

[^1]: If you ever get lost in a forest, simply make a sweeping claim about "all living cells", and a biologist will appear to argue with you. There are endless edge cases and exceptions in biology: Viruses sometimes have RNA genomes, are they not cells? (they are not, even when enveloped). Human red blood cells destroy their own genome when maturing, what about them? Look, the claim in the section may not apply to _all_ living cells for _all_ definitions of "living", but it's damn near the closest to a universal truth in biology there is.

[^2]: Not entirely. There are dynamic chemical modifications to RNA going on in cells, and even modifications of DNA molecules. However, these modifications are the exception that prove the rule. In particular, I'm tired of people mentioning epigenetics as if epigenetics somehow upturns the idea that genetic information come from the digital signal in nucleotides. Epigenetics is just another exception in biology, and not even a particularly important one.

[^3]: There are not 20 amino acids. Amino acids are a group of chemicals with potentially infinite members. Life on Earth uses 22 different amino acids to create proteins, but two of them, namely selenocysteine and pyrrolysine are oddballs and not directly encoded in the genetic code, so we ignore them for now.
