# Optimization Notes

Algorithm D is pretty efficient as Knuth presents it in *The Art of Computer Programming*, but I have done some micro-optimizations that do make a difference.

Most of the optimizations have to do with the inner while loop that does a high-speed test for whether the estimated quotient digit is too large.  The loop itself is already an optimization that Knuth himself does.  One could accomplish the same task by multiplying full divisor by the estimated partial quotient, q̂, to see if the resulting product is larger than the current dividend, and make similar adjustments as one does later, in which case we wouldn't even need the later possible fix-up because the resulting `q̂` would be correct once it passed this test.  However, it's important to remember that this intial `q̂` might be two digits, not just one, requiring 3*n* primitive operations for the multiplication rather than just the *n* operations required later on when we're multiplying by a single digit.  Additionally, it's frequently the case that the initial `q̂` is too large.  So you'd have to do that at least once, and possibly multiple times on each iteration through the outer loop.  By just using the two most signficant digits of the divisor combined with the two most signficant digits of the dividend, Knuth cleverly turns those O(*n*) exact tests into imperfect, but pretty good and really fast O(1) tests, with a later O(*n*) fix-up for the rare cases when it gets it wrong.

Let's look at what that loop would look without my optimizations:

    while true
    {
        if q̂ >= radix 
            || q̂ * BigDigit(v[n - 2]) > radix * r̂ + BigDigit(u[j + n - 2])
        {
            q̂ -= 1
            r̂ += v[n - 1]
            if r̂ < radix { continue }
        }
        break
    }

The first thing to note is that since `n` is a constant, and `j` is the index for the outer `for` loop, both are invariant from the perspective of this loop.  We don't need to recompute those indices based on them each time through the while loop, so we can replace them with local constants.  This is an optimization called invariant code motion, which the compiler should be able to do for us, but I find that doing it myself manually helps me see other optimziations that can be done.   As a minor bonus, doing it manually also speeds up the code in debugging, since optimizations are normally turned off for debug builds.  Our loop now looks like this:

    let jPlusN = j + n
    let jPlusNMinus2 = jPlusN - 2
    let nMinus1 = n - 1
    let nMinus2 = n - 2
    
    while true
    {
        if q̂ >= radix 
            || q̂ * BigDigit(v[nMinus2]) > radix * r̂ + BigDigit(u[jPlusNMinus2])
        {
            q̂ -= 1
            r̂ += v[nMinus1]
            if r̂ < radix { continue }
        }
        break
    }

We then notice that `v[nMinus1]`,  `v[nMinus2]`, and `u[ujPlusNMinus2]` are our two most signficant divisor digits and second most signficant dividend digit, respectively.  These are also invariant for the loop, as are the `BigDigit`s we're using them to initialize, so we can extract those:

    let jPlusN = j + n
    let jPlusNMinus2 = jPlusN - 2
    let nMinus1 = n - 1
    let nMinus2 = n - 2
    
    let vLast = BigDigit(v.last!)
    let vNextToLast = BigDigit(v[n - 2])
    let ujPlusNMinus2 = BigDigit(u[jPlusNMinus2])
    
    while true
    {
        if q̂ >= radix || q̂ * vNextToLast > radix * r̂ + ujPlusNMinus2
        {
            q̂ -= 1
            r̂ += vLast
            if r̂ < radix { continue }
        }
        break
    }

The only place we use `jPlusNMinus2` is for `ujPlusNMinus2`, so we don't get any benefit from that constant, so we remove it.  Additionally we can see that `vLast` and `vNextToLast` are not only invariant with respect to the inner loop, but the outer loop as well, so we can move them even further out, since we're focusing on the inner loop, their declarations disappear from the code we're examining.

    let jPlusN = j + n
    let ujPlusNMinus2 = BigDigit(u[jPlusN - 2])

    while true
    {
        if q̂ >= radix || q̂ * vNextToLast > radix * r̂ + ujPlusNMinus2
        {
            q̂ -= 1
            r̂ += vLast
            if r̂ < radix { continue }
        }
        break
    }

Now let's focus on the `if` statement's condition.  The presence of the boolean `||` operator doesn't just mean that the statement is true if either the left side or right side is true.  It also implies that if the left side true, the right side is not even evaluated.  This might seem like a nice feature, and often it is, especially if the right side is expensive to compute, which isn't the case here, but it means that there is a conditional branch hidding inside the `||`.   You might wonder why this matters.

If you're not famliiar with modern CPU design, you should be aware that they don't work quite like the old Von Neumann model we all learned about in Computer Science 101 with its simple fetch-decode-execute instruction cycle.   They have on-chip memory caches, deep pipelines of prefetched instructions, multiple arithmetic, logic and floating point units, and most relevantly, they simultaneously and speculatively execute multiple prefetched instructions in advance, according to branch prediction.  All of this is intended to make your code run faster, and it does... if you use it right.  If you don't, it can actually make your code run slower.   The fastest code is simple straight-line code with no branches, or if there are branches, they are unconditional.  The reason is because the CPU can examine the instruction pipeline, find instructons whose results don't depend on one another, re-order them, and execute them in parallel on redundant computation units long before the program counter actually gets to them, so that when it does, the results are ready immediately, or at least in many fewer clock cycles than they would be if it didn't begin executing them until the program counter reached them.   

