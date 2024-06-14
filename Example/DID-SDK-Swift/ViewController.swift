//
//  ViewController.swift
//  DID-SDK-Swift
//
//  Created by jinsik on 03/18/2022.
//  Copyright (c) 2022 jinsik. All rights reserved.
//

import UIKit
import DID_SDK_Swift
import VerifiableSwift
import JWTsSwift

class ViewController: UIViewController {
    
    @IBOutlet weak var didLabel: UILabel!
    @IBOutlet weak var privateKeyLabel: UILabel!

    
    var wallet: MetaWallet!
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    


    @IBAction func createDidAction() {
        
        //테스트넷
        let delegator = MetaDelegator(delegatorUrl: "https://testdelegator.metadium.com",
                                      nodeUrl: "https://api.metadium.com/dev",
                                      resolverUrl: "https://testnetresolver.metadium.com/1.0/identifiers/",
                                      didPrefix: "did:meta:testnet:",
                                      api_key: "")
        
        
        /*
        //메인넷
        let delegator = MetaDelegator(delegatorUrl: "https://delegator.metadium.com",
                                      nodeUrl: "https://api.metadium.com/prod",
                                      resolverUrl: "https://resolver.metadium.com/1.0/identifiers/",
                                      didPrefix: "did:meta:",
                                      api_key: "")
         */
        
        self.wallet = MetaWallet(delegator: delegator)
        self.wallet.createDID {
            DispatchQueue.main.asyncAfter(deadline: .now()) {
                guard let key = self.wallet.getKey() else {
                    return
                }
                
                print("privateKey:\(key.privateKey ?? "")")
                print("did: \(self.wallet.getDid())")
                
                self.didLabel.text = self.wallet.getDid()
                self.privateKeyLabel.text = key.privateKey
                
                let did = self.wallet.getDid()
                if let didDocument = try? MetaWallet.getDiDDocument(did: did, resolverUrl: delegator.resolverUrl) {
                    
                }
                
                //load wallet
                let wallet1 = MetaWallet(delegator: delegator, jsonStr: self.wallet.toJson()!)
                print(wallet1.getDid())
            }
        }
    }
    
    
    @IBAction func deleteDidAction() {
        
        self.wallet.deleteDID { successed in
            if successed {
                DispatchQueue.main.async {
                    self.didLabel.text = ""
                    self.privateKeyLabel.text = ""
                }
            }
        }
        /*
        let delegator = MetaDelegator(delegatorUrl: "https://testdelegator.metadium.com",
                                      nodeUrl: "https://api.metadium.com/dev",
                                      resolverUrl: "https://testnetresolver.metadium.com/1.0/identifiers/",
                                      didPrefix: "did:meta:testnet:",
                                      api_key: "")
        
        
        //UserDefaults 혹은 키체인에서 가져온 wallet json을 복호화
        let walletJson = ""
        let wallet = MetaWallet(delegator: delegator, jsonStr: walletJson)
        wallet.deleteDID()
         */
    }
    
    
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
}

extension Array where Element: Equatable {
    func contains(array: [Element]) -> Bool {
        for item in array {
            if !self.contains(item) { return false }
        }
        return true
    }
}

