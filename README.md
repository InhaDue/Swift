## inhashapp 빌드 & TestFlight 업로드 가이드

### 요구사항
- Xcode 16+ (CLI: `xcodebuild`, `altool`)
- App Store Connect API 키: Key ID, Issuer ID, `.p8` 파일

### API 키 설정
1) 키 파일 위치
   - 프로젝트 보관: `secrets/AuthKey_<KEYID>.p8` (Git에 커밋되지 않음)
   - 업로드 사용 경로(필수): `~/.appstoreconnect/private_keys/AuthKey_<KEYID>.p8`

2) 권한
   - App Store Connect 역할: Admin / App Manager / Developer 중 하나
   - 해당 앱(`Audora.inhashapp`) 접근 권한 포함

3) 배치 명령 예시
```bash
mkdir -p ~/.appstoreconnect/private_keys
cp secrets/AuthKey_<KEYID>.p8 ~/.appstoreconnect/private_keys/
chmod 600 ~/.appstoreconnect/private_keys/AuthKey_<KEYID>.p8
```

### 버전/빌드 넘버 업데이트
- 마케팅 버전(`MARKETING_VERSION`): 현재 1.0
- 빌드 번호(`CURRENT_PROJECT_VERSION`): 필요 시 증가(예: 17 → 18)

옵션 A) Xcode UI에서 타겟 > Build Settings > `CURRENT_PROJECT_VERSION` 수정

옵션 B) agvtool 사용(프로젝트 루트에서 실행)
```bash
agvtool new-version -all 18
```

### 아카이브(서명 없이)
```bash
xcodebuild \
  -scheme inhashapp \
  -project inhashapp.xcodeproj \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath build/inhashapp.xcarchive \
  CODE_SIGNING_ALLOWED=NO \
  clean archive
```

### IPA 내보내기(앱 스토어용)
- `ExportOptions.plist`가 없다면 생성:
```bash
/usr/libexec/PlistBuddy -c "Clear dict" \
  -c "Add :method string app-store" \
  -c "Add :teamID string F9BCX5LCAW" \
  -c "Add :uploadBitcode bool false" \
  -c "Add :uploadSymbols bool true" \
  -c "Add :signingStyle string automatic" \
  -c "Add :compileBitcode bool false" \
  -c "Add :destination string export" \
  -c "Add :generateAppStoreInformation bool true" \
  build/ExportOptions.plist
```

내보내기 실행:
```bash
xcodebuild -exportArchive \
  -archivePath build/inhashapp.xcarchive \
  -exportPath build/export \
  -exportOptionsPlist build/ExportOptions.plist \
  -allowProvisioningUpdates
```

### TestFlight 업로드
```bash
xcrun altool --upload-app \
  -f build/export/inhashapp.ipa -t ios \
  --apiKey <KEYID> --apiIssuer db34b5e9-2b84-4b0c-9a85-eb86a116d271 --verbose
```

### 참고 값
- Bundle ID: `Audora.inhashapp`
- Team ID: `F9BCX5LCAW`
- 아이콘: `AppIcon` (모든 필수 슬롯 채움, `INFOPLIST_KEY_CFBundleIconName=AppIcon`)

### 문제 해결 팁
- 401 인증 오류: API 키 권한/앱 접근 범위 확인, `.p8` 경로/권한(600) 확인
- 아이콘 오류: `AppIcon.appiconset/Contents.json`에 `ios-marketing 1024x1024` 포함 확인
- 번들/버전 오류: `PRODUCT_BUNDLE_IDENTIFIER`, `MARKETING_VERSION`, `CURRENT_PROJECT_VERSION` 확인


