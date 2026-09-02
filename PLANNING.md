# Locolog — 기획서 v0.7

> 날짜·위치 자동 태깅 기반의 스마트 메모 앱  
> **"무지성으로 던져도 자동 정리되는 메모장"**  
> **발길과 날짜가 목차가 되는 메모장**

---

## 1. 앱 개요

| 항목 | 내용 |
|---|---|
| 앱 이름 | **Locolog** |
| 플랫폼 | **iOS + macOS** (SwiftUI Multiplatform 단일 코드베이스) |
| 배포 | App Store (iOS) + Mac App Store (macOS) |
| 한 줄 | 생각난 것을 던지면, 언제·어디서 적었는지로 다시 찾는다 |
| 핵심 가치 | 메모하면 날짜·장소가 자동으로 붙고, 나중에 찾을 수 있다 |
| 디자인 철학 | 가볍고, 심플하고, 직관적 — Mac 기본 메모 앱처럼 |

Locolog는 Apple Notes를 대체하는 두 번째 뇌가 아니다. Notion·Obsidian 같은 워크스페이스·PKM·위키도 아니다. **시간과 장소가 정리의 축인 생각 로그**다.

### 왜 이 앱인가

분류를 잘 안 하는 사람이, 적은 **장소**로 다시 찾게 하려고 만들었다. 회사에서 적은 것은 회의록이 되고, 마트에서 적은 것은 장보기가 되고, 집에서 적은 것은 메모지가 된다. 장소가 1차 분류다.

그 안에서 한 번 더 나누고 싶을 때만 폴더 이름을 치지 않는다. **미리 둔 아이콘을 글에 끌어 붙이거나 탭하면** 된다.

> Android는 현재 계획에서 제외. 추후 필요 시 별도 검토.

---

## 2. 디자인 원칙

### 핵심 3원칙

1. **가볍게 (Lightweight)**
   - 앱 실행 → 메모 시작까지 탭 1회 (위젯·공유 시트는 탭 0~1회)
   - 불필요한 설정, 온보딩, 팝업 최소화
   - OS 내장 API 최대 활용 → 서드파티 의존 최소화

2. **심플하게 (Simple)**
   - Mac 기본 메모 앱의 3-패널 레이아웃 참조
   - 아이콘보다 행동이 명확한 레이블 우선 (내비게이션)
   - **분류만은 예외**: 글자 입력 대신 아이콘 한 번
   - 화면 전환 최소화, 모달보다 인라인 편집
   - **쓰는 순간에 분류를 요구하지 않는다**

3. **직관적으로 (Intuitive)**
   - 처음 쓰는 사람도 설명 없이 사용 가능
   - 날짜·위치는 사용자가 신경 쓸 필요 없이 자동
   - 찾기는 캘린더(언제) / 지도(어디) / 검색(단어)이 동급

### UI 레퍼런스
- **구조**: Apple Notes (사이드바 + 목록 + 에디터 3단)
- **캡처**: Google Keep 위젯 — 앱을 깊게 열지 않고 던지기
- **에디터**: 가벼운 마크다운 (코드 블록, 인라인 포맷). 블록 DB 아님
- **캘린더**: 미니멀 히트맵 (GitHub 잔디 스타일)

### 하지 않는 것 (잠금)

- Notion식 데이터베이스, 템플릿, 슬래시 워크스페이스
- OneNote식 공책·섹션을 **기본 화면**으로 두는 것
- Obsidian 그래프 / 백링크를 전면에
- Evernote식 웹 클리퍼를 핵심 기능으로
- 온보딩에서 폴더·태그 체계를 가르치기
- 세컨드 브레인, PKM, 위키를 제품 언어로 쓰기

---

## 2.5 사용 방식 (핵심 루프)

사람들이 많이 쓰는 메모 앱은 **넣는 순간에 분류하지 않고**, 나중에 찾는다. Locolog도 그 습관을 따르되, 정리의 주체는 사용자가 아니라 **시각과 장소**다.

```
던지기 (주로 폰)
    제목·폴더·태그 없이 적고 나간다
    작성 시각·위치가 붙는다
        │
        ▼
찾기 (폰 또는 맥)
    캘린더 — 언제
    지도 / 여기 근처 — 어디
    검색 — 단어
    오늘 — 오늘 던진 것
        │
        ▼
다듬기 (주로 맥)
    폰에서 던진 메모를 펼쳐 고친다
    iPhone ↔ Mac 동기화가 이 루프의 전제
```

