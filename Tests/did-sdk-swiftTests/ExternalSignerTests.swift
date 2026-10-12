import XCTest
import Web3Core
import BigInt
@testable import did_sdk_swift

/// 로컬 키가 외부 키 보관 서비스 역할을 한다. 서명 로직 테스트는 네트워크를 사용하지 않으며, 지갑 테스트는 MetaDelegator 생성 시 네트워크 설정을 호출한다.
/// mode 0: r||s, 1: r||s||v(0), 2: high-s 인 r||s, 3: ASN.1 DER
private struct LocalKeyStore: MetaKeySigner {
    let privateKey: Data
    let mode: Int

    var publicKey: Data {
        return Web3Core.SECP256K1.privateToPublic(privateKey: privateKey, compressed: false)!
    }

    func signDigest(_ digest: Data) throws -> Data {
        let signature = Web3Core.SECP256K1.signForRecovery(hash: digest, privateKey: privateKey).serializedSignature!
        let r = Data(signature.prefix(32))
        var s = BigUInt(Data(signature[32..<64]))

        if mode == 2 {
            s = ExternalSignatureUtils.curveOrder - s
        }

        if mode == 3 {
            // AWS KMS, Google Cloud KMS 와 같은 DER 형식
            func derInteger(_ value: BigUInt) -> [UInt8] {
                var bytes = [UInt8](value.serialize())
                if bytes[0] & 0x80 != 0 {
                    bytes.insert(0, at: 0)
                }
                return [0x02, UInt8(bytes.count)] + bytes
            }

            let body = derInteger(BigUInt(r)) + derInteger(s)
            return Data([0x30, UInt8(body.count)] + body)
        }

        let out = r + ExternalSignatureUtils.pad32(s)
        return mode == 1 ? out + Data([0]) : out
    }
}

final class ExternalSignerTests: XCTestCase {

    func testSign65MatchesLocalSignatureForAllSignerOutputForms() throws {
        let privateKey = Web3Core.SECP256K1.generatePrivateKey()!
        let hash = ExternalSignatureUtils.personalMessageHash(Data(repeating: 7, count: 32))!
        let expected = Web3Core.SECP256K1.signForRecovery(hash: hash, privateKey: privateKey).serializedSignature!

        for mode in 0...3 {
            let signer = LocalKeyStore(privateKey: privateKey, mode: mode)
            let signature = try ExternalSignatureUtils.sign65(digest: hash, signer: signer)

            XCTAssertEqual(signature.count, 65, "mode \(mode)")
            XCTAssertTrue(signature[64] == 27 || signature[64] == 28, "mode \(mode)")
            XCTAssertTrue(BigUInt(Data(signature[32..<64])) <= ExternalSignatureUtils.curveOrder / 2, "mode \(mode)")
            XCTAssertEqual(signature, expected, "mode \(mode)")
        }
    }

    func testSignatureOfOtherKeyIsRejected() throws {
        struct WrongKeyStore: MetaKeySigner {
            let claimedPublicKey: Data
            let actual: LocalKeyStore
            var publicKey: Data { return claimedPublicKey }
            func signDigest(_ digest: Data) throws -> Data { return try actual.signDigest(digest) }
        }

        let a = LocalKeyStore(privateKey: Web3Core.SECP256K1.generatePrivateKey()!, mode: 0)
        let b = LocalKeyStore(privateKey: Web3Core.SECP256K1.generatePrivateKey()!, mode: 0)
        let signer = WrongKeyStore(claimedPublicKey: a.publicKey, actual: b)

        XCTAssertThrowsError(try ExternalSignatureUtils.sign65(digest: Data(repeating: 1, count: 32), signer: signer))
    }

    func testUnsupportedSignatureFormIsRejected() throws {
        XCTAssertThrowsError(try ExternalSignatureUtils.rs(from: Data(repeating: 1, count: 10)))
        XCTAssertThrowsError(try ExternalSignatureUtils.rs(from: Data([0x30, 0x05, 0x02, 0x01, 0x01, 0x02, 0x01, 0x01, 0x00, 0x00])))
    }

    func testExternalJWSSignerRejectsSignatureOfOtherKey() throws {
        struct WrongKeyStore: MetaKeySigner {
            let claimedPublicKey: Data
            let actual: LocalKeyStore
            var publicKey: Data { return claimedPublicKey }
            func signDigest(_ digest: Data) throws -> Data { return try actual.signDigest(digest) }
        }

        let a = LocalKeyStore(privateKey: Web3Core.SECP256K1.generatePrivateKey()!, mode: 0)
        let b = LocalKeyStore(privateKey: Web3Core.SECP256K1.generatePrivateKey()!, mode: 0)
        let signer = ExternalJWSSigner(signer: WrongKeyStore(claimedPublicKey: a.publicKey, actual: b))

        XCTAssertThrowsError(try signer.sign(header: JWSHeader(algorithm: .ES256K), signingInput: Data("header.payload".utf8)))
    }

    func testExternalJWSSignerAcceptsDer() throws {
        let signer = LocalKeyStore(privateKey: Web3Core.SECP256K1.generatePrivateKey()!, mode: 3)

        let signature = try ExternalJWSSigner(signer: signer).sign(header: JWSHeader(algorithm: .ES256K), signingInput: Data("header.payload".utf8))

        XCTAssertEqual(signature.count, 64)
    }

    func testPublicKeyAcceptsBothEncodings() throws {
        let raw = Data(repeating: 9, count: 64)

        XCTAssertEqual(try ExternalSignatureUtils.rawPublicKey(raw), raw)
        XCTAssertEqual(try ExternalSignatureUtils.rawPublicKey(Data([0x04]) + raw), raw)
        XCTAssertThrowsError(try ExternalSignatureUtils.rawPublicKey(Data(repeating: 1, count: 33)))
    }

    func testExternalJWSSignerReturnsLowS64Bytes() throws {
        let signer = LocalKeyStore(privateKey: Web3Core.SECP256K1.generatePrivateKey()!, mode: 2)
        let header = JWSHeader(algorithm: .ES256K)

        let signature = try ExternalJWSSigner(signer: signer).sign(header: header, signingInput: Data("header.payload".utf8))

        XCTAssertEqual(signature.count, 64)
        XCTAssertTrue(BigUInt(Data(signature[32..<64])) <= ExternalSignatureUtils.curveOrder / 2)
    }

    func testWalletWithExternalSignerExposesPublicKeyOnly() throws {
        let delegator = MetaDelegator(delegatorUrl: "https://testdelegator.metadium.com",
                                      nodeUrl: "https://api.metadium.com/dev",
                                      resolverUrl: "https://testnetresolver.metadium.com/1.0/identifiers/",
                                      didPrefix: "did:meta:testnet:",
                                      api_key: "")
        let signer = LocalKeyStore(privateKey: Web3Core.SECP256K1.generatePrivateKey()!, mode: 0)
        let wallet = MetaWallet(delegator: delegator, signer: signer, did: "did:meta:testnet:0000000000000000000000000000000000000000000000000000000000000001")

        XCTAssertNil(wallet.toJson())
        XCTAssertNil(wallet.getKey()?.privateKey)
        XCTAssertNotNil(wallet.getKey()?.publicKey)
        XCTAssertNotNil(wallet.getKid())
    }
}
