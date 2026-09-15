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
- [x] `Tools/JuiceLab` 하네스 앱 — 실기기 체감 검증용 (XcodeGen)
- [ ] **실기기에서 3종 세기 체감 확인** ← J가 직접. 시뮬레이터는 햅틱이 안 난다
- [ ] 백그라운드 → 복귀 후에도 햅틱이 살아있는지 확인

### S1.2 Audio (pitch scaling)
- [x] `MusicalScale` — 펜타토닉/메이저, 옥타브 연장, 상한 클램프
- [x] `ToneRecipe` — 주파수·길이·게인·엔벨로프 + 순수 샘플 렌더링
- [x] `PitchedTonePlayer` — AVAudioEngine, 버퍼 캐시, 라우트 변경 복구
- [x] `JuiceSequence` — 연속 액션 카운터 + 타임아웃 리셋 규칙
- [x] `JuiceAudioSession` — `.ambient` + `.mixWithOthers`, 타앱 재생 감지
- [x] SFX 볼륨을 독립 채널로 분리 (BGM 자리 확보)
- [x] **합성 방식 채택 — 외부 SFX 에셋 불필요** (D-026)
- [x] 단위 테스트 22종 추가 (누적 35종)
- [x] `verify.sh` 3단계 전부 통과
- [ ] **실기기에서 음계 상승 체감** ← JuiceLab → Audio
- [ ] **시퀀스 리셋 체감** — 연타하면 올라가고, 쉬었다 누르면 루트로 복귀
- [ ] 다른 앱 음악 틀어놓고 죽지 않는지 확인

> **BGM은 보류다 (D-020).** 게임 #1이 완성된 뒤에 넣을지 판단한다.
> 다만 `AVAudioSession` 구성과 볼륨 채널 분리는 지금 해둔다. 나중에 BGM을 끼울 자리만 남기는 것이다.

### S1.3 Victory catharsis
- [x] `VictoryTimeline` — 레이어별 시작·길이, 스태거 보장
- [x] `ShakeCurve` — 감쇠 진동, **정확히 0으로 복귀**
- [x] `ParticleField` — 시드 결정론적 버스트, 중력, 페이드
- [x] `PopCurve` — 오버슈트 후 정착 (배수 표시)
- [x] `.victorySequence(isPresented:configuration:onFinished:)` 모디파이어
- [x] Canvas 단일 패스 렌더링 (파티클당 View 생성 안 함)
- [x] Reduce Motion 대응 — 흔들림 제거, 파티클 1/3, **연출은 유지**
- [x] 사운드·햅틱 연동 (상승 4단 → 마일스톤)
- [x] 단위 테스트 24종 추가 (누적 59종)
- [x] `verify.sh` 3단계 전부 통과
- [ ] **실기기에서 연출 체감** ← JuiceLab → Victory
- [ ] Reduce Motion 켜고 재생 확인
- [ ] 파티클 300개에서 프레임 저하 없는지 확인

### S1.4 Persistence
- [x] `StageProgress` — 순수 값 타입 + 병합 규칙
- [x] `StageRecord` `@Model` — 전 프로퍼티 기본값, `@Attribute(.unique)` 없음
- [x] `ProgressStore` — `ModelConfiguration(cloudKitDatabase: .automatic)`
- [x] **중복 행 병합·정리** — CloudKit이 유니크를 강제하지 못하는 것에 대한 대응
- [x] 병합 규칙 멱등성·교환법칙 테스트
- [x] `ProgressSummary` — 집계를 저장하지 않고 파생
- [x] 단위 테스트 20종 추가 (누적 79종)
- [x] `docs/architecture/cloudkit-setup.md` — 설정 절차 + 출시 함정
- [x] `verify.sh` 3단계 전부 통과
- [ ] **JuiceLab → Progress에서 중복 병합 동작 확인**
- [ ] 게임 #1에서 iCloud capability 켜고 **삭제 → 재설치 복원** 실기기 확인
- [ ] **출시 직전 CloudKit Console에서 Production 스키마 배포** ← 빠뜨리면 실사용자만 동기화 실패

### S1.5 StoreKit 2
- [x] `StoreClient` 프로토콜 — 테스트 가능한 이음새
- [x] `StoreKitClient` — fetch → purchase → **verify** → finish
- [x] `PurchaseManager` — `adsRemoved`를 `currentEntitlements`에서만 파생
- [x] `Transaction.updates` 리스너 (Ask to Buy·타기기·중단된 결제)
- [x] `.unverified` 거래는 아무것도 부여하지 않음
- [x] `.pending`을 실패로 처리하지 않음
- [x] Restore Purchases — sync 실패해도 엔타이틀먼트 재조회
- [x] `ProductID.removeAds(bundleID:)` 규칙
- [x] `Tools/JuiceLab/JuiceLab.storekit` 설정 파일
- [x] 단위 테스트 16종 추가 (누적 95종)
- [x] `docs/architecture/iap-setup.md`
- [ ] **Xcode → Edit Scheme → Run → Options → StoreKit Configuration 드롭다운 확인** ← 자동 검증 불가 (D-043)
- [ ] JuiceLab → Purchases에서 구매 → `Ads removed: YES`
- [ ] **Debug → StoreKit → Manage Transactions에서 환불 → `no`로 복귀 확인**
- [ ] Ask to Buy 시뮬레이션으로 `pending` 경로 확인

