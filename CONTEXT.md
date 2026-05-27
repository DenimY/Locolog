# Locolog — 개발 컨텍스트 (에이전트 인수인계)

> 새 대화에서 이 파일을 먼저 읽으면 현재 상태를 파악할 수 있습니다.  
> 마지막 업데이트: 2026-05-27 (STEP 6 완료)

---

## 프로젝트 한 줄 요약

날짜·위치 자동 태깅 기반의 스마트 메모 앱 (iOS + macOS 동시 지원)  
**"무지성으로 던져도 날짜와 장소로 자동 정리"**

---

## 레포 & 경로

| 항목 | 내용 |
|---|---|
| GitHub | https://github.com/DenimY/Locolog |
| 로컬 경로 | `/Users/youkyungmu/Documents/Project/git/Locolog` |
| 기획서 | `PLANNING.md` (v0.5 확정) |
| 기술 스택 문서 | `TECH_STACK.md` |
| 레퍼런스 | `REFERENCES.md` |

---

## 기술 스택 (확정)

| 역할 | 기술 |
|---|---|
| 프레임워크 | **SwiftUI Multiplatform** (iOS 17+ / macOS 14+) |
| 로컬 DB | **SwiftData** |
| 서버 | **Supabase** (Auth + PostgreSQL + Realtime + Storage + Edge Functions) |
| 에디터 렌더링 | **swift-markdown-ui** (MIT) |
| 코드 하이라이팅 | **Highlightr** (MIT) |
| 인증/동기화 SDK | **supabase-swift** (MIT) |
| 위치 | **CoreLocation + CLGeocoder** (Apple 내장, 무료) |
| 지도 | **MapKit** (Apple 내장, Phase 3) |
| 패키지 관리 | **Swift Package Manager** |
| 프로젝트 생성 | **xcodegen** (`project.yml` → `Locolog.xcodeproj`) |

> Android 지원 없음. 추후 필요 시 별도 검토.

---

## 현재 빌드 상태

```
✅ BUILD SUCCEEDED
타겟: Locolog_iOS (iPhone 15 Pro Simulator)
Xcode 26.5 / Swift 6
마지막 확인: 2026-05-27 (STEP 2 완료 후)
```

---

## 완료된 작업

### Phase 1 — STEP 1: Xcode 프로젝트 세팅 ✅
### Phase 1 — STEP 2: 에디터 기능 완성 ✅
### Phase 1 — STEP 3: 카테고리 관리 UI + 스마트 폴더 UI + 캘린더 뷰 완성 ✅
### Phase 1 — STEP 4: 위치 자동 태깅 + POI 매칭 + macOS fallback 완성 ✅
### Phase 1 — STEP 5: 메모 목록 + 카테고리 UI 완성 ✅
### Phase 1 — STEP 6: 캘린더 뷰 완성 ✅

**생성된 파일 구조:**
```
Locolog/
├── Locolog.xcodeproj          ← xcodegen으로 생성
├── project.yml                ← xcodegen 스펙 (재생성 시: xcodegen generate)
├── PLANNING.md                ← 기획서 v0.5 (확정)
├── TECH_STACK.md              ← 기술 스택
├── REFERENCES.md              ← 레퍼런스 조사
├── CONTEXT.md                 ← 이 파일
├── .gitignore
├── Locolog/
│   ├── Resources/
│   │   ├── Info.plist
│   │   └── Locolog.entitlements
│   └── Sources/
│       ├── App/
│       │   ├── LocologApp.swift      ← @main, ModelContainer, Scene 설정
│       │   ├── RootView.swift        ← 온보딩 완료 여부에 따라 분기
│       │   └── ContentView.swift     ← iOS: MainTabView / macOS: MainSplitView
│       ├── Core/
│       │   ├── Theme/AppTheme.swift  ← 폰트, 컬러, 간격 상수
│       │   └── Utils/LocationManager.swift ← CoreLocation 포그라운드 전용
│       ├── Domain/Models/
│       │   ├── Note.swift            ← @Model, isDirty, locationPOI, displayTitle
│       │   ├── Category.swift        ← @Model
│       │   ├── Tag.swift             ← @Model
│       │   └── SmartFolder.swift     ← @Model, NoteFilter JSON 직렬화
│       └── Features/
│           ├── App/                  ← (위에 정리됨)
│           ├── Editor/
│           │   ├── Views/NoteEditorView.swift     ← 에디터 메인
│           │   └── Components/CodeAccessoryToolbar.swift ← 키보드 코드 툴바
│           ├── Notes/Views/
│           │   ├── NoteListView.swift
│           │   ├── NoteRowView.swift
│           │   └── SidebarView.swift
│           ├── Calendar/Views/CalendarView.swift   ← 히트맵 달력
│           ├── Search/Views/SearchView.swift
│           ├── Settings/Views/SettingsView.swift   ← Phase 2~3 stub 포함
│           └── Onboarding/Views/OnboardingView.swift ← "로컬로 시작" 우선
├── LocologTests/LocologTests.swift
└── LocologUITests/LocologUITests.swift
```

