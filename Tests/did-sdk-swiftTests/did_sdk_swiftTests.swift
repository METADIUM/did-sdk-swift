import XCTest
@testable import did_sdk_swift

final class did_sdk_swiftTests: XCTestCase {
    func testExample() throws {
        // XCTest Documentation
        // https://developer.apple.com/documentation/xctest

        // Defining Test Cases and Test Methods
        // https://developer.apple.com/documentation/xctest/defining_test_cases_and_test_methods
        
        
        //테스트넷 설정
        let delegator = MetaDelegator(delegatorUrl: "https://testdelegator.metadium.com",
                                      nodeUrl: "https://api.metadium.com/dev",
                                      resolverUrl: "https://testnetresolver.metadium.com/1.0/identifiers/",
                                      didPrefix: "did:meta:testnet:",
                                      api_key: "")
        
        var issuer: MetaWallet!
        var user: MetaWallet!
        
        // 1. 발급자, 사용자 DID 생성
        issuer = MetaWallet(delegator: delegator)
        
        let semaPhore = DispatchSemaphore(value: 0)
        
        issuer.createDID {

            print(issuer.getDid())
            
            user = MetaWallet(delegator: delegator)
            user.createDID {
                
                self.verify(issuer: issuer, user: user, resolverUrl: delegator.resolverUrl)
                semaPhore.signal()
            }
        }
        
        semaPhore.wait()
    }
    
    func verify(issuer: MetaWallet, user: MetaWallet, resolverUrl: String) {
        //사용자의 DID
        let holderDid = user.getDid()
        
        let claims = ["name" : "YoungBaeJeon", "birth" : "19800101", "id" : "800101xxxxxxxx"]
        
        let personalIdVC = try! issuer.issueCredential(types: ["PersonalIdCredential"],
                                                       id: "http://aa.metadium.com/credential/name/343",
                                                       nonce: nil,
                                                       issuanceDate: Date(),
                                                       expirationDate: Date.init(timeIntervalSinceNow: 60 * 60),
                                                       ownerDid: holderDid,
                                                       subjects: claims)?.serialize()
        
        //발급자가 사용자에게 personalIdVC 전달
        
        //사용자가 안전한 공간에 credential 저장
        
        let userVcList: [String] = [personalIdVC!]
        
        // 5. 사용자가 발급자에게 presentation 제출
        // 검증자 요구하는 정보. presentation name, types
        
        let requirePresentationName = "TestPresentation"
        let requireCredentialType = ["PersonalIdCredential"]
        
        //presentation 발급
        
        let foundVcList = self.findVC(holderVcList: userVcList, typesOfRequiresVcs: [requireCredentialType])
        
        let vpForVerify = try? user.issuePresentation(types: [requirePresentationName], id: nil, nonce: nil, issuanceDate: Date(), expirationDate: Date.init(timeIntervalSinceNow: 60 * 60), vcList: foundVcList)?.serialize()
        
        
        //사용자가 검증자에게 vpForVerify 제출
        
        // 6. 검증자가 presentation 검증
        
        let vpJwt = try? JWSObject(string: vpForVerify!)
        let isVerify = try! MetaWallet.verify(jwt: vpJwt!, resolverUrl: resolverUrl)
        
        let jwt = try? JWT.init(jsonData: vpJwt!.payload)
        
        if !isVerify {
            XCTAssert(false, "vpForVerify 검증 실패")
        }
        else if jwt?.expirationTime != nil && (jwt?.expirationTime)! < Date() {
            XCTAssert(false, "vpForVerify 만료")
        }
        
        let vpObj = try! VerifiablePresentation(jws: vpJwt!)
        let presentorDid = vpObj.holder
        
        
        //Credential 목록 확인 및 검증
        for vc in vpObj.verifiableCredentials()! {
            
            if vc is String {
                let signedVc = try! JWSObject(string: vc as! String)
                
                let vcPayload = try! JWT.init(jsonData: signedVc.payload)
                
                if !(try! MetaWallet.verify(jwt: signedVc, resolverUrl: resolverUrl)) {
                    XCTAssert(false)
                }
                else if vcPayload.expirationTime != nil && vcPayload.expirationTime! < Date() {
                    XCTAssert(false)
                }
                
                //credential 소유자 확인
                if vcPayload.subject != user.getDid() || presentorDid != user.getDid() {
                    XCTAssert(false)
                }
                
                //요구하는 발급자가 발급한 credential 인지 확인
                let credential = try! VerifiableCredential(jws: signedVc)
                
                if credential.issuer != issuer.getDid() {
                    XCTAssert(false)
                }
                
                //claim 정보 확인
                if let subjects = credential.credentialSubject as? [String : Any] {
                    
                    for (key, value) in subjects {
                        let claimName = key
                        let claimValue = value
                        
                        print("\(claimName) = \(claimValue)")
                    }
                }
            }
        }
    }
    
    func findVC(holderVcList: [String], typesOfRequiresVcs: [[String]]) -> [String] {
        
        var ret: [String] = []
        
        for serializedVc in holderVcList {
            
            let credential = try! VerifiableCredential.init(jws: JWSObject.init(string: serializedVc))
            
            for types in typesOfRequiresVcs {
                
                if credential.getTypes()!.contains(array: types) {
                    ret.append(serializedVc)
                }
            }
        }
        
        return ret
    }
}


extension Array where Element: Equatable {
    func contains(array: [Element]) -> Bool {
        for item in array {
            if !self.contains(item) { return false }
        }
        return true
    }
}
