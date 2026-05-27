# Locolog — 기술 스택

> 플랫폼: **iOS + macOS** (SwiftUI Multiplatform)  
> 최종 확정: 2026-05-27

---

## 프레임워크 선택 근거

| 기준 | SwiftUI Multiplatform | 결론 |
|---|---|---|
| iOS + macOS 단일 코드 | ✅ NavigationSplitView 등 적응형 레이아웃 | 채택 |
| Mac Notes 네이티브 느낌 | ✅ OS 렌더러 그대로 사용 | 채택 |
| Android | 현재 계획 없음 → 추후 별도 검토 | 문제없음 |
| OS 내장 API 활용 | CoreLocation, MapKit, EventKit, UserNotifications | 서드파티 의존 최소 |
| App Store 심사 친화성 | ✅ Apple 권장 스택 | 채택 |

---

## 클라이언트 스택

### 코어

| 역할 | 기술 | 비고 |
|---|---|---|
| UI 프레임워크 | **SwiftUI** | iOS 17+ / macOS 14+ 타겟 |
| 데이터 모델 | **SwiftData** | Core Data 후속, iOS 17+, `@Model` 매크로 |
| 아키텍처 | **MVVM** + SwiftData `@Query` | SwiftUI 네이티브 패턴 |
| 비동기 처리 | **Swift Concurrency** (`async/await`, `Actor`) | 별도 라이브러리 불필요 |
| 라우팅 | **NavigationSplitView** / **NavigationStack** | SwiftUI 내장 |

### 기능별 API / 패키지

| 역할 | 기술 | 라이센스 | 비용 |
|---|---|---|---|
| 위치 | **CoreLocation** (OS 내장) | Apple | 무료 |
| 역지오코딩 | **CLGeocoder** (OS 내장) | Apple | 무료, API 키 불필요 |
| 지도 | **MapKit** / SwiftUI `Map` (OS 내장) | Apple | 무료 |
| 알림 | **UserNotifications** (OS 내장) | Apple | 무료 |
| 캘린더 연동 | **Google Calendar REST API** (선택적) | Google ToS | 무료 쿼터 내 |
| 마크다운 렌더링 | **swift-markdown-ui** | MIT | 무료 |
| 코드 하이라이팅 | **Highlightr** | MIT | 무료 |
| Supabase 연동 | **supabase-swift** | MIT | 무료 |
| API 키 보관 | **Keychain** (OS 내장) | Apple | 무료 |

### 패키지 목록 (Swift Package Manager)

```
swift-markdown-ui   — MIT   — 마크다운 렌더링
Highlightr          — MIT   — 코드 문법 강조
supabase-swift      — MIT   — Auth / DB / Realtime / Storage
```

> 총 외부 패키지 3개. 나머지는 전부 Apple OS 내장 API.

---

## 서버 스택 (Supabase)

| 역할 | 기술 | 비용 |
|---|---|---|
| 인증 | **Supabase Auth** (Google OAuth + Apple Sign-In) | 무료 (50K MAU까지) |
| 데이터베이스 | **PostgreSQL** | 무료 (500MB까지) |
| 실시간 동기화 | **Supabase Realtime** | 무료 (200 동시 접속까지) |
| 파일 저장 | **Supabase Storage** | 무료 (1GB까지) |
| 서버리스 함수 | **Edge Functions** (Deno/TypeScript) | 무료 (500K 호출/월) |

### Edge Functions 역할

| 함수 | 역할 |
|---|---|
| `/geocode` | OSM Nominatim 호출 + DB 캐싱 (CLGeocoder 보조용, 필요 시) |
| `/ai-proxy` | 사용자 API 키 헤더 수신 → Claude / OpenAI / Gemini 중계 |

---

## 전체 아키텍처

```
┌───────────────────────────────────────────────┐
│           SwiftUI Multiplatform 앱             │
│                                               │
│  iPhone                        Mac            │
│  ┌─────────────────┐  ┌──────────────────┐   │
│  │  Tab Bar        │  │ NavigationSplit   │   │
│  │  [메모][캘린더] │  │ 사이드바+목록+에디터│  │
│  │  [검색][설정]   │  └──────────────────┘   │
│  └─────────────────┘                          │
│                                               │
│  SwiftData (로컬, 오프라인 우선)               │
│  CoreLocation + CLGeocoder (위치)             │
│  UserNotifications (로컬 알림)                │
│  MapKit (지도, Phase 3)                       │
│  Keychain (API 키 보관)                       │
└───────────────────┬───────────────────────────┘
                    │  HTTPS / WebSocket
          ┌─────────▼────────────┐
          │      Supabase        │
          │  Auth (Google+Apple) │
          │  PostgreSQL          │
          │  Realtime            │
          │  Storage             │
          │  Edge Functions      │
          │   └ /ai-proxy        │
          └──────────────────────┘
                    │
          ┌─────────▼──────────────────┐
          │  Google Calendar API       │
          │  (유저 선택 시에만 호출)    │
          └────────────────────────────┘
```

---

## 개발 환경

| 항목 | 내용 |
|---|---|
| IDE | **Xcode 16+** |
| 언어 | **Swift 6** |
| 최소 배포 타겟 | iOS 17 / macOS 14 |
| 패키지 관리 | **Swift Package Manager (SPM)** |
| 로컬 서버 | Supabase CLI + Docker (개발용) |
| CI | GitHub Actions |

```bash
# Supabase CLI 설치
brew install supabase/tap/supabase

# 로컬 Supabase 실행
supabase init
supabase start   # Docker 필요

# Xcode 프로젝트 생성
# File > New > Project > Multiplatform > App
# Bundle ID: com.locolog.app
# Targets: iOS + macOS
```

---

## 라이센스 & 비용 주의사항

| 항목 | 상태 | 내용 |
|---|---|---|
| swift-markdown-ui | ✅ MIT | 상업 배포 가능 |
| Highlightr | ✅ MIT | 상업 배포 가능 |
| supabase-swift | ✅ MIT | 상업 배포 가능 |
| Supabase 무료 티어 | ⚠️ 주의 | 7일 비활성 시 자동 정지 → 심사 기간 웨이크업 봇 필수 |
| Apple Sign-In | ⚠️ 필수 | 소셜 로그인 제공 시 App Store 정책상 의무 |
| iOS 위치 권한 | ⚠️ 주의 | `When In Use`만 사용. Always 요청 시 심사 거절 |
| Google Calendar API | ✅ | 유저 명시적 동의 후 사용, 무료 쿼터 충분 |
| CLGeocoder | ✅ | Apple 무료, 앱 내 직접 호출 가능 |
| MapKit | ✅ | Apple 무료, 별도 라이센스 없음 |

---

*최종 수정: 2026-05-27*
