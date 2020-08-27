/*
 Copyright 2020 Chip Jarred
 
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in all
 copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 SOFTWARE.
 */

// -------------------------------------
/**
 Divide multiprecision unsigned integer, `x`, by multiprecision unsigned
 integer, `y`, obtaining both the quotient and remainder.
 
 Implements Alogorithm D, from Donald Knuth's, *The Art of Computer Programming*
 , Volume 2,*Semi-numerical Algorithms*, Chapter 4.3.1.
 
 - Note: This version of the function is super-generic, hence the long list of
 type constraints, but you can use any kind of random access collection for the
 buffers, even different ones, so long as they use the same unsigned integer
 type for digits, that it is promotable (meaning there is a larger integer size
 defined on which basic  arithmetic operations can be performend, and so long
 as the collections use `Int` as their index type.  For performance reasons,
 you probably want to specialize it for your particular collection types, in
 order to  avoid lots of generic/protocol thunking through witness tables, but
 that should only require changing the function signature.  However, it is
 declared as `public` and `@inlinable`, not becuase I expect the  compiler to
 actually inline it, but because it exposes the implementation for it create a
 specialized version for the parameters it is called with.
 
 - Parameters:
    - dividend: The dividend stored as an unsigned multiprecision integer with
        its least signficant digit at index 0 (ie, little endian). Must have at
        least as many digits as `divisor`.
    - divisor: The divisor stored as a an unsigned multiprecision integer with
        its least signficant digit stored at index 0 (ie. little endian).
    - quotient: Buffer to receive the quotient (`x / y`).  Must be the size of
        the dividend minus the size of the divisor plus one.
    - remainder: Buffer to receive the remainder (`x % y`).  Must be the size
        of the divisor.
 */