### S1.6 AdMob
- [x] `CoreKitAdsGoogle` 타겟 분리 (SDK가 호스트 테스트를 깨지 않게)
- [x] `AdUnitIDs` — Google 테스트 ID 기본값, production은 플래그 필요
- [x] `AdPolicy` — 초반 유예·최소 간격·최소 클리어·보상형 쿨다운 (순수)
- [x] `InterstitialVerdict` — 왜 안 나왔는지 추적 가능
- [x] `AdPresenting` 프로토콜 + `AdCoordinator` 단일 게이트
- [x] `AdBannerView` — **Coordinator 단일 인스턴스 재사용**
- [x] `AdBannerSlot` — 광고 로드 전에도 높이 확보 (2.3.1 대응)
- [x] `GoogleAdPresenter` — 전면·보상형, continuation 정확히 1회 resume
- [x] `AdSetup` — ATT 먼저, SDK 시작 나중
- [x] 단위 테스트 22종 추가 (누적 117종)
- [x] `docs/architecture/admob-setup.md`
- [x] `verify.sh` 3단계 전부 통과
- [ ] **JuiceLab → Ads에서 배너 깜빡임 없는지 확인** ← 재렌더 카운터가 올라가는 동안
- [ ] 전면·보상형 실제 표시 확인
- [ ] Apply pacing policy 켜고 verdict가 바뀌는지 확인
- [ ] ATT 프롬프트 표시 확인 (앱 삭제 후 재설치 필요)

### S1.7 Analytics
- [x] `AnalyticsEvent` — 이름·파라미터 자동 정규화 (조용한 유실 방지)
- [x] `GameEvent` — 10개 게임 공통 이벤트 12종
- [x] `AnalyticsReporting` / `CrashReporting` 프로토콜
- [x] `AnalyticsHub` — 팬아웃, opt-out 지원
- [x] `ConsoleAnalyticsReporter` — 개발·하네스용
- [x] **`Packages/CoreKitFirebase` 별도 패키지** — Firebase 144MB가 빠른 루프를 오염시키지 않게
- [x] Crashlytics 비치명적 에러 + context
- [x] 단위 테스트 18종 추가 (누적 135종)
- [x] `docs/architecture/analytics-events.md`
- [x] `verify.sh` + `VERIFY_FIREBASE=1` 전부 통과
- [ ] **JuiceLab → Analytics에서 이벤트 페이로드 확인**
- [ ] 게임 #1에서 `GoogleService-Info.plist` 넣고 Firebase 콘솔에 실제 도달 확인
- [ ] DebugView로 실시간 이벤트 확인

### S1.8 Local Notifications (재참여)
- [x] `NotificationPolicy` — 감쇠 사다리 1·3·7·14·30일 (한 달 5회, 매일 금지)
- [x] `NotificationPlanner` — 순수 계획 생성, 결정론적
- [x] **동시 대기 5~6개** — 64개 제한에 애초에 닿지 않음 + `maxPending` 방어
- [x] 조용 시간 — 자정을 넘어 감싸는 구간 처리, 저녁 7시 고정
- [x] 과거 시각 예약 방지 (등록 즉시 발사 버그)
- [x] 앱 열면 사다리 전체 취소 후 오늘부터 재계산
- [x] 테마 3종 — `progress` / `curiosity` / `lossAversion`, **프로모션 테마 없음**
- [x] 문구 로테이션 + 변형 1개짜리 풀도 안전
- [x] 스트릭 만료 경고 (조용 시간이면 포기)
- [x] `requestAuthorizationAfterFirstClear()` — 첫 실행 요청 차단
- [x] `isEnabled` 토글 (4.5.4)
- [x] interval 트리거 사용 (타임존 이동 시 새벽 발사 방지)
- [x] 단위 테스트 20종 추가 (누적 155종)
- [x] `docs/architecture/notifications.md`
- [ ] **JuiceLab → Notifications에서 사다리 미리보기 확인**
- [ ] 권한 요청 흐름 실기기 확인
- [ ] FCM은 보류 (D-052)

