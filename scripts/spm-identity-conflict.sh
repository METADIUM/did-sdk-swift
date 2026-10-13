#!/usr/bin/env bash
# did-sdk-swift 가 METADIUM/web3swift 포크에 의존하므로, 상류 web3swift 를 직접 의존하는 앱이 의존성을 풀 수 있는지 확인한다.
# 3개 앱(패키지)을 /tmp/spm-identity-conflict 에 만들고 `swift package resolve` 를 실행한다. 빌드하지 않는다. 체인·서명 없음.
#
#   A: 앱이 상류 web3swift(from 3.3.0) 와 did-sdk-swift 를 함께 의존       -> 충돌이 의심되는 경우
#   B: 앱이 같은 포크·같은 태그(3.3.2-metadium.1)와 did-sdk-swift 를 함께 의존 -> README 가 안내하는 방법
#   C: 앱이 did-sdk-swift 만 의존                                         -> 기준
#
#   ./spm-identity-conflict.sh                      # did-sdk-swift 는 branch master
#   DID_REQ='from: "1.2.0"' ./spm-identity-conflict.sh   # 태그가 생긴 뒤
set -uo pipefail
DID_REQ="${DID_REQ:-branch: \"master\"}"
BASE=/tmp/spm-identity-conflict
rm -rf "$BASE" && mkdir -p "$BASE"
echo "$(swift --version 2>&1 | head -1)"
echo "did-sdk-swift: $DID_REQ"

mk() {  # mk <dir> <web3swift dependency line or empty>
  local d="$BASE/$1"; mkdir -p "$d/Sources/App"; echo "public let x = 1" > "$d/Sources/App/App.swift"
  local extra="" prod=""
  if [ -n "$2" ]; then extra=",
        $2"; prod=",
            .product(name: \"web3swift\", package: \"web3swift\")"; fi
  cat > "$d/Package.swift" <<PKG
// swift-tools-version:5.9
import PackageDescription
let package = Package(
    name: "Consumer",
    platforms: [.iOS(.v15), .macOS(.v12)],
    dependencies: [
        .package(url: "https://github.com/METADIUM/did-sdk-swift.git", $DID_REQ)$extra
    ],
    targets: [
        .target(name: "App", dependencies: [
            .product(name: "DID-SDK-Swift", package: "did-sdk-swift")$prod
        ])
    ]
)
PKG
}
mk A '.package(url: "https://github.com/web3swift-team/web3swift.git", from: "3.3.0")'
mk B '.package(url: "https://github.com/METADIUM/web3swift.git", exact: "3.3.2-metadium.1")'
mk C ''

for c in A B C; do
  echo
  echo "=============== case $c"
  (cd "$BASE/$c" && swift package resolve > resolve.log 2>&1; echo $? > exit.code)
  code=$(cat "$BASE/$c/exit.code")
  err=$(grep -m1 "^error:" "$BASE/$c/resolve.log" || true)
  if [ "$code" = "0" ]; then
    echo "resolved (exit 0)"
    python3 - "$BASE/$c/Package.resolved" <<'PY'
import json, sys
try:
    data = json.load(open(sys.argv[1]))
except Exception as e:
    print("  (Package.resolved not read:", e, ")"); sys.exit()
for pin in data.get("pins", []):
    if "web3swift" in (pin.get("identity") or "").lower():
        st = pin.get("state", {})
        print("  web3swift:", pin.get("location"), "version", st.get("version"), "revision", (st.get("revision") or "")[:7])
PY
  else
    echo "ERROR (exit $code): ${err:-see $BASE/$c/resolve.log}"
  fi
done
echo
echo "A resolves = a warning/pick (check the log); A fails = apps that depend on upstream web3swift directly break on 1.2.0 (needs 2.0.0)."
