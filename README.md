# KnuthAlgorithmD

Swift implementation of Donald Knuth's "Algorithm D" for dividing multiprecision unsigned integers from *The Art of Computer Programming*, Volume 2: *Semi-numerical Algorithms*, Chapter 4.3.1

I also have to give some credit to Henry Warren's book *Hacker's Delight*, and since the hackersdelight.org website for the source code in the book is dead, to this github [repo](https://github.com/hcs0/Hackers-Delight) that archived the source code.  Not only did the test cases provided save me lots of headaches creating my own, but while contemplating why Warren uses a `goto` in his C implementation, I realized why my own implementation of that loop was subtly wrong, allowing me to fix it, and that it is a good example of a case where a formally structured loop doesn't work. I had to use an infinite loop with `break` and `continue` to accomplish the same thing.  Debugging that without the *Hacker's Delight* code as reference would undoubtedly have taken quite a long time.

The code of interest is in  `divideWithRemainder_KnuthD(_:by:quotient:remainder)` function found in `KnuthAlgorithmD.swift`.  For the purposes of this repo, I've made it super generic.   That means the function signature has a whole host of `where` clause constraints, and that might seem a little daunting, but you can use any kind of random access collection that uses integer indices for any of the parameters, so long as they agree on what kind unsigned `FixedWidthInteger` they contain.  This should make it easy to just drop into your code and use to get started, but for serious use, you'll want to specialize it.  I'll discuss that below. 

Be sure to read the function's doc comments, because the algorithm places constraints on the sizes of the collections you pass in.  The dividend must be at least as large as the divisor.  Your collection to receive the quotient must be large enough to hold it (1 + the difference in size between the dividend and divisor), and the collection for the remainder must be as large as the divisor.  These are not constraints I decidedn on.  Knuth states them when describing the algorithm in *The Art of Computer Programming*.  The idea is for you call it as an implementaton for your own diivsion, so you can arrange for the preconditions ot be met.  Exactly how you'd do that depends on how you've chosen to represent your multiprecision numbers.

The algorithm assumes that the unsigned integer type used for digits  is promotable to a larger integer of double the size.  That would make using `UInt64` (or `UInt` on 64-bit machines) as your digits a problem, since there isn't a larger Swift-native integer type.  To sovle that, I provide a wrapper to re-interpret the digit collections as `UInt32` so long as the collections you use support contiguous storage.  That should seamlessly take care of most of the cases where you use 64-bit integers as digits, but it also means that you're mostly doing the division with in 32- not 64-bit.

## Things you'll want to specialize

`divideWithRemainder_KnuthD` is marked as `@inlinable`,  not because I think the compiler will actually inline it, but because it exposes the implementaton outside of the package so the compiler can specialize it for your project.  I hope that will eleminate most or maybe even all of the thunking through generic/protocol witness tables that could slow it down.  However, if you're doing anything serious with it, you'll probably want to move the code directly in your project and specialize it manually.  There are three key things to focus on.

### The Digit type

If you've got your own multi-precision number type, you've almost certianly settled on a specific built-in integer type for your digits, and it's unlikely that you'll want to use different types, and even if you do, in most cases a simple `typealias` rather than generics would do the trick.  If you use 32-bit or smaller digits, the code will work by just explicitly specifying that type.  

If you want to use 64-bit digits though, you'll run into the problem that they're not promotable, which is necessary because the algorithm relies on some full-width multiplication and division.   There are two solutions:

1) Implement a 128-bit type that conforms to `FixedWidthInteger` and `UnsignedInteger`, then make `UInt64` (or `UInt` on 64-bit systems) conform to `PromotableInteger` (part of this package) with your 128-bit integer as its `Promoted` type.

2) Modify the algorithm to use `FixedWidthInteger`'s  `multipliedFullWidth` and `dividingFullWidth` methods instead of relying on arithmetic operators.

Option 1 is a bit of a chicken and the egg problem, because it's very likely that implementing 128-bit and larger types is precisely why you want to use this function in the first place. Still, it can work, because the 128-bit digit type doesn't have to implement everything, and the division case it needs to handle is dividing a 128-bit value by a 64-bit value (ie. the high 64 bits of the 128-bit divisor is always 0). 

Option 2 is more immediately doable, but `multipliedFullWidth` returns a tuple of integers, and `dividingFullWidth` takes a tuple as its parameter, which in and of itself isn't a problem, but you need to do some comparisons,  addition and subtraction on those tuples too, treating them as though they were a single 128-bit number.  You'll need to manually compare both parts separately, remember to manually carry overflows in adding from the low part to the high part, and similarly subtract borrows.  It makes the code a little messier, which is why I didn't do it in version I provide here, but totally worth it for serious use.  

