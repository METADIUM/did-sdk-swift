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

    func testPublicKeyForms() throws {
        let privateKey = Web3Core.SECP256K1.generatePrivateKey()!
        let uncompressed = Web3Core.SECP256K1.privateToPublic(privateKey: privateKey, compressed: false)!   // 0x04 || X || Y
        let compressed = Web3Core.SECP256K1.privateToPublic(privateKey: privateKey, compressed: true)!
        let raw = Data(uncompressed.dropFirst())
        let spkiHeader = Data.fromHex("0x3056301006072a8648ce3d020106052b8104000a034200")!

        XCTAssertEqual(try ExternalSignatureUtils.rawPublicKey(raw), raw)
        XCTAssertEqual(try ExternalSignatureUtils.rawPublicKey(uncompressed), raw)
        XCTAssertEqual(try ExternalSignatureUtils.rawPublicKey(compressed), raw)
        XCTAssertEqual(try ExternalSignatureUtils.rawPublicKey(spkiHeader + uncompressed), raw)

        // 곡선 위의 점이 아니거나 형식이 맞지 않는 값
        var offCurve = raw
        offCurve[63] ^= 0x01
        XCTAssertThrowsError(try ExternalSignatureUtils.rawPublicKey(offCurve))
        XCTAssertThrowsError(try ExternalSignatureUtils.rawPublicKey(Data(repeating: 9, count: 64)))
        XCTAssertThrowsError(try ExternalSignatureUtils.rawPublicKey(Data()))
        XCTAssertThrowsError(try ExternalSignatureUtils.rawPublicKey(Data(repeating: 1, count: 33)))
    }

    func testOutOfRangeRAndSAreRejectedWithoutCrash() throws {
        let n = ExternalSignatureUtils.curveOrder
        let max = (BigUInt(1) << 256) - 1
        let cases: [(BigUInt, BigUInt)] = [(0, 1), (1, 0), (n, 1), (1, n), (1, n + 1), (max, 1), (1, max)]

        for (r, s) in cases {
            let raw = ExternalSignatureUtils.pad32(r) + ExternalSignatureUtils.pad32(s)
            XCTAssertThrowsError(try ExternalSignatureUtils.rs(from: raw), "r=\(r) s=\(s)")
        }

        // DER 로 들어와도 같다
        func derInteger(_ value: BigUInt) -> [UInt8] {
            var bytes = [UInt8](value.serialize())
            if bytes[0] & 0x80 != 0 {
                bytes.insert(0, at: 0)
            }
            return [0x02, UInt8(bytes.count)] + bytes
        }
        let body = derInteger(1) + derInteger(max)
        XCTAssertThrowsError(try ExternalSignatureUtils.rs(from: Data([0x30, UInt8(body.count)] + body)))
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
        let wallet = try MetaWallet(delegator: delegator, signer: signer, did: "did:meta:testnet:0000000000000000000000000000000000000000000000000000000000000001")

        XCTAssertNil(wallet.toJson())
        XCTAssertNil(wallet.getKey()?.privateKey)
        XCTAssertNotNil(wallet.getKey()?.publicKey)
        XCTAssertNotNil(wallet.getKid())
    }

    // MARK: - wallet

    private static let did = "did:meta:testnet:0000000000000000000000000000000000000000000000000000000000000001"

    private func makeDelegator() -> MetaDelegator {
        return MetaDelegator(delegatorUrl: "https://testdelegator.metadium.com",
                             nodeUrl: "https://api.metadium.com/dev",
                             resolverUrl: "https://testnetresolver.metadium.com/1.0/identifiers/",
                             didPrefix: "did:meta:testnet:",
                             api_key: "")
    }

    private func verifier(for signer: LocalKeyStore) -> ECDSAVerifier {
        return ECDSAVerifier(publicKey: Data([0x04]) + (try! ExternalSignatureUtils.rawPublicKey(signer.publicKey)))
    }

    func testWalletInitRejectsInvalidPublicKey() throws {
        struct BadKeyStore: MetaKeySigner {
            var publicKey: Data { return Data(repeating: 9, count: 64) }
            func signDigest(_ digest: Data) throws -> Data { return Data(repeating: 1, count: 64) }
        }

        XCTAssertThrowsError(try MetaWallet(delegator: makeDelegator(), signer: BadKeyStore()))
    }

    func testIssueCredentialWithExternalSignerIsVerifiable() throws {
        let signer = LocalKeyStore(privateKey: Web3Core.SECP256K1.generatePrivateKey()!, mode: 3)
        let wallet = try MetaWallet(delegator: makeDelegator(), signer: signer, did: ExternalSignerTests.did)
        let ownerDid = "did:meta:testnet:0000000000000000000000000000000000000000000000000000000000000002"

        // 서명자를 지정하지 않으면 지갑의 외부 서명자를 사용한다.
        let automatic = try wallet.issueCredential(types: ["NameCredential"], id: nil, nonce: nil, issuanceDate: nil, expirationDate: nil, ownerDid: ownerDid, subjects: ["name": "x"])
        XCTAssertTrue(try automatic!.verify(verifier: verifier(for: signer)))

        // 서명자를 지정한 경우
        let explicit = try wallet.issueCredential(types: ["NameCredential"], id: nil, nonce: nil, issuanceDate: nil, expirationDate: nil, ownerDid: ownerDid, subjects: ["name": "x"], jwsSigner: ExternalJWSSigner(signer: signer))
        XCTAssertTrue(try explicit!.verify(verifier: verifier(for: signer)))
    }

    func testWalletRejectsJWSSignerOfAnotherKey() throws {
        let signer = LocalKeyStore(privateKey: Web3Core.SECP256K1.generatePrivateKey()!, mode: 0)
        let other = LocalKeyStore(privateKey: Web3Core.SECP256K1.generatePrivateKey()!, mode: 0)
        let wallet = try MetaWallet(delegator: makeDelegator(), signer: signer, did: ExternalSignerTests.did)

        // 다른 키의 정상적인 서명자. kid 는 지갑의 키를 가리킨다.
        XCTAssertThrowsError(try wallet.issueCredential(types: ["NameCredential"], id: nil, nonce: nil, issuanceDate: nil, expirationDate: nil, ownerDid: ExternalSignerTests.did, subjects: ["name": "x"], jwsSigner: ExternalJWSSigner(signer: other))) { error in
            guard case MetaWalletError.signerMismatch = error else {
                return XCTFail("\(error)")
            }
        }
    }

    func testSigningWithoutDidThrowsInsteadOfCrashing() throws {
        let signer = LocalKeyStore(privateKey: Web3Core.SECP256K1.generatePrivateKey()!, mode: 0)
        let wallet = try MetaWallet(delegator: makeDelegator(), signer: signer)   // DID 없음

        XCTAssertThrowsError(try wallet.issueCredential(types: ["NameCredential"], id: nil, nonce: nil, issuanceDate: nil, expirationDate: nil, ownerDid: ExternalSignerTests.did, subjects: [:], jwsSigner: ExternalJWSSigner(signer: signer)))

        // 키가 없는 지갑
        let keyless = MetaWallet(delegator: makeDelegator())
        XCTAssertThrowsError(try keyless.issuePresentation(types: ["TestPresentation"], id: nil, nonce: nil, issuanceDate: nil, expirationDate: nil, vcList: [], jwsSigner: ExternalJWSSigner(signer: signer)))
    }

    func testSignatureErrorOfTheSignerIsNotSwallowed() throws {
        struct FailingKeyStore: MetaKeySigner {
            struct KeyStoreDown: Error {}
            let publicKey: Data
            func signDigest(_ digest: Data) throws -> Data { throw KeyStoreDown() }
        }

        let local = LocalKeyStore(privateKey: Web3Core.SECP256K1.generatePrivateKey()!, mode: 0)
        let wallet = try MetaWallet(delegator: makeDelegator(), signer: FailingKeyStore(publicKey: local.publicKey), did: ExternalSignerTests.did)

        XCTAssertThrowsError(try wallet.signature(data: Data(repeating: 1, count: 32))) { error in
            XCTAssertTrue(error is FailingKeyStore.KeyStoreDown)
        }
        XCTAssertNil(wallet.getSignature(data: Data(repeating: 1, count: 32)))
    }

    func testCreateDidWithSignerOnWalletWithPrivateKeyCompletesWithError() throws {
        let json = "{\"did\":\"\(ExternalSignerTests.did)\",\"private_key\":\"\(Web3Core.SECP256K1.generatePrivateKey()!.toHexString())\"}"
        let wallet = MetaWallet(delegator: makeDelegator(), jsonStr: json)
        let signer = LocalKeyStore(privateKey: Web3Core.SECP256K1.generatePrivateKey()!, mode: 0)
        let done = expectation(description: "completion")

        wallet.createDID(signer: signer) { receipt, error in
            XCTAssertNil(receipt)
            guard case MetaWalletError.conflictingKeyMode? = error else {
                return XCTFail("\(String(describing: error))")
            }
            done.fulfill()
        }

        wait(for: [done], timeout: 5)
        XCTAssertNotNil(wallet.getKey()?.privateKey)   // 개인키를 지우지 않는다
    }
}
