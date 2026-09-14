# checklist.md

각 스텝이 끝나면 체크하고, 같은 커밋에 이 파일도 포함한다.
`[ ]` 미착수 · `[~]` 진행 중 · `[x]` 완료(검증까지 끝남)

---

## Phase 0 — 토대

### S0.1 문서 뼈대
- [x] `CLAUDE.md` 작성 (영문)
- [x] `PLAN.md` 작성
- [x] `checklist.md` 작성
- [x] `context-notes.md` 작성
- [x] 디렉토리 뼈대 (`docs/`, `Packages/`, `Apps/`)
- [x] `docs/design/README.md` + D1~D6 템플릿 카드
- [ ] **J 확인** — 구조와 로드맵 동의

### S0.2 저장소 초기화
- [x] `git init` (기본 브랜치 `main`)
- [x] Swift/Xcode용 `.gitignore` (시크릿·GoogleService-Info 차단 포함)
- [x] `docs/architecture/naming.md` — 코드네임 / 스토어 이름 분리 규칙
- [x] `scripts/check-name.sh` — App Store 중복 확인 (동작 검증 완료)
- [x] 첫 커밋 (Claude 자동 커밋으로 전환)
- [x] 원격 저장소 연결 — `jacobnko/ios-game-portfolio` (**public**), push 자동화
- [x] `Apps/*` gitignore — 게임은 별도 저장소로 분리 (D-011)
- [x] public push 전 시크릿 스캔 통과
- [x] **J 확인** — 코드네임 방침 확정

### S0.3 CoreKit 스캐폴드
- [x] Open Question Q1~Q4 확정 (`context-notes.md` D-005)
- [ ] 최소 배포 타겟 iOS 18.0 반영
- [x] `Package.swift` — 타겟 `CoreKitJuice` / `CoreKitData` / `CoreKitServices`
- [x] 테스트 타겟 2종 (`CoreKitJuiceTests` / `CoreKitDataTests`)
- [x] `swift build` 통과 (5.46s)
- [x] `swift test` 통과 (3 tests)
- [x] 외부 의존성 0 — AdMob은 S1.6, Firebase는 S1.7에서 추가
- [x] `docs/architecture/audio-assets.md` — 효과음·배경음 조달 전략

---

## Phase 1 — CoreKit

### S1.1 Haptics
- [x] `HapticRecipe` — 플랫폼 무관 순수 매핑 (intent → intensity/sharpness/eventCount)
- [x] `HapticEngine` — `.micro` / `.milestone` / `.error`
- [x] `micro` 단계별 상승 (피치 상승과 동기)
- [x] `CoreHaptics` 미지원 기기 → `UIImpactFeedbackGenerator` 폴백
- [x] 엔진 중단·리셋 핸들러 (백그라운드 복귀 후 햅틱 사망 방지)
- [x] `isEnabled` 토글 + `prepare()` / `teardown()`
- [x] 단위 테스트 10종 통과
- [x] iOS 실제 빌드 확인 (에러·경고 0)
- [x] `scripts/verify.sh` — host 테스트 + iOS 빌드 일괄 검증
- [ ] **실기기에서 3종 세기 체감 확인** ← J가 직접. 시뮬레이터는 햅틱이 안 난다

### S1.2 Audio (pitch scaling)
- [ ] one-shot SFX 피치 시프트 재생기
- [ ] 연속 액션 음계 상승 + 시퀀스 리셋 규칙
- [ ] Kenney UI SFX 팩에서 피치 시프트 가능한 원샷 소스 확보 (150ms 이하, 리버브 없음)
- [ ] `AVAudioSession` `.ambient` + `.mixWithOthers` — 사용자 음악 죽이지 않기
- [ ] 설정의 SFX / 햅틱 토글 분리

> **BGM은 보류다 (D-020).** 게임 #1이 완성된 뒤에 넣을지 판단한다.
> 다만 `AVAudioSession` 구성과 볼륨 채널 분리는 지금 해둔다. 나중에 BGM을 끼울 자리만 남기는 것이다.

