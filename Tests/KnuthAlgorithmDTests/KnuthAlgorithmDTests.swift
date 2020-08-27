import XCTest
@testable import KnuthAlgorithmD

final class KnuthAlgorithmDTests: XCTestCase {

    static var allTests = [
        (
            "divideWithRemainder_KnuthD dividing 0 by non-zero",
            test_divideWithRemainder_KnuthD_produces_0_quotient_and_remainder_when_dividing_0_by_non_zero
        ),
        (
            "divideWithRemainder_KnuthD dividing number by itself",
            test_divideWithRemainder_KnuthD_produces_quotient_1_and_remainder_0_when_dividing_nonzero_number_by_itself
        ),
        (
            "divideWithRemainder_KnuthD dividing by 1",
            test_divideWithRemainder_KnuthD_produces_quotient_same_as_dividend_and_remainder_0_when_dividing_nonzero_number_by_1
        ),
        (
            "divideWithRemainder_KnuthD dividing by repeated digit by that digit",
            test_divideWithRemainder_KnuthD_produces_quotient_1s_corresponding_to_each_dividend_digit_and_remainder_0_when_dividend_consists_of_repeating_digit_and_divisor_is_that_digit
        ),
        (
            "divideWithRemainder_KnuthD divisor greater than dividend",
            test_divideWithRemainder_KnuthD_produces_quotient_0_remainder_same_as_dividend_when_divisor_is_greater_than_dividend
        ),
        (
            "divideWithRemainder_KnuthD miscellaneous common cases",
            test_divideWithRemainder_KnuthD_miscellaneous_common_cases
        ),
        (
            "divideWithRemainder_KnuthD first estimated quotient digit larger than radix",
            test_divideWithRemainder_KnuthD_first_estimated_quotient_digit_can_be_larger_than_the_radix
        ),
        (
            "divideWithRemainder_KnuthD adding back step needed",
            test_divideWithRemainder_KnuthD_cases_when_adding_back_to_remainder_and_decrementing_quotient_digit_is_required
        ),
        (
            "divideWithRemainder_KnuthD result of multiply and subtract step cannot be treated as signed",
            test_divideWithRemainder_KnuthD_results_of_multiply_and_subtract_for_intermediate_remainder_cannot_be_treated_as_signed
        ),
    ]
    
    // -------------------------------------
    struct TestCase
    {
        let dividend: [UInt32]
        let divisor: [UInt32]
        let expectedQuotient: [UInt32]
        let expectedRemainder: [UInt32]
        let expectsError: Bool
        
        var m: Int { return dividend.count }
        var n: Int { return divisor.count }
    }
    
    static let digitMax = UInt32.max
    var randomDigit: UInt32 { UInt32.random(in: 0...UInt32.max) }

    // -------------------------------------
    func test_divideWithRemainder_KnuthD_produces_0_quotient_and_remainder_when_dividing_0_by_non_zero() throws
    {
        var testCases: [TestCase] =
        [
            TestCase(
                dividend: [0],
                divisor: [Self.digitMax],
                expectedQuotient: [0],
                expectedRemainder: [0],
                expectsError: false
            ),
            TestCase(
                dividend: [0, 0],
                divisor: [0,1],
                expectedQuotient: [0],
                expectedRemainder: [0,0],
                expectsError: false
            )
        ]
        
        for _ in 0..<100
        {
            let dividendSize = Int.random(in: 1..<256)
            var dividend = [UInt32]()
            dividend.reserveCapacity(dividendSize)
            for _ in 0..<dividendSize { dividend.append(0) }
            let divisorSize = Int.random(in: 1...dividendSize)
            var divisor = [UInt32]()
            divisor.reserveCapacity(divisorSize)
            for _ in 0..<dividendSize { divisor.append(randomDigit) }

            testCases.append(
                TestCase(
                    dividend: dividend,
                    divisor: divisor,
                    expectedQuotient: [0],
                    expectedRemainder: .init(repeating: 0, count: dividendSize),
                    expectsError: false
                )
            )
        }

        for testCase in testCases
        {
            let m = testCase.m
            let n = testCase.n
            let u = testCase.dividend
            let v = testCase.divisor
            let cq = testCase.expectedQuotient
            let cr = testCase.expectedRemainder

            var q = [UInt32](repeating: 0, count: max(m - n + 1, 1))
            var r: [UInt32] = [UInt32](repeating: 0, count: n)

            divideWithRemainder_KnuthD(
                testCase.dividend,
                by: testCase.divisor,
                quotient: &q,
                remainder: &r
            )
            
            XCTAssertEqual(
                q,
                cq,
                  "\nError, dividend u = \(x: u)\n"
                + "       divisor  v = \(x: v)\n"
                + "For quotient,  got: \(x: q)\n"
                + "        Should get: \(x: cq)\n"
            )
            
            XCTAssertEqual(
                r,
                cr,
                  "\nError, dividend u = \(x: u)\n"
                + "       divisor  v = \(x: v)\n"
                + "For remainder, got: \(x: r)\n"
                + "        Should get: \(x: cr)\n"
            )
        }
    }
    
