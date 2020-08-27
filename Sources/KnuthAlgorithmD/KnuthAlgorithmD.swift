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

import Foundation

internal extension FixedWidthInteger
{
    // -------------------------------------
    /// Fast creation of an integer from a Bool
    @usableFromInline @inline(__always) init(_ source: Bool)
    {
        assert(unsafeBitCast(source, to: UInt8.self) & 0xfe == 0)
        self.init(unsafeBitCast(source, to: UInt8.self))
    }
}

// -------------------------------------
internal extension RandomAccessCollection
    where Element: FixedWidthInteger, Element: UnsignedInteger
{
    @usableFromInline @inline(__always)
    func withUInt32Buffer<R>(
        body: (UnsafeBufferPointer<UInt32>) throws -> R) rethrows -> R
    {
        return try withContiguousStorageIfAvailable
        {
            precondition(
                $0.baseAddress != nil,
                "\(Self.self) does not support accessing contiguous storage"
            )
            
            return try $0.withMemoryRebound(to: UInt32.self) {
                return try body($0)
            }
        }!
    }
}

// -------------------------------------
internal extension RandomAccessCollection
    where
    Element: FixedWidthInteger,
    Element: UnsignedInteger,
    Self: MutableCollection
{
    @usableFromInline @inline(__always)
    mutating func withMutableUInt32Buffer<R>(
        body: (UnsafeMutableBufferPointer<UInt32>) throws -> R) rethrows -> R
    {
        return try withContiguousMutableStorageIfAvailable
        {
            precondition(
                $0.baseAddress != nil,
                "\(Self.self) does not support accessing mutable contiguous "
                + "storage"
            )
            
            return try $0.withMemoryRebound(to: UInt32.self) {
                return try body($0)
            }
        }!
    }
}

// -------------------------------------
@usableFromInline @inline(__always)
func subtractReportingBorrow<T: FixedWidthInteger>(_ x: inout T, _ y: T) -> T
{
    let b: Bool
    (x, b) = x.subtractingReportingOverflow(y)
    return T(b)
}

// -------------------------------------
@usableFromInline @inline(__always)
func addReportingCarry<T: FixedWidthInteger>(_ x: inout T, _ y: T) -> T
{
    let c: Bool
    (x, c) = x.addingReportingOverflow(y)
    return T(c)
}

// -------------------------------------
@usableFromInline @inline(__always)
func subtractReportingBorrow<T, U>(
    _ x: T,
    times k: T.Element,
    from y: inout U) -> T.Element
    where T: RandomAccessCollection,
    T.Element: FixedWidthInteger,
    T.Element.Magnitude == T.Element,
    T.Index == Int,
    U: RandomAccessCollection,
    U: MutableCollection,
    U.Element == T.Element,
    U.Index == T.Index
{
    assert(x.count <= y.count)
    
    var borrow: T.Element = 0
    for (i, j) in zip(x.indices, y.indices)
    {
        borrow = subtractReportingBorrow(&y[j], borrow)
        let (pHi, pLo) = k.multipliedFullWidth(by: x[i])
        borrow &+= pHi
        borrow &+= subtractReportingBorrow(&y[j], pLo)
    }
    return borrow
}

// -------------------------------------
@usableFromInline @inline(__always)
func addReportingCarry<T, U>(x: T, to y: inout U) -> T.Element
    where T: RandomAccessCollection,
    T.Element: FixedWidthInteger,
    T.Index == Int,
    U: RandomAccessCollection,
    U: MutableCollection,
    U.Element == T.Element,
    U.Index == T.Index
{
    assert(x.count == y.count)
    var carry: T.Element = 0
    for (i, j) in zip(x.indices, y.indices)
    {
        carry = addReportingCarry(&y[j], carry)
        carry &+= addReportingCarry(&y[j], x[i])
    }
    
    return carry
}

// -------------------------------------
@usableFromInline @inline(__always)
func leftShift<T, U>(_ x: T, by shift: Int, into y: inout U)
    where
    T: RandomAccessCollection,
    T.Element:BinaryInteger,
    T.Index == Int,
    U: RandomAccessCollection,
    U: MutableCollection,
    U.Element == T.Element,
    U.Index == T.Index
{
    assert(y.count >= x.count)
    assert(y.startIndex == x.startIndex)
    
    let bitWidth = MemoryLayout<T.Element>.size * 8
    
    for i in (1..<x.count).reversed() {
        y[i] = (x[i] << shift) | (x[i - 1] >> (bitWidth - shift))
    }
    y[0] = x[0] << shift
}

// -------------------------------------
@usableFromInline @inline(__always)
func rightShift<T, U>(_ x: T, by shift: Int, into y: inout U)
    where
    T: RandomAccessCollection,
    T.Element:BinaryInteger,
    T.Index == Int,
    U: RandomAccessCollection,
    U: MutableCollection,
    U.Element == T.Element,
    U.Index == T.Index
{
    assert(y.count == x.count)
    assert(y.startIndex == x.startIndex)
    let bitWidth = MemoryLayout<T.Element>.size * 8
    
    let lastElemIndex = x.count - 1
    for i in 0..<lastElemIndex {
        y[i] = (x[i] >> shift) | (x[i + 1] << (bitWidth - shift))
    }
    y[lastElemIndex] = x[lastElemIndex] >> shift
}

// -------------------------------------
/**
 Divide the multiprecision number stored in x, by the "digit" y.
 
 - Parameters:
    x: The dividend as a multiprecision number with the least signficant digit
        stored at index 0 (ie. little endian).
    y: The single digit divisor (where digit is the same radix as digits of
        `x`).
    z: storage to receive the quotient on exit.  Must be same size as `x`

- Returns: A single digit remainder.
 */
@usableFromInline @inline(__always)
func divide<T, U>(_ x: T, by y: T.Element, result z: inout U) -> T.Element
    where T: RandomAccessCollection,
    T.Element: FixedWidthInteger,
    T.Element.Magnitude == T.Element,
    T.Index == Int,
    U: RandomAccessCollection,
    U: MutableCollection,
    U.Element == T.Element,
    U.Index == T.Index
{
    assert(x.count == z.count)
    assert(x.startIndex == z.startIndex)
    
    var r: T.Element = 0
    var i = x.count - 1
    
    (z[i], r) = x[i].quotientAndRemainder(dividingBy: y)
    i -= 1
    
    while i >= 0
    {
        (z[i], r) = y.dividingFullWidth((r, x[i]))
        i -= 1
    }
    return r
}


// -------------------------------------
/*
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
         These two lines are inside the loop according to Knuth's algorithm,
         but in fact, we only need to do the multiplications once, then we can
         update these with addition and subtraction in the loop if needed.  To
         be sure, these multiplications translate directly to native
         instructions, so they're not slow, but so do the addition and
         subtraction, and they're faster than multiplication.
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
/*
 Divide multiprecision unsigned integer, `x`, by multiprecision unsigned
 integer, `y`, obtaining both the quotient and remainder.
 
 Implements Alogorithm D, from Donald Knuth's, *The Art of Computer Programming*
 , Volume 2,*Semi-numerical Algorithms*, Chapter 4.3.1.
 
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
/*
 Divide multiprecision unsigned integer, `x`, by multiprecision unsigned
 integer, `y`, obtaining both the quotient and remainder.
 
 Implements Alogorithm D, from Donald Knuth's, *The Art of Computer Programming*
 , Volume 2,*Semi-numerical Algorithms*, Chapter 4.3.1.
 
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
