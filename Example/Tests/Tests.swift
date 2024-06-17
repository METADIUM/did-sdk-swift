import XCTest
import DID_SDK_Swift
//import VerifiableSwift
//import JWTsSwift


class Tests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testExample() {
        // This is an example of a functional test case.
        XCTAssert(true, "Pass")
    }
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure() {
            // Put the code you want to measure the time of here.
        }
    }
    
    
    func test() {
        //메인넷
//        let delegator = MetaDelegator.init()

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
        
        
        
        // Signing
        let signatureData = issuerWallet.getSignature(data: Data())
        
        let signature = String(data: (signatureData?.signData)!, encoding: .utf8)?.addHexPrefix()
        let r = signatureData?.r
        let s = signatureData?.s
        let v = signatureData?.v
        
        print(signature ?? "")
        
        
        // 2. 사용자가 발급자에게 credential 발급 요청
        let vpForIssueCredential = try? userWallet.issuePresentation(types: [],
                                                                     id: nil,
                                                                     nonce: nil,
                                                                     issuanceDate: Date(),
                                                                     expirationDate: nil,
                                                                     vcList: [])?.serialize()
        
        
        
        // 3. 발급자가 DID 검증
        
        do {
            let verified = try! MetaWallet.verify(jwt: JWSObject(string: vpForIssueCredential!!), resolverUrl: delegator.resolverUrl)
            
            if !verified {
                //검증실패
                XCTAssert(false, "vpForIssueCredential 검증 실패")
            }
            
        } catch verifyError.noneDidDocument {
            
        } catch verifyError.nonePublicKey {
            
        } catch verifyError.failedVerify {
            
        }
        
        
        let vp = try? VerifiablePresentation(jws: JWSObject(string: vpForIssueCredential!!))
        
        //사용자의 DID
        let holderDid = vp?.holder
        
        let claims = ["name" : "YoungBaeJeon", "birth" : "19800101", "id" : "800101xxxxxxxx"]
        
        let personalIdVC = try! issuerWallet.issueCredential(types: ["PersonalIdCredential"],
                                                        id: "http://aa.metadium.com/credential/name/343",
                                                        nonce: nil,
                                                        issuanceDate: Date(),
                                                        expirationDate: Date.init(timeIntervalSinceNow: 60 * 60),
                                                        ownerDid: holderDid!,
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
        
        
        let vpForVerify = try? userWallet.issuePresentation(types: [requirePresentationName], id: nil, nonce: nil, issuanceDate: Date(), expirationDate: Date.init(timeIntervalSinceNow: 60 * 60), vcList: foundVcList)?.serialize()
        
        
        //사용자가 검증자에게 vpForVerify 제출
        
        // 6. 검증자가 presentation 검증
        
        let vpJwt = try? JWSObject(string: vpForVerify!!)
        let isVerify = try! MetaWallet.verify(jwt: vpJwt!, resolverUrl: delegator.resolverUrl)
        
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
                
                if !(try! MetaWallet.verify(jwt: signedVc, resolverUrl: delegator.resolverUrl)) {
                    XCTAssert(false)
                }
                else if vcPayload.expirationTime != nil && vcPayload.expirationTime! < Date() {
                    XCTAssert(false)
                }
                
                //credential 소유자 확인
                if vcPayload.subject != userWallet.getDid() || presentorDid != userWallet.getDid() {
                    XCTAssert(false)
                }
                
                //요구하는 발급자가 발급한 credential 인지 확인
                let credential = try! VerifiableCredential(jws: signedVc)
                
                if credential.issuer != issuerWallet.getDid() {
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