### S1.3 Victory catharsis
- [ ] 화면 흔들림 modifier
- [ ] 파티클 버스트
- [ ] 점수 배수 표시
- [ ] 4요소 순차 연출 `VictorySequence`
- [ ] Preview 단독 재생 확인

### S1.4 Persistence
- [ ] `GameProgress` `@Model`
- [ ] 전 프로퍼티 optional 또는 기본값, `@Attribute(.unique)` 없음
- [ ] `ModelConfiguration(cloudKitDatabase: .automatic)`
- [ ] 삭제 → 재설치 복원 실기기 확인

### S1.5 StoreKit 2
- [ ] `PurchaseManager` (fetch → purchase → verify → finish)
- [ ] `adsRemoved`를 `Transaction.currentEntitlements`에서만 파생
- [ ] Restore Purchases 동작
- [ ] StoreKit Configuration 파일로 시나리오 테스트

### S1.6 AdMob
- [ ] 배너 — `Coordinator` 단일 인스턴스 재사용
- [ ] 부모 state 변경 시 리로드/깜빡임 없음 확인
- [ ] 전면 광고
- [ ] 보상형 광고
- [ ] ATT 프롬프트 플로우
- [ ] 테스트 Ad Unit ID가 기본값인지 확인
- [ ] 모든 광고 호출부가 단일 `adsRemoved` 게이트 뒤에 있음

### S1.7 Analytics
- [ ] `AnalyticsReporting` 프로토콜
- [ ] Firebase Analytics 어댑터
- [ ] Crashlytics 연결
- [ ] 공통 이벤트 스키마 문서화 (`docs/architecture/analytics-events.md`)

### S1.8 Localization & Theme
- [ ] `.xcstrings` 규약 + 공통 키 세트
- [ ] 시스템 설정 언어 딥링크
- [ ] `GameTheme` (팔레트 · 타이포 · 아이콘 스타일 주입)
- [ ] `GameTheme` 교체만으로 외형 전환 확인

---

## Phase 2 — GameTemplate
- [ ] 공통 화면 골격 (Home / Stage Select / Game / Result / Settings)
- [ ] 광고 · 저장 · 분석 훅 지점 고정
- [ ] `docs/architecture/new-game-setup.md`
- [ ] 문서만으로 빈 게임 앱 30분 내 기동 검증

---

## Phase 3 — Game #1

### 디자인 트랙
- [ ] D1 브랜드/팔레트
- [ ] D2 앱 아이콘
- [ ] D3 게임플레이 화면
- [ ] D4 보조 화면
- [ ] D5 Juice/VFX 스펙
- [ ] D6 스토어 에셋

### 구현 트랙
- [ ] S3.1 보드 모델 + 퍼즐 포맷 + 검증기
- [ ] S3.2 그리드 렌더 + 드래그 연결
- [ ] S3.3 승리 판정 + 피치/햅틱 상승 연결
- [ ] S3.4 `VictorySequence` 적용
- [ ] S3.5 광고 연결 (클리어 전면 · 힌트 보상형)
- [ ] S3.6 진행 저장 + CloudKit
- [ ] S3.7 스테이지 30개 이상 + 난이도 곡선
- [ ] S3.8 KO/EN 로컬라이즈, 하드코딩 문자열 0
- [ ] S3.9 **모델 전환 알림 (Opus → Sonnet 5)**

---

## Phase 4 — 릴리즈 파이프라인
- [ ] 심사 리젝 체크리스트 문서
- [ ] 개인정보처리방침 페이지 + 앱 내 링크
- [ ] Small Business Program 신청
- [ ] 실제 Ad Unit ID 교체 절차
- [ ] App Store Connect 등록 절차 문서

---

## Phase 5 — Games #2~10

게임별 항목은 `docs/concepts/game-concepts.md`(비공개)에서 관리한다.

- [ ] #2
- [ ] #3
- [ ] #4
- [ ] #5
- [ ] #6
- [ ] #7
- [ ] #8
- [ ] #9
- [ ] #10