Unfortunately very few useful programs can be written without any conditional branches, and they throw a monkey wrench into the CPU's speculative execution clockwork, because it can't know whether to speculatively execute the code path if the branch is taken, or the code path if the branch falls through.  To address this, CPUs contain a branch predictor.   It tries to decide, based on a statistical history, which path a particular branch will take, and speculatively execute those instructions.   If it gets the prediction right, you're code proceeds at high speed with no hiccups, but if it gets it wrong... oh man does your code's performance take it hit.  The CPU has to discard all of its speculative execution results, flush the instruction pipeline, jump to the correct location, which may or may not trigger a cache fault, then begin refilling the instruction pipeline again so it can finally get back to executing your code, which hopefully isn't another mispredicted branch straight-away.  

So to get good preformance we really want to avoid conditional branches when we can by replacing them with computation that achieves the same result, or if we can't do that, at least make the branches as predictable as possible.  In our case we really do need the `if` statement, but we don't really need the implicit conditional branch in the boolean "or".   To be fair, the `if` isn't too bad.   It's not like a binary search where the path taken is entirely unpredictable for the CPU.  In our case, the left-hand side of the "or" will continue to be true, until it's false, and then it will stay false, at least for the current iteration of the outer loop.  That's because we're strictly decrementing `q̂`, and we're comparing it to a constant.  The behavior of the right hand side is a bit more complicated, but is similarly predictable.  The problem is that CPU doesn't know that, and it doesn't bother to find out until it gets to the right hand side to execute it a few times, which it will only do after finally after getting past the left hand side.  In fact, it's got about a 50/50 chance of mispredicting the right hand side the very first time it encounters it through each iteration of the outer loop, and because the updates to q̂ and r̂ are specifically designed to guarantee that the `if` condition will finally be false, the branch predictor won't have a lot of opportunity to figure out what's going on with the right-hand side.  It's likely to be mispredicted a lot.   

What we really need is to replace that boolean "or" with a computation that does the same thing in terms of logical evaluation, but doesn't involve the unnecessary conditional branch.  There is such a thing, the *bitwise* "or", which is purely a computation and has no implicit branches.  The thing is, it operates on integer types, and unlike C or C++, Swift doesn't think of `Bool` as a number that happens to be 1 or 0, so we have to convert it.   The usual way would be something like this:

    let b = condition ? 1 : 0
    
The problem is that the ternary operator is just syntactic sugar for an if statement... another branch.  We're trying to avoid that.  It turns out that this will do it.

    let b = unsafeBitcast(condition, to: UInt8.self)

I don't like having `unsafeBitcast` in the wild, if I can avoid it, so I put that in an initializer for `FixedWidthInteger` via an `extension`, where I can also assert that the other bits are 0.  So now we can do this:

    let jPlusN = j + n
    let ujPlusNMinus2 = BigDigit(u[jPlusN - 2])

    while true
    {
        if UInt8(q̂ >= radix) 
            | UInt8(q̂ * vNextToLast > radix * r̂ + ujPlusNMinus2) == 1
        {
            q̂ -= 1
            r̂ += vLast
            if r̂ < radix { continue }
        }
        break
    }

Now our outer `if` only has a one opportunity to mispredict instead of two.  We can't do anything about the inner `if`.  That's about all we can do to help the branch predictor.  

Those multiplications in the loop stand out though.  They are just integer multiplication, so they're not especially slow, but we can make them faster.  In `q̂ * vNextToLast`, only changes in response to decrementing `q̂` by 1.  Decrementing `q̂` has the effect of subtracting `vNextToLast` from the product, so let's do that instead.

    let jPlusN = j + n
    let ujPlusNMinus2 = BigDigit(u[jPlusN - 2])
    var partialProduct = q̂ * vNextToLast
    
    while true
    {
        if UInt8(q̂ >= radix) 
            | UInt8(partialProduct > radix * r̂ + ujPlusNMinus2) == 1
        {
            q̂ -= 1
            r̂ += vLast
            
            partialProduct -= vNextToLast
            
            if r̂ < radix { continue }
        }
        break
    }

The other multiplication, `radix * r̂`,  changes in a slightly more complicated way, but not very much more complicated.  `r̂` changes by increasing it by `vLast`,  which means the product increases by `radix * vLast`.  That seems inconvenient because it's another multiplication, except that `radix` is an actual constant and `vLast` is invariant - it's the most signficant digit of our divisor.  For the purposes of the current call to our function `radix * vLast` is invariant.  We can calculate it, and we'll call it `partialRemainderDelta` before the outer loop: 

    let jPlusN = j + n
    let ujPlusNMinus2 = BigDigit(u[jPlusN - 2])
    var partialProduct = q̂ * vNextToLast
    var partialRemainder = radix * r̂ + ujPlusNMinus2

    while true
    {
        if UInt8(q̂ >= radix) | UInt8(partialProduct > partialRemainder) == 1
        {
            q̂ -= 1
            r̂ += vLast
            
            partialProduct -= vNextToLast
            partialRemainder += partialRemainderDelta
            
            if r̂ < radix { continue }
        }
        break
    }