### S1.9 Localization & Theme
- [x] `CoreKitUI` 타겟 신설 (Phase 2 공통 화면이 들어올 자리)
- [x] `GameTheme` — 팔레트 · 타이포(패밀리 포함) · 메트릭
- [x] `ThemeColor` 라이트/다크 분리
- [x] `@Environment(\.gameTheme)` 주입
- [x] `theme.victoryConfiguration()` — 승리 연출이 테마 색을 따라감
- [x] `Common.xcstrings` — 공통 키 26종, en/ko
- [x] `CommonStrings` + 카탈로그 데이터 검증 테스트 (누락·고아 키)
- [x] `Package.swift`에 `defaultLocalization` (없으면 리소스 미처리)
- [x] `LanguageSettings` — 시스템 설정 딥링크, `AppleLanguages` 미조작
- [x] 지원 언어 7종 + 출시 세트(en/ko) 정의
- [x] 단위 테스트 16종 추가 (누적 171종)
- [x] `docs/architecture/localization-and-theme.md`
- [x] `verify.sh` 3단계 전부 통과
- [ ] **JuiceLab → Theme에서 3개 테마 전환 확인**
- [ ] 다크 모드로 전환해서 세 테마 모두 성립하는지
- [ ] 언어 버튼 → 설정 앱 이동 확인

---

## Phase 1.5 — 감사 (모델 전환 전)
- [x] 구현 전체 재검토, 결함 7건 수정 (`context-notes.md` B-01~B-07)
- [x] 회귀 테스트 4종 추가
- [x] **2차 감사** — 결함 6건 추가 수정 (B-08~B-13), 회귀 테스트 6종 (누적 181종)
- [x] 위험 패턴 스캔 — `try!`·`fatalError`·강제 언래핑·`DispatchQueue` 전무
- [x] **3차 감사 (방법 변경)** — 커버리지 실측·경고 승격·정적 분석·테스트 감사·시뮬레이터 실행
- [x] 결함 2건 추가 수정 (B-14·B-15), 테스트 26종 추가 (누적 207종)
- [x] 커버리지 60.5% → **68.2%** (잔여 0%는 전부 기기 전용 계층)
- [x] `verify.sh`가 산출물 Info.plist 필수 키 검사
- [x] Sendable 경고 0
- [x] `verify.sh` + `VERIFY_FIREBASE=1` 전부 통과
- [ ] **J 기기 확인** — `docs/DEVICE-TEST.md` (60여 항목, 🔴 표시가 필수)

## Phase 2 — GameTemplate

### S2.1 공통 화면 골격
- [x] `GameRoute` / `StageOutcome` — 5화면 라우팅 모델
- [x] `StageDescriptor` 프로토콜 — 스테이지 데이터는 게임이 정의
- [x] `GameFlowCoordinator` — 네비게이션 + 진행도·구매·광고·분석 연결
- [x] `HomeView` / `StageSelectView` / `ResultView` / `SettingsView` — `CoreKitUI` 재사용 뷰 (A안)
- [x] 로고·배너는 슬롯(ViewBuilder)으로 주입 — `CoreKitUI`가 `CoreKitAdsGoogle`에 의존하지 않음
- [x] **전면 광고는 `completeStage`가 아니라 `advanceFromResult`에서만** — 승리 연출 보호
- [x] `retryStage` — 실패 후 재시도, funnel에 새 attempt로 기록
- [x] 저장 실패를 크래시 리포팅에 기록 (침묵 스월로우 방지)
- [x] 동시 탭 가드 (`isAdvancing`) — 레이스로 스테이지 스킵되는 버그 재현 후 수정
- [x] 단위 테스트 25종 추가 (누적 231종)
- [x] `FlowLabView` — JuiceLab에 전체 흐름 데모 (Home→StageSelect→Game(stub)→Result)
- [x] `./scripts/audit.sh` 6종 전부 통과
- [x] 시뮬레이터 기동 확인 (스크린샷) — **UI 탭 진행은 MCP 차단으로 미검증**
- [ ] **J 실기기에서 Flow 탭 전체 흐름 확인** (테스트 보류 중)

### S2.2 새 게임 설정 문서
- [x] `docs/architecture/new-game-setup.md` — 저장소 생성부터 5화면 배선까지
- [ ] 실제 게임(Chordline)으로 30분 검증 (Phase 3에서)

