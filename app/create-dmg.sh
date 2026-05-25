#!/bin/bash
# 오늘시간표 macOS DMG 빌더
# 사용법: ./create-dmg.sh

APP_NAME="오늘시간표"
APP_PATH="build/Build/Products/Release/TodayTimetableMac.app"
DMG_NAME="오늘시간표-Mac"
DMG_DIR="dmg-output"

# 이전 빌드 정리
rm -rf "$DMG_DIR"
mkdir -p "$DMG_DIR"

# .app 파일 확인
if [ ! -d "$APP_PATH" ]; then
    echo "❌ $APP_PATH 를 찾을 수 없습니다."
    echo "   Xcode에서 Product > Archive 또는 Release 빌드를 먼저 해주세요."
    echo ""
    echo "   또는 커맨드라인으로 빌드:"
    echo "   xcodebuild -scheme TodayTimetableMac -configuration Release build"
    exit 1
fi

# DMG 생성
create-dmg \
    --volname "$APP_NAME" \
    --volicon "$APP_PATH/Contents/Resources/AppIcon.icns" \
    --window-pos 200 120 \
    --window-size 600 400 \
    --icon-size 100 \
    --icon "$APP_NAME.app" 150 185 \
    --app-drop-link 450 185 \
    --hide-extension "$APP_NAME.app" \
    "$DMG_DIR/$DMG_NAME.dmg" \
    "$APP_PATH"

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ DMG 생성 완료: $DMG_DIR/$DMG_NAME.dmg"
    open "$DMG_DIR"
else
    echo "❌ DMG 생성 실패"
fi