    // -------------------------------------
    func test_divideWithRemainder_KnuthD_produces_quotient_1_and_remainder_0_when_dividing_nonzero_number_by_itself() throws
    {
        var testCases: [TestCase] =
        [
            TestCase(
                dividend: [3],
                divisor: [3],
                expectedQuotient: [1],
                expectedRemainder: [0],
                expectsError: false
            ),
            TestCase(
                dividend: [Self.digitMax],
                divisor: [Self.digitMax],
                expectedQuotient: [1],
                expectedRemainder: [0],
                expectsError: false
            ),
            TestCase(
                dividend: [0x0000ffff, 0x0000ffff],
                divisor: [0x0000ffff, 0x0000ffff],
                expectedQuotient: [1],
                expectedRemainder: [0, 0],
                expectsError: false
            ),
            TestCase(
                dividend: [0x0000789a, 0x0000bcde],
                divisor: [0x0000789a, 0x0000bcde],
                expectedQuotient: [1],
                expectedRemainder: [0, 0],
                expectsError: false
            ),
        ]
        
        for _ in 0..<100
        {
            let dividendSize = Int.random(in: 1..<256)
            var dividend = [UInt32]()
            dividend.reserveCapacity(dividendSize)
            for _ in 0..<dividendSize { dividend.append(randomDigit) }

            testCases.append(
                TestCase(
                    dividend: dividend,
                    divisor: dividend,
                    expectedQuotient: [1],
                    expectedRemainder: .init(repeating: 0, count: dividendSize),
                    expectsError: false
                )
            )
        }

        for testCase in testCases
        {
            let m = testCase.m
            let n = testCase.n
            let u = testCase.dividend
            let v = testCase.divisor
            let cq = testCase.expectedQuotient
            let cr = testCase.expectedRemainder

            var q = [UInt32](repeating: 0, count: max(m - n + 1, 1))
            var r: [UInt32] = [UInt32](repeating: 0, count: n)

            divideWithRemainder_KnuthD(
                testCase.dividend,
                by: testCase.divisor,
                quotient: &q,
                remainder: &r
            )
            
            XCTAssertEqual(
                q,
                cq,
                  "\nError, dividend u = \(x: u)\n"
                + "       divisor  v = \(x: v)\n"
                + "For quotient,  got: \(x: q)\n"
                + "        Should get: \(x: cq)\n"
            )
            
            XCTAssertEqual(
                r,
                cr,
                  "\nError, dividend u = \(x: u)\n"
                + "       divisor  v = \(x: v)\n"
                + "For remainder, got: \(x: r)\n"
                + "        Should get: \(x: cr)\n"
            )
        }
    }
    