Fortunately the only part that really needs modifying is the arithmetic related to the inner `while` loop that does quick testing to see if the estimated quotient digit is too large (corresponding to Step D3 in Knuth's algorithm).

### The Collection types

In all probability you use one specific kind of collection for digits to represent your numbers.  Most libraries/packages I've looked at use `Array`.  The point is that you don't need a function that supports four different collection types to be passed as parameters at the same time.  You can probably just pick one, and specialize for that.  If you use arrays to store your digits, handling `ArraySlice` too might be a good idea.

### Working storage for intermediate computation

The function allocates two arrays to do its work interally: one to hold the normalized divisor, and one to hold the normalized dividend which is transformed into a normalized remainder as the algorithm progresses.  The quotient digits are placed directly where they need to go, but at the end, the remainder must be denormalized and copied into the remainder parameter..  This works, but it's slow, and not really because of the copying.  Every array initialization is a heap allocation, and heap allocations are slow.   If you're processing numbers with thousands or millions of digits, ok, the heap allocations might be a negligble cost, but if you're working with 128-bit to, say, 2048-bit numbers, you could finish the entire division in the time it takes to allocate just one of the arrays, and this function allocates two of them.

There are solutions to this, of course.  Knuth's algorithm doesn't say anything about allocating working storage.  It simply modifies the data where it is, so if you're ok with mutating your input parameters, you don't need any additional storage at all, though parameter size requirements change: The dividend would need space for one extra digit for the overflow that can happen in normalization.  You can reduce the number of parameters from 2 value parameters and 2 `inout` parameters to 3 `inout` parameters

Let's assume that mutating your input parameters isn't an option.  You can pass in the working buffers as parameters, so you can re-use them.  That elevates the responsibility for creating the buffers to the caller.  Of course it also exposes an implementation detail to the caller, but you want to be fast, right?

Alternatively, instead of allocating the arrays directly, you could request them from an array cache that just hands them out from pool of previously allocated buffers.  For that to work well you probably need to make sure you return the dispensed arrays back to the cache at the end of the function, like returning a book to the library so it can be checked out again, and you want to make sure that the cache management is low cost.  Also the cache would need to remove all references to the array from its pool when you request one, because otherwise, its reference count will be 2, and as soon as you make a modification to your copy, you'll trigger copy-on-write, which will do the heap allocation you're trying to avoid.

If your application has special points at which it would be safe to reset all temporary storage at once, you could use an arena allocator.  These are used frequently in high performance games, but can certainly be used in other domains.  The idea (taking a video game as an example) is that for each frame, the game has to do a gazillion computations.  It has to figure out what things collided with which other things, what things are destroyed, what are created, where they are now that they've moved, etc...  Many of those computations require temporary data structures that are only relevant during the frame, maybe even only for one single computaton in the frame.  Allocating and dellocating heap storage is expensive, so instead, game programmers use an "arena" that allocates a huge block of memory once when the program starts up.  It starts with a pointer to the beginning, and then whenever you request some temporary memory, it just returns a copy of that pointer, then increments its own pointer by however many bytes you requested (plus padding for word alignment).   During the frame, the arena's internal pointer only ever increases.  It never tries to mimick "freeing" any of the pointers it hands out.   Then at the end of the frame, all of those temporary pointers just go out of scope, and the arena simply sets its pointer back to the beginning of the block it allocated at the beginning of the program, making it ready for re-use in the next frame.  The area itself is never deallocated.

You could do something similar, preallocating a large array, many times larger than you expect to need for any single computation, and hand out slices of it on request.  You just need to have some synchronization point, analogous to a frame in a video game, at which it's safe for you to reset the arena, otherwise you'll eventually get to the end of it, which would require you either to allocate more, or error out.  Or instead of array slices, you could use `UnsafeMutableBufferPointer`s, which can be used like arrays, except being pointers, they have reference semantics, but that's a good thing for this case.  For that to work well, you'd probably want the arena to allocate with C's `malloc`, that way you you can hand out pointers into that block without worry about validity of keeping it in some specific Swift scope.  Just `import Darwin`, or on Linux, `import GLibC`, to be able to call `malloc`.  On MacOS importing `Foundation` implicitly imports `Darwin`.  Swift's unsafe pointer types also have static `allocate` method you could use in lieu of `malloc`.

For my own use, I prefer to use the runtime stack as temporary storage and use `UnsafeBufferPointer` and `UnsafeMutableBufferPointer` as my digit collections, at least as far as the buffer-level functions are concerned, passed in as parameters.  Doing this puts some constraints on my big number types, but it also means temporary storage allocation is super fast.  It's literally just decrementing the stack pointer register. I have to wrap my calls to buffer-level math functions with closures passed to nested calls to the `withUnsafe...` family of functions, but those are optimized away in release builds.  It also means that my big number integers are not suitable for, say, finding the millionth digit of π, or the next prime number beyond the ones currently known, because those applications require arbitrarily large numbers of digits, and with my big number implementation that would chew up the runtime stack pretty fast.  It works very well for lots of applications, like secure hashing and encryption, that need bigger than built-in types, but not crazy big.

In any case, to get good performance on small numbers with relatively few digits (though more digits than you might think), you'll need to do something better for the working storage than allocating arrays on each call.  Exactly what the best approach is depends on the details of your big number implemenation, and maybe even on the applications that use it.