@inlinable
public func divideWithRemainder_KnuthD<T, U, V, W>(
    _ dividend: T,
    by divisor: U,
    quotient: inout V,
    remainder: inout W
)
    where
    T: RandomAccessCollection,
    T.Element: PromotableInteger,
    T.Element.Magnitude == T.Element,
    T.Element.Promoted.Demoted == T.Element,
    T.Index == Int,
    U: RandomAccessCollection,
    U.Element == T.Element,
    U.Index == T.Index,
    V: RandomAccessCollection,
    V: MutableCollection,
    V.Element == T.Element,
    V.Index == T.Index,
    W: RandomAccessCollection,
    W: MutableCollection,
    W.Element == T.Element,
    W.Index == T.Index
{
    typealias Digit = T.Element
    typealias BigDigit = Digit.Promoted
    let digitWidth = Digit.bitWidth
    let m = dividend.count
    let n = divisor.count
    
    assert(n > 0, "Divisor must have at least one digit")
    assert(divisor.reduce(0) { $0 | $1 } != 0, "Division by 0")
    assert(m >= n, "Dividend must have at least as many digits as the divisor")
    assert(
        quotient.count == m - n + 1,
        "Must have space for the number of digits in the dividend minus the "
        + "number of digits in the divisor plus one more digit."
    )
    assert(
        remainder.count == n,
        "Remainder must have space for the same number of digits as the divisor"
    )

    let radix: Digit.Promoted = 1 << digitWidth
    
    guard n > 1 else
    {
        remainder[0] = divide(dividend, by: divisor.first!, result: &quotient)
        return
    }

    let shift = divisor.last!.leadingZeroBitCount
    
    var v = [Digit](repeating: 0, count: n)
    leftShift(divisor, by: shift, into: &v)

    var u = [Digit](repeating: 0, count: m + 1)
    u[m] = dividend[m - 1] >> (digitWidth - shift)
    leftShift(dividend, by: shift, into: &u)
    
    let vLast = BigDigit(v.last!)
    let vNextToLast = BigDigit(v[n - 2])
    let cRightDelta = vLast * radix

    for j in (0...(m - n)).reversed()
    {
        let jPlusN = j &+ n
        
        let dividendHead: BigDigit =
            BigDigit(u[jPlusN]) &* radix &+ BigDigit(u[jPlusN &- 1])
        
        var (q̂, r̂) = dividendHead.quotientAndRemainder(dividingBy: vLast)
        
        let ujPlusNMinus2 = BigDigit(u[jPlusN &- 2])
        
        /*
         The following loop corresponds to the Step D3 in Knuth's Alogorithm D.
         It does operations and comparison involving just the first two digits
         of the divisor and the first two digits of the dividend in an attempt
         quickly estimate the next quotient digit.  Although this loop is
         triggered frequently, it does not actually repeat very many times when
         it is triggered, as the adjustments to q̂ and r̂ quickly bring it a
         point it can break out.  Still any inner loops or branches will slow
         things down, so it's worth optimizing.  I've commented on a those
         optimizatons below, but mainly they involve extracting constant
         expressions (theoretically the compiler would do that for us anyway as
         "invariant code motion" is a common optimization), replacing a boolean
         "or" with a bitwise "or" to eliminate a hidden branch, and replacing
         repeated multiplication where one of the multiplicands remains
         constant and the other changes by one with addition or subtraction.
         
         These next two lines are inside the loop according to Knuth's
         algorithm, but in fact, we only need to do the multiplications once,
         then we can update the products with addition and subtraction in the
         loop if needed. To be sure, these multiplications translate directly
         to single native instructions, so they're not slow, but so do the
         addition and subtraction, and they're faster than multiplication.
         */
        var c2Left = q̂ &* vNextToLast
        var c2Right = radix &* r̂ &+ ujPlusNMinus2
        
        while true
        {
            let q̂IsTwoDigits = UInt8(q̂ >= radix)
            let otherDigitsMakeQTooHigh = UInt8(c2Left > c2Right)
            
            /*
             Bitwise "or" here helps the branch predictor. The logical "or" one
             would normally use implicitly adds another branch to be
             mispredicted
             */
            if (q̂IsTwoDigits | otherDigitsMakeQTooHigh) == 1
            {
                q̂ &-= 1
                r̂ &+= vLast
                
                /*
                 As mentioned in a previous comment, we avoid multiplying
                 inside the loop.  The following two lines are the secret sauce.
                 */
                c2Left &-= vNextToLast
                c2Right &+= cRightDelta
                
                if r̂ < radix { continue }
            }
            break
        }

        /*
         Notes on the efficiency of subtracting then retro-adjusting:
         
         In the subtraction below, we get a borrow if q̂ is still too high.
         The while loop above catches most of the cases where q̂ was one too big
         and all of the cases where q̂ was two too big, but that check only
         involved the first two digits of the divisor and first two digit of
         the dividend.  Though rare, we can still have cases where lower digits
         in the dividend and divisor still make q̂ one too big.
         
         You might be tempted think that rarity is what makes just blindly
         doing the subtraction first and then adding back if needed more
         efficient than checking first to see if we should subtract first, but
         you'd be wrong.  To see why, let's compare the number of primitive
         digit operations we need for the two possibilties.
         
         For what we're actually doing:
         
            Multiply-and-subtract: This is done in a single pass O(n) loop.
                Technically the multiply and subtract are still 2 operations per
                digit, but since we do it in one pass, it's fair to call it n,
                since we don't execute a second sequence of branch instructions,
                as we would if we were to first do the whole multiplication and
                then do the subtraction. But let's call it 1.5 n to take into
                account that we are doing more than just a single primitive
                arithmetic operation per iteration.
         
            Test the borrow: This is a constant time operation.  We can ignore
                its cost.
         
            Conditionally add back.  This is another single-pass loop of n
                primitive digit operations.
         
         So the total is 1.5 * n normally, and rarely 2.5 * n.
         
         The alternative would be to do the multiplication, but hold off on the
         subtraction, and instead compare the product with the current dividend.
         If the product is larger than the dividend, decrement q̂ and recompute
         the product, then do the subtraction.  If the product was less than
         the dividend, we'd go straight to doing the final subtraction.  What's
         the cost of that?
         
            Multiply: This is n primitive digit operations.
         
            Compare: Conceptually the comparison is O(n), but for practical
                purposes, in this scenario it would return a result in the
                first few digits the vast majority of the time, so we we can
                treat it as constant time on average, and ignore it.
         
            Conditionally decrement q̂: This is constant time, so we can ignore
                it.
         
            Conditionally recompute the product:  There are two ways we could
                do this.  We could either multiply the new q̂ by the divisor
                again, or we could subtract the divisor from our existing
                product.  Both require n operations, though subtraction is
                faster for the CPU to do, so we'd probably do it that way.  In
                either case, it's n primitive digit operations.
         
            Subtract the product from the dividend: This is n digit operations.
         
         In this alternative scenario we require 2 * n operations if we don't
         need to correct q̂, namely multiply and subtract.  When we do need
         to adjust q̂, it's 3 * n operations, namely mutiplication, and two
         subtractions (or two multiplications and one subtraction).
         
         That's 33% more work than what we're actually doing when q̂ does not
         need adjustment, and 20% more when q̂ does need adjustment. In short,
         checking in advance would be more costly regardless of how rare the
         adjustment is.
         
         The "test first" approach requires additional storage for the
         intermediate product in order to compare it with the current dividend.
         On top of the cost of allocating it, it would raise the chances of L2
         cache faults, slowing things down more.  They way we're doing it, the
         product goes right back into the dividend via subtraction.  The only
         extra "storage" needed is per digit, which will be in a register.
         
         The immediately following statement does multiplicaton and subtraction
         together.
         */
        var borrow = subtractReportingBorrow(
            v[0..<n],
            times: q̂.low,
            from: &u[j..<jPlusN]
        )
        borrow = subtractReportingBorrow(&u[jPlusN], borrow)

        quotient[j] = q̂.low
        
        if borrow != 0
        {
            quotient[j] &-= 1
            let carry = addReportingCarry(x: v[0..<n], to: &u[j..<(jPlusN)])
            u[jPlusN] &+= carry
        }
    }
    
    rightShift(u[0..<n], by: shift, into: &remainder)
}

