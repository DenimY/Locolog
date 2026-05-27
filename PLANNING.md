# Locolog — 기획서 v0.5

> 날짜·위치 자동 태깅 기반의 스마트 메모 앱  
> **"무지성으로 던져도 자동 정리되는 메모장"**

---

## 1. 앱 개요

| 항목 | 내용 |
|---|---|
| 앱 이름 | **Locolog** |
| 플랫폼 | **iOS + macOS** (SwiftUI Multiplatform 단일 코드베이스) |
| 배포 | App Store (iOS) + Mac App Store (macOS) |
| 핵심 가치 | 메모하면 날짜·장소가 자동으로 붙고, 나중에 찾을 수 있다 |
| 디자인 철학 | 가볍고, 심플하고, 직관적 — Mac 기본 메모 앱처럼 |

> Android는 현재 계획에서 제외. 추후 필요 시 Kotlin Multiplatform(KMM) 또는 React Native로 별도 검토.

---

## 2. 디자인 원칙

### 핵심 3원칙

1. **가볍게 (Lightweight)**
   - 앱 실행 → 메모 시작까지 탭 1회
   - 불필요한 설정, 온보딩, 팝업 최소화
   - OS 내장 API 최대 활용 → 서드파티 의존 최소화

2. **심플하게 (Simple)**
   - Mac 기본 메모 앱의 3-패널 레이아웃 참조
   - 아이콘보다 행동이 명확한 레이블 우선
   - 화면 전환 최소화, 모달보다 인라인 편집

3. **직관적으로 (Intuitive)**
   - 처음 쓰는 사람도 설명 없이 사용 가능
   - 날짜·위치는 사용자가 신경 쓸 필요 없이 자동
   - 검색과 필터는 항상 한 번에 접근 가능

### UI 레퍼런스
- **구조**: Apple Notes (사이드바 + 목록 + 에디터 3단 레이아웃)
- **에디터**: Notion / Slack 스타일 마크다운 (코드 블록, 인라인 포맷)
- **캘린더**: 미니멀 히트맵 달력 (GitHub 잔디 스타일)

---

## 3. 핵심 기능 정의

### 3-1. 메모 작성

#### 자동 제목 (Auto-Titling)
- **제목 입력란 없음** — 유저가 작성한 첫 번째 줄을 자동으로 목록 제목으로 표시 (Apple Notes 방식)
- 첫 줄이 비어 있으면 작성 날짜+시각을 제목으로 fallback

#### 자동 저장 (Auto-Save)
- 타이핑할 때마다 SwiftData에 실시간 저장 — 저장 버튼 없음
- 앱 종료, 백그라운드 전환, 뒤로가기 시 데이터 유실 없음
- `onChange(of: content)` 디바운스(0.3s) 후 SwiftData 쓰기

#### 에디터
- **마크다운 기반 에디터**: Markdown 원문 `String` 저장, 뷰어에서 `swift-markdown-ui` 렌더링
- SwiftUI 네이티브 `TextEditor` + 마크다운 툴바 조합 (외부 에디터 라이브러리 불필요)
- 굵게 / 기울임 / 목록 / 체크박스 / 코드 블록 / 인라인 코드
- 이미지 첨부 (Phase 2)

