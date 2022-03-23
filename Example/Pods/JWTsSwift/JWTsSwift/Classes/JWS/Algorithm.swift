//
//  Algorithm.swift
//  JWTS
//
//  Created by 전영배 on 12/08/2019.
//  Copyright © 2019 전영배. All rights reserved.
//

import Foundation


/// Signature algorim. Current exists only ES256K
///
/// - ES256K: SHA256WithECDSA with secp256k1 curve
public enum SignatureAlgorithm: String {
    case ES256K
}
