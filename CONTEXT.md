# Locolog — 개발 컨텍스트 (에이전트 인수인계)

> 새 대화에서 이 파일을 먼저 읽으면 현재 상태를 파악할 수 있습니다.  
> 마지막 업데이트: 2026-09-02 (기획 v0.7 + 아이콘 스탬프)

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
| 기획서 | `PLANNING.md` (v0.7 확정) |
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
타겟: Locolog_iOS (iPhone 17 Pro Simulator) + Locolog_macOS
Xcode / Swift 6
마지막 확인: 2026-09-02 (아이콘 스탬프)
단위 테스트: LocologTests 12개 통과
```

---

## 완료된 작업

### Phase 1 — STEP 1: Xcode 프로젝트 세팅 ✅
### Phase 1 — STEP 2: 에디터 기능 완성 ✅
### Phase 1 — STEP 3: 카테고리 관리 UI + 스마트 폴더 UI + 캘린더 뷰 완성 ✅
### Phase 1 — STEP 4: 위치 자동 태깅 + POI 매칭 + macOS fallback 완성 ✅
### Phase 1 — STEP 5: 메모 목록 + 카테고리 UI 완성 ✅
### Phase 1 — STEP 6: 캘린더 뷰 완성 ✅
### Phase 2 — STEP 7: Supabase 연동 + Apple Sign-In 구현 ✅
### Phase 2 — STEP 8: 오프라인-온라인 동기화 (SyncManager) ✅
### Phase 2 — STEP 9: 고급 필터 + 스마트 폴더 ✅
### Phase 2 — STEP 10: 알림 + Google Calendar 연동 (선택적) ✅
### Phase 3 — STEP 11: AI 연동 (BYOK: Claude / OpenAI / Gemini) ✅
### Phase 3 — STEP 12: 지도 뷰 (MapKit) ✅
### Phase 3 — STEP 13: 이미지 첨부 + 내보내기 ✅
### Phase 3 — STEP 14: iOS 홈 위젯 (WidgetKit) ✅
### Phase 4 — STEP 15: 기획 v0.6 + 오늘 / 여기 근처 기본 뷰 ✅
### Phase 4 — STEP 16: 위젯 퀵 캡처 + `locolog://` 딥링크 ✅
### Phase 4 — STEP 17: 온보딩·빈 화면 카피 ✅
### Phase 4 — STEP 17b: 아이콘 스탬프로 2차 분류 ✅

