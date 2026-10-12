//
//  MetaKeySigner.swift
//
//  외부 키 보관 서비스(HSM, KMS, 지갑 서비스)에 개인키가 있는 경우 사용하는 서명자.
//

import Foundation
import Web3Core
import BigInt

/// 외부 키 보관 서비스를 호출하는 서명자.
/// 개인키는 SDK 로 전달되지 않으며 SDK 는 공개키와 32바이트 다이제스트에 대한 서명만 필요로 한다.
public protocol MetaKeySigner {

    /// secp256k1 공개키. 비압축 형식. 64바이트(X||Y) 또는 0x04 접두를 포함한 65바이트.
    var publicKey: Data { get }

    /// 다이제스트에 추가 해시 없이 그대로 서명한다.
    /// - Parameter digest: 32바이트 다이제스트
    /// - Returns: r||s (64바이트) 또는 r||s||v (65바이트). v 는 선택이며 없거나 값이 달라도 SDK 가 공개키로 복원한다.
    func signDigest(_ digest: Data) throws -> Data
}

public enum MetaKeySignerError: Error {
    case invalidPublicKey
    case invalidSignature
    case signatureMismatch
}

enum ExternalSignatureUtils {

    /// secp256k1 curve order
    static let curveOrder = BigUInt("FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141", radix: 16)!

    /// 0x04 접두를 제거한 64바이트 공개키
    static func rawPublicKey(_ publicKey: Data) throws -> Data {
        if publicKey.count == 64 {
            return publicKey
        }

        if publicKey.count == 65 && publicKey[publicKey.startIndex] == 0x04 {
            return Data(publicKey.dropFirst())
        }

        throw MetaKeySignerError.invalidPublicKey
    }

    /// 32바이트로 패딩
    static func pad32(_ value: BigUInt) -> Data {
        let bytes = value.serialize()
        return Data(repeating: 0x00, count: max(0, 32 - bytes.count)) + bytes
    }

    /// 서명자가 반환한 값에서 r, s 를 꺼내고 s 를 정규형(low-s)으로 변환한다.
    static func rs(from raw: Data) throws -> (r: Data, s: Data) {
        guard raw.count == 64 || raw.count == 65 else {
            throw MetaKeySignerError.invalidSignature
        }

        let bytes = Data(raw)
        let r = Data(bytes.prefix(32))
        var s = BigUInt(Data(bytes[32..<64]))

        if s > curveOrder / 2 {
            s = curveOrder - s
        }

        return (r, pad32(s))
    }

    /// 다이제스트를 서명자로 서명하고 r||s||v (65바이트, v = 27 또는 28) 로 반환한다.
    static func sign65(digest: Data, signer: MetaKeySigner) throws -> Data {
        let publicKey = try rawPublicKey(signer.publicKey)
        let (r, s) = try rs(from: try signer.signDigest(digest))

        for recId in 0...1 {
            let signature = r + s + Data([UInt8(recId)])

            guard let recovered = Web3Core.SECP256K1.recoverPublicKey(hash: digest, signature: signature, compressed: false),
                  recovered.count == 65 else {
                continue
            }

            if Data(recovered.dropFirst()) == publicKey {
                return r + s + Data([UInt8(27 + recId)])
            }
        }

        throw MetaKeySignerError.signatureMismatch
    }

    /// personal message 해시. "\u{19}Ethereum Signed Message:\n32" + data 의 keccak256
    static func personalMessageHash(_ data: Data) -> Data? {
        return Utilities.hashPersonalMessage(data)
    }
}

/// 외부 키 보관 서비스로 서명하는 ES256K JWS 서명자. VC, VP 서명에 사용한다.
/// JWS signing input 의 SHA-256 다이제스트를 서명하며 결과는 r||s (64바이트, low-s) 이다.
public class ExternalJWSSigner: JWSSigner {
    let signer: MetaKeySigner

    public init(signer: MetaKeySigner) {
        self.signer = signer
    }

    public func sign(header: JWSHeader, signingInput: Data) throws -> Data {
        guard let alg = header.parameters["alg"] as? String,
              let algorithm = SignatureAlgorithm(rawValue: alg) else {
            throw SigningError.notSupportedAlgorithm
        }

        switch algorithm {
        case .ES256K:
            let raw = try signer.signDigest(sha256(data: signingInput))
            let (r, s) = try ExternalSignatureUtils.rs(from: raw)
            return r + s
        }
    }
}