#### 개발자용 코드 입력 툴바 (Input Accessory View)
- iPhone 소프트 키보드 바로 위에 고정되는 한 줄 툴바
- 원터치 삽입 버튼:

  ```
  [```] [{] [}] [(] [)] [[] []] [_] [->] [//] [언어▾]
  ```

- **[언어▾]** 드롭다운: swift / python / javascript / bash / json / sql 선택 → ` ```언어\n\n``` ` 자동 삽입, 커서를 블록 내부로 이동
- macOS에서는 Touch Bar 또는 에디터 상단 툴바로 동일하게 노출

### 3-2. 자동 메타데이터

| 메타데이터 | 수집 시점 | 방식 |
|---|---|---|
| 작성 시각 | 메모 최초 생성 시 | `Date()` 자동 기록, 이후 불변 |
| 위치명 | **포그라운드 + 메모 작성 시점** | CoreLocation → CLGeocoder 역지오코딩 |
| POI명 | 동일 | `CLPlacemark.areasOfInterest[0]` (예: "성수역", "스타벅스 성수점") |
| 위치 좌표 | 동일 | CoreLocation |

**저장 형식 예시**: `locationName = "서울 성동구"`, `locationPOI = "성수역 3번 출구"`

> **⚠️ iOS 위치 권한 전략 (App Store 심사 리스크 방지)**
> - `NSLocationWhenInUseUsageDescription` 만 사용 (When In Use)
> - 백그라운드 위치 수집 없음 — 메모 앱 카테고리에서 Always 권한 요청 시 심사 거절
> - 권한 거부 시 메모 정상 저장, 위치 필드 공란. 수동 입력 가능.
> - CLGeocoder: Apple 서버 사용, 무료, 별도 API 키 불필요

> **⚠️ macOS 위치 특이사항 (Sandbox 환경)**
> - macOS는 GPS 없음, Wi-Fi 기반 위치 (정확도 낮음, 첫 실행 시 5~10초 딜레이 가능)
> - 에디터 진입 시 상단에 소형 위치 로딩 인디케이터 표시
> - 실패/타임아웃(10초) 시 → "최근 사용한 장소" 목록 또는 "장소 수동 입력" 팝업으로 자연 전환
> - Mac App Store 출시 시 `com.apple.security.personal-information.location` entitlement 필수

### 3-3. 카테고리 & 태그
- 사용자 정의 카테고리 (폴더 구조, 색상 지정)
- 해시태그 자동 인식 (`#태그`)
- 기본: 전체 / 미분류

### 3-4. 캘린더 뷰
- 월간 캘린더에서 메모 작성일 시각화 (히트맵)
- 날짜 탭 → 해당일 메모 목록
- SwiftUI 커스텀 컴포넌트

### 3-5. 검색 & 필터 + 스마트 폴더

#### 기본 검색 & 필터
- 전문 검색 (내용, POI명, 태그 통합)
- 필터 조합: 날짜 범위 + 위치 + 카테고리 + 태그
- 최근 검색어 저장

#### 스마트 폴더 (Smart Folders)
- 필터 조합을 이름 붙여 저장 → 사이드바에 카테고리와 동일 레벨로 고정
- 예: `[카테고리: 개발] + [위치: 강남구]` → "강남 작업실 코드"
- 조건에 맞는 메모가 자동으로 해당 폴더에 집계 (실제 이동 아님, 가상 필터)
- `SmartFolder` 모델에 필터 조건을 JSON 직렬화하여 저장

### 3-6. 알림 & 캘린더 연동

#### 로컬 알림 (기본)
- 메모 작성 시 선택적 알림 설정 (`UserNotifications`)
- `reminder_at`은 앱 내부 DB에만 저장, 외부 캘린더와 무관
- 반복 알림 지원

#### 기기 간 알림 동기화
- 앱 실행/포그라운드 복귀 시 Supabase `reminder_at` vs 로컬 `UNUserNotificationCenter` 예약 목록 비교
- 누락된 알림 자동 재등록 (SyncManager가 처리)
- **macOS**: iPhone에서 등록된 `reminder_at`이 Mac으로 동기화될 때, Mac 앱 포그라운드 복귀 시 `UNUserNotificationCenter`에 Mac 알림 센터 예약 스케줄러 실행

#### 위치 기반 리마인더 (포그라운드 지오펜싱)
- 메모에 "장소 도착 시 알림" 설정 가능 (특정 좌표 + 반경 지정)
- 구현 방식: 앱 포그라운드 복귀 시 현재 위치 vs 저장된 리마인더 위치 비교 (반경 500m 이내 → 알림)
- **Always 권한 불필요** → `When In Use` 유지, App Store 심사 안전
- 진짜 백그라운드 지오펜싱 아님 — "도착해서 앱 열면 알림"에 해당

#### Google Calendar 연동 (완전 선택적)

```
기본: reminder_at → 앱 DB + 로컬 푸시 알림만
선택: 유저가 특정 메모에서 "Google Calendar에 추가" → 해당 메모만 이벤트 생성
```

| 상황 | 동작 |
|---|---|
| 기본 | 앱 DB + 로컬 알림 |
| 유저가 설정 > "Google 캘린더 연동" 토글 ON | 그 시점에 `calendar.events` scope Incremental Auth 팝업 |
| 특정 메모에서 "캘린더에 추가" 선택 | Google Calendar API로 이벤트 생성 |
| 토글 OFF | 이후 연동 중단 (기존 이벤트 유지) |

### 3-7. AI 기능 _(선택 사항 — 사용자 API 키 필요)_
- 설정 > AI 연동에서 활성화
- 지원 모델: **Claude (Anthropic)**, **OpenAI GPT**, **Google Gemini**
- 기능: 메모 자동 요약 / 카테고리 분류 제안 / 관련 메모 추천
- **AI 없이도 모든 기본 기능 완전 동작**
- API 키는 기기 Keychain에만 저장, 서버 미보관
- Supabase Edge Function을 통해 AI API 중계 (BYOK 방식)

### 3-8. 기기 간 동기화
- Google / Apple 로그인 → iPhone ↔ Mac 실시간 동기화 (Supabase Realtime)
- 오프라인 작성 후 온라인 복귀 시 `isDirty = true` 메모만 `upsert` 동기화
- 로그인 없이 로컬 전용 사용 가능 (SwiftData)
- 충돌 해결: `updated_at` 기준 Last-write-wins, 충돌 감지 시 사용자 선택

---

## 4. 로그인 & 계정

> **⚠️ App Store Guideline 4.0 방어 — 온보딩 구조**
>
> Apple은 타사 소셜 로그인을 온보딩 전면에 강제 배치하는 것을 거절 사유로 봄.  
> **"로컬로 시작"을 가장 크게, 소셜 로그인은 동기화 필요 시점에 유도.**

### 온보딩 플로우
```
앱 최초 실행
    │
    ▼
온보딩 슬라이드 (2~3장, 스킵 가능)
    │
    ▼
┌─────────────────────────────┐
│  로컬로 시작하기             │  ← 가장 크게, 기본 버튼
│  (로그인 없이 바로 사용)     │
├─────────────────────────────┤
│  계정으로 시작하기 (동기화)  │  ← 보조 버튼
│  → Apple로 로그인            │
│  → Google로 로그인           │
└─────────────────────────────┘
```

### 계정 연동 (설정 > 계정)
```
설정 > 계정 및 동기화
    ├── Apple로 로그인하여 동기화   (동등한 위계)
    └── Google로 로그인하여 동기화  (동등한 위계)
```

| 항목 | 내용 |
|---|---|
| 비로그인 | 로컬 전용 (SwiftData, 동기화 없음) — **기본 시작** |
| Apple 로그인 | Supabase Auth Apple Provider |
| Google 로그인 | Supabase Auth Google Provider |
| calendar.events scope | Google 캘린더 토글 ON 시점에 Incremental Auth로 별도 요청 |
| API 키 | 기기 Keychain 저장 |

---

## 5. 정보 구조 (IA)

```
Locolog
├── 메모 목록 (홈)
│   ├── 전체 메모
│   ├── 카테고리별
│   └── 스마트 폴더 (저장된 필터)
├── 캘린더 뷰
├── 지도 뷰  ← Phase 3
├── 검색 / 필터
└── 설정
    ├── 계정 & 동기화
    │   ├── Apple 로그인
    │   └── Google 로그인
    ├── AI 연동 (Claude / OpenAI / Gemini API 키)
    ├── 알림
    ├── Google 캘린더 연동 (토글)
    ├── 내보내기 (Markdown, PDF)
    └── 오픈소스 라이센스
```

---

## 6. 화면 목록 & UX 흐름

| 화면 | 레이아웃 | 주요 액션 |
|---|---|---|
| **온보딩** | 슬라이드 2~3장 → 로컬 시작 / 계정 연결 | "로컬로 시작" 기본 |
| **메모 목록** | 3단 (Mac) / 2단 (iPhone) NavigationSplitView | 새 메모, 카테고리·스마트폴더 이동 |
| **메모 에디터** | TextEditor + 코드 툴바(Input Accessory) + 하단 메타데이터 바 | 작성, 포맷팅, 위치/알림 확인 |
| **캘린더 뷰** | 상단 히트맵 달력 + 하단 메모 목록 | 날짜 선택 |
| **지도 뷰** | MapKit + 위치 클러스터 핀 | 위치 선택, 메모 보기 |
| **검색** | 검색 바 + 필터 칩 + 스마트폴더 저장 | 검색, 필터 조합, 폴더 저장 |
| **설정** | Form 기반 그룹 목록 | 계정, AI, 캘린더 연동 |

### 메모 에디터 레이아웃 상세 (iPhone)
```
┌──────────────────────────────────────┐
│  ← 뒤로                              │  ← 네비게이션 바
├──────────────────────────────────────┤
│                                      │
│  오늘 배운 것                         │  ← 첫 줄이 자동 제목 (목록에 표시)
│                                      │
│  ```python                           │  ← 코드 블록 (Highlightr 렌더링)
│  def hello():                        │
│      print("world")                  │
│  ```                                 │
│                                      │
│  #개발 #python                       │  ← 해시태그 자동 인식
│                                      │
│  📍 성수역 3번 출구 · 서울 성동구    │  ← 자동 위치 (POI + 주소)
│  🕐 2026.05.27  14:32               │  ← 자동 시각
│                                      │
├──────────────────────────────────────┤
│ B  I  •—  ☑  [```] {  }  [  ]  _ // ▾│  ← Input Accessory View (코드 툴바)
├──────────────────────────────────────┤
│         [ 소프트 키보드 ]             │
└──────────────────────────────────────┘
```

### macOS 레이아웃 (NavigationSplitView)
```
┌──────────┬───────────────┬──────────────────────────┐
│ 사이드바  │   메모 목록    │        에디터             │
│          │               │                          │
│ 전체     │  2026.05.27   │  오늘 배운 것             │
│ 카테고리1 │  성수역 근처   │                          │
│ 카테고리2 │               │  ```python               │
│          │  2026.05.26   │  def hello():            │
│ ─────── │  강남 작업실   │      print("world")      │
│ [스마트] │               │  ```                     │
│ 강남코드 │  ...          │                          │
│ ─────── │               │  📍 성수역 3번 출구       │
│ [캘린더] │               │  🕐 2026.05.27  14:32   │
│ [지도]   │               │                          │
│ [설정]   │               │  ── 마크다운 툴바 ──      │
└──────────┴───────────────┴──────────────────────────┘
```

### iPhone Tab Bar
```
[메모] [캘린더] [검색] [설정]
```

---

## 7. 데이터 모델

### 로컬 (SwiftData)

```swift
@Model class Note {
    var id: UUID
    var content: String           // Markdown 원문
    var categoryId: UUID?
    var createdAt: Date           // 불변 (최초 생성 시각)
    var updatedAt: Date
    var locationLat: Double?
    var locationLng: Double?
    var locationName: String?     // 예: "서울 성동구"
    var locationPOI: String?      // 예: "성수역 3번 출구"  ← POI 추가
    var reminderAt: Date?
    var reminderLocationLat: Double?  // 위치 기반 리마인더용
    var reminderLocationLng: Double?
    var isDeleted: Bool
    var isDirty: Bool             // 동기화 대기 여부  ← 오프라인 동기화
    var tags: [Tag]
}