**쓰는 순간에 하면 안 되는 것**
- 폴더를 먼저 고르기
- 제목 칸을 채우기
- 태그 체계를 설계하기
- 저장 버튼을 누르기

폴더·`#태그`·스마트폴더는 **나중에 가끔 쓰는 선반**이다. 매일의 정리는 이미 끝난 상태여야 한다.

**한 번 더 나누고 싶을 때**
- 폴더 이름을 입력하지 않는다
- 에디터 상단(또는 하단)의 아이콘을 본문에 드래그하거나, 아이콘을 탭한다
- 프리셋: 회의 · 코드 · 장보기 · 집 · 아이디어. 없으면 그 순간 폴더가 생긴다
- 안 붙여도 장소·날짜로 이미 찾을 수 있다

---

## 3. 핵심 기능 정의

### 3-1. 메모 작성 (던지기)

#### 빠른 진입
- 앱 안: 탭 1회로 빈 메모
- iOS 홈 위젯: **탭하면 새 메모** (최근 목록만 보여주는 위젯이 아님). 중형 위젯은 새 메모 + 최근 몇 개 열기
- 가능하면 공유 시트·제어 센터 등 시스템 진입점 추가
- 생성 시 폴더·제목을 묻지 않는다. 빈 메모가 곧 로그 한 줄이다

#### 자동 제목 (Auto-Titling)
- **제목 입력란 없음** — 첫 번째 줄을 목록 제목으로 (Apple Notes 방식)
- 첫 줄이 비면 작성 날짜+시각으로 fallback

#### 자동 저장 (Auto-Save)
- 저장 버튼 없음. 앱 종료·백그라운드·뒤로가기 시 유실 없음
- **메모리 + `isDirty`: 키 입력 즉시**
- **디스크**: `onChange` 디바운스 0.3초 후 SwiftData 쓰기
- **원격**: 로그인된 경우 약 2초 디바운스 후 push
- 에디터를 떠나거나 백그라운드로 갈 때, 아직 안 쓴 내용만 즉시 flush

#### 에디터
- Markdown 원문 `String` 저장, 뷰어에서 `swift-markdown-ui` 렌더링
- SwiftUI `TextEditor` + 마크다운 툴바
- 굵게 / 기울임 / 목록 / 체크박스 / 코드 블록 / 인라인 코드
- 이미지 첨부는 로컬 저장 (Storage 동기화는 이후)

#### 개발자용 코드 입력 툴바 _(숨은 힘 — 전면 기능 아님)_
- iPhone 키보드 위 한 줄: 백틱, 괄호, 언어 선택
- macOS는 에디터 툴바로 동일 노출
- 처음 연 사람은 이 툴바를 몰라도 “적고 달력에서 다시 본다”만 알면 된다

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
> - 백그라운드 위치 수집 없음 — Always 요청 시 심사 거절
> - 권한 거부 시 메모 정상 저장, 위치 필드 공란. 수동 입력 가능
> - CLGeocoder: Apple 서버, 무료, API 키 불필요

> **⚠️ macOS 위치 특이사항 (Sandbox)**
> - GPS 없음, Wi-Fi 기반. 첫 실행 5~10초 딜레이 가능
> - 에디터 상단 위치 로딩 인디케이터
> - 실패/타임아웃(10초) → 장소 수동 입력
> - Mac App Store: `com.apple.security.personal-information.location` 필수

### 3-3. 폴더 & 태그 _(찾기 보조, 필수 분류 아님)_

- **1차 분류는 장소다.** 회사 / 마트 / 집은 필터·지도·여기 근처로 나뉜다
- **2차 분류는 아이콘 스탬프.** 에디터 상단 독. 드래그하거나 탭 한 번. 글자 입력 아님
- 트리형 폴더 (구 카테고리). 색·아이콘. 스탬프로 생긴 폴더가 사이드바에 나타난다
- 해시태그 자동 인식 (`#태그`). 태그의 소스는 본문 파싱
- 기본 보기: **오늘 / 여기 근처 / 전체**. 폴더는 그 아래
- 빈 화면 카피: “폴더를 만드세요”가 아니라 **“적으면 장소가 목차가 됩니다”**

### 3-4. 캘린더 뷰 _(주 찾기: 언제)_