    // -------------------------------------
    func test_divideWithRemainder_KnuthD_produces_quotient_same_as_dividend_and_remainder_0_when_dividing_nonzero_number_by_1() throws
    {
        var testCases: [TestCase] =
        [
            TestCase(
                dividend: [Self.digitMax],
                divisor: [1],
                expectedQuotient: [Self.digitMax],
                expectedRemainder: [0],
                expectsError: false
            ),
            TestCase(
                dividend: [Self.digitMax, Self.digitMax],
                divisor: [1],
                expectedQuotient: [Self.digitMax, Self.digitMax],
                expectedRemainder: [0],
                expectsError: false
            ),
        ]
        
        for _ in 0..<100
        {
            let dividendSize = Int.random(in: 1..<256)
            var dividend = [UInt32]()
            dividend.reserveCapacity(dividendSize)
            for _ in 0..<dividendSize { dividend.append(randomDigit) }

            testCases.append(
                TestCase(
                    dividend: dividend,
                    divisor: [1],
                    expectedQuotient: dividend,
                    expectedRemainder: [0],
                    expectsError: false
                )
            )
        }
        
        for testCase in testCases
        {
            let m = testCase.m
            let n = testCase.n
            let u = testCase.dividend
            let v = testCase.divisor
            let cq = testCase.expectedQuotient
            let cr = testCase.expectedRemainder

            var q = [UInt32](repeating: 0, count: max(m - n + 1, 1))
            var r: [UInt32] = [UInt32](repeating: 0, count: n)

            divideWithRemainder_KnuthD(
                testCase.dividend,
                by: testCase.divisor,
                quotient: &q,
                remainder: &r
            )
            
            XCTAssertEqual(
                q,
                cq,
                  "\nError, dividend u = \(x: u)\n"
                + "       divisor  v = \(x: v)\n"
                + "For quotient,  got: \(x: q)\n"
                + "        Should get: \(x: cq)\n"
            )
            
            XCTAssertEqual(
                r,
                cr,
                  "\nError, dividend u = \(x: u)\n"
                + "       divisor  v = \(x: v)\n"
                + "For remainder, got: \(x: r)\n"
                + "        Should get: \(x: cr)\n"
            )
        }
    }
    
    // -------------------------------------
    func test_divideWithRemainder_KnuthD_produces_quotient_1s_corresponding_to_each_dividend_digit_and_remainder_0_when_dividend_consists_of_repeating_digit_and_divisor_is_that_digit() throws
    {
        var testCases: [TestCase] =
        [
            TestCase(
                dividend: [Self.digitMax, Self.digitMax],
                divisor: [Self.digitMax],
                expectedQuotient: [1,1],
                expectedRemainder: [0],
                expectsError: false
            ),
        ]
        
        for _ in 0..<100
        {
            let digit = randomDigit
            let dividendSize = Int.random(in: 1..<256)
            var dividend = [UInt32]()
            dividend.reserveCapacity(dividendSize)
            for _ in 0..<dividendSize { dividend.append(digit) }

            testCases.append(
                TestCase(
                    dividend: dividend,
                    divisor: [digit],
                    expectedQuotient: .init(repeating: 1, count: dividendSize),
                    expectedRemainder: [0],
                    expectsError: false
                )
            )
        }
        
        for testCase in testCases
        {
            let m = testCase.m
            let n = testCase.n
            let u = testCase.dividend
            let v = testCase.divisor
            let cq = testCase.expectedQuotient
            let cr = testCase.expectedRemainder

            var q = [UInt32](repeating: 0, count: max(m - n + 1, 1))
            var r: [UInt32] = [UInt32](repeating: 0, count: n)

            divideWithRemainder_KnuthD(
                testCase.dividend,
                by: testCase.divisor,
                quotient: &q,
                remainder: &r
            )
            
            XCTAssertEqual(
                q,
                cq,
                  "\nError, dividend u = \(x: u)\n"
                + "       divisor  v = \(x: v)\n"
                + "For quotient,  got: \(x: q)\n"
                + "        Should get: \(x: cq)\n"
            )
            
            XCTAssertEqual(
                r,
                cr,
                  "\nError, dividend u = \(x: u)\n"
                + "       divisor  v = \(x: v)\n"
                + "For remainder, got: \(x: r)\n"
                + "        Should get: \(x: cr)\n"
            )
        }
    }
    
