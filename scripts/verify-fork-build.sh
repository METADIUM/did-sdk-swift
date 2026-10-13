#!/usr/bin/env bash
# did-sdk-swift PR #7 (web3swift 포크) 빌드 확인.
# Package.swift 를 손으로 바꾸지 않고, 브랜치 그대로 깨끗한 복사본에서 빌드하고 ExternalSignerTests 를 실행한다.
# 결과를 /tmp/did-pkg-result.md 에 정리한다. 체인에는 쓰지 않는다.
#
#   REPO=~/Projects/DID/did-sdk-swift ./verify-fork-build.sh
set -uo pipefail

REPO="${REPO:-$HOME/Projects/DID/did-sdk-swift}"
DEVICE="${DEVICE:-iPhone 17}"
BRANCH="chore/web3swift-xcode27-fork"
WORK=/tmp/did-pkg
LOG=/tmp/did-pkg-build.log
OUT=/tmp/did-pkg-result.md

cd "$REPO" || { echo "REPO 를 찾을 수 없습니다: $REPO"; exit 1; }
if [ -n "$(git status --porcelain)" ]; then
  echo "작업 폴더에 변경이 있습니다. 먼저 정리하십시오 (git status)."; exit 1
fi
git fetch origin && git checkout "$BRANCH" && git pull origin "$BRANCH" || exit 1
HEAD_LINE="$(git log --oneline -1)"
echo "브랜치 head: $HEAD_LINE"

rm -rf "$WORK" && mkdir "$WORK"
git archive HEAD Package.swift Sources Tests | tar -x -C "$WORK"
cd "$WORK" || exit 1
rm -rf "$HOME"/Library/Developer/Xcode/DerivedData/did-pkg-*

echo "Package.swift 의 web3swift 줄 (포크와 exact 3.3.2-metadium.1 이어야 합니다):"
grep -n "web3swift" Package.swift

echo "빌드와 테스트 중... (로그: $LOG)"
xcodebuild test -scheme DID-SDK-Swift \
  -destination "platform=iOS Simulator,name=$DEVICE" \
  -only-testing:did-sdk-swiftTests/ExternalSignerTests > "$LOG" 2>&1
STATUS=$?

RESOLVED="$(find "$WORK" -name Package.resolved -not -path '*/checkouts/*' 2>/dev/null | head -1)"
{
  echo "Build of \`$BRANCH\` at **$HEAD_LINE**, without replacing the dependency by hand (clean copy of \`Package.swift Sources Tests\`)."
  echo
  echo "Xcode: \`$(xcodebuild -version 2>/dev/null | tr '\n' ' ')\`, destination: \`$DEVICE\` simulator."
  echo
  echo "\`Package.swift\`:"
  echo '```'
  grep -n "web3swift" Package.swift
  echo '```'
  echo
  echo "Resolved web3swift (\`Package.resolved\`${RESOLVED:+, $RESOLVED}):"
  echo '```'
  if [ -n "$RESOLVED" ]; then
    python3 - "$RESOLVED" <<'PY'
import json, sys
data = json.load(open(sys.argv[1]))
for pin in data.get("pins", data.get("object", {}).get("pins", [])):
    name = pin.get("identity") or pin.get("package")
    if name and "web3swift" in name.lower():
        state = pin.get("state", {})
        print(name, pin.get("location") or pin.get("repositoryURL"), "version", state.get("version"), "revision", state.get("revision"))
PY
  else
    echo "(Package.resolved not found)"
  fi
  echo '```'
  echo
  echo "\`ExternalSignerTests\`:"
  echo '```'
  grep -E "Executed [0-9]+ tests|TEST (SUCCEEDED|FAILED)|error:" "$LOG" | sort -u | tail -6
  echo '```'
} > "$OUT"

echo
echo "xcodebuild 종료 코드: $STATUS"
echo "================ $OUT ================"
cat "$OUT"
[ "$STATUS" -eq 0 ] || echo "실패했습니다. 로그: $LOG 에서 'error:' 줄을 확인하십시오."
exit "$STATUS"
