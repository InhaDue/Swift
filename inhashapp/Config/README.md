# 환경 설정 가이드

## 설정 방법

`AppConfig.swift` 파일을 열어 사용할 URL의 주석을 해제합니다.

## 환경 전환 방법 (한 줄만 수정!)

### 1. 시뮬레이터 테스트 (기본값):
```swift
static let baseURL = "http://localhost:8080"
// static let baseURL = "http://192.168.1.100:8080"
// static let baseURL = "https://api.inhash.com"
```

### 2. 실제 기기 테스트:
```swift
// static let baseURL = "http://localhost:8080"
static let baseURL = "http://192.168.1.100:8080"  // Mac의 IP 주소로 변경
// static let baseURL = "https://api.inhash.com"
```

### 3. 프로덕션 배포:
```swift
// static let baseURL = "http://localhost:8080"
// static let baseURL = "http://192.168.1.100:8080"
static let baseURL = "https://api.inhash.com"
```

## 주의사항

- `Config.xcconfig` 파일은 `.gitignore`에 포함되어 있어 git에 커밋되지 않습니다.
- 각 개발자는 자신의 환경에 맞게 `Config.xcconfig` 파일을 설정해야 합니다.
- Xcode 프로젝트 설정에서 Configuration File로 `Config.xcconfig`를 지정해야 합니다.

## Xcode 설정 방법

1. Xcode에서 프로젝트를 엽니다.
2. 프로젝트 네비게이터에서 프로젝트 파일을 선택합니다.
3. PROJECT > inhashapp를 선택합니다.
4. Info 탭으로 이동합니다.
5. Configurations 섹션에서:
   - Debug와 Release 설정 각각에 대해
   - inhashapp 타겟 옆의 화살표를 클릭
   - "Based on Configuration File"에서 `Config`를 선택

이제 앱이 `Config.xcconfig`에 설정된 `BASE_URL`을 사용합니다.
