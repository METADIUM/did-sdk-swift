//
//  Data+Padding.swift
//  JWS
//
//  Created by 전영배 on 16/08/2019.
//  Copyright © 2019 전영배. All rights reserved.
//

import Foundation


// MARK: - Base64URL extension
extension Data {
    
    /// init with base64url encoded string
    ///
    /// - Parameter base64UrlEncoded: base64 url encoded
    public init?(base64UrlEncoded: String) {
        let reminder = base64UrlEncoded.count % 4
        var paddingBase64: String
        if (reminder > 0) {
            paddingBase64 = base64UrlEncoded.padding(
                toLength:base64UrlEncoded.count+4-reminder,
                withPad: "=",
                startingAt: 0)
        }
        else {
            paddingBase64 = base64UrlEncoded
        }
        
        paddingBase64 = paddingBase64.replacingOccurrences(of: "-", with: "+")
        paddingBase64 = paddingBase64.replacingOccurrences(of: "_", with: "/")
        
        self.init(base64Encoded: paddingBase64)
    }
    
    
    /// to base64url encoding
    ///
    /// - Returns: base64url encoded
    public func base64UrlEncoding() -> String {
        return self.base64EncodedString().replacingOccurrences(of: "=", with: "").replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_")
    }
}
