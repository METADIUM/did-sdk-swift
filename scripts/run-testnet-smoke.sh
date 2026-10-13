#!/usr/bin/env bash
# did-sdk-swift 테스트넷 스모크 테스트 실행 (체인에 씁니다).
# 브랜치 test/testnet-smoke 를 깨끗한 복사본에서 빌드하고(web3swift 는 복사본에서만 포크로 교체),
# createDID -> deleteDID -> existDid 를 실행합니다. 결과를 /tmp/did-testnet-smoke-result.md 에 정리합니다.
#
#   /tmp/run-testnet-smoke.sh                       # 바로 실행
#   PAUSE=90 /tmp/run-testnet-smoke.sh              # 생성 뒤 90초 멈춤 (그 사이 scripts/check-identity.sh 로 삭제 전 확인)
#   REPO=<경로> DEVICE="iPhone 17 Pro" /tmp/run-testnet-smoke.sh
set -uo pipefail

REPO="${REPO:-$HOME/Projects/DID/did-sdk-swift}"
DEVICE="${DEVICE:-iPhone 17}"
PAUSE="${PAUSE:-0}"
BRANCH="test/testnet-smoke"
WORK=/tmp/did-pkg
LOG=/tmp/did-testnet-smoke.log
OUT=/tmp/did-testnet-smoke-result.md

cd "$REPO" || { echo "REPO 를 찾을 수 없습니다: $REPO"; exit 1; }
if [ -n "$(git status --porcelain)" ]; then
  echo "작업 폴더에 변경이 있습니다. 먼저 정리하십시오 (git status)."; exit 1
fi
git fetch origin && git checkout "$BRANCH" && git pull origin "$BRANCH" || exit 1
HEAD_LINE="$(git log --oneline -1)"
echo "브랜치 head: $HEAD_LINE"

rm -rf "$WORK" && mkdir "$WORK"
git archive HEAD Package.swift Sources Tests scripts | tar -x -C "$WORK"
cd "$WORK" || exit 1
# 이 브랜치의 Package.swift 는 상류 web3swift 를 가리키므로 복사본에서만 포크로 바꾼다 (Xcode 27 빌드용)
sed -i '' 's|\.package(url: "https://github.com/web3swift-team/web3swift.git", .upToNextMajor(from: "3.0.0"))|.package(url: "https://github.com/METADIUM/web3swift.git", exact: "3.3.2-metadium.1")|' Package.swift
if ! grep -q 'METADIUM/web3swift.git' Package.swift; then
  echo "Package.swift 의 web3swift 줄을 포크로 바꾸지 못했습니다:"; grep -n "web3swift" Package.swift; exit 1
fi
rm -rf "$HOME"/Library/Developer/Xcode/DerivedData/did-pkg-*

echo "테스트넷에 씁니다 (DID 생성과 삭제). 로그: $LOG"
[ "$PAUSE" != "0" ] && echo "생성 뒤 ${PAUSE}초 멈춥니다. 그때 다른 터미널에서 scripts/check-identity.sh <did> 를 실행하십시오."
TEST_RUNNER_SMOKE_CONFIRM=yes TEST_RUNNER_SMOKE_PAUSE_SECONDS="$PAUSE" \
xcodebuild test -scheme DID-SDK-Swift \
  -destination "platform=iOS Simulator,name=$DEVICE" \
  -only-testing:did-sdk-swiftTests/TestnetSmokeTests > "$LOG" 2>&1 &
PID=$!
# 진행 상황 ([smoke] 줄)을 실시간으로 보여준다
tail -f "$LOG" 2>/dev/null | grep --line-buffered -E "\[smoke\]|error:|TEST (SUCCEEDED|FAILED)" &
TAILPID=$!
wait $PID
STATUS=$?
sleep 1; kill $TAILPID 2>/dev/null

{
  echo "Testnet run of \`$BRANCH\` at **$HEAD_LINE**, Xcode: \`$(xcodebuild -version 2>/dev/null | tr '\n' ' ')\`, \`$DEVICE\` simulator, web3swift fork \`3.3.2-metadium.1\`."
  echo
  echo '```'
  grep -E "\[smoke\]|Test Case .*(passed|failed|skipped)|error:|TEST (SUCCEEDED|FAILED)" "$LOG"
  echo '```'
} > "$OUT"

echo
echo "xcodebuild 종료 코드: $STATUS"
echo "================ $OUT ================"
cat "$OUT"
[ "$STATUS" -eq 0 ] || echo "실패했습니다. 로그: $LOG"
exit "$STATUS"
