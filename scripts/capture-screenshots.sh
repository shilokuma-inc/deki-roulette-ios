#!/bin/bash
# App Store 用スクリーンショットを撮る。
#
#   scripts/capture-screenshots.sh              # 全端末 × 全言語
#   scripts/capture-screenshots.sh --iphone     # iPhone だけ（--ipad も可）
#   scripts/capture-screenshots.sh "14 Plus"    # 名前が部分一致する端末だけ（動作確認向け）
#   SCREENSHOT_DIR=/path/to/out scripts/capture-screenshots.sh
#   SIMULATOR_RUNTIME=iOS-27 scripts/capture-screenshots.sh   # 使う iOS ランタイムを変える
#
# DekiRouletteScreenshots スキームの UI テスト（DekiRouletteUITests/ScreenshotTests.swift）を
# 端末 × 言語で実行し、添付画像を xcresult から取り出して
#   screenshots/<ASC ロケール>/<ASC screenshotDisplayType>/NN-name.png
# に並べる。このディレクトリ構成を scripts/asc-upload-screenshots.swift がそのまま読む。
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="$ROOT/DekiRoulette.xcodeproj"
SCHEME="DekiRouletteScreenshots"
# project.yml の PRODUCT_BUNDLE_IDENTIFIER と揃える
APP_BUNDLE_ID="ml.mrs1669.DekiRoulette"
# 撮影に使う iOS シミュレータのランタイム。前方一致で、該当するうちいちばん新しいものを使う。
# ランタイムによって描画が変わる（iOS 27.0 beta では 6.5 インチの画面上端に前のフレームが混ざる）ので、
# 手元と CI で同じ絵になるよう固定する。CI の Xcode を上げるときはここも見直す
RUNTIME="${SIMULATOR_RUNTIME:-iOS-26}"
OUT="${SCREENSHOT_DIR:-$ROOT/screenshots}"
DERIVED="$ROOT/build/dd"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# "<シミュレータ名>|<App Store Connect の screenshotDisplayType>"
# 6.9 インチは 6.7 インチと同じ APP_IPHONE_67 に入れる（1320x2868 を受け付ける）。
# 6.5 インチ（APP_IPHONE_65、1284x2778）は App Store Connect が今も要求するので 14 Plus で撮る
ALL_DEVICES=(
  "iPhone 17 Pro Max|APP_IPHONE_67"
  "iPhone 14 Plus|APP_IPHONE_65"
  "iPad Pro 13-inch (M5)|APP_IPAD_PRO_3GEN_129"
)
# "<ASC ロケール>|<-testLanguage>|<-testRegion>"
LOCALES=(
  "ja|ja|JP"
  "en-US|en|US"
)

DEVICES=()
for device in "${ALL_DEVICES[@]}"; do
  match=no
  case "${1:-}" in
    "")       match=yes ;;
    --iphone) if [[ "${device##*|}" == APP_IPHONE* ]]; then match=yes; fi ;;
    --ipad)   if [[ "${device##*|}" == APP_IPAD* ]]; then match=yes; fi ;;
    -*)       echo "usage: $0 [--iphone|--ipad|<端末名の一部>]" >&2; exit 2 ;;
    *)        if [[ "${device%%|*}" == *"$1"* ]]; then match=yes; fi ;;
  esac
  if [ "$match" = yes ]; then DEVICES+=("$device"); fi
