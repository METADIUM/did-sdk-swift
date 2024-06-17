//
//  JWSVerifier.swift
//  JWTS
//
//  Created by 전영배 on 12/08/2019.
//  Copyright © 2019 전영배. All rights reserved.
//

import Foundation


/// JWS verifier
public protocol JWSVerifier {
    func verify(header: JWSHeader, signedContent: Data, signature: Data) throws -> Bool
}
