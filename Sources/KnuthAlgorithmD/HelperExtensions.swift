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
        { buf in
            precondition(
                buf.baseAddress != nil,
                "\(Self.self) does not support accessing contiguous storage"
            )
            
            return try buf.baseAddress!
                .withMemoryRebound(to: UInt32.self, capacity: buf.count * 2)
                { ptr in
                    return try body(
                        UnsafeBufferPointer(start: ptr, count: buf.count * 2)
                    )
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
        { buf in
            precondition(
                buf.baseAddress != nil,
                "\(Self.self) does not support accessing contiguous storage"
            )
            
            return try buf.baseAddress!
                .withMemoryRebound(to: UInt32.self, capacity: buf.count * 2)
                { ptr in
                    return try body(
                        UnsafeMutableBufferPointer(
                            start: ptr,
                            count: buf.count * 2
                        )
                    )
                }
        }!
    }
}