done
if [ ${#DEVICES[@]} -eq 0 ]; then
  echo "該当する端末がありません: ${1:-}" >&2
  exit 2
fi

log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }

# 名前が一致するシミュレータのうち、いちばん新しい iOS ランタイムの UDID を返す。
# 用意されていない機種（runner には古い iPhone が無い）はその場で作る。
# 同じ名前で作るので、次回以降は既存のものが見つかり増えていかない
udid_for() {
  local name="$1" udid devicetype runtime
  udid="$(xcrun simctl list devices available -j | python3 -c '
import json, sys
name, prefix = sys.argv[1], sys.argv[2]
devices = json.load(sys.stdin)["devices"]
def key(rt):
    return [int(x) for x in rt.rsplit("-", 2)[-2:]]
matching = (r for r in devices if "SimRuntime." + prefix in r)
for runtime in sorted(matching, key=key, reverse=True):
    for d in devices[runtime]:
        if d["name"] == name:
            print(d["udid"]); sys.exit(0)
' "$name" "$RUNTIME")"
  if [ -n "$udid" ]; then
    echo "$udid"
    return
  fi

  devicetype="$(xcrun simctl list devicetypes -j | python3 -c '
import json, sys
name = sys.argv[1]
for t in json.load(sys.stdin)["devicetypes"]:
    if t["name"] == name:
        print(t["identifier"]); sys.exit(0)
sys.exit(f"device type not found: {name}")
' "$name")"
  runtime="$(xcrun simctl list runtimes -j | python3 -c '
import json, sys
devicetype, prefix = sys.argv[1], sys.argv[2]
runtimes = [
    r for r in json.load(sys.stdin)["runtimes"]
    if r.get("isAvailable") and "SimRuntime." + prefix in r["identifier"]
    and any(t["identifier"] == devicetype for t in r.get("supportedDeviceTypes", []))
]
if not runtimes:
    sys.exit(f"{prefix} に {devicetype} を動かせるランタイムがありません")
print(max(runtimes, key=lambda r: [int(x) for x in r["version"].split(".")])["identifier"])
' "$devicetype" "$RUNTIME")"
  log "create: $name ($runtime)" >&2
  xcrun simctl create "$name" "$devicetype" "$runtime"
}

# シミュレータのシステム言語・地域を切り替える（停止中に設定ファイルを書き換え、次の起動で反映）。
# -testLanguage だけではアプリ内文言しか変わらず、ステータスバーの日付やキーボードが OS の言語のまま残るため
set_system_locale() {
  local udid="$1" lang="$2" region="$3"
  local plist="$HOME/Library/Developer/CoreSimulator/Devices/$udid/data/Library/Preferences/.GlobalPreferences.plist"
  xcrun simctl shutdown "$udid" 2>/dev/null || true
  /usr/libexec/PlistBuddy -c "Delete :AppleLanguages" "$plist" >/dev/null 2>&1 || true
  /usr/libexec/PlistBuddy -c "Delete :AppleLocale" "$plist" >/dev/null 2>&1 || true
  /usr/libexec/PlistBuddy \
    -c "Add :AppleLanguages array" \
    -c "Add :AppleLanguages:0 string $lang" \
    -c "Add :AppleLocale string ${lang}_${region}" \
    "$plist" >/dev/null
}

if [ ! -d "$PROJECT" ]; then
  log "xcodegen generate"
  (cd "$ROOT" && xcodegen generate >/dev/null)
fi

log "build-for-testing"
xcodebuild build-for-testing \
  -project "$PROJECT" -scheme "$SCHEME" \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$DERIVED" -quiet

for device in "${DEVICES[@]}"; do
  name="${device%%|*}"
  display_type="${device##*|}"
  udid="$(udid_for "$name")"

  for locale in "${LOCALES[@]}"; do
    IFS='|' read -r asc_locale lang region <<<"$locale"
    dest="$OUT/$asc_locale/$display_type"
    result="$WORK/$display_type-$asc_locale.xcresult"
    export_dir="$WORK/$display_type-$asc_locale"

    log "boot: $name / $asc_locale ($udid)"
    set_system_locale "$udid" "$lang" "$region"
    xcrun simctl boot "$udid"
    xcrun simctl bootstatus "$udid" -b >/dev/null
    # 前回の実行で残ったアプリのスナップショットが起動直後の画面に重なるため、いったん消す
    xcrun simctl uninstall "$udid" "$APP_BUNDLE_ID" 2>/dev/null || true
    # ステータスバーを App Store 向けに固定する
    xcrun simctl status_bar "$udid" override \
      --time "9:41" --dataNetwork wifi --wifiMode active --wifiBars 3 \
      --cellularMode active --cellularBars 4 --batteryState charged --batteryLevel 100

    log "test: $name / $asc_locale"
    xcodebuild test-without-building \
      -project "$PROJECT" -scheme "$SCHEME" \
      -destination "id=$udid" \
      -testLanguage "$lang" -testRegion "$region" \
      -derivedDataPath "$DERIVED" \
      -resultBundlePath "$result" -quiet

    xcrun xcresulttool export attachments \
      --path "$result" --output-path "$export_dir" --filter '*.png' >/dev/null

    rm -rf "$dest"
    mkdir -p "$dest"
    # manifest.json の suggestedHumanReadableName は "<添付名>_<連番>_<UUID>.png" になるので添付名だけ残す
    python3 - "$export_dir" "$dest" <<'PY'
import json, re, shutil, sys
from pathlib import Path
export_dir, dest = Path(sys.argv[1]), Path(sys.argv[2])
manifest = json.loads((export_dir / "manifest.json").read_text())
count = 0
for test in manifest:
    for att in test.get("attachments", []):
        human = att.get("suggestedHumanReadableName", "")
        m = re.match(r"^(\d{2}-[A-Za-z0-9-]+)", human)
        if not m:
            continue
        shutil.copy(export_dir / att["exportedFileName"], dest / f"{m.group(1)}.png")
        count += 1
if count == 0:
    sys.exit(f"no screenshots exported from {export_dir}")
PY

    for png in "$dest"/*.png; do
      size="$(sips -g pixelWidth -g pixelHeight "$png" | awk '/pixel/ {printf "%s ", $2}')"
      printf '    %s  (%s)\n' "${png#"$OUT/"}" "${size% }"
    done
  done

  xcrun simctl status_bar "$udid" clear
done

log "done: $OUT"