- 월간 히트맵으로 작성일 시각화
- 날짜 탭 → 해당일 메모 목록
- 기본 제공 뷰 **오늘**과 같은 축 (오늘 = 오늘 작성한 로그)

### 3-5. 지도 · 검색 · 스마트 폴더

#### 지도 _(주 찾기: 어디)_
- MapKit 핀 클러스터
- 기본 제공 뷰 **여기 근처**: 현재 위치 반경(약 1km) 안의 메모
- Always 권한 없이, 앱이 포그라운드일 때 현재 위치와 비교

#### 검색
- 내용, POI, 태그 통합
- 필터: 날짜 범위 + 위치 + 폴더 + 태그
- 최근 검색어 저장

#### 스마트 폴더 _(파워유저, 사이드바 하단)_
- 필터 조합을 이름 붙여 저장. 실제 이동 아님
- 예: `[폴더: 개발] + [위치: 강남구]` → "강남 작업실 코드"
- 사용자가 만들기 **전에** 앱이 오늘/여기를 제공한다

### 3-6. 알림 & 캘린더 연동

#### 로컬 알림
- 메모별 선택 알림 (`UserNotifications`)
- `reminder_at`은 앱 DB. 외부 캘린더와 무관

#### 기기 간 알림
- 동기화 후 `reminder_at` vs 로컬 예약 목록 비교, 누락분 재등록
- Mac: iPhone에서 온 reminder를 포그라운드 복귀 시 알림 센터에 등록

#### 위치 기반 리마인더 (포그라운드)
- Keep식 “그 장소에 가면 떠오름”
- 앱 포그라운드 복귀 시 현재 위치 vs 리마인더 좌표 (반경 500m)
- Always 불필요. 백그라운드 지오펜싱 아님

#### Google Calendar (완전 선택, 이후 작업)
- 기본은 앱 알림만
- 설정에서 토글 ON일 때 `calendar.events` Incremental Auth
- 특정 메모만 “캘린더에 추가”

### 3-7. AI _(설정 안, 숨은 힘)_
- 설정 > AI에서 활성화. BYOK: Claude / OpenAI / Gemini
- 요약 / 분류 제안 / 관련 메모
- **AI 없이도 기본 기능 전부 동작**
- 키는 Keychain만, 서버 미보관

### 3-8. 기기 간 동기화

폰에서 던지고 맥에서 보는 루프의 전제다. 부가 기능이 아니다.

- 로그인 없이 로컬 전용 가능 (기본 시작)
- Apple / Google 로그인 → iPhone ↔ Mac
- 오프라인 수정은 `isDirty`. 네트워크 복귀(NWPathMonitor) 시 dirty만 upsert
- Postgres 변경 → debounce pull (Realtime). **편집 중 dirty 메모는 덮지 않음**
- push 도중 로컬이 더 바뀌면 dirty를 유지 (전송 스냅샷과 비교)
- 충돌 UI 없음. **로컬 dirty 우선**, 아니면 `updated_at` last-write-wins
- 폴더·스마트폴더도 동기화. 노트에 `folder_id`, `note_type`, `is_favorited`, `icon_emoji`
- 첨부·아이콘 **이미지 파일**은 아직 기기 로컬 (Storage는 이후)

---

## 4. 로그인 & 계정

> **⚠️ App Store Guideline 4.0**  
> **"로컬로 시작"을 가장 크게.** 소셜 로그인은 동기화가 필요할 때.

### 온보딩
- 슬라이드 대신(또는 짧게): **던진다 → 달력·지도에서 다시 본다**
- 폴더·태그 설명은 빼기
- 기본 버튼: 로컬로 시작하기
- 보조: Apple / Google로 동기화

### 설정 > 계정
- Apple / Google 동등 위계
- 동기화 상태: 마지막 시각, 오류, 오프라인, 수동 동기화

| 항목 | 내용 |
|---|---|
| 비로그인 | 로컬 전용 — **기본 시작** |
| Apple / Google | Supabase Auth |
| `calendar.events` | 캘린더 토글 ON 때만 |
| API 키 | Keychain |

---

## 5. 정보 구조 (IA)

찾기 축(언제·어디)이 폴더보다 앞에 온다.

```
Locolog
├── 오늘          ← 기본 제공
├── 여기 근처     ← 기본 제공
├── 캘린더        ← 언제
├── 지도          ← 어디
├── 전체 메모
├── 즐겨찾기
├── 폴더 (트리, 선택)
├── 스마트 폴더 (선택)
├── 검색
└── 설정
    ├── 계정 & 동기화
    ├── AI (선택)
    ├── 알림
    ├── Google 캘린더 (선택, 이후)
    ├── 내보내기
    └── 라이센스
```