enum SyncStatus { case synced, pending, conflict }

@Model class Category {
    var id: UUID
    var name: String
    var color: String
    var icon: String?
    var position: Int
}

@Model class Tag {
    var id: UUID
    var name: String
}

@Model class SmartFolder {          // 스마트 폴더  ← 신규
    var id: UUID
    var name: String
    var filterJSON: String          // 필터 조건 JSON 직렬화
    var position: Int
}
```

> **isDirty 동기화 전략**
> 1. 오프라인에서 메모 작성/수정 → `isDirty = true`
> 2. 네트워크 복귀 감지 (NWPathMonitor)
> 3. SyncManager가 `isDirty == true` 메모 수집
> 4. Supabase `upsert` (updated_at 기준 충돌 감지)
> 5. 성공 시 `isDirty = false`

### 원격 (Supabase PostgreSQL)

```sql
notes
  id                    uuid  PK
  user_id               uuid  FK → auth.users
  content               text              -- Markdown 원문
  category_id           uuid  nullable
  created_at            timestamptz       -- 불변
  updated_at            timestamptz
  location_lat          float8  nullable
  location_lng          float8  nullable
  location_name         text    nullable
  location_poi          text    nullable  -- POI명
  reminder_at           timestamptz nullable
  reminder_location_lat float8  nullable  -- 위치 기반 리마인더
  reminder_location_lng float8  nullable
  is_deleted            bool    default false

