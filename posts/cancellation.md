@def rss = "How Julia's new cancellation system works."
@def rss_pubdate = Dates.Date(2026, 10, 26)

# Cancellation in Julia 1.14
_Written 2026-11-04_

Julia 1.14 is in alpha and will probably be released in a few months.
One of the many new features of Julia 1.14 is *cancellation*, mostly designed by Keno Fischer, with inputs from David Anthoff and Julian Samaroo.

The individual functions and types of the feature are [described in the Julia documentation](https://docs.julialang.org/en/v1.14.0-alpha2/base/parallel/#Cancellation), but I found it hard to comprehend the whole system from reading about its individual parts.
I could have used a tutorial, or an explainer of the whole cancellation feature, so that's what I aim to provide to you, in this post.

Two caveats before we dive in:
First, Julia 1.14 is not released yet, and much of the cancellation API has not been marked as public yet.
It's entirely possible it will change between this post and its release. Check the date at the top of this post - by the time you read this, cancellation might have been released in a revised form, and I might not have updated this post.

Second, I have not been part of implementing or designing this API.
Therefore, I don't have any insider knowledge of its internals or design deliberation,
so the content of this post comes from my own (and my AI's) inference from reading the code and the PRs to the Julia repository.

## Cancellation basics
Put most simply, cancellation means stopping a computation before it finishes. Under such a broad definition, however, cancellation can be achieved with normal control flow. After all, what is `break` except cancelling a loop, and `return` except cancelling a function?

This definition is not *wrong*, but it is too wide to be useful. The kind of cancellation that is tricky enough to warrant its own feature is when you attempt to cancel running code from *outside*.
In concrete Julia cancelling means stopping one running `Task` from another task.

This is useful in situations like:

* A user wants to interrupt an interactive computation with Ctrl-C.
* Two tasks race to finish the same computation using different algorithms.
  Once one finishes, the other is pointless and so could be stopped.
* A connection to a server is closed, and so a request being served by the server does not need to finish but can be dropped.

Writing a basic form of cancellation is easy enough: Pass an atomic variable into the cancellable task, and have that task check the variable intermittently.

In fact, let's look at a simple implementation of how this could look:

@@juliacode
```julia
mutable struct MyCancellationToken
    @atomic is_cancelled::Bool

    MyCancellationToken() = new(false)
end

struct MyCancellationError <: Exception end

function do_work(token::MyCancellationToken)
    for _ in 1:100
        Libc.systemsleep(0.1) # simulate some work

        # Check if the task has been cancelled
        (@atomic :monotonic token.is_cancelled) && throw(MyCancellationError())
    end
end

function main()
    token = MyCancellationToken()
    task = Threads.@spawn do_work(token)

    sleep(0.1)
    @atomic :monotonic token.is_cancelled = true # actually, I changed my mind
    wait(task; throw=false)
    @assert task.result isa MyCancellationError
end
```
@@

A homemade cancellation approach like the above works perfectly fine, and you can indeed implement cancellation in your application using simple atomic flags like that. However, as you will see below, there are tonnes of annoying complications, which are not addressed by the simple example.

## Julia's cancellation implementation 
My example implementation requires passing the cancellation token to every single function that can be cancelled - for a larger system of code, this means threading tokens through tens, or hundreds of functions.

Luckily, Julia already has a mechanism to solve exactly this problem, when you have a non-constant value used rarely, that you don't want to thread through all the functions as an argument: Scoped values. I made [a previous post on scoped values](https://discourse.julialang.org/t/task-local-storage-and-scoped-values-what-they-are-used-for/132045), if you're not familiar with them.
And indeed, in Julia 1.14, Base has `Base.CANCEL_TOKEN`, a global scoped value whose value is supposed to be set to the current cancellation token.

That is, if you want a task to be cancellable via some `token`, you should set `Base.CANCEL_TOKEN` to `token` in the scope of the task, like so:

@@juliacode
```julia
Base.ScopedValues.@with Base.CANCEL_TOKEN => token begin
    task = Threads.@spawn some_function()
end
```
@@

This means `task` can refer to the token that may be used to cancel it as `Base.CANCEL_TOKEN[]`. Also, cancel checks, which I'll mention later, check `Base.CANCEL_TOKEN` by default.

### Tokens and sources
The actual cancellation machinery in Julia conceptually splits the tokens into *token sources*, which can be used to cancel a task, and *tokens*, which are read-only values pointing to the source.

Let's call the task being cancelled the "child", and the task doing the cancellation the "parent".
There is no actual need for the cancelling task to be the task that spawns the cancelled tasks - any task holding the source can cancel the task holding the token - but in practice, I expect most of the time, parent tasks will cancel their children, so that's the terminology I'll go with here.

So: The parent creates a source, then creates a token referring to that source, and passes the token to a child. The parent can then call `Base.cancel!` on the source to cancel the child.

Since scoped values are inherited by the children of any task, if you don't explicitly set `Base.CANCEL_TOKEN` for a spawned child task, it will inherit the parent's value.
This is a sensible default: Normally, if you cancel a parent process, you also want its children to be automatically cancelled, too.

But what if your task lifetime is different from just the parent's lifetime? What if you want to spawn a task which is *not* tied to the parent lifetime?
Then, you can make a new token source, and pass its derived token to the child task: 

@@juliacode
```julia
using Base.ScopedValues: @with
using Base: CancellationTokenSource, CancellationToken, cancel!, CANCEL_TOKEN 
using Base.Threads: @spawn

source = CancellationTokenSource()

@with CANCEL_TOKEN => CancellationToken(source) begin
    child = @spawn do_some_work()
end

# Then later, when you want to cancel the child:
cancel!(source)
```
@@

In fact, `CancellationTokenSource` can inherit from multiple tokens, in which case cancelling *any* of those tokens will cancel all tokens generated from that source.
This can be useful if some task needs to follow two distinct lifetimes.
For example, a request to a server has a lifetime tied to *both* the server connection, *and* to the request itself. These may be independently cancelled, but cancelling either should cancel the request. 

### Propagation of cancellation
Cancelling a parent task should usually cancel their children, and as I showed above, this is achieved through having the tokens inherit from each other.
How is the cancellation propagated in the implementation?

Upon calling `Base.cancel!(source)`, all children of `source` are walked, recursively, to get all descendants. For each descendant source, it then sets the descendant as cancelled.
Each source contains a list of all tasks that uses a token from that souce, and which is parked.
These tasks are then immediately woken up and cancelled.

Then, the cancellation walks every *thread*, and checks if that thread's current task contains a descendant of the token, and if the thread is currently eligible to be cancelled immediately (we'll get back later to how that is defined), interrupts it immediately and cancels it.

This way, all tasks, waiting or running, are reached. The cancellation will only have an effect on running tasks once they hit a cancel check point - we will also get to those later.
### What happens when code is cancelled?
Task cancellation is analogous to garbage collection and task yielding: It's cooperative (*mostly* cooperative, for cancellation), so tasks need to intermittently check for whether they have been cancelled, just like they need to intermittently check for whether the garbage collector needs to run, or whether they need to yield.

Task yielding happens when a task is blocked, or at explicit `yield()`. Checks for garbage collection happen at every non-inlined function call, and explicit `GC.safepoint()` calls. Checks for cancellation happen when a task is blocked, or at explicit `Base.@cancel_check`.

In my example code above, a cancel check is an exception behind an if-statement. The actual implementation of `Base.@cancel_check` is a little more involved:
It does do the branch-and-throw, but it also stores the thread's *context* in a field of the current task.
The context is the task's current CPU state, i.e. stack and frame pointers, return address, and a handful of registers - basically the same information needed for a task switch.

Storing this data signals that the task is now able to be cancelled at any time; technically speaking, that it is *in a reset region*.
The reset region closes when the next side-effectful or unsafe code is entered. When that happens, the context field is cleared (by storing NULL there).

The idea behind reset regions is that a user will put in a `Base.@cancel_check` only at points where the task being cancelled does not leave the program in an illegal state.
By "illegal state", I don't mean some fancy compiler-related illegality, I mean that the code isn't in a state where it has temporarily broken some invariant.

So, we assume the cancel check happens in a non-illegal state.
The compiler reasonably assumes that no code that is `:effect_free` can cause the code to enter an illegal state.
This way, the code remains cancellable for a brief period of time after the actual check.
External code, that is, `@ccall` sites, can be marked explicitly to not cause the reset region to end with `Base.@assume_effects :reset_safe`.

When a running task is cancelled, the thread it runs on is sent a SIGUSR2 signal (on Linux), which checks the context of the task, and if it is not null (i.e. the task was in a reset-safe region), the task jumps back to address given by the context, continuing execution from there - meaning that the CPU basically jumps back to the cancel check.
Since the first step of `Base.@cancel_check` is the branch-and-throw part, the exception is thrown and the task is thus cancelled.

When I learned the reset safety mechanism, it seemed like overkill.
Effect-ful code happens all the time, so presumably this reset region would typically last only nanoseconds.
Is it really worth this complexity to keep a nanosecond-long window open? 

My understanding now is that the reset region allows cancelling in a few situations which would otherwise be hard to support:
First, it allows users to mark foreign code, called via `@ccall`, as being reset-safe, so it can be cancelled.
Second, it allows tight loops to be cancellable without slowing them down with intermittent `Base.@cancel_check`: The user can add a single check before the hot loop, and if they then make sure the entire hot loop is inferred as `:effect_free`, it can be interrupted at any time, with zero runtime cost in the loop itself.

### Severity levels of cancellation
When a task is cancelled, it begins some cleanup work: Any in-progress I/O is cancelled, and the task begins waiting for libuv's completion callback. Try/catch/finally statements need to run their `finally` blocks. All tasks tracked by a `@sync` block need to finish before the task running the `@sync` block itself can exit - and there may be other kinds of cleanup I don't know about, too.

But what happens if any of this cleanup code is broken, and doesn't respond? From a user's perspective, the code hangs, and can't even be cancelled.
If you've used Julia for some time, you're probably familiar with spamming Ctrl-C with seemingly no effect and know how frustrating that can be.

With Julia's new cancellation system, cancellations can escalate in severity: Calling `cancel!(source)` defaults to the lowest level: `Base.CANCEL_REQUEST_SAFE`. However, you can escalate with `cancel!(source, Base.CANCEL_REQUEST_ABANDON_EXTERNAL)`, which makes the cancelled task wait for child tasks, but stops waiting for e.g. external IO to finish cancelling.

Finally, cancellation can be escalated with `Base.CANCEL_REQUEST_ABANDON_ALL`, which stops the tasks without waiting for anything. This final step is a last resort, after which the system may not be recoverable, but is hopefully put in a state where some work can be saved, or the error that caused the cancellation can be debugged.
However, this last-ditch effort may cause your code to stop working. For example, it may cause deadlocks if an abandoned task is holding a lock (because the task simply stops running and never releases the lock).

As of Julia 1.14-alpha2, `Base.CANCEL_REQUEST_ABANDON_ALL` is not yet completely implemented - `Base.cancel!` never actually uses this escalation level.
Even if the user passes it explicitly, it behaves like a `Base.CANCEL_REQUEST_ABANDON_EXTERNAL`.

## So, how do I *actually use* cancellation again?
Since the feature is still in alpha, I still haven't seen any idiomatic cancellation code. However, from what I can read, you use it like this:

**Most code should add intermittent cancel checks**. Low-level libraries, such as implementing a new data structure, probably don't need cancel checks, as its operations are expected to finish in microseconds. Slightly more long-running code needs to add `Base.@cancel_check` intermittently.

Example:
@@juliacode
```julia
for iteration in 1:n
    # Check if we're cancelled once in a while. Make sure that if the task is
    # cancelled at this point, the task does not leave some data in an intermediate
    # unsafe state.
    Base.@cancel_check
    do_work()
end
```
@@

Base code like IO and filesystem code will presumably be littered with cancellation checks on their blocking operations, which means code needs only to think about adding these checks if they have long-running tasks which use CPU and memory, but do not do blocking calls.

**Performance-sensitive points** can improve the speed of `Base.@cancel_check` by loading the token first outside a loop with `token = Base.CANCEL_TOKEN[]`, and then check with `Base.@cancel_check token`.

There is currently no API for a faster branch-and-throw check which does not spend time to set up the task context or the reset window. Such a function would be faster than normal `Base.@cancel_check`, and could be used in side-effectful loops where the context buys little value, and where its performance cost matters.
Such a function might be added in the future.

**Code wanting to selectively cancel child tasks** needs to create `Base.CancellationTokenSource`s from `Base.CANCEL_TOKEN[]`, then create tokens from these sources, and set `Base.CANCEL_TOKEN` to those tokens for its child tasks.

Example:
@@juliacode
```julia
# Current task handles some server connection, and Base.CANCEL_TOKEN
# tracks if that server connection is cancelled

using Base.ScopedValues: @with
using Base: CANCEL_TOKEN, CancellationTokenSource, CancellationToken, cancel!
using Base.Threads: @spawn

function make_foo_request(timeout::Real)
    # Make a new cancellation source so the function can cancel the foo request
    # after timeout seconds.
    
    request_src = CancellationTokenSource(CANCEL_TOKEN[])

    @with Base.CANCEL_TOKEN => CancellationToken(request_src) begin
        # In this block, CANCEL_TOKEN[] refers to the token from `request_src`.
        # Since that descends from the parent's CANCEL_TOKEN[], this task is
        # cancelled *either* directly via `request_src` *or* if `make_foo_request`
        # itself is cancelled
    
        request_work = @spawn do_request_work()
    end

    timedwait(() -> istaskdone(request_work), timeout)
    
    if !istaskdone(request_work)
        cancel!(request_src)
    end

    [...]
end
```
@@

## Conclusion
Having dug into Julia cancellation, I've come away with a great deal of respect for the thoughtfulness of the design.
The implications of cancellation seems to have been thoroughly pondered, and the system, for all its complexity, is easy to use.
In that sense, it reminded me of Julia's green threading system, which I've also come to appreciate more the more I learn about it. 

It was always annoying that Julia never allowed stopping a task from the outside. Before cancellation, once in a while, a Julian would stumble into a situation where they needed to do just that, only to find it's not possible without risking bringing down the entire runtime.
Cancellation tackles this problem in a prinicipled manner with a well designed new feature.

When looking at the development process of this feature from the outside, it looks like a model process for how responsible feature development can look in the age of AI agents: An initial prototype was vibecoded, then refied based on feedback and some pilot usage.
Then, the vibecoded prototype is either cleaned up, or, as happened with the original cancellation PR, entirely scrapped and rewritten to un-sloppify it.
