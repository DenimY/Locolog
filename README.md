# Locolog

> 무지성으로 던져도 날짜와 장소로 자동 정리되는 스마트 메모 앱

메모를 작성하는 순간 **날짜·위치(POI)가 자동으로 태깅**되고, 캘린더와 필터로 언제 어디서 썼는지 바로 찾을 수 있습니다. 개발자를 위한 코드 블록 하이라이팅과 스마트 폴더(저장된 필터)까지 갖춘 iOS + macOS 네이티브 메모 앱입니다.

---

## 주요 기능

| 기능 | 설명 |
|---|---|
| **자동 메타데이터** | 메모 저장 시 날짜·시각·위치(주소 + POI명)를 자동 기록 |
| **자동 제목** | 첫 번째 줄이 목록 제목으로 자동 추출 (입력 불필요) |
| **자동 저장** | 타이핑할 때마다 로컬에 실시간 저장 (저장 버튼 없음) |
| **마크다운 에디터** | 편집 모드 ↔ 미리보기 모드 전환, 문법 강조 렌더링 |
| **코드 블록** | Highlightr 기반 문법 강조, 다크/라이트 테마 자동 전환 |
| **코드 입력 툴바** | iPhone 키보드 위 특수문자 원터치 입력 (백틱, 괄호, 언어 선택) |
| **캘린더 뷰** | 히트맵 달력으로 날짜별 메모 기록 확인 |
| **스마트 폴더** | 필터 조건(위치+카테고리+태그)을 저장해 사이드바에 고정 |
| **AI 연동** | Claude / OpenAI / Gemini (사용자 API 키, 완전 선택 사항) |
| **Google Calendar** | 특정 메모를 선택적으로 캘린더에 내보내기 (Phase 2) |
| **멀티 디바이스 동기화** | Supabase Realtime 기반 iPhone ↔ Mac 실시간 동기화 (Phase 2) |

---

## 기술 스택

| 역할 | 기술 |
|---|---|
| UI | SwiftUI Multiplatform (iOS 17+ / macOS 14+) |
| 로컬 저장 | SwiftData |
| 서버 | Supabase (Auth · PostgreSQL · Realtime · Storage) |
| 마크다운 렌더링 | [swift-markdown-ui](https://github.com/gonzalezreal/swift-markdown-ui) |
| 코드 하이라이팅 | [Highlightr](https://github.com/raspu/Highlightr) |
| 인증 · 동기화 SDK | [supabase-swift](https://github.com/supabase/supabase-swift) |
| 위치 · 지도 | CoreLocation · CLGeocoder · MapKit (Apple 내장) |
| 패키지 관리 | Swift Package Manager |
| 프로젝트 생성 | [xcodegen](https://github.com/yonaskolb/XcodeGen) |

---

## 개발 환경 요구사항

| 항목 | 버전 |
|---|---|
| Xcode | 16.0 이상 |
| Swift | 6.0 |
| iOS 배포 타겟 | 17.0 이상 |
| macOS 배포 타겟 | 14.0 이상 |

---

## 빌드 & 실행

### 1. 저장소 클론

```bash
git clone https://github.com/DenimY/Locolog.git
cd Locolog
```

### 2. Xcode 프로젝트 열기

```bash
open Locolog.xcodeproj
```

Xcode가 열리면 SPM이 자동으로 패키지 3개를 다운로드합니다 (1~3분 소요).

### 3. 실행

| 플랫폼 | 방법 |
|---|---|
| iPhone 시뮬레이터 | 타겟 `Locolog (iOS)` → 시뮬레이터 선택 → `Cmd+R` |
| 실기기 | Apple Developer 계정 로그인 후 기기 선택 → `Cmd+R` |
| Mac | 타겟 `Locolog (macOS)` → `Cmd+R` |

### 4. CLI 빌드 확인

```bash
xcodebuild \
  -project Locolog.xcodeproj \
  -scheme Locolog_iOS \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  -configuration Debug build 2>&1 \
  | grep -E "error:|BUILD (SUCCEEDED|FAILED)"
```

### 5. 새 파일 추가 후 프로젝트 재생성

터미널로 Swift 파일을 추가한 경우 반드시 실행:

```bash
xcodegen generate
```

---

## 프로젝트 구조

```
Locolog/
├── Locolog.xcodeproj
├── project.yml                xcodegen 스펙
├── PLANNING.md                기획서 v0.5
├── TECH_STACK.md              기술 스택 상세
├── CONTEXT.md                 개발 현황 및 다음 에이전트 인수인계
├── CLAUDE.md                  에이전트 행동 규칙
├── Locolog/
│   ├── Resources/
│   └── Sources/
│       ├── App/               앱 진입점, 레이아웃
│       ├── Core/              Theme, LocationManager
│       ├── Domain/Models/     SwiftData 모델
│       └── Features/          Editor, Notes, Calendar, Search, Settings, Onboarding
├── LocologTests/
└── LocologUITests/
```

---

## 로드맵

### Phase 1 — iOS MVP (진행 중)
- [x] 프로젝트 세팅 (SwiftData 모델, 아키텍처)
- [x] 마크다운 에디터 + 자동저장 + 자동제목
- [x] 코드 블록 문법 강조 (Highlightr)
- [x] 개발자용 코드 입력 툴바
- [x] 위치 자동 태깅 (CoreLocation + CLGeocoder POI)
- [x] iOS NavigationStack 화면 전환
- [ ] 캘린더 뷰 완성
- [ ] 카테고리 관리 UI
- [ ] 스마트 폴더 UI

### Phase 2 — 로그인 & 동기화
- [ ] Google / Apple 로그인 (Supabase Auth)
- [ ] iPhone ↔ Mac 실시간 동기화
- [ ] 오프라인 → 온라인 병합 (isDirty 기반)
- [ ] 알림 + Google Calendar 선택적 연동

### Phase 3 — 고급 기능
- [ ] AI 연동 (Claude / OpenAI / Gemini, BYOK)
- [ ] 지도 뷰 (MapKit)
- [ ] 이미지 첨부, 내보내기
- [ ] iOS 홈 화면 위젯

---

## App Store 심사 주의사항

- **위치 권한**: `When In Use`만. `Always` 요청 시 즉시 거절
- **온보딩**: "로컬로 시작하기" 기본 버튼. 소셜 로그인 강제 배치 금지 (Guideline 4.0)
- **Apple Sign-In**: 소셜 로그인 제공 시 반드시 포함
- **Google Calendar scope**: 설정 토글 ON 시에만 Incremental Auth 요청
- **Supabase 무료 티어**: 7일 비활성 시 자동 정지 → 심사 기간 웨이크업 봇 필요

---

## 라이센스

MIT License © 2026 DenimY
