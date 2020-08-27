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

fileprivate let hexDigits = [Character]("0123456789abcdef")

// -------------------------------------
extension String.StringInterpolation
{
    // -------------------------------------
    mutating func appendInterpolation<T>(x: T)
        where T: FixedWidthInteger
    {
        var s = ""
        s.reserveCapacity(MemoryLayout<T>.size * 2)
        toHex(x, into: &s)
        appendLiteral(s)
    }
    
    // -------------------------------------
    enum DigitOrder
    {
        case leastSignficantDigitsFirst
        case mostSignficantDigitsFirst
    }
    
    // -------------------------------------
    mutating func appendInterpolation<T>(
        x: T,
        digitOrder: DigitOrder = .mostSignficantDigitsFirst)
        where T:RandomAccessCollection,
        T.Element: FixedWidthInteger,
        T.Index == Int
    {
        var s = ""
        s.reserveCapacity(MemoryLayout<T>.size * x.count * 2)
        
        switch digitOrder
        {
            case .mostSignficantDigitsFirst:
                for value in x.reversed() {
                    toHex(value, into: &s)
                }
            
            case .leastSignficantDigitsFirst:
                for value in x.reversed() {
                    toHex(value, into: &s)
                }
        }
        
        appendLiteral(s)
        
    }
    
    // -------------------------------------
    fileprivate func toHex<T: FixedWidthInteger>(_ x: T, into s: inout String)
    {
        let nibbleCount = MemoryLayout<T>.size * 2
        
        var hexChars = [Character]()
        hexChars.reserveCapacity(nibbleCount)
        
        var value = x
        for _ in 0..<nibbleCount
        {
            hexChars.append(hexDigits[Int(value & 0xf)])
            value >>= 4
        }
        
        s.append(contentsOf: hexChars.reversed())
    }
}
