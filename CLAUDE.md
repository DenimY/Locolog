# CLAUDE.md — Locolog 에이전트 행동 규칙

> 이 파일은 Locolog 프로젝트에서 Claude Code 에이전트가 반드시 지켜야 하는 규칙과 개발 방식을 정의합니다.  
> Claude Code는 매 세션 시작 시 이 파일을 자동으로 읽습니다.

---

## 세션 시작 시 필수 절차

1. **`CONTEXT.md` 먼저 읽기** — 현재 개발 상태, 완료된 작업, 다음 스텝을 파악한다
2. **`PLANNING.md` 확인** — 기능 범위와 설계 결정을 확인한다
3. **현재 빌드 상태 확인** — 필요한 경우 `xcodebuild` 로 빌드가 정상인지 확인한다

---

## 세션 종료 시 필수 절차

1. **`CONTEXT.md` 업데이트** — 완료된 작업을 체크하고, 다음 스텝을 최신화한다
2. **커밋** — 작업한 모든 파일을 커밋한다
3. **푸시** — `git push origin main` 으로 원격 저장소에 반영한다

---

## 개발 규칙

### 파일 추가 시 반드시 xcodegen 재실행 + 위젯 패치 적용

터미널에서 Swift 파일을 추가하거나 삭제했다면 **반드시** 아래 순서로 실행:

```bash
cd /Users/youkyungmu/Documents/Project/Locolog
xcodegen generate

# WidgetKit embed을 iOS 전용으로 제한 (macOS 빌드 에러 방지)
sed -i '' '/LocologWidget.appex in Embed Foundation Extensions/s/settings = {/platformFilter = ios; settings = {/' \
  Locolog.xcodeproj/project.pbxproj
```

xcodegen 없이 추가된 파일은 Xcode 프로젝트에 포함되지 않아 빌드 에러가 발생한다.  
위젯 패치를 빠뜨리면 macOS 빌드 시 "embedded content built for iOS" 에러가 발생한다.

### 빌드 확인 명령어

```bash
xcodebuild \
  -project Locolog.xcodeproj \
  -scheme Locolog_iOS \
  -destination 'platform=iOS Simulator,id=826E1BBA-8546-4701-A37A-7B4FCECC6B32' \
  -configuration Debug build 2>&1 \
  | grep -E "error:|BUILD (SUCCEEDED|FAILED)" | grep -v "skipping cache"
```

빌드 에러가 있으면 해결 후에 커밋한다. BUILD SUCCEEDED 상태에서만 커밋한다.

### Swift 6 Strict Concurrency 주의사항

- `nonisolated` 델리게이트 메서드에서 actor-isolated 프로퍼티를 `Task {}` 안으로 캡처하면 data race 에러 발생
- 해결: `Task {}` 경계를 넘기 전에 로컬 `let` 변수로 값을 복사한 뒤 Task 안에서 사용

```swift
// 잘못된 예
nonisolated func someDelegate(_ manager: CLLocationManager) {
    Task { @MainActor in
        if manager.authorizationStatus == .authorizedWhenInUse { ... }  // 에러
    }
}

// 올바른 예
nonisolated func someDelegate(_ manager: CLLocationManager) {
    let status = manager.authorizationStatus  // Task 경계 밖에서 읽기
    Task { @MainActor in
        if status == .authorizedWhenInUse { ... }
    }
}
```

### SwiftUI Color 사용

- `.accent`, `.accentColor` ShapeStyle 단축어 없음 → `Color.accentColor` 사용
- 다크/라이트 대응 색상: `Color.primary`, `Color.secondary` 사용

---

## 변경 금지 설계 결정

다음은 확정된 설계 결정이며 절대 변경하지 않는다:

| 결정 | 이유 |
|---|---|
| 위치 권한 `When In Use` 만 사용 | `Always` 요청 시 App Store 심사 거절 |
| 온보딩: "로컬로 시작" 기본 버튼 | Guideline 4.0 — 소셜 로그인 강제 금지 |
| Apple Sign-In 반드시 포함 | 소셜 로그인 제공 시 App Store 정책 필수 |
| `calendar.events` scope는 토글 ON 시에만 | Incremental Auth — 온보딩 요청 금지 |
| 에디터: Markdown 원문 text 저장 | Quill Delta 대신 — 가볍고 유지보수 쉬움 |
| CLGeocoder (Apple 무료) 사용 | 별도 API 키, 비용 불필요 |

---

## 커밋 컨벤션

```
feat: 새 기능
fix: 버그 수정
refactor: 코드 개선 (기능 변화 없음)
docs: 문서 수정 (CONTEXT.md, README.md 등)
chore: 빌드 설정, xcodegen, 패키지 변경
```

예시: `feat: 캘린더 뷰 히트맵 완성`

---

## 기능 추가 순서 (PLANNING.md 기준)

로드맵 순서를 벗어나서 작업하지 않는다. 현재 스텝을 먼저 완료하고 다음 스텝으로 진행한다.

현재 단계는 항상 `CONTEXT.md`의 "다음 작업" 섹션을 기준으로 한다.

---

## 금지 사항

- `xcuserdata/` 커밋 금지 (`.gitignore` 에 포함됨)
- `Secrets.swift` 커밋 금지 (Supabase 환경변수 — 추후 생성 시 `.gitignore` 에 추가)
- 기획서 (`PLANNING.md`) 임의 수정 금지 — 변경 시 사용자 승인 필요
- 핵심 설계 결정 (위 표) 임의 변경 금지

---

## 프로젝트 경로 참조

| 항목 | 경로 |
|---|---|
| 로컬 경로 | `/Users/youkyungmu/Documents/Project/git/Locolog` |
| GitHub | https://github.com/DenimY/Locolog |
| xcodegen 스펙 | `project.yml` |
| 개발 컨텍스트 | `CONTEXT.md` |
| 기획서 | `PLANNING.md` |