**생성된 파일 구조:**
```
Locolog/
├── Locolog.xcodeproj          ← xcodegen으로 생성
├── project.yml                ← xcodegen 스펙 (재생성 시: xcodegen generate)
├── PLANNING.md                ← 기획서 v0.7 (확정)
├── TECH_STACK.md              ← 기술 스택
├── REFERENCES.md              ← 레퍼런스 조사
├── CONTEXT.md                 ← 이 파일
├── .gitignore
├── supabase/migrations/       ← DB 마이그레이션 파일
├── Locolog/
│   ├── Resources/
│   │   ├── Info.plist
│   │   └── Locolog.entitlements
│   └── Sources/
│       ├── App/
│       │   ├── LocologApp.swift      ← @main, ModelContainer, Scene 설정
│       │   ├── RootView.swift        ← 온보딩 완료 여부에 따라 분기, onOpenURL
│       │   ├── ContentView.swift     ← iOS: MainTabView / macOS: MainSplitView
│       │   └── DeepLinkRouter.swift  ← locolog://new, locolog://note/<uuid>
│       ├── Core/
│       │   ├── AI/AIManager.swift    ← BYOK AI (Claude/OpenAI/Gemini) URLSession
│       │   ├── Auth/                 ← AuthManager, SupabaseService, Secrets
│       │   ├── Notifications/NotificationManager.swift
│       │   ├── Sync/SyncManager.swift
│       │   ├── Theme/AppTheme.swift
│       │   └── Utils/LocationManager.swift
│       ├── Domain/Models/
│       │   ├── Note.swift            ← @Model, isDirty, locationPOI, displayTitle
│       │   ├── Folder.swift
│       │   ├── CategoryStamp.swift   ← 아이콘 스탬프 프리셋 + 할당
│       │   ├── Category.swift        ← @Model
│       │   ├── Tag.swift             ← @Model
│       │   └── SmartFolder.swift     ← @Model, NoteFilter JSON 직렬화
│       └── Features/
│           ├── AI/Views/AICommandView.swift  ← AI 명령어 시트 UI
│           ├── Editor/
│           │   ├── Views/NoteEditorView.swift     ← 에디터 메인 (아이콘 독 + AI)
│           │   └── Components/
│           │       ├── CategoryIconDock.swift     ← 분류 아이콘 드래그/탭
│           │       ├── CodeAccessoryToolbar.swift
│           │       └── ReminderPickerView.swift
│           ├── Notes/Views/
│           │   ├── NoteListView.swift
│           │   ├── NoteRowView.swift
│           │   └── SidebarView.swift
│           ├── SmartFolders/Views/SmartFolderFormView.swift
│           ├── Calendar/Views/CalendarView.swift
│           ├── Search/Views/SearchView.swift
│           ├── Settings/Views/SettingsView.swift
│           └── Onboarding/Views/OnboardingView.swift
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

## 이번 세션 완료 작업 (2026-06-15)

### 보안 강화 & Google Sign-In 구현 ✅
- **KeychainManager.swift** (신규): Security 프레임워크 기반 API 키 저장 (`kSecClassGenericPassword`)
- **AIManager.swift**: `activeProvider`, `apiKey(for:)` → `UserDefaults` 대신 Keychain 사용
- **SettingsView.swift**:
  - iOS `AISettingsView`: `@AppStorage` → Keychain `@State` + `.onChange` 저장
  - macOS `AITabView`: 동일하게 Keychain 기반으로 통일
  - iOS `AccountView`: Google Sign-In 버튼 활성화 + `signInWithGoogle()` 추가
  - macOS `AccountTabView`: Google Sign-In 버튼 활성화 + `signInWithGoogle()` 추가
- **AuthManager.swift**:
  - `signInWithGoogle()`: `ASWebAuthenticationSession` + Supabase OAuth 플로우
  - `performWebAuth(url:callbackScheme:)`: async/await 래퍼
  - `ASWebAuthenticationPresentationContextProviding` 채택
  - `webAuthSession` 프로퍼티로 세션 생명주기 관리
- **OnboardingView.swift**: Google Sign-In 버튼 활성화
- **SyncManager.swift**: 
  - `pull()` — `user_id` 필터 추가 (타 사용자 메모 접근 방지)
  - `isFavorited` 동기화 (`NotePayload`, `NoteRecord` 필드 추가)

### 사이드바 UX 개선 ✅
- **SidebarView.swift**:
  - 카테고리 드래그 재정렬 (`ForEach.onMove` + `category.position` SwiftData 저장)
  - 태그 섹션 추가 (삭제되지 않은 노트의 태그만 표시)
  - 고정 항목 드래그 재정렬 (`@AppStorage("navOrder")` 기반)
- **ContentView.swift**:
  - `SidebarItem.tag(String)` 케이스 추가
  - `NavItem` enum 추가 (rawValue 기반 순서 관리)
  - 앱 실행 시 `navOrder` 첫 번째 항목 자동 선택
- **NoteListView.swift**: `.tag(tagName)` 필터 + 내비게이션 타이틀 추가

### macOS 인라인 편집 ✅
- `NavigationSplitView` detail 패널에 `NoteEditorView` 직접 표시 (Edit 버튼 없음)
- `NoteEditorView` macOS 즐겨찾기 툴바 버튼 추가

### 머지 충돌 해결 ✅
- `SettingsView.swift`: HEAD(Keychain) + 원격(macOS TabView 재설계) 통합
- `scripts/fix_pbxproj.py`: Sparkle `platformFilter maccatalyst → macos` (원격 버전 채택)

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

## 추가 완료된 작업 (2026-06 macOS 배포 + UX 개선)

### macOS Developer ID DMG 배포 ✅
- `ExportOptions.plist` 생성 (Developer ID export)
- `Locolog_macOS.entitlements` — 네트워크·위치·파일 권한, Apple Sign-In 제외 (Developer ID용)
- `project.yml`: `ENABLE_HARDENED_RUNTIME`, `CODE_SIGN_ENTITLEMENTS` 추가
- `scripts/fix_pbxproj.py`:
  - Sparkle를 iOS 타겟에서 완전 제거 (섹션 2)
  - Sparkle `platformFilter maccatalyst → macos` 자동 패치 (섹션 3, 신규)
- `create-dmg` + `xcrun notarytool` + `xcrun stapler` 로 공증 DMG 생성 완료

### macOS UX 개선 ✅
- **NoteType 추가**: `Note.swift`에 `NoteType` enum (markdown/log), `noteTypeRaw` 필드
- **LogRendererView**: 터미널 스타일 뷰어 — ANSI 제거, 레벨 뱃지(ERR/WRN/INF/DBG)
- **NoteEditorView 개선**:
  - 파일별 preview 모드 `UserDefaults` 저장/복원
  - 다크모드 `adaptiveMarkdownTheme` (dark: 커스텀, light: gitHub)
  - `+` 블럭 삽입 메뉴 (Obsidian/Notion 스타일: 제목/목록/코드/인용/노트타입)
- **NoteListView**: macOS 오른쪽 클릭 `contextMenu` (새 메모/즐겨찾기/노트타입/삭제)
- **NoteRowView**: 로그 타입 메모에 터미널 아이콘 표시
- **SettingsView 전면 재설계**:
  - macOS: `TabView` 기반 네이티브 설정창 (계정/AI/알림/정보 탭)
  - iOS: 기존 `NavigationStack + Form` 유지
  - `#if os(macOS)` 분기로 플랫폼별 완전히 다른 UI