### S2.3 코드네임 확정 게이트
- [x] Phase 0에서 이미 확정 (`docs/concepts/game-concepts.md`)
- [x] 10개 전부 프로그램적 재검증 — 번들 ID 중복 없음, 형식 일치, 금지 상표어(Wordle/Picross/Flappy/Flow) 미포함, 홈화면 12자 이하
- [x] Chordline(게임 #1) US App Store 재확인 (2026-09-15) — 동일 이름 없음, 게이트 통과
- [x] **Phase 2 전체 종료**

---

## Phase 3 — Game #1

### 디자인 트랙
- [x] `docs/design/01-chordline/` 폴더 + `00-brief.md` 작성 (게임 컨셉 확정값 반영)
- [x] D1 카드 — Chordline 전용 프롬프트 완성, **J가 Claude Design(Opus)에서 실행해야 함**
- [x] D2 카드 — 프롬프트 뼈대 완성, D1 결과값(hex·키워드) 채우는 자리만 남음
- [x] D1 실제 실행 → 팔레트 표 채우기 → `GameTheme.chordline`에 반영
  - [x] 리드 6종(hex·글리프·텍스처) → `ChordlineCore/SignalLead.swift`
  - [x] 코어 팔레트 · 메트릭 → `ChordlineUI/GameTheme+Chordline.swift`
  - [x] `Color(hex:)` → `CoreKitUI/Color+Hex.swift` (D2 이후 모든 게임이 씀)
  - [x] `palette-ledger.md` 1번 줄 + "2~10번이 피해야 할 것"
  - [ ] Sora / JetBrains Mono `.ttf` 번들 → `ThemeTypography` 패밀리 채우기 (D-078)
  - [ ] **생성기 색 수 > 팔레트 용량 충돌** — S3.7에서 결정 (D-076)
- [ ] D2 실제 실행 → 아이콘 1024 마스터
- [ ] D3 게임플레이 화면 (D1 완료 후)
- [ ] D4 보조 화면
- [ ] D5 Juice/VFX 스펙
- [ ] D6 스토어 에셋
- [ ] D3 게임플레이 화면
- [ ] D4 보조 화면
- [ ] D5 Juice/VFX 스펙
- [ ] D6 스토어 에셋

### 구현 트랙
- [x] S3.1 보드 모델 + 퍼즐 포맷 + **솔버(검증기+생성기)**
  - [x] `Apps/Chordline` 패키지 생성 (별도 저장소 예정, 현재 미백업)
  - [x] `Grid` / `Puzzle` / `ColorPair` — 격자 그림 그대로의 파일 포맷
  - [x] 손 오타 검증 — 짝 없는 글자·짧은 행·미지 문자·빈 격자를 전부 잡음
  - [x] `BoardState` — 되돌리기 버튼 없는 드로잉 규칙 (되짚기·중간 잡기·교차 절단)
  - [x] `Solver` — 해 존재/유일성, 힌트 경로, 노드 예산
  - [x] `PuzzleGenerator` — 답을 먼저 만들고 솔버로 검증
  - [x] `balancedConfiguration` — 색 개수를 넓이에 맞춰 자동 산출
  - [x] **105판 / 0.7초 실측** — S3.7의 100판 목표 달성 가능 확인
  - [x] 테스트 63종, 커버리지 92.6% (솔버 97.5%)
  - [x] `audit.sh`가 게임 패키지도 검사하도록 확장 (7단계)
  - [x] 별도 저장소 생성 및 푸시 — `jacobnko/Chordline-ios-game` (private)
- [x] S3.2 그리드 렌더 + 드래그 연결
  - [x] `BoardLayout` — 좌표 ↔ 화면 변환, `ChordlineCore`에 순수 로직으로 (호스트 테스트 10개)
  - [x] `NodeGlyph`/`LineTexture` → `Path`/`StrokeStyle` (텍스처는 D1 근사치 — D3 목업 나오면 재조정)
  - [x] `GameplayBoardView` — `Canvas` 렌더 + `DragGesture`, `Sources/ChordlineUI/Views/`에 배치
  - [x] `audit.sh` 7단계에 `GAME_DEVICE_ONLY`('UI/Views/') 추가 — `CoreKitUI/Screens` 예외와 같은 이유
  - [ ] **검증은 Xcode Live Preview로** — 아직 실제 앱 프로젝트가 없다. 패키지를 Xcode에서 열고
        `GameplayBoardPreview`를 Live/Interactive Preview로 돌려서 마우스로 드래그해본다.
        점 잡기 → 잇기 → 되짚어 지우기 → 다른 선 가로질러 끊기 → 반대쪽 끝점에서 완성, 다섯 가지 다 확인
- [ ] S3.3 승리 판정 + 피치/햅틱 상승 연결
- [ ] S3.4 `VictorySequence` 적용
- [ ] S3.5 광고 연결 (클리어 전면 · 힌트 보상형)
- [ ] S3.6 진행 저장 + CloudKit
- [ ] S3.7 **스테이지 100개 이상** (수작업 20~30 + 생성기) + 난이도 곡선
- [ ] S3.8 KO/EN 로컬라이즈, 하드코딩 문자열 0
- [ ] S3.9 **모델 전환 알림 (Opus → Sonnet 5)**

---

## Phase 4 — 릴리즈 파이프라인
- [ ] **CloudKit Console → Deploy Schema to Production** (게임마다, 매 스키마 변경마다)
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