That's nearly all we can do with this loop, but there is one more minor thing.  The normal arithmetic operators in Swift detect overflow and that means they have to test the values that result from the operators.  That's done quite efficiently, so it's fast, but what would be even faster is to not do it at all.  To quote a Kevlin Henney presentation slide,  "No code is faster than no code."  No matter how efficiently you do something, it will never be as fast as doing nothing instead.  Strictly speaking, we don't need the overflow detection.  This is meant as an implementation detail of a big integer arithmetic library routine.  We'd better be handling the overflows appropriately at some level above this function.  We just need to do the computation requested as quickly as possible, so instead, I use the overflowing versions of the operators, and not just here, but everywhere in the routine, and in lots of others too.

    let jPlusN = j &+ n
    let ujPlusNMinus2 = BigDigit(u[jPlusN &- 2])
    var partialProduct = q̂ &* vNextToLast
    var partialRemainder = radix &* r̂ &+ ujPlusNMinus2

    while true
    {
        if UInt8(q̂ >= radix) | UInt8(partialProduct > partialRemainder) == 1
        {
            q̂ &-= 1
            r̂ &+= vLast
            
            partialProduct &-= vNextToLast
            partialRemainder &+= partialRemainderDelta
            
            if r̂ < radix { continue }
        }
        break
    }

The only other thing I do for this loop is to give the conditions names, but while I think that optimizes human comprehension, that's not the sort of optimization this document intends to cover.  The actual routine has the named conditions. 

# Notes on the efficiency of subtracting then retro-adjusting:

In the subtraction below, we get a borrow if `q̂` is still too high.
The while loop above catches most of the cases where `q̂` was one too big
and all of the cases where `q̂` was two too big, but that check only
involved the first two digits of the divisor and first two digit of
the dividend.  Though rare, we can still have cases where lower digits
in the dividend and divisor still make `q̂` one too big.

You might be tempted think that rarity is what makes just blindly
doing the subtraction first and then adding back if needed more
efficient than checking first to see if we should subtract first, but
you'd be wrong.  To see why, let's compare the number of primitive
digit operations we need for the two possibilties.

For what we're actually doing:

   Multiply-and-subtract: This is done in a single pass O(*n*) loop.
       Technically the multiply and subtract are still 2 operations per
       digit, but since we do it in one pass, it's fair to call it *n*,
       since we don't execute a second sequence of branch instructions,
       as we would if we were to first do the whole multiplication and
       then do the subtraction. But let's call it 1.5 \* *n* to take into
       account that we are doing more than just a single primitive
       arithmetic operation per iteration.

   Test the borrow: This is a constant time operation.  We can ignore
       its cost.

   Conditionally add back.  This is another single-pass loop of *n*
       primitive digit operations.

So the total is 1.5 \* *n* normally, and rarely 2.5 \* *n*.

The alternative would be to do the multiplication, but hold off on the
subtraction, and instead compare the product with the current dividend.
If the product is larger than the dividend, decrement `q̂` and recompute
the product, then do the subtraction.  If the product was less than
the dividend, we'd go straight to doing the final subtraction.  What's
the cost of that?

   Multiply: This is *n* primitive digit operations.

   Compare: Conceptually the comparison is O(*n*), but for practical
       purposes, in this scenario it would return a result in the
       first few digits the vast majority of the time, so we we can
       treat it as constant time on average, and ignore it.

   Conditionally decrement `q̂`: This is constant time, so we can ignore
       it.

   Conditionally recompute the product:  There are two ways we could
       do this.  We could either multiply the new `q̂` by the divisor
       again, or we could subtract the divisor from our existing
       product.  Both require n operations, though subtraction is
       faster for the CPU to do, so we'd probably do it that way.  In
       either case, it's *n* primitive digit operations.

   Subtract the product from the dividend: This is n digit operations.

In this alternative scenario we require 2 \* *n* operations if we don't
need to correct `q̂`, namely multiply and subtract.  When we do need
to adjust `q̂`, it's 3 \* *n* operations, namely mutiplication, and two
subtractions (or two multiplications and one subtraction).

That's 33% more work than what we're actually doing when `q̂` does not
need adjustment, and 20% more when `q̂` does need adjustment. In short,
checking in advance would be more costly regardless of how rare the
adjustment is.

The "test first" approach requires additional storage for the
intermediate product in order to compare it with the current dividend.
On top of the cost of allocating it, it would raise the chances of L2
cache faults, slowing things down more.  The way we're doing it, the
product goes right back into the dividend via subtraction.  The only
extra "storage" needed is per digit, which will be in a register.
