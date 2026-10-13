import XCTest
import Web3Core
@testable import did_sdk_swift

/// 테스트넷 스모크 테스트. 체인에 씁니다.
///
/// 외부 서명자(메모리의 소프트웨어 키)로 DID 를 만들고(createDID: 트랜잭션 2개), 삭제하고(deleteDID: 트랜잭션 2개),
/// 삭제 뒤 existDid 가 false 인지 확인합니다. 환경 변수 SMOKE_CONFIRM=yes 가 없으면 건너뜁니다.
///
/// xcodebuild 는 TEST_RUNNER_ 접두를 붙인 환경 변수를 테스트 프로세스에 접두 없이 전달합니다.
///
///     TEST_RUNNER_SMOKE_CONFIRM=yes xcodebuild test -scheme DID-SDK-Swift \
///       -destination 'platform=iOS Simulator,name=iPhone 17' \
///       -only-testing:did-sdk-swiftTests/TestnetSmokeTests
///
/// 선택: SMOKE_DELEGATOR, SMOKE_NODE, SMOKE_RESOLVER, SMOKE_PREFIX, SMOKE_API_KEY (기본값은 테스트넷).
/// SMOKE_PAUSE_SECONDS=60 이면 생성 뒤 삭제 전에 그 시간만큼 멈춥니다. 그 사이에 다른 터미널에서 scripts/check-identity.sh 로 삭제 전 상태를 볼 수 있습니다.
/// 출력에서 "[smoke]" 로 시작하는 줄에 DID 와 서명 횟수가 있습니다. 체인 쪽 확인은 scripts/check-identity.sh 로 합니다.

/// 메모리의 키. 키 보관 서비스 역할을 한다.
private struct SoftwareKeyStore: MetaKeySigner {
    let privateKey: Data

    var publicKey: Data {
        return Web3Core.SECP256K1.privateToPublic(privateKey: privateKey, compressed: false)!
    }

    func signDigest(_ digest: Data) throws -> Data {
        guard let signature = Web3Core.SECP256K1.signForRecovery(hash: digest, privateKey: privateKey).serializedSignature else {
            throw MetaKeySignerError.invalidSignature
        }

        // r||s (64바이트)
        return Data(signature.prefix(64))
    }
}

/// 서명 횟수를 센다.
private final class CountingKeyStore: MetaKeySigner {
    let inner: MetaKeySigner
    private(set) var calls = 0

    init(inner: MetaKeySigner) {
        self.inner = inner
    }

    var publicKey: Data {
        return inner.publicKey
    }

    func signDigest(_ digest: Data) throws -> Data {
        calls += 1
        return try inner.signDigest(digest)
    }
}

final class TestnetSmokeTests: XCTestCase {

    private func setting(_ name: String, _ fallback: String) -> String {
        let value = ProcessInfo.processInfo.environment[name] ?? ""
        return value.isEmpty ? fallback : value
    }

    /// 지갑의 키로 identity 가 체인에 있는지 (hasIdentity)
    private func existsOnChain(_ wallet: MetaWallet) -> Bool {
        var result = false
        let done = expectation(description: "existDid")

        Task {
            await wallet.existDid { exists in
                result = exists
                done.fulfill()
            }
        }

        wait(for: [done], timeout: 60)
        return result
    }

    func testCreateAndDeleteDidWithExternalSigner() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["SMOKE_CONFIRM"] == "yes",
                          "이 테스트는 체인에 씁니다(DID 생성과 삭제). SMOKE_CONFIRM=yes 를 지정하면 실행합니다.")

        let delegator = MetaDelegator(delegatorUrl: setting("SMOKE_DELEGATOR", "https://testdelegator.metadium.com"),
                                      nodeUrl: setting("SMOKE_NODE", "https://api.metadium.com/dev"),
                                      resolverUrl: setting("SMOKE_RESOLVER", "https://testnetresolver.metadium.com/1.0/identifiers/"),
                                      didPrefix: setting("SMOKE_PREFIX", "did:meta:testnet:"),
                                      api_key: setting("SMOKE_API_KEY", ""))
        XCTAssertNotNil(delegator.registryAddress, "delegator 가 get_all_service_addresses 에 응답하지 않았습니다")

        let signer = CountingKeyStore(inner: SoftwareKeyStore(privateKey: Web3Core.SECP256K1.generatePrivateKey()!))
        let wallet = try MetaWallet(delegator: delegator, signer: signer)
        let begin = Date()

        // 1. DID 생성 (create_identity, add_public_key)
        var createdReceipt: TransactionReceipt?
        var createdError: Error?
        let created = expectation(description: "createDID")

        wallet.createDID(signer: signer) { receipt, error in
            createdReceipt = receipt
            createdError = error
            created.fulfill()
        }

        wait(for: [created], timeout: 180)
        print("[smoke] createDID error=\(String(describing: createdError)) status=\(String(describing: createdReceipt?.status)) 서명 \(signer.calls)회")
        XCTAssertNil(createdError)
        XCTAssertTrue(createdReceipt?.status == .ok)

        let did = wallet.getDid()
        print("[smoke] did=\(did)")
        XCTAssertFalse(did.isEmpty)
        XCTAssertTrue(existsOnChain(wallet), "생성 뒤 existDid 가 true 여야 합니다")
        print("[smoke] 이 시점에 scripts/check-identity.sh \(did) 로 체인의 identity 를 확인할 수 있습니다")

        let pause = Double(setting("SMOKE_PAUSE_SECONDS", "0")) ?? 0
        if pause > 0 {
            print("[smoke] \(Int(pause))초 멈춥니다. 지금 scripts/check-identity.sh \(did) 를 실행하십시오 (associatedAddresses 에 주소가 있어야 합니다)")
            Thread.sleep(forTimeInterval: pause)
        }

        // 2. DID 삭제 (remove_public_key, remove_associated_address). 두 번째 단계는 이 PR 이 처음 실행한다.
        var deletedReceipt: TransactionReceipt?
        var deletedError: Error?
        let deleted = expectation(description: "deleteDID")

        wallet.deleteDID { receipt, error in
            deletedReceipt = receipt
            deletedError = error
            deleted.fulfill()
        }

        wait(for: [deleted], timeout: 240)
        print("[smoke] deleteDID error=\(String(describing: deletedError)) status=\(String(describing: deletedReceipt?.status)) 서명 합계 \(signer.calls)회")
        XCTAssertNil(deletedError, "partialDeletion 이면 공개키만 삭제된 상태입니다. DID \(did) 를 직접 확인하십시오")
        XCTAssertTrue(deletedReceipt?.status == .ok)

        // 3. 삭제 뒤
        XCTAssertFalse(existsOnChain(wallet), "삭제 뒤 existDid 가 false 여야 합니다")
        print("[smoke] 끝. \(Int(Date().timeIntervalSince(begin)))초, 서명 \(signer.calls)회 (예상 4회: create_identity, add_public_key, remove_public_key, remove_associated_address)")
        print("[smoke] 삭제 뒤 scripts/check-identity.sh \(did) 로 associated address 가 없는지 확인하십시오")
    }
}
