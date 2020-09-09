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
@usableFromInline @inline(__always)
func multiply<T>(
    _ x: (high: T, low: T),
    _ y: T) -> (high: T, low: T)
    where T: FixedWidthInteger, T.Magnitude == T
{
    var product = x.low.multipliedFullWidth(by: y)
    let productHigh = x.high.multipliedFullWidth(by: y)
    assert(productHigh.high == 0, "multiplication overflow")
    let c = addReportingCarry(&product.high, productHigh.low)
    assert(c == 0, "multiplication overflow")
    
    return product
}

// -------------------------------------
@usableFromInline @inline(__always)
func divide<T>(_ x: (high: T, low: T), by y: T)
    -> (quotient: (high: T, low: T), remainder: (high: T, low: T))
    where T: FixedWidthInteger, T.Magnitude == T
{
    var r: T
    let q: (high: T, low: T)
    (q.high, r) = x.high.quotientAndRemainder(dividingBy: y)
    (q.low, r) = y.dividingFullWidth((high: r, low: x.low))
    
    return (q, (high: 0, low: r))
}

// -------------------------------------
@usableFromInline @inline(__always)
func isGreater<T>(
    _ x: (high: T, low: T),
    _ y: (high: T, low: T)) -> UInt8
    where T: FixedWidthInteger, T.Magnitude == T
{
    return UInt8(x.high > y.high)
        | (UInt8(x.high == y.high) & UInt8(x.low > y.low))
}

// -------------------------------------
@usableFromInline @inline(__always)
func add<T>(_ x: inout (high: T, low: T),
                              plus y: T)
    where T: FixedWidthInteger, T.Magnitude == T

{
    x.high &+= addReportingCarry(&x.low, y)
}

// -------------------------------------
@usableFromInline @inline(__always)
func addTuple<T>(
    _ x: inout (high: T, low: T),
    plus y: (high: T, low: T))
    where T: FixedWidthInteger, T.Magnitude == T

{
    x.high &+= addReportingCarry(&x.low, y.low)
    x.high &+= y.high
}

// -------------------------------------
@usableFromInline @inline(__always)
func subtract<T>(
    _ x: inout (high: T, low: T),
    minus y: T)
    where T: FixedWidthInteger, T.Magnitude == T

{
    x.high &-= subtractReportingBorrow(&x.low, y)
}
