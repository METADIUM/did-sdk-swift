//
//  JWTObject.swift
//  JWS
//
//  Created by 전영배 on 16/08/2019.
//  Copyright © 2019 전영배. All rights reserved.
//

import Foundation


/// JWT
public class JWT {
    
    /// claims of JWT
    public var claims: [String: Any]
    
    
    /// init with cliams dictionary
    ///
    /// - Parameter claims: dictionary claims
    public init(claims: [String: Any]) {
        self.claims = claims;
    }
    
    
    /// init
    public convenience init() {
        self.init(claims: [String: Any]())
    }
    
    

    /// init with base64 encoded json string
    ///
    /// - Parameter base64EncodedJson: base64 encoded json string
    /// - Throws: fail serializing json
    public convenience init(base64EncodedJson: String) throws {
        let data = Data.init(base64UrlEncoded: base64EncodedJson)
        let claims = try JSONSerialization.jsonObject(with: data!, options: []) as! [String: Any]
        self.init(claims: claims)
    }
    
    
    /// init with json string
    ///
    /// - Parameter jsonString: json string
    /// - Throws: fail serializing json
    public convenience init(jsonString: String) throws {
        let claims = try JSONSerialization.jsonObject(with: jsonString.data(using: .utf8)!, options: []) as! [String: Any]
        self.init(claims: claims)
    }
    
    
    /// init with json data
    ///
    /// - Parameter jsonData: json data
    /// - Throws: fail serializing json
    public convenience init(jsonData: Data) throws {
        let claims = try JSONSerialization.jsonObject(with: jsonData, options: []) as! [String: Any]
        self.init(claims: claims)
    }
    
    
    /// issuer (iss)
    public var issuer: URL? {
        set {
            claims["iss"] = newValue?.absoluteString
        }
        get {
            guard let parameter = claims["iss"] as? String else {
                return nil
            }
            return URL(string: parameter)
        }
    }
    
    
    /// subject (sub)
    public var subject: String? {
        set {
            claims["sub"] = newValue
        }
        get {
            return claims["sub"] as? String
        }
    }
    
    
    /// audience (aud)
    public var audience: [String]? {
        set {
            claims["aud"] = newValue
        }
        get {
            return claims["aud"] as? [String]
        }
    }
    
    
    /// expire time (exp)
    public var expirationTime: Date? {
        set {
            if newValue != nil {
                claims["exp"] = UInt64(newValue!.timeIntervalSince1970)
            }
        }
        get {
            guard let exp: UInt64 = claims["exp"] as? UInt64 else {
                return nil
            }
            return Date.init(timeIntervalSince1970: Double(exp))
        }
    }
    
    /// Not before time (nbf)
    public var notBeforeTime: Date? {
        set {
            if newValue != nil {
                claims["nbf"] = UInt64(newValue!.timeIntervalSince1970)
            }
        }
        get {
            guard let nbf: UInt64 = claims["nbf"] as? UInt64 else {
                return nil
            }
            return Date.init(timeIntervalSince1970: Double(nbf))
        }
    }
    
    
    /// issued time (iat)
    public var issuedAt: Date? {
        set {
            if newValue != nil {
                claims["iat"] = UInt64(newValue!.timeIntervalSince1970)
            }
        }
        get {
            guard let iat: UInt64 = claims["iat"] as? UInt64 else {
                return nil
            }
            return Date.init(timeIntervalSince1970: Double(iat))
        }
    }
    
    
    /// JWT ID (jti)
    public var jwtID: String? {
        set {
            claims["jti"] = newValue
        }
        get {
            return claims["jti"] as? String
        }
    }
    

    /// set single audience (aud)
    ///
    /// - Parameter audience: audience
    public func setAudience(audience: String) {
        self.audience = [audience]
    }
    
    
    /// to base64 encoded string
    ///
    /// - Returns: base64 encoded string
    /// - Throws: fail serializing json
    public func base64() throws -> String {
        return try data().base64UrlEncoding()
    }
    
    
    /// to data
    ///
    /// - Returns: data
    /// - Throws: fail serializing json
    public func data() throws -> Data {
        return try JSONSerialization.data(withJSONObject: claims, options: [])
    }
}