    // -------------------------------------
    func test_divideWithRemainder_KnuthD_produces_quotient_0_remainder_same_as_dividend_when_divisor_is_greater_than_dividend() throws
    {
        var testCases: [TestCase] =
        [
            TestCase(
                dividend: [3],
                divisor: [4],
                expectedQuotient: [0],
                expectedRemainder: [3],
                expectsError: false
            ),
            TestCase(
                dividend: [0x00007899, 0x0000bcde],
                divisor: [0x0000789a, 0x0000bcde],
                expectedQuotient: [0],
                expectedRemainder: [0x00007899, 0x0000bcde],
                expectsError: false
            ),
        ]
        
        for _ in 0..<100
        {
            let dividendSize = Int.random(in: 1..<256)
            var dividend = [UInt32]()
            dividend.reserveCapacity(dividendSize)
            for _ in 0..<dividendSize { dividend.append(randomDigit & ~1) }
            
            var divisor = dividend
            divisor[Int.random(in: divisor.indices)] += 1

            testCases.append(
                TestCase(
                    dividend: dividend,
                    divisor: divisor,
                    expectedQuotient: [0],
                    expectedRemainder: dividend,
                    expectsError: false
                )
            )
        }

        for testCase in testCases
        {
            let m = testCase.m
            let n = testCase.n
            let u = testCase.dividend
            let v = testCase.divisor
            let cq = testCase.expectedQuotient
            let cr = testCase.expectedRemainder

            var q = [UInt32](repeating: 0, count: max(m - n + 1, 1))
            var r: [UInt32] = [UInt32](repeating: 0, count: n)

            divideWithRemainder_KnuthD(
                testCase.dividend,
                by: testCase.divisor,
                quotient: &q,
                remainder: &r
            )
            
            XCTAssertEqual(
                q,
                cq,
                  "\nError, dividend u = \(x: u)\n"
                + "       divisor  v = \(x: v)\n"
                + "For quotient,  got: \(x: q)\n"
                + "        Should get: \(x: cq)\n"
            )
            
            XCTAssertEqual(
                r,
                cr,
                  "\nError, dividend u = \(x: u)\n"
                + "       divisor  v = \(x: v)\n"
                + "For remainder, got: \(x: r)\n"
                + "        Should get: \(x: cr)\n"
            )
        }
    }
    
