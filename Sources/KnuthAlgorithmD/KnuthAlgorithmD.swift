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
 , Volume 2,*Semi-numerical Algorithms*, Chapter 4.3.3.
 
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
    T.Element: FixedWidthInteger,
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
    typealias Digit = T.Element
    typealias TwoDigits = (high: T.Element, low: T.Element)
    let digitWidth = Digit.bitWidth
    let m = dividend.count
    let n = divisor.count
    
    assert(n > 0, "Divisor must have at least one digit")
    assert(divisor.reduce(0) { $0 | $1 } != 0, "Division by 0")
    assert(m >= n, "Dividend must have at least as many digits as the divisor")
    assert(
        quotient.count >= m - n + 1,
        "Must have space for the number of digits in the dividend minus the "
        + "number of digits in the divisor plus one more digit."
    )
    assert(
        remainder.count == n,
        "Remainder must have space for the same number of digits as the divisor"
    )

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
    
    let vLast: Digit = v.last!
    let vNextToLast: Digit = v[n - 2]
    let partialDividendDelta: TwoDigits = (high: vLast, low: 0)

    for j in (0...(m - n)).reversed()
    {
        let jPlusN = j &+ n
        
        let dividendHead: TwoDigits = (high: u[jPlusN], low: u[jPlusN &- 1])
        
        // These are tuple arithemtic operations.  `/%` is custom combined
        // division and remainder operator.  See TupleMath.swift
        var (q̂, r̂) = dividendHead /% vLast
        var partialProduct = q̂ * vNextToLast
        var partialDividend:TwoDigits = (high: r̂.low, low: u[jPlusN &- 2])
        
        while true
        {
            if (UInt8(q̂.high != 0) | (partialProduct > partialDividend)) == 1
            {
                q̂ -= 1
                r̂ += vLast
                partialProduct -= vNextToLast
                partialDividend += partialDividendDelta
                
                if r̂.high == 0 { continue }
            }
            break
        }

        quotient[j] = q̂.low
        
        if subtractReportingBorrow(v[0..<n], times: q̂.low, from: &u[j...jPlusN])
        {
            quotient[j] &-= 1
            u[j...jPlusN] += v[0..<n] // digit collection addition!
        }
    }
    
    rightShift(u[0..<n], by: shift, into: &remainder)
}
