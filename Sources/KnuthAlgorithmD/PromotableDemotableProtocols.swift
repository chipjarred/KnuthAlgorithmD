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
 Protocol for integer types for which there is a larger (double bit width) size
 */
public protocol PromotableInteger: FixedWidthInteger
{
    /// Integer type for the next larger size than this integer.
    associatedtype Promoted: DemotableInteger
}

// -------------------------------------
extension PromotableInteger
{
    // -------------------------------------
    /// This integer's value promoted to the next larger integer size
    @inlinable public var promoted: Promoted
    {
        assert(2 * MemoryLayout<Self>.size == MemoryLayout<Promoted>.size)
        return Promoted(self)
    }
}

// -------------------------------------
/**
  Protocol for integer types for which there is a smaller (half bit width) size
 */
public protocol DemotableInteger: FixedWidthInteger
{
    /// Integer type for the next smaller size than this integer.
    associatedtype Demoted: PromotableInteger
}

// -------------------------------------
extension DemotableInteger
{
    // -------------------------------------
    /// This integer's value demoted to the next smaller integer size
    @inlinable public var demoted: Demoted
    {
        assert(MemoryLayout<Self>.size == 2 * MemoryLayout<Demoted>.size)
        return Demoted(self)
    }
}

// -------------------------------------
extension UInt64: DemotableInteger {
    public typealias Demoted = UInt32
}
extension UInt32: PromotableInteger, DemotableInteger
{
    public typealias Promoted = UInt64
    public typealias Demoted = UInt16
}
extension UInt16: PromotableInteger, DemotableInteger
{
    public typealias Promoted = UInt32
    public typealias Demoted = UInt8
}
extension UInt8: PromotableInteger
{
    public typealias Promoted = UInt16
}

extension Int64: DemotableInteger {
    public typealias Demoted = Int32
}
extension Int32: PromotableInteger, DemotableInteger
{
    public typealias Promoted = Int64
    public typealias Demoted = Int16
}
extension Int16: PromotableInteger, DemotableInteger
{
    public typealias Promoted = Int32
    public typealias Demoted = Int8
}
extension Int8: PromotableInteger
{
    public typealias Promoted = Int16
}

#if arch(x86_64) || arch(arm64)
// 64-bit UInt
extension UInt: DemotableInteger {
    public typealias Demoted = UInt32
}

// 64-bit Int
extension Int: DemotableInteger {
    public typealias Demoted = Int32
}
#elseif arch(arm) || arch(i386)
// 32-bit UInt
extension UInt: PromotableInteger, DemotableInteger {
    public typealias Promoted = UInt64
    public typealias Demoted = UInt16
}

// 32-bit Int
extension Int: PromotableInteger, DemotableInteger {
    public typealias Promoted = Int64
    public typealias Demoted = Int16
}
#else
#error("Include your architecture according to UInt size")
#endif

// -------------------------------------
extension FixedWidthInteger
{
    @usableFromInline @inline(__always)
    static var lowMask: Self { Self.max >> (Self.bitWidth / 2) }
    
}

// -------------------------------------
extension FixedWidthInteger where Self: DemotableInteger
{
    // -------------------------------------
    /// The value of the least signficant half of this integer
    @inlinable
    public var low: Demoted { (self & Self.lowMask).demoted }

    // -------------------------------------
    /// The value of the most signficant half of this integer
    @inlinable
    public var high: Demoted { (self >> (Self.bitWidth / 2)).demoted }
}
