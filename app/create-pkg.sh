#!/bin/bash
# 오늘시간표 macOS PKG 인스톨러 빌더
# 사용법: ./create-pkg.sh

APP_DIR=$(ls -d ~/Desktop/TodayTimetableMac\ * 2>/dev/null | head -1)
APP_PATH="$APP_DIR/TodayTimetableMac.app"

if [ ! -d "$APP_PATH" ]; then
    # 바탕화면에 직접 있는 경우
    APP_PATH=~/Desktop/TodayTimetableMac.app
fi

if [ ! -d "$APP_PATH" ]; then
    echo "❌ TodayTimetableMac.app을 바탕화면에서 찾을 수 없습니다."
    echo "   Xcode에서 Archive → Export 먼저 해주세요."
    exit 1
fi

echo "📦 PKG 생성 중..."

# 임시 폴더에 앱 복사
STAGING="/tmp/todaytimetable-pkg"
rm -rf "$STAGING"
mkdir -p "$STAGING/Applications"
cp -R "$APP_PATH" "$STAGING/Applications/오늘시간표.app"

# PKG 생성
pkgbuild \
    --root "$STAGING" \
    --identifier "com.todayschooltimetable.mac" \
    --version "1.0.0" \
    --install-location "/" \
    "/tmp/TodayTimetable-component.pkg"

# 최종 설치 PKG (설치 UI 포함)
productbuild \
    --package "/tmp/TodayTimetable-component.pkg" \
    ~/Desktop/오늘시간표-Mac-Installer.pkg

# 정리
rm -rf "$STAGING" "/tmp/TodayTimetable-component.pkg"

echo ""
echo "✅ PKG 생성 완료: ~/Desktop/오늘시간표-Mac-Installer.pkg"
open ~/Desktop
