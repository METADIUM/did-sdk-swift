//
//  JWSHeader.swift
//  JWTS
//
//  Created by 전영배 on 12/08/2019.
//  Copyright © 2019 전영배. All rights reserved.
//

import Foundation


/// JWS header
public class JWSHeader : JOSEHeader {
    
    /// init with header dictionary
    ///
    /// - Parameter parameters: parameter of header
    /// - Throws:
    ///     JOSEHeaderError.RequiredParameterMissing - Require "alg"
    ///     JOSEHeaderError.InvalidJSON
    
    public override init(parameters: [String : Any]) throws {
        try super.init(parameters: parameters);
        
        guard parameters["alg"] is String else {
            throw JOSEHeaderError.RequiredParameterMissing(parameter: "alg")
        }
    }
    
    
    /// init with json data
    ///
    /// - Parameter headerData: json data
    /// - Throws: JOSEHeaderError.InvalidJSON
    public override init(headerData: Data) throws {
        try super.init(headerData: headerData)
    }
    
    
    /// init with signature algorithm
    ///
    /// - Parameter algorithm: signature algorithm. ex) SignatureAlgorithm.ES256K
    public convenience init(algorithm: SignatureAlgorithm) {
        let parameters = ["alg": algorithm.rawValue]
        
        try! self.init(parameters: parameters)
    }
    
    
    /// alogrithm (alg)
    public var alg: String {
        set {
            parameters["alg"] = newValue
        }
        get {
            return parameters["alg"] as! String
        }
    }
}