**주요 구현 내용:**
- SwiftData 전체 모델 (`Note`, `Category`, `Tag`, `SmartFolder`)
- `Note.displayTitle`: 첫 줄 자동 제목, 마크다운 헤더(`#`) 제거
- `Note.isDirty`: 오프라인 수정 추적 → 동기화 대기 플래그
- `Note.locationPOI`: CLPlacemark.areasOfInterest (예: "성수역 3번 출구")
- `LocationManager`: `@MainActor`, `When In Use` 전용, CLGeocoder POI 매칭
- `NoteEditorView`: `onChange` 0.3초 디바운스 자동저장, 에디터/프리뷰 전환
- `CodeAccessoryToolbar`: iPhone 키보드 위 코드 입력 툴바 (백틱, 언어 선택)
- `OnboardingView`: "로컬로 시작하기" 기본 버튼 (App Store Guideline 4.0 방어)
- `CalendarView`: 월간 히트맵 달력 + 날짜별 메모 목록

---

### Phase 1 — STEP 2 완료 내용

**HighlightrCodeHighlighter.swift** (신규 생성)
- `HighlightrCodeSyntaxHighlighter: CodeSyntaxHighlighter` 구현
- Dark: "atom-one-dark" / Light: "xcode" 테마
- iOS: `\.uiKit`, macOS: `\.appKit` 플랫폼별 AttributedString 변환

**NoteEditorView.swift** 업데이트
- 새 메모 생성 시 키보드 자동 포커스
- 편집 ↔ 프리뷰 전환 0.15s opacity 애니메이션
- 프리뷰 모드에 `HighlightrCodeSyntaxHighlighter` + `.markdownTheme(.gitHub)` 적용
- 위치 로딩 중 ProgressView 표시

**NoteListView.swift** 업데이트
- iOS: `NavigationStack(path:)` + `NavigationLink(value:)` + `navigationDestination(for:)`
- 스와이프 삭제 (soft delete: `isDeleted = true, isDirty = true`)
- `ContentUnavailableView` 빈 상태 화면

**수정된 빌드 에러들**
- `ShapeStyle has no member 'accent'` → `Color.accentColor` 로 교체
- Swift 6 data race in LocationManager → `nonisolated` 메서드 밖에서 status 값 읽기
- `HighlightrCodeSyntaxHighlighter` 파일 누락 → `xcodegen generate` 재실행으로 해결
- 코드 하이라이터 dot syntax 에러 → 직접 인스턴스화로 해결

**문서 추가**
- `README.md`: 앱 설명, 기능 표, 빌드 방법, 프로젝트 구조, 로드맵
- `CLAUDE.md`: 에이전트 행동 규칙 (세션 시작/종료 절차, 개발 규칙, 커밋 컨벤션)

---

## 다음 작업 (Phase 1 완료 → Phase 2 시작)

**Phase 1 완료. 다음은 STEP 7: Supabase 연동 + Google/Apple 로그인**

```
우선순위 순서:

1. [ ] Supabase 프로젝트 생성 및 Secrets.swift 설정
2. [ ] Apple Sign-In 구현 (App Store 필수)
3. [ ] Google Sign-In 구현 (선택적)
4. [ ] SettingsView 로그인 UI 연결
```

---

## 이후 로드맵 (순서대로)

