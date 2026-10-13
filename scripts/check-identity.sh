#!/usr/bin/env bash
# 체인(IdentityRegistry)에서 DID 의 identity 를 읽는다. 읽기 전용이다.
#
#   scripts/check-identity.sh <did> [registry 주소] [노드 URL]
#
# 기본값은 테스트넷이다. DID 는 끝의 64자리 16진수가 EIN 이다.
# 삭제가 끝났으면 associatedAddresses 에 그 DID 의 주소가 없어야 한다 (identityExists 가 false 이거나, 목록이 비어 있다).
set -euo pipefail

DID="${1:?usage: $0 <did> [registry] [node]}"
REGISTRY="${2:-0xbe2bb3d7085ff04bde4b3f177a730a826f05cb70}"   # 테스트넷. 확인: curl -s -X POST https://testdelegator.metadium.com --data '{"jsonrpc":"2.0","method":"get_identity_registry_address","params":null,"id":1}'
NODE="${3:-https://api.metadium.com/dev}"

EIN="${DID##*:}"
if [[ ! "$EIN" =~ ^[0-9a-fA-F]{64}$ ]]; then
  echo "DID 끝이 64자리 16진수가 아닙니다: $DID" >&2
  exit 1
fi

call() {   # call <selector>
  curl -s -m 20 -X POST "$NODE" -H 'Content-Type: application/json' \
    --data '{"jsonrpc":"2.0","id":1,"method":"eth_call","params":[{"to":"'"$REGISTRY"'","data":"'"$1$EIN"'"},"latest"]}'
}

echo "registry=$REGISTRY node=$NODE ein=0x$EIN"

echo "-- identityExists(ein)"
call 0x5b5aed3a | python3 -c '
import json, sys
r = json.load(sys.stdin)
print("  error:", r["error"]) if "error" in r else print("  identityExists =", int(r["result"], 16) == 1)'

echo "-- getIdentity(ein)"
call 0x85e3f058 | python3 -c '
import json, sys
r = json.load(sys.stdin)
if "error" in r:
    print("  eth_call error (identity 가 없으면 revert 될 수 있다):", r["error"]); sys.exit(0)
h = r["result"][2:]
w = [h[i:i+64] for i in range(0, len(h), 64)]
def arr(off):
    i = int(off, 16) // 32
    n = int(w[i], 16)
    return ["0x" + w[i + 1 + k][24:] for k in range(n)]
print("  recoveryAddress     :", "0x" + w[0][24:])
print("  associatedAddresses :", arr(w[1]))
print("  providers           :", arr(w[2]))
print("  resolvers           :", arr(w[3]))'