---

## 6. 화면 목록 & UX 흐름

| 화면 | 레이아웃 | 주요 액션 |
|---|---|---|
| **온보딩** | 던지기 → 달력·지도. 로컬 시작 기본 | 폴더 설명 없음 |
| **오늘 / 여기 / 전체** | 목록. 새 메모는 분류 묻지 않음 | 던지기, 열기 |
| **메모 에디터** | 상단 아이콘 독 + TextEditor + 하단 시각·위치 | 작성, 아이콘으로 나누기, 자동저장 |
| **캘린더** | 히트맵 + 해당일 목록 | 날짜로 찾기 |
| **지도** | MapKit 클러스터 | 장소로 찾기 |
| **검색** | 검색 바 + 필터 칩 | 단어·필터 |
| **설정** | 계정/동기화 상태를 숨기지 않음 | 로그인, 수동 동기화 |

### iPhone Tab Bar
```
[메모] [캘린더] [지도] [검색] [설정]
```
메모 탭 안 상단: **오늘 / 여기 / 전체** 가 폴더 칩보다 앞.

### macOS 사이드바 순서 (위 → 아래)
```
오늘 / 여기 근처 / 캘린더 / 지도 / 전체 / 즐겨찾기
────────
폴더 트리 (선택)
스마트 폴더 (선택)
```

### 메모 에디터 (iPhone) — 제목 칸 없음, 시각·위치는 아래
첫 줄이 목록 제목. **상단 아이콘 독**에서 끌어다 본문에 놓거나 탭하면 분류. 하단 바: POI · 작성 시각 · (붙인 아이콘). 키보드 위 코드 툴바는 개발자용.

---

## 7. 데이터 모델

### 로컬 (SwiftData)

```swift
@Model class Note {
    var id: UUID
    var content: String
    var categoryId: UUID?          // 레거시. 신규는 folderId
    var folderId: UUID?
    var createdAt: Date            // 불변
    var updatedAt: Date
    var locationLat, locationLng: Double?
    var locationName, locationPOI: String?
    var reminderAt: Date?
    var reminderLocationLat, reminderLocationLng: Double?
    var isDeleted, isFavorited, isDirty: Bool
    var attachmentURLs: [String]   // 로컬 파일. 아직 서버 미동기화
    var noteTypeRaw: String        // markdown | log
    var iconEmoji: String?
    var iconImagePath: String?     // 로컬. 이모지만 서버 동기화
    var tags: [Tag]
}

@Model class Folder {
    var id: UUID
    var name: String
    var parentId: UUID?
    var position: Int
    var colorHex, iconEmoji, iconImagePath: String?
}

@Model class Tag { var id: UUID; var name: String }
@Model class SmartFolder { var id: UUID; var name, filterJSON: String; var position: Int }
```

`Category`는 마이그레이션용 레거시. 신규 UI는 Folder만 쓴다.

> **isDirty**
> 1. 로컬 수정 → 즉시 `isDirty = true` (본문은 키 입력 시)
> 2. 디스크 저장은 0.3초 디바운스 또는 화면 이탈 시 flush
> 3. NWPathMonitor / 포그라운드 / Realtime 트리거
> 4. dirty만 upsert. 성공 시에만, **push 시점 스냅샷과 같으면** `isDirty = false`
> 5. pull은 서버가 더 최신이고 로컬이 dirty가 아닐 때만 적용

### 원격 (요지)

```
notes: id, user_id, content, category_id, folder_id, note_type,
       created_at, updated_at, location_*, reminder_at,
       is_deleted, is_favorited, is_public, icon_emoji

folders: id, user_id, name, parent_id, position, color_hex, icon_emoji
smart_folders: id, user_id, name, filter_json, position
```

`note_tags` 테이블은 스키마에 있을 수 있으나 클라이언트는 본문 `#태그`를 소스로 쓴다.

마이그레이션: `supabase/migrations/20260831000000_sync_folders_and_note_fields.sql`

---

## 8. 서버 구조

```
iPhone / Mac
    HTTPS + (Realtime: notes 변경 → debounce pull)
        ▼
Supabase
    Auth (Apple / Google)
    PostgreSQL (notes, folders, smart_folders)
    Realtime publication
    Storage — 이미지 동기화는 이후
    Edge /ai-proxy — BYOK 중계 (선택)
```

