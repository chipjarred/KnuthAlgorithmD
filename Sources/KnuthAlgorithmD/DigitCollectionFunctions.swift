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
 Subtract two `FixedWidthInteger`s, `x`, and `y`, storing the result back to
 `y`. (ie. `x -= y`)
 
 - Parameters:
    - x: The minuend and recipient of the resulting difference.
    - y: The subtrahend
 
 - Returns: Borrow out of the difference.
 */
@usableFromInline @inline(__always)
func subtractReportingBorrow<T: FixedWidthInteger>(_ x: inout T, _ y: T) -> T
{
    let b: Bool
    (x, b) = x.subtractingReportingOverflow(y)
    return T(b)
}

// -------------------------------------
/**
 Add two `FixedWidthInteger`s, `x`, and `y`, storing the result back to `x`.
 (ie. `x += y`)
 
 - Parameters:
    - x: The first addend and recipient of the resulting sum.
    - y: The second addend
 
 - Returns: Carry out of the sum.
 */
@usableFromInline @inline(__always)
func addReportingCarry<T: FixedWidthInteger>(_ x: inout T, _ y: T) -> T
{
    let c: Bool
    (x, c) = x.addingReportingOverflow(y)
    return T(c)
}

// -------------------------------------
/**
 Compute `y = y - x * k`
 
 - Parameters:
    - x: A multiprecision number with the least signficant digit
        stored at index 0 (ie. little endian).  It is multiplied by the "digit",
        `k`, with the resulting product being subtracted from `y`
    - k: Scalar multiple to apply to `x` prior to subtraction
    - y: Both the number being subtracted from, and the storage for the result,
        represented as a collection of digits with the least signficant digits
        at index 0.
 
 - Returns: The borrow out of the most signficant digit of `y`.
 */
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
/**
 Add two multiprecision numbers.
 
 - Parameters:
    - x: The first addend as a collection digits with the least signficant
        digit at index 0 (ie. little endian).
    - y: The second addend and the storage for the resulting sum as a
        collection of digits with the the least signficant digit at index 0
        (ie. little endian).
 
 - Returns: Carry out of the most signfnifant digits of `y`.
 */
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
/**
 Shift the multiprecision unsigned integer, `x`, left by `shift` bits.
 
 - Parameters:
    - x: The mutliprecision unsigned integer to be left-shfited, stored as a
        collection of digits with the least signficant digit stored at index 0.
        (ie. little endian)
    - shift: the number of bits to shift `x` by.
    - y: Storage for the resulting shift of `x`.  May alias `x`.
 */
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
/**
 Shift the multiprecision unsigned integer,`x`, right by `shift` bits.
 
 - Parameters:
    - x: The mutliprecision unsigned integer to be right-shfited, stored as a
        collection of digits with the least signficant digit stored at index 0.
        (ie. little endian)
    - shift: the number of bits to shift `x` by.
    - y: Storage for the resulting shift of `x`.  May alias `x`.
 */
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
 Divide the multiprecision number stored in `x`, by the "digit",`y.`
 
 - Parameters:
    - x: The dividend as a multiprecision number with the least signficant digit
        stored at index 0 (ie. little endian).
    - y: The single digit divisor (where digit is the same radix as digits of
        `x`).
    - z: storage to receive the quotient on exit.  Must be same size as `x`

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
