//
//  MetadiumKey.swift
//  KeepinCRUD
//
//  Created by hanjinsik on 2020/12/04.
//

import UIKit

public class MetadiumKey: NSObject {
    public var publicKey: String?
    public var privateKey: String?
    public var address: String?
}


public class SignatureData: NSObject {
    
    public var signData: Data!
    public var r: String!
    public var s: String!
    public var v: String!
    
    
    init(signData: Data, r: String, s: String, v: String) {
        self.signData = signData
        self.r = r
        self.s = s
        self.v = v
    }
}
