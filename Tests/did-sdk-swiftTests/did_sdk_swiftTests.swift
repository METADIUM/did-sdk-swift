import XCTest
@testable import did_sdk_swift

final class did_sdk_swiftTests: XCTestCase {
    func testExample() throws {
        // XCTest Documentation
        // https://developer.apple.com/documentation/xctest

        // Defining Test Cases and Test Methods
        // https://developer.apple.com/documentation/xctest/defining_test_cases_and_test_methods
        
        
        //테스트넷
        let delegator = MetaDelegator(delegatorUrl: "https://testdelegator.metadium.com",
                                      nodeUrl: "https://api.metadium.com/dev",
                                      resolverUrl: "https://testnetresolver.metadium.com/1.0/identifiers/",
                                      didPrefix: "did:meta:testnet:",
                                      api_key: "")
        
        
        // 1. 발급자, 사용자 DID 생성
        let issuerWallet = MetaWallet(delegator: delegator)
        issuerWallet.createDID {
            print(issuerWallet.getDid())
        }
        
        
        let userWallet = MetaWallet(delegator: delegator)
        userWallet.createDID {
            print(userWallet.getDid())
        }
    }
}