```
STEP 2  에디터 기능 완성 + 시뮬레이터 검증     ✅ 완료
STEP 3  카테고리 관리 UI + 스마트 폴더 UI      ✅ 완료
STEP 4  위치 자동 태깅 + POI 매칭 완성         ✅ 완료
STEP 5  메모 목록 + 카테고리 UI 완성           ✅ 완료
STEP 6  캘린더 뷰 완성                         ✅ 완료
─────── Phase 1 완료 ───────
STEP 7  Supabase 연동 + Google/Apple 로그인    ← 현재
STEP 8  오프라인-온라인 동기화 (SyncManager, isDirty 기반)
STEP 9  고급 필터 + 스마트 폴더
STEP 10 알림 + Google Calendar 연동 (선택적)
─────── Phase 2 완료 ───────
STEP 11 AI 연동 (BYOK: Claude / OpenAI / Gemini)
STEP 12 지도 뷰 (MapKit)
STEP 13 이미지 첨부 + 내보내기
STEP 14 iOS 홈 위젯 (WidgetKit)
```

---

## macOS 목표 UI (STEP 12 타겟)

PlaceCal 스타일 3-패널 레이아웃:
- 좌측 사이드바: 캘린더 / 지도 / 전체 메모 / 스마트 폴더 / 카테고리
- 중앙 패널: 지도(MapKit) + 달력 그리드 동시 표시
- 우측 패널: 선택된 메모 상세 (장소, 연결 일정, 첨부파일, 생성 정보)

> STEP 12(MapKit) 구현 시 이 레이아웃을 목표로 삼는다.
> 현재는 사이드바 → 메모 목록/캘린더 → 에디터 구조 유지.

---

## 핵심 설계 결정 (변경 금지)

| 결정 | 이유 |
|---|---|
| 위치 권한 `When In Use` 만 사용 | Always 요청 시 App Store 심사 거절 |
| 온보딩에 "로컬로 시작" 기본 배치 | Guideline 4.0 — 소셜 로그인 강제 금지 |
| Apple Sign-In 반드시 포함 | App Store 정책: 소셜 로그인 제공 시 필수 |
| `calendar.events` scope는 토글 ON 시에만 | Incremental Auth — 온보딩에서 요청 금지 |
| 에디터: Markdown 원문 text 저장 | Quill Delta(JSONB) 대신 — 가볍고 유지보수 쉬움 |
| CLGeocoder (Apple 무료) 사용 | 별도 API 키, 비용 불필요 |
| Supabase 무료 티어 7일 정지 주의 | 심사 기간 웨이크업 봇 또는 Pro($25/월) 필요 |
| macOS 위치 로딩 딜레이 대응 필요 | GPS 없음, Wi-Fi 기반, 최대 10초 딜레이 가능 |

---

## 자주 쓰는 명령어

```bash
# 경로 이동
cd /Users/youkyungmu/Documents/Project/git/Locolog

# Xcode 프로젝트 열기
open Locolog.xcodeproj

# 프로젝트 재생성 (project.yml 수정 후)
xcodegen generate

# CLI 빌드 확인
xcodebuild \
  -project Locolog.xcodeproj \
  -scheme Locolog_iOS \
  -destination 'platform=iOS Simulator,id=826E1BBA-8546-4701-A37A-7B4FCECC6B32' \
  -configuration Debug build 2>&1 \
  | grep -E "error:|BUILD (SUCCEEDED|FAILED)" | grep -v "skipping cache"

# 사용 가능한 시뮬레이터 확인
xcrun simctl list devices available | grep iPhone
```

---

## 주의사항 (에이전트 공통)

- `project.yml` 수정 후 반드시 `xcodegen generate` 재실행
- Swift 6 Strict Concurrency 적용 중 — actor 경계 넘는 캡처 주의
- `Color.accentColor` 사용 (`.accent`, `.accentColor` ShapeStyle 단축어 없음)
- `xcuserdata/` 폴더는 커밋하지 않도록 `.gitignore` 이미 설정됨
- Supabase 환경변수는 추후 `Secrets.swift` (gitignore 됨)에 관리 예정

---

*이 파일은 개발 진행에 따라 지속 업데이트됩니다.*