---

## 9. 지도 뷰

- MapKit, 위치 있는 메모 핀 클러스터
- 여기 근처 목록과 같은 좌표 데이터

---

## 10. 개발 순서

### Phase 1~3 — 완료
에디터·위치·목록·캘린더·로그인·동기화·필터·알림·AI·지도·첨부·위젯(최근 보기)

### Phase 4 — 사용 루프 완성 (현재)

컨셉을 화면에 맞추는 단계. 기능 나열이 아니라 **던지기 → 찾기**.

```
STEP 15  기획 v0.6 반영 + 오늘 / 여기 근처 기본 뷰
STEP 16  위젯 퀵 캡처 (새 메모) + 기존 메모 열기 (딥링크)
STEP 17  온보딩·빈 화면 카피
STEP 17b 아이콘 스탬프로 한 번 더 나누기 (드래그/탭)
STEP 18  공유 시트 등 추가 시스템 진입점
STEP 19  Supabase 마이그레이션 적용 (폴더·타입 동기화)
```

### 그다음 (루프가 안정된 뒤)

```
이미지 Storage 동기화
친구 / 팀 공유 UI
Google Calendar 실제 연동
위젯 Lock Screen
App Store 제출
```

---

## 11. 경쟁과 차별

많이 쓰는 앱은 **빨리 넣기**로 이겼고, 진 앱은 **먼저 정리하세요**를 강요했다.

| 앱 | 사람들이 쓰는 방식 | Locolog |
|---|---|---|
| Apple Notes | 기본 앱, 즉시 작성, 검색 | 캡처 속도는 맞추고, **언제·어디 로그**를 더함 |
| Google Keep | 위젯으로 던짐, 위치 알림 | 위젯 던지기 + 장소가 본문의 목차 |
| Samsung Notes | 잠금화면 필기 | 마찰 제로만 참고 (필기 캔버스는 안 함) |
| OneNote | 공책 구조 | 구조를 기본 입구로 두지 않음 |
| Notion | 쓰기 전 설계 | 하지 않음 |
| Evernote | 클리퍼·노트북 | 핵심으로 두지 않음 |
| Bear | `#태그` | 본문 태그는 유지, 전면은 시간·장소 |
| GeoNotes | 위치만 | 마크다운 + 캘린더 + 네이티브 |

**차별**: 위치·POI·날짜가 자동으로 붙고, 캘린더와 지도가 주 찾기인 네이티브 메모.

---

## 12. 비용 & 라이센스

| 항목 | 상태 | 내용 |
|---|---|---|
| Supabase 무료 티어 7일 정지 | ⚠️ | 심사 기간 웨이크업 또는 Pro |
| 온보딩 소셜 로그인 강제 | ⚠️ | 로컬 시작 기본 |
| Apple Sign-In | ⚠️ 필수 | 소셜 제공 시 |
| iOS 위치 | ⚠️ | When In Use만 |
| macOS 위치 | ⚠️ | 인디케이터 + 수동 입력 |
| calendar.events | ✅ | 토글 ON 때만 |
| CLGeocoder / MapKit | ✅ | Apple 무료 |
| supabase-swift, swift-markdown-ui, Highlightr | MIT | 상업 가능 |

---

## 13. 수익화 (추후)

- **무료**: 기본 전체, 로컬, 단일 기기
- **Pro (검토)**: 다기기 동기화
- **AI**: 사용자 키, 별도 과금 없음

---

## 변경 금지 설계

| 결정 | 이유 |
|---|---|
| 위치 `When In Use`만 | Always → 심사 거절 |
| 온보딩 "로컬로 시작" 기본 | Guideline 4.0 |
| Apple Sign-In 포함 | 소셜 로그인 시 필수 |
| `calendar.events`는 토글 ON 때만 | Incremental Auth |
| Markdown 원문 저장 | 가볍고 유지보수 |
| CLGeocoder | API 키·비용 없음 |
| 정리의 축은 시간·장소 | 폴더를 기본 입구로 올리지 않음 |

---

*v0.6 → v0.7: 원점 명시(장소가 1차 분류). 에디터 아이콘 스탬프(드래그/탭)로 2차 분류. 폴더 이름 입력을 요구하지 않음.*  
*최종 수정: 2026-09-02*
