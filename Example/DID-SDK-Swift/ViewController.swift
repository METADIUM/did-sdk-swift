//
//  ViewController.swift
//  DID-SDK-Swift
//
//  Created by jinsik on 03/18/2022.
//  Copyright (c) 2022 jinsik. All rights reserved.
//

import UIKit
import DID_SDK_Swift

class ViewController: UIViewController {
    
    @IBOutlet weak var didLabel: UILabel!
    @IBOutlet weak var privateKeyLabel: UILabel!
    @IBOutlet weak var vcLabel: UILabel!
    @IBOutlet weak var activityView: UIActivityIndicatorView!
    @IBOutlet weak var deleteButton: UIButton!
    
    var wallet: MetaWallet!
    
    var issuerWalletJson: String = ""
    var userWalletJson: String = ""
    var vcString: String = ""
    
    
    /*
     //메인넷
    let delegator = MetaDelegator.init()
     */
    
    let delegator = MetaDelegator(delegatorUrl: "https://testdelegator.metadium.com",
                                  nodeUrl: "https://api.metadium.com/dev",
                                  resolverUrl: "https://testnetresolver.metadium.com/1.0/identifiers/",
                                  didPrefix: "did:meta:testnet:",
                                  api_key: "")
    
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        self.activityView.isHidden = true
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    
    //issuer, user의 DID 발급
    @IBAction func createDidAction() {
        self.createKey()
    }
    
    
    //user의 DID 삭제
    @IBAction func deleteDidAction() {
        if self.userWalletJson.isEmpty {
            return
        }
        
        let userWallet = MetaWallet(delegator: self.delegator, jsonStr: self.userWalletJson)
        
        userWallet.deleteDID {
            DispatchQueue.main.async {
                self.didLabel.text = ""
                self.privateKeyLabel.text = ""
                self.userWalletJson = ""
            }
        }
    }
    
    
    func createKey() {
        //메인넷 설정
        /*
        let delegator = MetaDelegator.init()
         */
        
        //테스트넷 설정
        
        var issuer: MetaWallet!
        var user: MetaWallet!
        
        
        DispatchQueue.main.async {
            self.activityView.isHidden = false
            self.activityView.startAnimating()
        }
        
        // 1. 사용자 DID 생성
        user = MetaWallet(delegator: self.delegator)
        user.createDID {
            
            self.userWalletJson = user.toJson() ?? ""
            
            DispatchQueue.main.async {
                if let key = user.getKey() {
                    self.didLabel.text = user.getDid()
                    self.privateKeyLabel.text = key.privateKey
                }
            }
            
            //2. 발급자 DID 생성
            issuer = MetaWallet(delegator: self.delegator)
            issuer.createDID {
                
                self.issuerWalletJson = issuer.toJson() ?? ""
                
                DispatchQueue.main.async {
                    self.activityView.stopAnimating()
                    self.activityView.isHidden = true
                }
            }
        }
    }
    
    
    
    @IBAction func verifyButtonAction() {
        if self.userWalletJson.isEmpty || self.issuerWalletJson.isEmpty {
            return
        }
        
        let issuerWallet = MetaWallet(delegator: self.delegator, jsonStr: self.issuerWalletJson)
        let userWallet = MetaWallet(delegator: self.delegator, jsonStr: self.userWalletJson)
        
        self.verify(issuer: issuerWallet, user: userWallet, resolverUrl: delegator.resolverUrl)
    }
    
    

    func verify(issuer: MetaWallet, user: MetaWallet, resolverUrl: String) {
        
        //사용자의 DID
        let holderDid = user.getDid()
        
        //사용자가 안전한 공간에 credential 저장
        let claims = ["name" : "YoungBaeJeon", "birth" : "19800101", "id" : "800101xxxxxxxx"]
        
        let personalIdVC = try! issuer.issueCredential(types: ["PersonalIdCredential"],
                                                        id: "http://aa.metadium.com/credential/name/343",
                                                        nonce: nil,
                                                        issuanceDate: Date(),
                                                        expirationDate: Date.init(timeIntervalSinceNow: 60 * 60),
                                                        ownerDid: holderDid,
                                                             subjects: claims)?.serialize()
        
        //발급자가 사용자에게 personalIdVC 전달
        let userVcList: [String] = [personalIdVC!]
        
        // 사용자가 발급자에게 presentation 제출
        // 검증자 요구하는 정보. presentation name, types
        
        let requirePresentationName = "TestPresentation"
        let requireCredentialType = ["PersonalIdCredential"]
        
        //presentation 발급
        
        let foundVcList = self.findVC(holderVcList: userVcList, typesOfRequiresVcs: [requireCredentialType])
        
        let vpForVerify = try? user.issuePresentation(types: [requirePresentationName], id: nil, nonce: nil, issuanceDate: Date(), expirationDate: Date.init(timeIntervalSinceNow: 60 * 60), vcList: foundVcList)?.serialize()
        
        
        //사용자가 검증자에게 vpForVerify 제출
        
        // 6. 검증자가 presentation 검증
        
        let vpJwt = try? JWSObject(string: vpForVerify!!)
        let isVerify = try! MetaWallet.verify(jwt: vpJwt!, resolverUrl: resolverUrl)
        
        let jwt = try? JWT.init(jsonData: vpJwt!.payload)
        
        if !isVerify {
            
        }
        else if jwt?.expirationTime != nil && (jwt?.expirationTime)! < Date() {
            
        }
        
        let vpObj = try! VerifiablePresentation(jws: vpJwt!)
        let presentorDid = vpObj.holder
        
        
        //Credential 목록 확인 및 검증
        for vc in vpObj.verifiableCredentials()! {
            
            if vc is String {
                let signedVc = try! JWSObject(string: vc as! String)
                
                let vcPayload = try! JWT.init(jsonData: signedVc.payload)
                
                if !(try! MetaWallet.verify(jwt: signedVc, resolverUrl: resolverUrl)) {
                    
                }
                else if vcPayload.expirationTime != nil && vcPayload.expirationTime! < Date() {
                    
                }
                
                //credential 소유자 확인
                if vcPayload.subject != user.getDid() || presentorDid != user.getDid() {
                    
                }
                
                //요구하는 발급자가 발급한 credential 인지 확인
                let credential = try! VerifiableCredential(jws: signedVc)
                
                if credential.issuer != issuer.getDid() {
                    
                }
                
                //claim 정보 확인
                if let subjects = credential.credentialSubject as? [String : Any] {
                    
                    for (key, value) in subjects {
                        let claimName = key
                        let claimValue = value
                        
                        print("\(claimName) = \(claimValue)")
                        
                        self.vcString.append("\(claimName) = \(claimValue)" + "\n")
                    }
                    
                    self.vcLabel.text = self.vcString
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

