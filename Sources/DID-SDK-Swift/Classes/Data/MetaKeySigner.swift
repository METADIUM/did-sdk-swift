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

    /// secp256k1 공개키. 64바이트(X||Y), 0x04 접두를 포함한 65바이트, 압축 33바이트 또는 SubjectPublicKeyInfo DER. 곡선 위의 점이어야 한다.
    var publicKey: Data { get }

    /// 다이제스트에 추가 해시 없이 그대로 서명한다.
    /// - Parameter digest: 32바이트 다이제스트
    /// - Returns: r||s (64바이트), r||s||v (65바이트) 또는 ASN.1 DER (AWS KMS, Google Cloud KMS 가 반환하는 형식).
    ///   v 는 선택이며 없거나 값이 달라도 SDK 가 공개키로 복원한다.
    ///
    /// 다이제스트는 최종값이다. SDK 가 이미 해시를 했으므로(Delegator 요청은 personal message 해시, VC/VP 는 JWS signing input 의 SHA-256)
    /// 추가 해시 없이 그대로 서명해야 한다.
    ///
    /// 동기 호출이며 보통 네트워크 호출이므로 메인 스레드가 아닌 백그라운드 큐에서 호출해야 한다.
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

    /// 키 보관 서비스가 준 공개키를 0x04 접두 없는 64바이트 X||Y 로 변환한다.
    /// 지원 형식: X||Y (64바이트), 0x04||X||Y (65바이트), 압축 (33바이트), X.509 SubjectPublicKeyInfo DER
    /// (AWS KMS, Google Cloud KMS GetPublicKey. 끝의 65바이트가 비압축 점).
    /// secp256k1 곡선 위의 점이 아니면 invalidPublicKey 를 던진다.
    static func rawPublicKey(_ publicKey: Data) throws -> Data {
        let bytes = [UInt8](publicKey)
        let point: [UInt8]

        if bytes.count == 64 {
            point = [0x04] + bytes
        } else if bytes.count == 65 && bytes[0] == 0x04 {
            point = bytes
        } else if bytes.count == 33 && (bytes[0] == 0x02 || bytes[0] == 0x03) {
            point = bytes
        } else if bytes.count > 65 && bytes[bytes.count - 65] == 0x04 {
            point = Array(bytes[(bytes.count - 65)...])
        } else {
            throw MetaKeySignerError.invalidPublicKey
        }

        // 점을 파싱해서 곡선 위의 점인지 확인하고 비압축 형식으로 직렬화한다.
        guard let serialized = Web3Core.SECP256K1.combineSerializedPublicKeys(keys: [Data(point)], outputCompressed: false),
              serialized.count == 65 else {
            throw MetaKeySignerError.invalidPublicKey
        }

        return Data(serialized.dropFirst())
    }

    /// 32바이트로 패딩
    static func pad32(_ value: BigUInt) -> Data {
        let bytes = value.serialize()
        return Data(repeating: 0x00, count: max(0, 32 - bytes.count)) + bytes
    }

    /// 서명자가 반환한 값에서 r, s 를 꺼내고 s 를 정규형(low-s)으로 변환한다.
    /// 지원 형식: r||s (64바이트), r||s||v (65바이트), ASN.1 DER (AWS KMS, Google Cloud KMS 가 반환하는 형식. 0x30 으로 시작)
    static func rs(from raw: Data) throws -> (r: Data, s: Data) {
        let bytes = [UInt8](raw)
        var r: BigUInt
        var s: BigUInt

        if bytes.count == 64 || bytes.count == 65 {
            r = BigUInt(Data(bytes[0..<32]))
            s = BigUInt(Data(bytes[32..<64]))
        } else if bytes.count > 8 && bytes[0] == 0x30 {
            let pair = try derRS(bytes)
            r = pair.0
            s = pair.1
        } else {
            throw MetaKeySignerError.invalidSignature
        }

        // 0 < r, s < n. 이 범위를 벗어난 값은 아래 감산에서 BigUInt 가 trap(crash) 되므로 먼저 거른다.
        guard r > 0, r < curveOrder, s > 0, s < curveOrder else {
            throw MetaKeySignerError.invalidSignature
        }

        if s > curveOrder / 2 {
            s = curveOrder - s
        }

        return (pad32(r), pad32(s))
    }

    /// SEQUENCE { INTEGER r, INTEGER s }. secp256k1 서명은 최대 72바이트이므로 길이는 short form 이다.
    private static func derRS(_ der: [UInt8]) throws -> (BigUInt, BigUInt) {
        guard der[1] & 0x80 == 0, Int(der[1]) == der.count - 2 else {
            throw MetaKeySignerError.invalidSignature
        }

        var pos = 2
        var values: [BigUInt] = []

        for _ in 0..<2 {
            guard pos + 2 <= der.count, der[pos] == 0x02 else {
                throw MetaKeySignerError.invalidSignature
            }

            let length = Int(der[pos + 1])
            pos += 2

            guard length > 0, length <= 33, pos + length <= der.count else {
                throw MetaKeySignerError.invalidSignature
            }

            values.append(BigUInt(Data(der[pos..<(pos + length)])))
            pos += length
        }

        guard pos == der.count else {
            throw MetaKeySignerError.invalidSignature
        }

        return (values[0], values[1])
    }

    /// 서명이 공개키로 복원되는 recovery id (0 또는 1). 공개키로 서명한 것이 아니면 nil.
    static func recoveryId(digest: Data, r: Data, s: Data, publicKey: Data) -> Int? {
        for recId in 0...1 {
            let signature = r + s + Data([UInt8(recId)])

            guard let recovered = Web3Core.SECP256K1.recoverPublicKey(hash: digest, signature: signature, compressed: false),
                  recovered.count == 65 else {
                continue
            }

            if Data(recovered.dropFirst()) == publicKey {
                return recId
            }
        }

        return nil
    }

    /// 다이제스트를 서명자로 서명하고 r||s||v (65바이트, v = 27 또는 28) 로 반환한다.
    static func sign65(digest: Data, signer: MetaKeySigner) throws -> Data {
        let publicKey = try rawPublicKey(signer.publicKey)
        let (r, s) = try rs(from: try signer.signDigest(digest))

        guard let recId = recoveryId(digest: digest, r: r, s: s, publicKey: publicKey) else {
            throw MetaKeySignerError.signatureMismatch
        }

        return r + s + Data([UInt8(27 + recId)])
    }

    /// personal message 해시. "\u{19}Ethereum Signed Message:\n32" + data 의 keccak256
    static func personalMessageHash(_ data: Data) -> Data? {
        return Utilities.hashPersonalMessage(data)
    }
}

/// 외부 키 보관 서비스로 서명하는 ES256K JWS 서명자. VC, VP 서명에 사용한다.
/// JWS signing input 의 SHA-256 다이제스트를 서명하며 결과는 r||s (64바이트, low-s) 이다.
/// 서명이 `signer.publicKey` 와 맞는지 확인하며 맞지 않으면 `MetaKeySignerError.signatureMismatch` 를 던진다.
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
            let digest = sha256(data: signingInput)
            let (r, s) = try ExternalSignatureUtils.rs(from: try signer.signDigest(digest))

            // 다른 키로 서명하면 검증자 단계가 아니라 서명 시점에 바로 실패시킨다.
            let publicKey = try ExternalSignatureUtils.rawPublicKey(signer.publicKey)
            guard ExternalSignatureUtils.recoveryId(digest: digest, r: r, s: s, publicKey: publicKey) != nil else {
                throw MetaKeySignerError.signatureMismatch
            }

            return r + s
        }
    }
}