categories
  id, user_id, name, color, icon, position

tags
  id, user_id, name

note_tags
  note_id, tag_id  PRIMARY KEY

smart_folders
  id, user_id, name, filter_json, position
```

**인덱스**
- `notes(user_id, created_at DESC)`
- `notes(user_id, location_name)`, `notes(user_id, location_poi)`
- `pg_trgm` 확장으로 content Full-text search

---

## 8. 서버 구조

```
iPhone / Mac (SwiftUI)
    │
    │  HTTPS + WebSocket
    ▼
┌────────────────────────────────────┐
│            Supabase                │
│                                    │
│  Auth ── Apple Sign-In             │
│          Google OAuth              │
│                                    │
│  PostgreSQL ── notes               │
│                categories          │
│                tags / smart_folders│
│                                    │
│  Realtime ── iPhone ↔ Mac 동기화   │
│              (isDirty 기반 upsert) │
│                                    │
│  Storage ── 이미지 첨부 (Phase 2)  │
│                                    │
│  Edge Functions                    │
│    └── /ai-proxy  AI API 중계      │
└────────────────────────────────────┘
         │ (유저 선택 시에만)
         ▼
┌──────────────────────┐
│  Google Calendar API │
└──────────────────────┘
```

---

## 9. 지도 뷰 전략

- **MapKit** (Apple Maps) 사용 — OS 내장, 추가 패키지·비용 없음
- SwiftUI `Map` 컴포넌트로 위치 핀 클러스터링
- Phase 3 구현 예정

---

## 10. 개발 순서도 (Phase별 STEP)

### Phase 1 — iOS MVP _(써볼 수 있는 최소 앱)_

```
STEP 1  Xcode 프로젝트 세팅
        SwiftUI Multiplatform, SwiftData 모델 정의
        (Note + isDirty, Category, Tag, SmartFolder)
            ↓
