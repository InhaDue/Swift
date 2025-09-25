# Xcode 프로젝트 설정 가이드

## Info.plist 설정 추가

Xcode에서 다음 설정들을 추가해주세요:

### 1. Background Modes 활성화
1. Xcode에서 프로젝트 선택
2. Targets → inhashapp 선택
3. "Signing & Capabilities" 탭 선택
4. "+ Capability" 버튼 클릭
5. "Background Modes" 추가
6. 다음 옵션들 체크:
   - ✅ Background fetch
   - ✅ Remote notifications
   - ✅ Background processing

### 2. Info.plist에 직접 추가
프로젝트 네비게이터에서 Info.plist 파일을 찾아 다음 키들을 추가:

```xml
<key>BGTaskSchedulerPermittedIdentifiers</key>
<array>
    <string>com.inhash.app.refresh</string>
</array>

<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
```

또는 Xcode의 Info 탭에서:
1. Targets → inhashapp → Info 탭
2. "Custom iOS Target Properties" 섹션
3. "+" 버튼으로 추가:
   - `BGTaskSchedulerPermittedIdentifiers` (Array) → Item 0: `com.inhash.app.refresh`
   - `App Transport Security Settings` (Dictionary) → `Allow Arbitrary Loads`: YES

### 3. Push Notifications 활성화
1. "Signing & Capabilities" 탭
2. "+ Capability" 버튼
3. "Push Notifications" 추가

### 4. 빌드 후 테스트
1. Clean Build Folder: Cmd + Shift + K
2. Build: Cmd + B
3. Run: Cmd + R

## 주의사항
- 실제 기기에서 백그라운드 작업을 테스트하려면 개발자 계정이 필요합니다
- 시뮬레이터에서는 백그라운드 페치가 제한적으로 작동합니다

