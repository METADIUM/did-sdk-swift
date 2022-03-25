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

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    
    @IBAction func createDidAction() {
        
        let delegator = MetaDelegator(delegatorUrl: "https://testdelegator.metadium.com",
                                      nodeUrl: "https://api.metadium.com/dev",
                                      resolverUrl: "https://testnetresolver.metadium.com/1.0/identifiers/",
                                      didPrefix: "did:meta:testnet:",
                                      api_key: "")
        
        let wallet = MetaWallet(delegator: delegator)
        wallet.createDID()
        
        
        DispatchQueue.main.async {
            let key = wallet.getKey()
            
            print("did: \(wallet.getDid())")
            print("privateKey:\(key?.privateKey)")
            
            self.didLabel.text = wallet.getDid()
            self.privateKeyLabel.text = key?.privateKey
        }
        
        let did = wallet.getDid()
        let didDocument = try? MetaWallet.getDiDDocument(did: did, resolverUrl: delegator.resolverUrl)
        
        
        //load wallet
        let wallet1 = MetaWallet(delegator: delegator, jsonStr: wallet.toJson())
        print(wallet1.getDid())
    }
    
    
    @IBAction func deleteDidAction() {
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