STEP 2  메모 에디터 + 자동저장 + 자동제목
        TextEditor + onChange 디바운스 저장
        첫 줄 자동 제목 추출 → 목록 표시
            ↓
STEP 3  개발자 코드 툴바 (Input Accessory View)
        키보드 위 툴바: 백틱, 특수문자, 언어 선택 드롭다운
        Highlightr 코드 블록 렌더링
            ↓
STEP 4  위치 자동 태깅 + POI 매칭
        CoreLocation (When In Use)
        CLGeocoder → areasOfInterest + 주소 저장
        macOS: 로딩 인디케이터 + 실패 시 수동 입력 fallback
            ↓
STEP 5  메모 목록 + 카테고리
        NavigationSplitView (Mac) / Tab Bar (iPhone)
        swift-markdown-ui 렌더링
            ↓
STEP 6  캘린더 뷰
        히트맵 달력, 날짜별 메모 목록
```

### Phase 2 — 로그인 & 동기화

```
STEP 7  Supabase 연동 + 로그인
        온보딩: "로컬로 시작" 우선
        Apple / Google 로그인 (설정에서 동등 위계)
            ↓
STEP 8  오프라인-온라인 동기화 (SyncManager)
        NWPathMonitor → isDirty 메모 upsert
        기기 간 알림 재등록 트리거
        macOS 알림 센터 스케줄러
            ↓
STEP 9  고급 필터 + 스마트 폴더
        날짜/위치/카테고리/태그 복합 필터
        SmartFolder 저장 → 사이드바 고정
            ↓
