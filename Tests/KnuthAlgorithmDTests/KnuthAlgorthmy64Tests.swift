import XCTest
@testable import KnuthAlgorithmD

class KnuthAlgorthmy64Tests: XCTestCase
{
    // -------------------------------------
    func generateRandomArray(_ count: Int) -> [UInt64]
    {
        var x = [UInt64]()
        x.reserveCapacity(count)
        
        for _ in 0..<count {
            x.append(UInt64.random(in: 0...UInt64.max))
        }
        
        if x.last! == 0 { x[count - 1] |= 1 }
        
        return x
    }
    
    // -------------------------------------
    func test_64_bit_algorthm_against_original()
    {
        for _ in 0..<100
        {
            let divisorLength = Int.random(in: 1...100)
            let dividendLength = Int.random(in: divisorLength...200)
            
            let divisor = generateRandomArray(divisorLength)
            let dividend = generateRandomArray(dividendLength)
            
            let quotientLength = dividendLength - divisorLength + 1
            
            var originalQuotient = [UInt64](repeating: 0, count: quotientLength)
            var originalRemainder = [UInt64](repeating: 0, count: divisorLength)
            
            divideWithRemainder_KnuthD(
                dividend,
                by: divisor,
                quotient: &originalQuotient,
                remainder: &originalRemainder
            )
            
            var newQuotient = [UInt64](repeating: 0, count: quotientLength)
            var newRemainder = [UInt64](repeating: 0, count: divisorLength)
            
            divideWithRemainder_KnuthD64(
                dividend,
                by: divisor,
                quotient: &newQuotient,
                remainder: &newRemainder
            )
            
            XCTAssertEqual(newQuotient, originalQuotient)
            XCTAssertEqual(newRemainder, originalRemainder)
        }
    }
}
