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

/*
 The operators in this file implement the tuple operations for the 2-digit
 arithmetic needed for Knuth's Algorithm D, and *only* those operations.
 There is no attempt to be a complete set. They are meant to make the code that
 uses them more readable than if the operations they express were written out
 directly.
 */
// -------------------------------------
/// Multiply a tuple of digits by 1 digit
@usableFromInline @inline(__always)
internal func * <T>(
    left: (high: T, low: T),
    right: T) -> (high: T, low: T)
    where T: FixedWidthInteger, T.Magnitude == T
{
    var product = left.low.multipliedFullWidth(by: right)
    let productHigh = left.high.multipliedFullWidth(by: right)
    assert(productHigh.high == 0, "multiplication overflow")
    let c = addReportingCarry(&product.high, productHigh.low)
    assert(c == 0, "multiplication overflow")
    
    return product
}

infix operator /% : MultiplicationPrecedence

// -------------------------------------
/// Divide a tuple of digits by 1 digit obtaining both quotient and remainder
@usableFromInline @inline(__always)
internal func /% <T>(
    left: (high: T, low: T),
    right: T) -> (quotient: (high: T, low: T), remainder: (high: T, low: T))
    where T: FixedWidthInteger, T.Magnitude == T
{
    var r: T
    let q: (high: T, low: T)
    (q.high, r) = left.high.quotientAndRemainder(dividingBy: right)
    (q.low, r) = right.dividingFullWidth((high: r, low: left.low))
    
    return (q, (high: 0, low: r))
}

// -------------------------------------
/**
 Tests if  the typle, `left`, is greater than tuple, `right`.
 
 - Returns: `UInt8` that has the value of 1 if `left` is greater than right;
    otherwise, 0.  This is done in place of returning a boolean as part of an
    optimization to avoid hidden conditional branches in boolean expressions.
 */

@usableFromInline @inline(__always)
internal func > <T>(left: (high: T, low: T), right: (high: T, low: T)) -> UInt8
    where T: FixedWidthInteger, T.Magnitude == T
{
    return UInt8(left.high > right.high)
        | (UInt8(left.high == right.high) & UInt8(left.low > right.low))
}

// -------------------------------------
/// Add a digit to a tuple's low part, carrying to the high part.
@usableFromInline @inline(__always)
func += <T>(left: inout (high: T, low: T), right: T)
    where T: FixedWidthInteger, T.Magnitude == T

{
    left.high &+= addReportingCarry(&left.low, right)
}

// -------------------------------------
/// Add one tuple to another tuple
@usableFromInline @inline(__always)
func += <T>(left: inout (high: T, low: T), right: (high: T, low: T))
    where T: FixedWidthInteger, T.Magnitude == T

{
    left.high &+= addReportingCarry(&left.low, right.low)
    left.high &+= right.high
}

// -------------------------------------
/// Subtract a digit from a tuple, borrowing the high part if necessary
@usableFromInline @inline(__always)
func -= <T>(left: inout (high: T, low: T), right: T)
    where T: FixedWidthInteger, T.Magnitude == T

{
    left.high &-= subtractReportingBorrow(&left.low, right)
}
