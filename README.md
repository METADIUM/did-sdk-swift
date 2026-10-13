# Metadium DID SDK for iOS(Swift)

DID 생성 및 키 관리 기능과 [Verifiable Credential](https://www.w3.org/TR/vc-data-model/) 의 서명과 검증에 대한 기능을 iOS에 제공합니다. 

## 용어정리
+ DID (탈중앙화 신원증명 : Decentralized Identity)
    + 개인의 데이터를 중앙화된 기관을 거치지 않으면서도 검증이 가능하게 하는 개념.
    + [W3C DID Spec](https://www.w3.org/TR/did-core/)
+ Claim
    + 전체데이터의 각 단위 데이터 입니다.
    + 예를 들어 디지털 신원 정보에서 이름, 생년월일, 성별 등과 각각의 값을 페어로 claim 이라 불림.
    + [W3C VC Claims](https://www.w3.org/TR/vc-data-model/#claims)
    
+ Verifiable Credential
    + 발급자, 유효기한, 검증에 사용되는 발급자의 공개키 등과 claim 의 집합과 서명을 포함하는 검증 가능한 Credential 입니다.
    + 위변조가 불가능하며 예로 휴대폰본인인증, 전자신분증 등 신원인증이 있습니다.
    + 발급자가 사용자의 정보를 인증하여 발급하고 사용자에게 전달됩니다.
    + [W3C VC Credential](https://www.w3.org/TR/vc-data-model/#credentials)
+ Verifiable Presentation
    + 하나 이상의 Verifiable Credential 과 소유자의 공개키와 서명을 포함하는 검증 가능한 Presentation 입니다.
    + 소유자가 발급자에게서 발급 받은 credential 을 검증자에게 제출 시 사용됩니다.
    + [W3C VC Presentation](https://www.w3.org/TR/vc-data-model/#presentations)
        
## DID Workflow

![Workflow](https://github.com/METADIUM/did-sdk-java/blob/master/images/DIDWorkflow.jpg)

1. 발급자(Issuer)와 사용자(Holder)는 Credential, Presentation 을 발급하기 위해 DID 를 미리 생성한다.
    - [DID 생성](#create-did)
2. 사용자는 발급자에게 Credential 발급 요청을 한다. 사용자가 발급하려는 Credential의 소유자라는 임을 확인하기 위해 DID 를 전달합니다.
    - 전달하는 DID에 대한 검증이 필요할 시 Credential 을 포함하지 않는 Presentation 을 전달
    -  [Presentation 발급](#issue-presentation)
3. 발급자는 사용자의 DID 를 확인하고
    - DID 가 presentation 으로 제출이 되면 presentation을 검증한다.
    - [Presentation 검증](#verify-credential-or-presentation)
4. 확인된 claim을 포함하는 Credential을 발급 합니다. 사용자에게 전달된 Credential은 안전한 저장공간에 저장합니다.
    - [Credential 발급](#issue-credential)
5. 사용자 검증자(Verifier)가 요구하는 Credential을 찾아 Presentation을 만들어 제출합니다.
    - [Presentation 발급](#issue-presentation)
6. 검증자는 Presentation 이 사용자가 보낸 것인지 검증하고 요구하는 발급자의 Credential 인지 검증을 합니다.
    - [Credential, Presentation 검증](#verify-credential-or-presentation)
    
[전체 테스트 코드](Example/Tests/Tests.swift)
        
        
## SDK 설치

DID-SDK-Swift is available through [CocoaPods](https://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
source 'https://github.com/CocoaPods/Specs.git'

target 'project' do
    pod 'DID-SDK-Swift'
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'
      config.build_settings["EXCLUDED_ARCHS[sdk=iphonesimulator*]"] = "arm64"
      end
  end
end
```


### Swift Package
The [Swift_Package_Manager](https://github.com/METADIUM/did-sdk-swift.git/ "")

```swift
dependencies: [
    .package(url: "https://github.com/METADIUM/did-sdk-swift.git", .upToNextMajor(from: "1.1.0"))
]
```

### 빌드 (Xcode 27)

web3swift 3.x 는 Xcode 27 SDK 로 빌드되지 않습니다 (`URLResponse` 에 `statusCode` 가 없음. [web3swift#916](https://github.com/web3swift-team/web3swift/issues/916), 수정 PR [#910](https://github.com/web3swift-team/web3swift/pull/910) 은 아직 머지되지 않음). 그래서 이 패키지는 상류 대신 **METADIUM 의 web3swift 포크**(`3.3.2-metadium.1`: 3.3.2 에 #910 의 수정 하나만 더한 것)에 의존합니다. 상류가 수정을 릴리스하면 상류로 되돌립니다. [포크](https://github.com/METADIUM/web3swift)

* **Swift Package Manager:** 별도 설정이 필요 없습니다. 앱이 상류 web3swift 를 **직접** 의존하면 같은 패키지 이름(`web3swift`)이라 SwiftPM 이 의존성을 풀지 못합니다. 그 경우 앱의 의존성도 **같은 포크, 같은 태그**로 바꾸십시오.

  ```swift
  // 앱의 Package.swift (상류 web3swift 대신)
  .package(url: "https://github.com/METADIUM/web3swift.git", exact: "3.3.2-metadium.1")
  ```

* **태그 보호:** 포크의 ruleset 이 `*-metadium.*` 태그의 수정과 삭제를 막고, 생성은 릴리스 팀(`web3swift-release`)만 할 수 있습니다. 릴리스 브랜치 `metadium/release` 는 force push 와 삭제가 막혀 있고 PR 승인이 필요합니다. 조직 관리자는 규칙 자체를 바꿀 수 있으므로 아래 확인 방법도 함께 쓰십시오.
* **태그가 가리키는 코드 확인:** 태그 `3.3.2-metadium.1` 은 커밋 `6a1a8c69566c4496e27b436b33adece760e37d9d` 를 가리킵니다. 받은 코드가 같은지 확인하려면:

  ```bash
  git ls-remote --tags https://github.com/METADIUM/web3swift.git '3.3.2-metadium.1^{}'
  # 6a1a8c69566c4496e27b436b33adece760e37d9d  refs/tags/3.3.2-metadium.1^{}
  ```

  앱은 `Package.resolved` 를 커밋해 두십시오. SwiftPM 은 태그가 다른 커밋으로 바뀌면 이를 감지할 수 있고(fingerprint 검사, `swift package --resolver-fingerprint-checking strict`), 바뀌었다면 받지 말고 알려 주십시오.
* **CocoaPods:** podspec 은 CocoaPods 의 `web3swift` pod 에 의존하므로 이 포크의 영향을 받지 않습니다. 포크에는 podspec 이 없어서 Xcode 27 에서 CocoaPods 로 빌드하는 방법은 확인하지 못했습니다.
* **이 저장소를 직접 빌드·테스트할 때:** 저장소 루트에 CocoaPods 용 `_Pods.xcodeproj` 링크가 있어서 `xcodebuild` 가 패키지 대신 Pods 프로젝트를 고릅니다. 패키지만 담은 깨끗한 복사본에서 빌드하십시오.

```bash
rm -rf /tmp/did-pkg && mkdir /tmp/did-pkg
git archive HEAD Package.swift Sources Tests | tar -x -C /tmp/did-pkg
cd /tmp/did-pkg
xcodebuild test -scheme DID-SDK-Swift \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:did-sdk-swiftTests/ExternalSignerTests
```

기존 `did_sdk_swiftTests` 는 테스트넷 delegator 를 호출하므로 위처럼 `-only-testing` 으로 분리해서 실행하십시오.




## 사용방법
* [네트워크 설정](#setup-network)
* [DID 기능](#did-operation)
    * [DID 생성](#create-did)
    * [DID 삭제](#delete-did)
    * [DID document 확인](#get-did-document)
    * [DID 확인](#check-did)
    * [지갑 저장](#save-wallet)
    * [지갑 불러오기](#load-wallet)
    * [서명](#signing)
* [Verifiable Credential](#verifiable-credential)
    * [Credential 발급](#issue-credential)
    * [Presentation 발급](#issue-presentation)
    * [Credential 또는 Presentation 검정](#verify-credential-or-presentation)
    * [Presentations에서 Credential 목록 확인](#get-verifiable-credentials-from-presentation)
    * [Credential에서 Claim 목록 확인](#get-claims-from-credential)
        

### Setup Network
DID를 생성 및 사용하기 위한 네트워크를 설정합니다. 

Delegator, Node, Resolver 의 end-point 와 did prefix 를 설정을 합니다.

추가로 Metadium mainnet, testnet 을 사용시에는 apiKey 는 Metadium 에서 발급을 받아야 합니다.

```Swift

    //Metadium Mainnet 설정
    let delegator = MetaDelegator(api_key: "")
    
    //Metadium Testnet 설정
    let delegator = MetaDelegator(delegatorUrl: "https://testdelegator.metadium.com", nodeUrl: "https://api.metadium.com/dev", resolverUrl: "https://resolver.metadium.com/1.0/identifiers/", didPrefix: "did:meta:testnet:", api_key: "")
    
    //Custom network 설정, private network일 때 해당 네크워크에 각 end-point를 설정합니다.
    let delegator = MetaDelegator(delegatorUrl: "https://custom.delegator.metadium.com", nodeUrl: "https://custom.api.metadium.com", resolverUrl: "https://custom.resolver.metadium.com/1.0/", didPrefix: "did:meta:custom:") 
```

### DID Operation 

DID 생성/삭제 기능을 설명합니다. 

#### Create DID

Secp256k1 Key pair를 생성하고 해당 키로 DID를 생성합니다. 

```Swift
    let wallet = MetaWallet(delegator: delegator)
    wallet.createDID { receipt, error in
        if error != nil {
            return
        }
        
        if let receipt, receipt.status == .ok {
            let did = wallet.getDid()         // 생성된 DID ex) did:meta:00000000000000000000000000000000000000000000000000000000000432a0 
            let kid = wallet.getKid()         // 생성된 private key의 id ex) did:meta:00000000000000000000000000000000000000000000000000000000000432a0#MetaManagementKey#234f9445cd405a2a454245b94f7bc5e9286912eb
        
            if let key = wallet.getKey() {
                let priateKey = key.privateKey
            }
        }
    }
    
```

#### Delete DID
DID를 삭제합니다.
 
```Swift
    wallet.deleteDID { receipt, error in
        if error != nil {
            return
        }
        
        if let receipt, receipt.status == .ok {
            //Todo...
        }
    }
}
```

#### Get DID Document

```Swift
    let didDocument = try? MetaWallet.getDiDDocument(did: did, resolverUrl: delegator.resolverUrl)
```


#### Check DID

DID가 블록체인에 존재하는지 확인한다.

```Swift
    try? wallet.existDid()
```


#### Save Wallet

```Swift

    let walletJson = wallet.toJson()
    
// wallet json을 SecKey로 암호화하여 Userdefaults 혹은 키체인에 저장한다.
```

### Load Wallet

```Swift
// UserDefaults 혹은 키체인에서 가져온 Wallet json string을 복호화

    let wallet = MetaWallet(delegator: delegator, jsonStr: walletJson)
    
```

### Signing
DID의 키로 서명([Elliptic Curve Digital Signature Algorithm](https://en.wikipedia.org/wiki/Elliptic_Curve_Digital_Signature_Algorithm)을 합니다.
 
```Swift
    let signatureData = wallet.getSignature(data: Data())
    
    let signature = String(data: (signatureData?.signData)!, encoding: .utf8)?.withHexPrefix
    
    let r = signatureData?.r
    let s = signatureData?.s
    let v = signatureData?.v
```

### 외부 키 보관 서비스

개인키를 외부 키 보관 서비스(HSM, KMS, 지갑 서비스)에 두고 SDK 에는 전달하지 않을 수 있습니다. 공개키와 32바이트 다이제스트를 서명해 주는 `MetaKeySigner` 만 구현하면 됩니다.

```swift
struct KeyStoreSigner: MetaKeySigner {
    // 키 보관 서비스가 반환한 공개키. 64바이트(X||Y), 0x04 접두를 포함한 65바이트, 압축 33바이트 또는
    // X.509 SubjectPublicKeyInfo DER (AWS KMS, Google Cloud KMS GetPublicKey) 를 받는다. 곡선 위의 점이어야 한다.
    var publicKey: Data { return keyStore.publicKey(keyId) }

    // 다이제스트를 그대로 서명한다. r||s (64바이트) 또는 r||s||v (65바이트) 를 반환한다.
    // AWS KMS, Google Cloud KMS 가 반환하는 ASN.1 DER 도 그대로 반환하면 된다.
    // v 가 없거나 달라도 SDK 가 공개키로 복원하며, s 가 크면 low-s 로 변환한다.
    // 동기 호출이며 보통 네트워크 호출이므로 메인 스레드가 아닌 백그라운드 큐에서 호출한다.
    func signDigest(_ digest: Data) throws -> Data {
        return try keyStore.sign(keyId, digest)
    }
}

let signer = KeyStoreSigner()

// DID 생성. 공개키 형식이 틀리면 MetaKeySignerError.invalidPublicKey 를 던진다.
let wallet = try MetaWallet(delegator: delegator, signer: signer)
wallet.createDID { receipt, error in     // createDID(signer: signer) { ... } 와 같다
    // receipt.status == .ok
}

// 이미 생성된 DID 의 지갑
let existingWallet = try MetaWallet(delegator: delegator, signer: signer, did: did)

// Credential, Presentation 발급. 외부 서명자를 사용하는 지갑은 자동으로 외부 키로 서명한다.
let vc = try wallet.issueCredential(types: ["StudentCredential"], id: nil, nonce: nil, issuanceDate: nil, expirationDate: nil, ownerDid: holderDid, subjects: claims)

// JWSSigner 를 직접 지정할 수도 있다.
let vp = try wallet.issuePresentation(types: ["TestPresentation"], id: nil, nonce: nil, issuanceDate: nil, expirationDate: nil, vcList: vcList, jwsSigner: ExternalJWSSigner(signer: signer))
```

* 개인키가 없으므로 `toJson()` 은 `nil` 을, `getKey()?.privateKey` 는 `nil` 을 반환합니다. 외부 서명자 모드와 개인키 모드는 함께 쓸 수 없습니다. 외부 서명자를 가진 지갑의 `createDID` 는 로컬 키를 만들지 않고 서명자로 생성하며, 개인키를 가진 지갑에 `createDID(signer:)` 를 호출하면 `MetaWalletError.conflictingKeyMode` 로 끝납니다.
* Delegator 요청은 `\x19Ethereum Signed Message:\n32` 접두를 붙인 해시(personal message)를 서명하며 v 는 27 또는 28 입니다. `MetaKeySigner` 는 SDK 가 계산한 다이제스트를 받습니다.
* VC, VP(ES256K)는 JWS signing input 의 SHA-256 다이제스트를 서명하며 결과는 r||s (64바이트, low-s) 입니다.
* `MetaKeySigner` 는 항상 최종 다이제스트를 받으며 추가 해시 없이 그대로 서명해야 합니다. did-sdk-java 는 이더리움 접두 없이 keccak256 다이제스트를 서명하고 이 SDK 는 접두를 붙인 personal message 해시를 서명하므로, 두 SDK 를 모두 쓰는 키 보관 서비스는 SDK 마다 다른 다이제스트를 받으며 delegator 는 둘 다 허용합니다. 근거는 [go-delegator 소스](https://github.com/METADIUM/go-delegator/blob/64ac5a93485556ed59872e215dc9f2602d35d7eb/metaresolver/util.go#L15-L32)(`METADIUM/go-delegator` 의 `metaresolver/util.go`, `verifySignature` 가 접두 없는 서명과 접두 있는 서명을 모두 시도)이며, 외부 키 보관 서비스와 delegator 를 실제로 연동해 실행해 보지는 않았습니다.
* 서명이 공개키와 맞는지 확인합니다. 키 보관 서비스가 다른 키로 서명하면 검증자 단계가 아니라 서명 시점에 `MetaKeySignerError.signatureMismatch` 로 실패합니다. `jwsSigner` 를 직접 넘긴 경우에도 서명이 지갑의 공개키로 검증되지 않으면 `MetaWalletError.signerMismatch` 를 던지고, DID 가 없으면 `MetaWalletError.noDid` 를 던집니다.
* 서명자가 던진 오류는 삼키지 않고 completion 의 `error` 로 전달됩니다. 모든 종료 경로에서 completion 이 정확히 한 번 호출됩니다. receipt 를 받지 못하면 `MetaWalletError.receiptNotFound` 입니다.
* DID 생성은 두 트랜잭션(create_identity, 공개키 등록)입니다. 두 번째 단계가 실패하면 공개키 없는 identity 가 남으며, `MetaWalletError.partialCreation(did:underlying:)` 로 DID 와 원인을 알려줍니다. 되돌리지 않습니다.
* r, s 가 0 이거나 곡선 위수 이상이면 `MetaKeySignerError.invalidSignature` 입니다.
* 트랜잭션이 revert 되면(receipt 의 status 가 failed) `MetaWalletError.transactionFailed(txId:)` 로 끝납니다. 해당 트랜잭션의 변경은 체인에 반영되지 않았습니다. 이전 버전은 revert 된 receipt 를 오류 없이 그대로 돌려주었습니다. DID 생성의 두 번째 단계(공개키 등록)가 revert 되면 `partialCreation(did:underlying:)` 의 `underlying` 으로 전달됩니다.
* create_identity 트랜잭션은 성공했지만 receipt 에서 `IdentityCreated` 이벤트를 찾지 못하면 `MetaWalletError.eventNotFound` 로 끝납니다. identity 가 체인에 생성되었을 가능성이 크지만 DID 를 알 수 없고, SDK 는 되돌리지 않습니다.
* `existDid(completion:)` 로 지갑의 키로 identity 가 있는지 확인할 수 있지만 한계가 있습니다. 조회에 실패해도 `false` 를 돌려주므로 "없음"과 "조회 실패"를 구분하지 못하고(실패하면 다시 시도하십시오), identity 가 있어도 DID 는 알려 주지 않습니다.

### Verifiable Credential

Verifiable credential, Verifiable presentation 을 발급 및 검증 하는 방법을 설명합니다.


#### Issue Credential

erifiable credential 을 발급한다.  
발급자(issuer)는 DID 가 생성되어 있어야 하며 credential 의 이름(types), 사용자(holder)의 DID, 발급할 내용(claims) 가 필수로 필요하다.

```Swift
    let claims = ["name": "YoungBaeJeon", "birth": "19800101", "id": "800101xxxxxxxx"]
    let vc = try? wallet.issueCredential(types: ["PersonalIdCredential"],                            // types : credential 의 이름. "Credential" 로 끝나야 함.
                                            id: "http://aa.metadium.com/credential/name/343",         // id : credential을 검증할 수 있는 고유 URL 을 입력해야 하며 필수는 아님.
                                            nonce: nil,                                               
                                            issuanceDate: issuanceDate,                               // issuance date
                                            expirationDate: expirationDate,                           // expiration date
                                            ownerDid: "did:meta:0000000...00002f4c",                  // ownerDid (holder의 did)
                                            subjects: claims)!                                        // claims
                                                   
   let personalIdVC = try? vc!.serialize()
```

위와 같이 credential 을 발급 받은 경우 검증자에게는 해당 credential을 그대로 넘겨야 하기 때문에 특정 claim 만 선택해서 보내거나 불필요한 claim을 감춰서 보낼 수는 없다.

특정 claim 만 선택해서 보내기 위해서는 아래와 같이 검증자가 claim 별로 credential 을 선택적으로 제출받을 수 있도록 claim 단위별로 credential 을 나누어서 발급자가 발급해야 한다.


```Swift
    let vc = try? wallet.issueCredential(types: ["PersonalIdCredential", "NameCredential"],      // 표현할 credential 의 이름을 나열. PersonalIdCredential의 NameCredential
                                            id: "http://aa.metadium.com/credential/name/343",         
                                            nonce: nil,                                            
                                            issuanceDate: issuanceDate,                               
                                            expirationDate: expirationDate,                           
                                            ownerDid: "did:meta:0000000...00002f4c",                 
                                            subjects: ["name": "YoungBaeJeon"])!                  // name
                                            
    let nameVC = try? vc!.serialize()
    
    let vc = try? wallet.issueCredential(types: ["PersonalIdCredential", "BirthCredential"],     // 표현할 credential 의 이름을 나열. PersonalIdCredential의 BirthCredential
                                        id: "http://aa.metadium.com/credential/name/343",         
                                        nonce: nil,                                            
                                        issuanceDate: issuanceDate,                               
                                        expirationDate: expirationDate,                           
                                        ownerDid: "did:meta:0000000...00002f4c",                 
                                        subjects: ["birth": "19800101"])!                         // birth
                                        
    let birthVC = try? vc!.serialize()
    
    let vc = try? wallet.issueCredential(types: ["PersonalIdCredential", "IdCredential"],        // 표현할 credential 의 이름을 나열. PersonalIdCredential의 IdCredential
                                    id: "http://aa.metadium.com/credential/name/343",         
                                    nonce: nil,                                            
                                    issuanceDate: issuanceDate,                               
                                    expirationDate: expirationDate,                           
                                    ownerDid: "did:meta:0000000...00002f4c",                 
                                    subjects: ["id": "800101xxxxxxxx"])!                          // id
                                        
    let birthVC = try? vc!.serialize()
```


#### Issue presentation

전달해야 하는 credential 의 목록을 포함하여 presentation 을 발급한다.
검증자는 전달해야 하는 credential의 types 를 소유자에게 알려줘야 하며 소유자는 해당하는 Credential 을 presentation으로 전달해야 하며
발급된 presentation 은 검증자에게 전달하여 검증을 받는다.

검증자가 2개의 credential 을 요청하고 소유자가 presentation을 발급하여 전달하는 예제 (주민등록증, 운전면허증 요구)

```Swift
    //검증자 요청 예제 : {"types":["TestPresentation"], "vc":[["PersonalIdCredential", "NameCredential"], ["PersonalIdCredential", "IdCredential"]]}
    let holderAllVc = [] // 소유자의 전체 credential 목록
    
    let vp = try? wallet.issuePresentation(types: ["TestPresentation"],
                                       id: "http://aa.metadium.com/credential/name/343",
                                       nonce: nil,
                                       issuanceDate: issuanceDate,
                                       expirationDate: expirationDate,
                                       vcList: foundVcList)
        
    let serializedVP = try? vp!.serialize()
```

소유자 credential 목록에서 검증자가 요구하는 credential 찾는 예제

```Swift
    func findVC(holderVcList: [String], typesOfRequiresVcs: [[String]]) {
        
        var ret: [String] = []
        
        for serializedVc in holderVcList {
            
            let credential = try! VerifiableCredential.init(jws: JWSObject.init(string: serializedVc))
            
            for types in typesOfRequiresVcs {
                
                if credential.getTypes()!.contains(array: types) {
                    ret.append(serializedVc)
                }
            }
        }
    }
```

```Swift
extension Array where Element: Equatable {
    func contains(array: [Element]) -> Bool {
        for item in array {
            if !self.contains(item) { return false }
        }
        return true
    }
}
```


#### Verify Credential or Presentation

네트워크가 메인넷이 안닌 경우 검증 전에 resolver URL 이 설정되어 있어야 정상적이 검증이 가능하다. [Setup Network 참조](#setup-network)  

전달받은 credential 또는 presentation 을 검증을 한다.

```Swift
    let jws = try? JWSObject.init(string: serializedVC)
    let jwt = try? JWT.init(jsonData: jws!.payload)

    let expireDate = jwt!.expirationTime


    do {
        let verified = try! MetaWallet.verify(jwt: JWSObject(string: vpForIssueCredential!!), resolverUrl: delegator.resolverUrl)
        
        if !verified {
            //검증실패
            XCTAssert(false, "vpForIssueCredential 검증 실패")
        }
        
    } catch verifyError.noneDidDocument {
        //todo
    } catch verifyError.nonePublicKey {
        //todo
    }
    
    if (expireDate != nil && expireDate! < Date()) {
        // 유효기간 초과
    }
```        


#### Get Verifiable credentials from presentation

presentation 에 나열되어 있는 credential 내역을 확인한다.

```Swift

    let vpObj = try? VerifiablePresentation.init(jws: JWSObject.init(string: serializedVp))
    let holDerDid = vpObj.holder                    //Presentation 제출
    let vpId = vpObj.id                             //Presentation ID
    
    for serializedVc in vpObj.verifiableCredentials() {
        
    }
```

#### Get claims from credential

credential 에 나열되어 있는 claim 의 내역을 확인한다.

```Swift

    let credential = try? VerifiableCredential(jws: JWSObject.init(string: "serializedVc"))
    
    if let subjects = credential.credentialSubject as? [String : Any] {
                    
        for (key, value) in subjects {
            let claimName = key
            let claimValue = value
                        
            print("\(claimName) = \(claimValue)")
        }
    }
    
```


## Example

To run the example project, clone the repo, and run `pod install` from the Example directory first.

## Requirements



## Author

jinsik, jshan@coinplug.com

## License

DID-SDK-Swift is available under the MIT license. See the LICENSE file for more info.