    // -------------------------------------
    func test_divideWithRemainder_KnuthD_miscellaneous_common_cases() throws
    {
        let testCases: [TestCase] =
        [
            TestCase(
                dividend: [3],
                divisor: [2],
                expectedQuotient: [1],
                expectedRemainder: [1],
                expectsError: false
            ),
            TestCase(
                dividend: [Self.digitMax],
                divisor: [3],
                expectedQuotient: [0x55555555],
                expectedRemainder: [0],
                expectsError: false
            ),
            TestCase(
                dividend: [Self.digitMax, Self.digitMax-1],
                divisor: [Self.digitMax],
                expectedQuotient: [Self.digitMax, 0],
                expectedRemainder: [Self.digitMax-1],
                expectsError: false
            ),
            TestCase(
                dividend: [0x00005678, 0x00001234],
                divisor: [0x00009abc],
                expectedQuotient: [0x1e1dba76,0],
                expectedRemainder: [0x6bd0],
                expectsError: false
            ),
            TestCase(
                dividend: [0, 7],
                divisor: [0,3],
                expectedQuotient: [2],
                expectedRemainder: [0,1],
                expectsError: false
            ),
            TestCase(
                dividend: [5, 7],
                divisor: [0,3],
                expectedQuotient: [2],
                expectedRemainder: [5,1],
                expectsError: false
            ),
            TestCase(
                dividend: [0, 6],
                divisor: [0,2],
                expectedQuotient: [3],
                expectedRemainder: [0,0],
                expectsError: false
            ),
            TestCase(
                dividend: [0x80000000],
                divisor: [0x40000001],
                expectedQuotient: [1],
                expectedRemainder: [0x3fffffff],
                expectsError: false
            ),
            TestCase(
                dividend: [0, 0x80000000],
                divisor: [0x40000001],
                expectedQuotient: [0xfffffff8, 0x00000001],
                expectedRemainder: [0x00000008],
                expectsError: false
            ),
            TestCase(
                dividend: [0, 0x80000000],
                divisor: [0x00000001, 0x40000000],
                expectedQuotient: [1],
                expectedRemainder: [0xffffffff, 0x3fffffff],
                expectsError: false
            ),
            TestCase(
                dividend: [0x0000789b, 0x0000bcde],
                divisor: [0x0000789a, 0x0000bcde],
                expectedQuotient: [1],
                expectedRemainder: [1, 0],
                expectsError: false
            ),
            TestCase(
                dividend: [0x0000ffff, 0x0000ffff],
                divisor: [0x00000000, 0x00000001],
                expectedQuotient: [0x0000ffff],
                expectedRemainder: [0x0000ffff, 0],
                expectsError: false
            ),
            TestCase(
                dividend: [0x000089ab, 0x00004567, 0x00000123],
                divisor: [0x00000000, 0x00000001],
                expectedQuotient: [0x00004567, 0x00000123],
                expectedRemainder: [0x000089ab, 0],
                expectsError: false
            ),
        ]

        for testCase in testCases
        {
            let m = testCase.m
            let n = testCase.n
            let u = testCase.dividend
            let v = testCase.divisor
            let cq = testCase.expectedQuotient
            let cr = testCase.expectedRemainder

            var q = [UInt32](repeating: 0, count: max(m - n + 1, 1))
            var r: [UInt32] = [UInt32](repeating: 0, count: n)

            divideWithRemainder_KnuthD(
                testCase.dividend,
                by: testCase.divisor,
                quotient: &q,
                remainder: &r
            )
            
            XCTAssertEqual(
                q,
                cq,
                  "\nError, dividend u = \(x: u)\n"
                + "       divisor  v = \(x: v)\n"
                + "For quotient,  got: \(x: q)\n"
                + "        Should get: \(x: cq)\n"
            )
            
            XCTAssertEqual(
                r,
                cr,
                  "\nError, dividend u = \(x: u)\n"
                + "       divisor  v = \(x: v)\n"
                + "For remainder, got: \(x: r)\n"
                + "        Should get: \(x: cr)\n"
            )
        }
    }
    
    // -------------------------------------
    func test_divideWithRemainder_KnuthD_first_estimated_quotient_digit_can_be_larger_than_the_radix() throws
    {
        let testCases: [TestCase] =
        [
            TestCase(
                dividend: [0x00000000, 0x0000fffe, 0x00008000],
                divisor: [0x0000ffff, 0x00008000],
                expectedQuotient: [0xffffffff, 0x00000000],
                expectedRemainder: [0x0000ffff, 0x00007fff],
                expectsError: false
            ),
        ]

        for testCase in testCases
        {
            let m = testCase.m
            let n = testCase.n
            let u = testCase.dividend
            let v = testCase.divisor
            let cq = testCase.expectedQuotient
            let cr = testCase.expectedRemainder

            var q = [UInt32](repeating: 0, count: max(m - n + 1, 1))
            var r: [UInt32] = [UInt32](repeating: 0, count: n)

            divideWithRemainder_KnuthD(
                testCase.dividend,
                by: testCase.divisor,
                quotient: &q,
                remainder: &r
            )
            
            XCTAssertEqual(
                q,
                cq,
                  "\nError, dividend u = \(x: u)\n"
                + "       divisor  v = \(x: v)\n"
                + "For quotient,  got: \(x: q)\n"
                + "        Should get: \(x: cq)\n"
            )
            
            XCTAssertEqual(
                r,
                cr,
                  "\nError, dividend u = \(x: u)\n"
                + "       divisor  v = \(x: v)\n"
                + "For remainder, got: \(x: r)\n"
                + "        Should get: \(x: cr)\n"
            )
        }
    }
    
