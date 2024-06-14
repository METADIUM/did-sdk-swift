//
//  JWS.swift
//  JWS
//
//  Created by 전영배 on 13/08/2019.
//  Copyright © 2019 전영배. All rights reserved.
//

import Foundation


/// JWS Error
///
/// - SerializedComponentError: Not three component. header, payload, signature
/// - InvaildPayload: not base64 payload
/// - InvaildSignature: not base64 signature
enum JWSError: Error {
    case SerializedComponentError
    case InvaildPayload
    case InvaildSignature
}

/// JWS
public class JWSObject : JOSEObject {
    
    /// header
    public var header: JWSHeader
    
    /// payload
    public var payload: Data
    
    /// signature
    public var signature: Data?
    
    /// input data to signing. base64(header).base64(payload)
    public var signingInput : Data
    
    
    /// init with header, payload
    ///
    /// - Parameters:
    ///   - header: JWS header
    ///   - payload: payload
    public init(header: JWSHeader, payload:Data) {
        self.header = header;
        self.payload = payload;
        self.signature = nil;
        self.signingInput = JWSObject.composeSigningInput(header: header, payload: payload)
    }
    
    
    /// init with serialized jws string. base64(header).base64(payload).base64(signature)
    ///
    /// - Parameter string: serialized JWS
    /// - Throws:
    ///     SerializedComponentError
    ///     InvalidJSON
    ///     InvaildPayload
    ///     InvaildSignature
    public init(string: String) throws {
        let parts = string.components(separatedBy: ".")
        if parts.count != 3 {
            throw JWSError.SerializedComponentError
        }
        
        guard let headerData = Data.init(base64UrlEncoded: parts[0]) else {
            throw JOSEHeaderError.InvalidJSON
        }
        self.header = try JWSHeader.init(headerData: headerData)
        guard let payload = Data.init(base64UrlEncoded: parts[1]) else {
            throw JWSError.InvaildPayload
        }
        self.payload = payload
        guard let signature = Data.init(base64UrlEncoded: parts[2]) else {
            throw JWSError.InvaildSignature
        }
        self.signature = signature
        self.signingInput = (parts[0]+"."+parts[1]).data(using: .utf8)!
    }
    
    
    /// JWS serializing
    ///
    /// - Returns: base64(header).base64(payload).base64(signature)
    /// - Throws: NotSignedYet, InvalidJSON
    public func serialize() throws -> String {
        return try serialize(detachedPayload: false)
    }
    
    
    /// JWS serializing
    ///
    /// - Parameter detachedPayload: whether detach payload
    /// - Returns: detachedPayload is false, base64(header)..base64(signature). true, base64(header).base64(payload).base64(signature)
    /// - Throws: NotSignedYet, InvalidJSON
    public func serialize(detachedPayload: Bool) throws -> String {
        guard signature != nil else {
            throw JOSEObjectError.NotSignedYet
        }
        guard let signatureBase64 = signature?.base64UrlEncoding() else {
            throw JOSEObjectError.NotSignedYet
        }
        guard let headerBase64 = header.base64() else {
            throw JOSEHeaderError.InvalidJSON
        }
        
        if detachedPayload {
            return headerBase64+".."+signatureBase64
        }
        return headerBase64+"."+payload.base64UrlEncoding()+"."+signatureBase64
    }
    
    
    /// Sign JWS
    ///
    /// - Parameter signer: to sign
    /// - Throws: notSupportedAlgorithm, signError
    public func sign(signer: JWSSigner) throws {
        self.signature = try signer.sign(header: header, signingInput: signingInput)
    }
    
    
    /// Verify JWS
    ///
    /// - Parameter verifier: to verify
    /// - Returns: if verified, return true.
    /// - Throws: InvaildSignature, notSupportedAlgorithm
    public func verify(verifier: JWSVerifier) throws -> Bool {
        guard self.signature != nil else {
            throw JWSError.InvaildSignature
        }
        return try verifier.verify(header: header, signedContent: signingInput, signature: signature!)
    }
    
    
    private static func composeSigningInput(header:JWSHeader, payload:Data) -> Data {
        let s = header.base64()!+"."+payload.base64UrlEncoding()
        return s.data(using: .utf8)!
    }
}
