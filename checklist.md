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