    // -------------------------------------
    func test_divideWithRemainder_KnuthD_cases_when_adding_back_to_remainder_and_decrementing_quotient_digit_is_required() throws
    {
        let testCases: [TestCase] =
        [
            TestCase(
                dividend: [0x00000003, 0x00000000, 0x80000000],
                divisor: [0x00000001, 0x00000000, 0x20000000],
                expectedQuotient: [0x00000003],
                expectedRemainder: [0, 0, 0x20000000],
                expectsError: false
            ),
            TestCase(
                dividend: [0x00000003, 0x00000000, 0x00008000],
                divisor: [0x00000001, 0x00000000, 0x00002000],
                expectedQuotient: [0x00000003],
                expectedRemainder: [0, 0, 0x00002000],
                expectsError: false
            ),
            TestCase(
                dividend: [0, 0, 0x00008000, 0x00007fff],
                divisor: [1, 0, 0x00008000],
                expectedQuotient: [0xfffe0000, 0],
                expectedRemainder: [0x00020000, 0xffffffff, 0x00007fff],
                expectsError: false
            ),
        ]

        for testCase in testCases
        {
            let m = testCase.m
            let n = testCase.n
            let u = testCase.dividend
            let v = testCase.divisor
            let cq = testCase.expectedQuotient
            let cr = testCase.expectedRemainder

            var q = [UInt32](repeating: 0, count: max(m - n + 1, 1))
            var r: [UInt32] = [UInt32](repeating: 0, count: n)

            divideWithRemainder_KnuthD(
                testCase.dividend,
                by: testCase.divisor,
                quotient: &q,
                remainder: &r
            )
            
            XCTAssertEqual(
                q,
                cq,
                  "\nError, dividend u = \(x: u)\n"
                + "       divisor  v = \(x: v)\n"
                + "For quotient,  got: \(x: q)\n"
                + "        Should get: \(x: cq)\n"
            )
            
            XCTAssertEqual(
                r,
                cr,
                  "\nError, dividend u = \(x: u)\n"
                + "       divisor  v = \(x: v)\n"
                + "For remainder, got: \(x: r)\n"
                + "        Should get: \(x: cr)\n"
            )
        }
    }
    
    // -------------------------------------
    func test_divideWithRemainder_KnuthD_results_of_multiply_and_subtract_for_intermediate_remainder_cannot_be_treated_as_signed() throws
    {
        let testCases: [TestCase] =
        [
            TestCase(
                dividend: [0, 0x0000fffe, 0, 0x00008000],
                divisor: [0x0000ffff, 0, 0x00008000],
                expectedQuotient: [0xffffffff, 0],
                expectedRemainder: [0x0000ffff, 0xffffffff, 0x00007fff],
                expectsError: false
            ),

            TestCase(
                dividend: [0, 0xfffffffe, 0, 0x80000000],
                divisor: [0x0000ffff, 0, 0x80000000],
                expectedQuotient: [0x00000000, 1],
                expectedRemainder: [0x00000000, 0xfffeffff, 0x00000000],
                expectsError: false
            ),

            TestCase(
                dividend: [0, 0xfffffffe, 0, 0x80000000],
                divisor: [0xffffffff, 0, 0x80000000],
                expectedQuotient: [0xffffffff, 0],
                expectedRemainder: [0xffffffff, 0xffffffff, 0x7fffffff],
                expectsError: false
            ),
        ]

        for testCase in testCases
        {
            let m = testCase.m
            let n = testCase.n
            let u = testCase.dividend
            let v = testCase.divisor
            let cq = testCase.expectedQuotient
            let cr = testCase.expectedRemainder

            var q = [UInt32](repeating: 0, count: max(m - n + 1, 1))
            var r: [UInt32] = [UInt32](repeating: 0, count: n)

            divideWithRemainder_KnuthD(
                testCase.dividend,
                by: testCase.divisor,
                quotient: &q,
                remainder: &r
            )
            
            XCTAssertEqual(
                q,
                cq,
                  "\nError, dividend u = \(x: u)\n"
                + "       divisor  v = \(x: v)\n"
                + "For quotient,  got: \(x: q)\n"
                + "        Should get: \(x: cq)\n"
            )
            
            XCTAssertEqual(
                r,
                cr,
                  "\nError, dividend u = \(x: u)\n"
                + "       divisor  v = \(x: v)\n"
                + "For remainder, got: \(x: r)\n"
                + "        Should get: \(x: cr)\n"
            )
        }
    }
}