// -------------------------------------
/**
 Divide multiprecision unsigned integer, `x`, by multiprecision unsigned
 integer, `y`, obtaining both the quotient and remainder.
 
 Implements Alogorithm D, from Donald Knuth's, *The Art of Computer Programming*
 , Volume 2,*Semi-numerical Algorithms*, Chapter 4.3.1.
 
 - Note: This is a wrapper for the main `divideWithRemainder_KnuthD` function
    to allow use of `UInt64` digits, provided that the collections support
    accessing contiguous storage.
 
 - Parameters:
    - dividend: The dividend stored as an unsigned multiprecision integer with
        its least signficant digit at index 0 (ie, little endian). Must have at
        least as many digits as `divisor`.
    - divisor: The divisor stored as a an unsigned multiprecision integer with
        its least signficant digit stored at index 0 (ie. little endian).
    - quotient: Buffer to receive the quotient (`x / y`).  Must be the size of
        the dividend minus the size of the divisor plus one.
    - remainder: Buffer to receive the remainder (`x % y`).  Must be the size
        of the divisor.
 */
@inlinable
public func divideWithRemainder_KnuthD<T, U, V, W>(
    _ dividend: T,
    by divisor: U,
    quotient: inout V,
    remainder: inout W
)
    where
    T: RandomAccessCollection,
    T.Element == UInt64,
    T.Element.Magnitude == T.Element,
    T.Index == Int,
    U: RandomAccessCollection,
    U.Element == T.Element,
    U.Index == T.Index,
    V: RandomAccessCollection,
    V: MutableCollection,
    V.Element == T.Element,
    V.Index == T.Index,
    W: RandomAccessCollection,
    W: MutableCollection,
    W.Element == T.Element,
    W.Index == T.Index
{
    dividend.withUInt32Buffer
    { dividend in
        divisor.withUInt32Buffer
        { divisor in
            quotient.withMutableUInt32Buffer
            {
                var quotient = $0
                remainder.withMutableUInt32Buffer
                {
                    var remainder = $0
                    divideWithRemainder_KnuthD(
                        dividend,
                        by: divisor,
                        quotient: &quotient,
                        remainder: &remainder
                    )
                }
            }
        }
    }
}

#if arch(arm64) || arch(x86_64)
// -------------------------------------
/**
 Divide multiprecision unsigned integer, `x`, by multiprecision unsigned
 integer, `y`, obtaining both the quotient and remainder.
 
 Implements Alogorithm D, from Donald Knuth's, *The Art of Computer Programming*
 , Volume 2,*Semi-numerical Algorithms*, Chapter 4.3.1.
 
 
 - Note: This is a wrapper for the main `divideWithRemainder_KnuthD` function
    to allow use of `UInt` digits on machines where `UInt` is 64-bits, provided
    that the collections support accessing contiguous storage.  It is not
    needed on machines where `UInt` is 32-bits.

 
 - Parameters:
    - dividend: The dividend stored as an unsigned multiprecision integer with
        its least signficant digit at index 0 (ie, little endian). Must have at
        least as many digits as `divisor`.
    - divisor: The divisor stored as a an unsigned multiprecision integer with
        its least signficant digit stored at index 0 (ie. little endian).
    - quotient: Buffer to receive the quotient (`x / y`).  Must be the size of
        the dividend minus the size of the divisor plus one.
    - remainder: Buffer to receive the remainder (`x % y`).  Must be the size
        of the divisor.
 */
@inlinable
public func divideWithRemainder_KnuthD<T, U, V, W>(
    _ dividend: T,
    by divisor: U,
    quotient: inout V,
    remainder: inout W
)
    where
    T: RandomAccessCollection,
    T.Element == UInt,
    T.Element.Magnitude == T.Element,
    T.Index == Int,
    U: RandomAccessCollection,
    U.Element == T.Element,
    U.Index == T.Index,
    V: RandomAccessCollection,
    V: MutableCollection,
    V.Element == T.Element,
    V.Index == T.Index,
    W: RandomAccessCollection,
    W: MutableCollection,
    W.Element == T.Element,
    W.Index == T.Index
{
    dividend.withUInt32Buffer
    { dividend in
        divisor.withUInt32Buffer
        { divisor in
            quotient.withMutableUInt32Buffer
            {
                var quotient = $0
                remainder.withMutableUInt32Buffer
                {
                    var remainder = $0
                    divideWithRemainder_KnuthD(
                        dividend,
                        by: divisor,
                        quotient: &quotient,
                        remainder: &remainder
                    )
                }
            }
        }
    }
}
#endif
