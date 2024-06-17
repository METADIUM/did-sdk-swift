//
//  JOSEHeader.swift
//  JWTS
//
//  Created by 전영배 on 12/08/2019.
//  Copyright © 2019 전영배. All rights reserved.
//

import Foundation


/// JOSE header error
///
/// - RequiredParameterMissing: not exists alg in JWS
/// - InvalidJSON: cause convert from Data or String to Json
enum JOSEHeaderError: Error {
    case RequiredParameterMissing(parameter: String)
    case InvalidJSON
}


/// JOSE header
///
public class JOSEHeader {
    
    /// header parameter
    public var parameters: [String: Any]
    
    
    /// init
    public init() {
        self.parameters = [String: Any]()
    }
    
    
    /// init from Dictionary
    ///
    /// - Parameter parameters: header parameter
    /// - Throws: JOSEHeaderError.InvalidJSON
    public init(parameters: [String: Any]) throws {
        guard JSONSerialization.isValidJSONObject(parameters) else {
            throw JOSEHeaderError.InvalidJSON
        }
        self.parameters = parameters
    }
    
    
    /// init json Data
    ///
    /// - Parameter headerData: json data
    /// - Throws: JOSEHeaderError.InvalidJSON
    public init(headerData: Data) throws {
        do {
            self.parameters = try JSONSerialization.jsonObject(with: headerData, options: []) as! [String: Any]
        }
        catch {
            throw JOSEHeaderError.InvalidJSON
        }
    }

    
    /// JWK set URL
    public var jku: URL? {
        set {
            parameters["jku"] = newValue?.absoluteString
        }
        get {
            guard let parameter = parameters["jku"] as? String else {
                return nil
            }
            return URL(string: parameter)
        }
    }
    
    /// The JSON Web key corresponding to the key used to digitally sign the JWS.
    public var jwk: String? {
        set {
            parameters["jwk"] = newValue
        }
        get {
            return parameters["jwk"] as? String
        }
    }
    
    /// The Key ID indicates the key which was used to secure the JWS.
    public var kid: String? {
        set {
            parameters["kid"] = newValue
        }
        get {
            return parameters["kid"] as? String
        }
    }
    
    /// The X.509 URL that referes to a resource for the X.509 public key certificate
    /// or certificate chain corresponding to the key used to sign the JWS.
    public var x5u: URL? {
        set {
            parameters["x5u"] = newValue?.absoluteString
        }
        get {
            guard let parameter = parameters["x5u"] as? String else {
                return nil
            }
            return URL(string: parameter)
        }
    }
    
    /// The X.509 certificate chain contains the X.509 public key certificate or
    /// certificate chain corresponding to the key used to sign the JWS.
    public var x5c: [String]? {
        set {
            parameters["x5c"] = newValue
        }
        get {
            return parameters["x5c"] as? [String]
        }
    }
    
    /// The X.509 certificate SHA-1 thumbprint of the DER encoding of the X.509 certificate
    /// corresponding to the key used to sign the JWS.
    public var x5t: String? {
        set {
            parameters["x5t"] = newValue
        }
        get {
            return parameters["x5t"] as? String
        }
    }
    
    /// The X.509 certificate SHA-256 thumbprint of the DER encoding of the X.509 certificate
    /// corresponding to the key used to sign the JWS.
    public var x5tS256: String? {
        set {
            parameters["x5tS256"] = newValue
        }
        get {
            return parameters["x5tS256"] as? String
        }
    }
    
    /// The type to declare the media type of the JWS object.
    public var typ: String? {
        set {
            parameters["typ"] = newValue
        }
        get {
            return parameters["typ"] as? String
        }
    }
    
    /// The content type to declare the media type of the secured content (payload).
    public var cty: String? {
        set {
            parameters["cty"] = newValue
        }
        get {
            return parameters["cty"] as? String
        }
    }
    
    /// The critical header parameter indicates the header parameter extensions.
    public var crit: [String]? {
        set {
            parameters["crit"] = newValue
        }
        get {
            return parameters["crit"] as? [String]
        }
    }
    
    
    /// header to base64 string
    ///
    /// - Returns: base64 encoded string
    public func base64() -> String? {
        guard let data = data() else {
            return nil
        }
        
        return data.base64UrlEncoding()
    }
    
    
    /// header to data
    ///
    /// - Returns: json data
    public func data() -> Data? {
        do {
            return try JSONSerialization.data(withJSONObject: parameters, options: [.sortedKeys])
        } catch {
        }
        return nil
    }
}
