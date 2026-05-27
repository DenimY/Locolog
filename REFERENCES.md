# Locolog — 레퍼런스 앱 조사

> 작성일: 2026-05-27

---

## 주요 오픈소스 노트 앱

### 크로스플랫폼 (iOS/Android + Desktop)

| 앱 | Stars | 스택 | 라이센스 | 링크 |
|---|---|---|---|---|
| **AppFlowy** | 70,800+ | Flutter + Rust | AGPL-3.0 | https://github.com/AppFlowy-IO/AppFlowy |
| **Memos** | 59,200+ | Go + React | MIT | https://github.com/usememos/memos |
| **Joplin** | 55,000+ | Electron/JS | MIT | https://github.com/laurent22/joplin |
| **SiYuan** | 44,100+ | TypeScript + Go | AGPL-3.0 | https://github.com/siyuan-note/siyuan |
| **Logseq** | 37,800+ | Clojure/JS | AGPL-3.0 | https://github.com/logseq/logseq |
| **AFFiNE** | 35,000+ | TypeScript | MIT | https://github.com/toeverything/AFFiNE |
| **Notesnook** | ~10,000+ | TypeScript | GPL-3.0 | https://github.com/streetwriters/notesnook |
| **Standard Notes** | 6,400+ | JS/Node | AGPL-3.0 | https://github.com/standardnotes |

### Flutter 기반 (직접 참고 가능)

| 앱 | Stars | 특징 |
|---|---|---|
| **GitJournal** | 4,100+ | Flutter, Git 동기화, 모바일 우선 |
| **Butterfly** | 1,800+ | Flutter, 드로잉+노트 |

### 위치 기반 (특화 레퍼런스)

| 앱 | 플랫폼 | 특징 |
|---|---|---|
| **GeoNotes** | Android | 위치 태깅, 지도 통합 |
| **TagSpaces** | Desktop | OpenStreetMap 좌표 추출, 태그 기반 |

### 심플 UI 레퍼런스

| 앱 | 특징 |
|---|---|
| **Simplenote** (Automattic) | iOS/Android/macOS, 완전 오픈소스 |
| **Notally** | Android, 미니멀 디자인의 기준점 |
| **Apple Notes** | Mac 기본 메모 - 목표 UI 레퍼런스 |

---

## UI 레퍼런스

- **Apple Notes**: 3-패널 레이아웃 (사이드바 + 목록 + 에디터)
- **Bear**: 태그 기반 사이드바, 마크다운 프리뷰
- **Notion**: 블록 에디터, 슬래시 커맨드
- **Slack**: 코드 포맷팅, 인라인 마크다운

---

## 경쟁 앱 차별화 포인트

우리 앱만의 핵심 차별점:
1. **자동 위치+날짜 메타데이터** — GeoNotes처럼 위치를 주요 기능으로
2. **캘린더 뷰** — 대부분의 앱에 없는 날짜 탐색 UX
3. **심플한 Mac 스타일 UI** — AppFlowy보다 가볍고 단순
4. **선택적 AI** (사용자 API 키) — 강요 없는 AI 기능

---

*최종 수정: 2026-05-27*