STEP 10 알림 + Google Calendar 연동
        UserNotifications, 위치 기반 리마인더
        Google Calendar Incremental Auth + 이벤트 내보내기
        Supabase 웨이크업 봇 (GitHub Actions)
```

### Phase 3 — 고급 기능

```
STEP 11 AI 연동 (BYOK)
        Claude / OpenAI / Gemini
        요약, 분류 제안, 관련 메모 추천
            ↓
STEP 12 지도 뷰
        MapKit, POI + 위치별 핀 클러스터
            ↓
STEP 13 이미지 첨부 + 내보내기
        Supabase Storage, Markdown / PDF 내보내기
            ↓
STEP 14 iOS 홈 위젯
        WidgetKit: 최근 메모 / 퀵 캡처
```

---

## 11. 경쟁 앱 분석

| 앱 | 강점 | 약점 | Locolog 차별점 |
|---|---|---|---|
| Apple Notes | 네이티브, 무료, 빠름 | 위치 태깅 없음, 필터 약함 | 위치+날짜+POI 자동 정리 |
| Bear | 마크다운, 아름다운 UI | 유료, 위치 없음 | 무료 기본기 + 위치 |
| Notion | 강력한 기능 | 무겁고 복잡 | 빠른 캡처 + 자동 메타데이터 |
| Joplin | 오픈소스, E2E 암호화 | UI 복잡, 위치 없음 | 심플 UI + POI 위치 |
| GeoNotes | 위치 특화 | Android만, 기능 단순 | 마크다운 + 캘린더 + 스마트폴더 |

**핵심 차별화**: 위치·POI·날짜 자동 태깅 + 캘린더 뷰 + 스마트 폴더 + 네이티브 UI

---

## 12. 비용 & 라이센스 주의사항

| 항목 | 상태 | 내용 |
|---|---|---|
| **Supabase 무료 티어 일시정지** | ⚠️ 심각 | 7일 비활성 시 자동 정지 → 심사관 접속 시 먹통 → Guideline 2.1 거절. 심사 기간 GitHub Actions 웨이크업 봇 또는 Pro($25/월) 필수 |
| **온보딩 소셜 로그인 강제 배치** | ⚠️ 심각 | "로컬로 시작"을 기본으로, 소셜 로그인은 설정에서 동등 위계로 제공. 온보딩에서 Google을 강조하면 Guideline 4.0 거절 |
| **Apple Sign-In 필수** | ⚠️ 필수 | 소셜 로그인 제공 시 Apple Login 반드시 포함 |
| **iOS 위치 권한** | ⚠️ 심사 리스크 | `When In Use`만 사용. Always 요청 시 즉시 거절 |
| **macOS 위치 Sandbox** | ⚠️ UX 필요 | Wi-Fi 기반, 딜레이 가능. 로딩 인디케이터 + 수동 입력 fallback 필수 |
| **Google calendar.events scope** | ✅ | 설정에서 토글 ON 시 Incremental Auth. 온보딩/로그인 시 요청 금지 |
| **CLGeocoder** | ✅ | Apple 무료 서버, API 키 불필요 |
| **MapKit** | ✅ | Apple 무료, 별도 라이센스 없음 |
| **Supabase** | Apache-2.0 | 셀프호스팅 가능, 상업 이용 가능 |
| **swift-markdown-ui** | MIT | 상업 앱 배포 가능 |
| **Highlightr** | MIT | 상업 앱 배포 가능 |

---

## 13. 수익화 (추후 검토)

- **무료**: 기본 기능 전체, 로컬 저장, 단일 기기
- **Pro (구독)**: 다기기 동기화, 무제한 저장, 고급 필터
- **AI**: 사용자 직접 API 키 입력 방식 (별도 과금 없음, 완전 선택)

---

*v0.4 → v0.5: 자동제목/자동저장 명세화, POI 장소명 추가, 개발자 코드 툴바 Input Accessory View 명세, 스마트 폴더 추가, isDirty 오프라인 동기화 모델, 온보딩 구조 App Store 방어 전략, macOS Sandbox 위치 예외처리, Google Calendar Incremental Auth, 위치 기반 리마인더(포그라운드 지오펜싱), macOS 알림 스케줄러*  
*최종 수정: 2026-05-27*