---

## 이번 세션 완료 작업 (2026-08-31)

### 자동저장 버그 수정
- 키 입력 즉시 `isDirty = true` (0.3초 창에서 pull이 편집을 덮어쓰던 문제 제거)
- `hasUnsavedChanges`로 디바운스 완료 여부와 저장 태스크를 분리 — 이미 저장된 노트를 나갈 때 `updatedAt`이 다시 올라가지 않음
- 에디터 이탈·백그라운드 전환 시 pending 저장만 flush
- 코드 툴바 / 블록 삽입 / AI 결과는 `localContent`를 통해 동일 저장 경로로 진입
- macOS 즐겨찾기 툴바가 `isDirty`를 빼먹던 문제 수정

### 동기화 버그 수정
- push 중 추가 편집이 있으면 snapshot 불일치로 `isDirty` 유지 (전송 완료로 잘못 지우던 문제)
- 겹치는 `sync()`는 버리던 것 → 재시도 큐
- 즐겨찾기·삭제·폴더 이동·아이콘·첨부·리마인더 등 메타데이터도 `scheduleSync`
- 폴더 / 스마트폴더 push·pull, 노트에 `folder_id`·`note_type`·`icon_emoji` 포함 (서버 미적용 시 레거시 payload로 재시도)
- 완전 삭제는 원격 delete 큐에 넣어 pull이 되살리지 못하게 함
- pull 시 본문의 `#태그`로 Tag 관계 재구성
- NWPathMonitor로 오프라인→온라인 복귀 시 동기화
- Auth `authStateChanges` + 세션 리프레시
- notes Realtime 변경 시 debounce pull
- 설정 화면에 마지막 동기화 시각 / 오류 / 오프라인 / 수동 동기화

### 서버 마이그레이션 (적용 필요)
`supabase/migrations/20260831000000_sync_folders_and_note_fields.sql`
- `notes.is_favorited`, `folder_id`, `note_type`, `icon_emoji`
- `folders` 테이블 + RLS
- `supabase_realtime` publication에 notes/folders/smart_folders

> **Supabase SQL 에디터에서 위 마이그레이션을 실행해야 폴더·노트타입 동기화가 살아난다.**
> 미적용이어도 본문 동기화는 레거시 upsert로 계속 시도한다.

### Phase 4 — 사용 루프 (2026-09-02)

