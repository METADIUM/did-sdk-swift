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
source 'https://github.com/METADIUM/Web3Swift-iOS'

target 'project' do
    pod 'DID-SDK-Swift', :git => 'https://github.com/METADIUM/did-sdk-swift.git'
end
```


## 사용방법
* [네트워크 설정](#setup-network)
* DID 기능(#did-operation)
    * [DID 생성](#create-did)
    * [DID 삭제](#delete-did)
    * [DID document 확인](#get-did-document)
    * [DID 확인](#check-did)
    * [지갑 저장](#save-wallet)
    * [지갑 불러오기](#load-wallet)
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
    wallet.createDID()
    let did = wallet.getDid()                       // 생성된 DID ex) did:meta:00000000000000000000000000000000000000000000000000000000000432a0 
    let kid = wallet.getKid()                       // 생성된 private key의 id ex) did:meta:00000000000000000000000000000000000000000000000000000000000432a0#MetaManagementKey#234f9445cd405a2a454245b94f7bc5e9286912eb
    
    let key = wallet.getKey()
    let priateKey = key?.privateKey                
    
```

#### Delete DID
DID를 삭제합니다.
 
```Swift
    wallet.deleteDID()
```

#### Get DID Document

```Swift
    let didDocument = try? MetaWallet.getDiDDocument(resolverUrl: delegator.resolverUrl)
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

    let isVerify = try! MetaWallet.verify(jwt: jws!, resolverUrl: delegator.resolverUrl)

    if isVerify == false {
        //검증실패
    }
    else if (expireDate != nil && expireDate! > Date()) {
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