- 기획서 `PLANNING.md` v0.6: 던지기 → 찾기 → 다듬기. 오늘/여기가 기본 뷰.
- iOS 메모 탭 상단 칩: **오늘 / 여기 / 전체**. 오늘 = 작성일 오늘, 여기 = 현재 위치 반경 1km.
- macOS 사이드바 기본 항목에 오늘·여기 근처. 기본 선택은 오늘.
- 위젯 소형: 탭하면 `locolog://new` 새 메모. 중형: 헤더 새 메모 + 행은 기존 메모 열기.
- 딥링크: `locolog://new`, `locolog://note/<uuid>`, `locolog://open`. URL Types에 `locolog` / `com.locolog.app`.
- 온보딩·빈 화면 카피를 루프에 맞게 수정.
- 기획서 v0.7: **장소가 1차 분류**. 회사→회의록, 마트→장보기, 집→메모지.
- 에디터 상단 아이콘 독: 회의·코드·장보기·집·아이디어. 본문에 드래그하거나 탭. 첫 사용 시 폴더 생성. 같은 아이콘 재탭하면 해제.

---

## 다음 작업 (Phase 4 나머지)

```
STEP 18  공유 시트 등 추가 시스템 진입점
STEP 19  Supabase에 `20260831000000_sync_folders_and_note_fields.sql` 적용 (폴더·타입 동기화)
- 친구 추가 기능 (명칭 미확정 / 이메일 초대 → 노트 공유, DB 스키마는 note_shares로 준비됨)
- 팀 공유 UI (SQL 스키마 완성됨, 클라이언트 미구현)
- Google Sign-In ← 클라이언트 구현 완료, Supabase 대시보드 Google 공급자 활성화 필요
  - Supabase Dashboard → Auth → Providers → Google 활성화
  - Redirect URL 추가: com.locolog.app://auth-callback
- Google Calendar 실제 연동
- 이미지 Supabase Storage 동기화 (첨부·아이콘 이미지는 아직 기기 로컬)
- 위젯 Lock Screen (accessoryRectangular 등)
- App Store 제출 준비 (스크린샷, 설명, 개인정보처리방침)
```

> **xcodegen 재실행 시 주의**: 위젯 embed platformFilter 패치 필수 (CLAUDE.md 참조)

---

## 이후 로드맵 (순서대로)

```
STEP 2  에디터 기능 완성 + 시뮬레이터 검증     ✅ 완료
STEP 3  카테고리 관리 UI + 스마트 폴더 UI      ✅ 완료
STEP 4  위치 자동 태깅 + POI 매칭 완성         ✅ 완료
STEP 5  메모 목록 + 카테고리 UI 완성           ✅ 완료
STEP 6  캘린더 뷰 완성                         ✅ 완료
─────── Phase 1 완료 ───────
STEP 7  Supabase 연동 + Google/Apple 로그인    ✅ 완료
STEP 8  오프라인-온라인 동기화 (SyncManager, isDirty 기반)  ✅ 완료
STEP 9  고급 필터 + 스마트 폴더                             ✅ 완료
STEP 10 알림 + Google Calendar 연동 (선택적)               ✅ 완료
─────── Phase 2 완료 ───────
STEP 11 AI 연동 (BYOK: Claude / OpenAI / Gemini)           ✅ 완료
STEP 12 지도 뷰 (MapKit)                                   ✅ 완료
STEP 13 이미지 첨부 + 내보내기                             ✅ 완료
STEP 14 iOS 홈 위젯 (WidgetKit)                            ✅ 완료
─────── Phase 3 완료 ───────
STEP 15 기획 v0.6 + 오늘 / 여기 근처 기본 뷰                 ✅ 완료
STEP 16 위젯 퀵 캡처 + locolog:// 딥링크                     ✅ 완료
STEP 17 온보딩·빈 화면 카피                                  ✅ 완료
STEP 17b 아이콘 스탬프 (드래그/탭으로 2차 분류)                 ✅ 완료
STEP 18 공유 시트 등 추가 시스템 진입점
STEP 19 Supabase 마이그레이션 적용 (폴더·타입 동기화)
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
  -destination 'platform=iOS Simulator,id=DA48DF67-F5A4-4C8F-A0A0-699E9014C557' \
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
