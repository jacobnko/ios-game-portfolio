# 새 게임 Xcode 프로젝트 만들기

이 문서만 보고 **30분 안에** CoreKit이 붙은 빈 게임 앱이 기기에서 돌아야 한다.
실제 동작 예시는 `Tools/JuiceLab`의 `FlowLabView.swift`다 — 이 문서와 같은 배선을 그대로 보여준다.

> **이 문서를 실행하는 시점 — 게임 로직이 다 끝난 뒤다, 시작할 때가 아니다.**
> Chordline은 §0의 번들 ID·D1은 미리 확정해뒀지만, 실제 `project.yml`/앱 진입점
> 생성은 순수 로직·juice·광고·저장·로컬라이즈(구 Phase 3 전체)가 SPM 패키지 안에서
> 끝난 **뒤**에 했다. 그 전까지는 `swift test` + Xcode Live Preview로만 검증했고,
> 실기기 확인이 아예 불가능했다 — 앱 자체가 없었기 때문이다. `CLAUDE.md` §2.6이
> 이제 이 순서를 게임마다 반복할 규칙으로 못 박아둔다: **로직 완성 → 이 문서 실행 →
> 실기기 핸드오프 → 그 다음에야 릴리즈 파이프라인 단계로 넘어간다.**

---

## 0. 선행 조건

- [ ] 코드네임 확정 — `docs/architecture/naming.md`의 상표 위험 목록 통과
- [ ] `docs/design/<NN-game-name>/00-brief.md` 작성 (게임 컨셉)
- [ ] Claude Design D1(브랜드/팔레트) 최소 완료 — `GameTheme`을 채우려면 필요

**번들 ID는 여기서 고정되고 이후 변경 비용이 크다.** 확정 전에 시작하지 않는다.

---

## 1. 저장소 생성

```bash
gh repo create jacobnko/<codename> --private --clone
cd <codename>
```

`docs/architecture/repo-strategy.md`대로 게임은 별도 저장소다. 생성 직후 시크릿 패턴을 `.gitignore`에 복사한다.

```bash
cat >> .gitignore <<'GITIGNORE'
GoogleService-Info.plist
Secrets.xcconfig
*.p8
*.mobileprovision
GITIGNORE
```

## 2. Xcode 프로젝트 생성 (XcodeGen)

`project.yml`을 만든다. `Tools/JuiceLab/project.yml`을 베이스로 삼되 다음을 바꾼다.

| 항목 | 값 |
|---|---|
| `name` | 코드네임 (예: `Chordline`) |
| `PRODUCT_BUNDLE_IDENTIFIER` | `com.jacobkostudio.<codename>` |
| `packages.CoreKit.path` | 이 저장소 기준 상대 경로로 `00_Games/Packages/CoreKit`를 가리킨다 |
| `info.properties.GADApplicationIdentifier` | 개발 중엔 **Google 테스트 앱 ID** `ca-app-pub-3940256099942544~1458002511`. 실제 ID로 바꾸지 않는다 |
| `info.properties.NSUserTrackingUsageDescription` | ATT 프롬프트 문구 |
| `schemes.<Name>.run.storeKitConfiguration` | `<Name>.storekit` |

> ⚠️ **`GENERATE_INFOPLIST_FILE: YES` + `INFOPLIST_KEY_*`를 쓰지 않는다.**
> Xcode가 정한 키 목록에만 매핑되고 `GADApplicationIdentifier`는 그 목록에 없어서
> **경고 없이 버려지고 앱이 실행 즉시 크래시한다** (Phase 1 B-15). 실제 `Info.plist` +
> XcodeGen의 `info: path/properties`를 쓴다.

```bash
xcodegen generate
open <Codename>.xcodeproj
```

## 3. StoreKit Configuration 파일

`<Codename>.storekit`을 만든다. `Tools/JuiceLab/JuiceLab.storekit`을 복사하고 다음만 바꾼다.

- `productID`: `com.jacobkostudio.<codename>.removeads`
- `displayPrice`: `2.99` (출발점. §4 참조)

Xcode → **Edit Scheme → Run → Options → StoreKit Configuration**에서 선택되어 있는지 확인한다.
비어 있으면 구매 테스트가 전부 조용히 실패한다.

## 4. iCloud / CloudKit capability

Signing & Capabilities에서 다음을 켠다 (`docs/architecture/cloudkit-setup.md` 참조).

- **iCloud → CloudKit**, 컨테이너 `iCloud.com.jacobkostudio.<codename>`
- **Background Modes → Remote notifications**

## 5. `GameTheme` 등록

D1에서 나온 hex·폰트·모서리 값을 채운다.

```swift
// GameTheme+Chordline.swift
extension GameTheme {
    static let chordline = GameTheme(
        palette: ThemePalette(
            primary: ThemeColor(light: .cyan, dark: .cyan),
            // ... D1 결과값
        ),
        typography: ThemeTypography(systemDesign: .default),
        metrics: ThemeMetrics(cornerRadius: 4, tileSpacing: 10)
    )
}
```

`docs/concepts/palette-ledger.md`(비공개)에서 인접 게임과 팔레트가 겹치지 않는지 확인한다.

### 5.1 실제 게임플레이 화면은 `Sources/<Game>UI/Views/`에 둔다

`GeometryReader` + `Canvas` + 제스처로 조립되는 화면 — 즉 "만져서 확인해야 하는" 코드 —
은 이 하위 폴더에 둔다. `audit.sh` 7단계가 `UI/Views/`를 커버리지 하한에서 제외해 주는데,
이건 `CoreKitUI/Screens`가 이미 그런 취급을 받는 것과 같은 이유다 — `GraphicsContext`는
공개 이니셜라이저가 없어서 호스트 테스트가 렌더 함수를 직접 부를 방법이 없다.

**반대로, 좌표 변환·경로/스타일 계산처럼 값만 다루는 로직은 이 폴더 밖에 둔다.**
그래야 하한 검사를 실제로 받는다. Chordline의 예:

| 파일 | 위치 | 이유 |
|---|---|---|
| `BoardLayout.swift` | `ChordlineCore/` | `CGPoint`/`CGRect`만 다룸 — SwiftUI 불필요, 호스트에서 100% 테스트 |
| `NodeGlyph+Path.swift`, `LineTexture+StrokeStyle.swift` | `ChordlineUI/` (Views 밖) | `Path`/`StrokeStyle`을 만들 뿐 그리지 않음 — 결과값을 단언할 수 있음 |
| `GameplayBoardView.swift` | `ChordlineUI/Views/` | 실제 `Canvas` 렌더 + `DragGesture` — 여기만 예외 대상 |

## 6. App 진입점 — 다섯 화면을 배선한다

이게 전체 배선의 핵심이다. `FlowLabView.swift`가 정확히 이 모양이다.

```swift
@main
struct ChordlineApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .gameTheme(.chordline)
        }
    }
}

struct RootView: View {
    @State private var coordinator: GameFlowCoordinator?

    var body: some View {
        Group {
            if let coordinator {
                FlowRouter(coordinator: coordinator)
            } else {
                ProgressView().task { await setUp() }
            }
        }
    }

    private func setUp() async {
        let store = ProgressStore(container: try! ProgressStore.makeContainer())
        let purchases = PurchaseManager()
        purchases.start()
        let presenter = GoogleAdPresenter(adUnitIDs: .test)  // production() 전환은 §8
        let ads = AdCoordinator(purchases: purchases, presenter: presenter)
        coordinator = GameFlowCoordinator(progress: store, purchases: purchases, ads: ads)
    }
}

private struct FlowRouter: View {
    @Bindable var coordinator: GameFlowCoordinator

    var body: some View {
        NavigationStack(path: $coordinator.path) {
            HomeView(
                onPlay: { coordinator.showStageSelect() },
                onSettings: { coordinator.openSettings() },
                logo: { /* 게임 로고 */ },
                banner: { AdBannerSlot(adUnitID: AdUnitIDs.test.banner, isVisible: coordinator.ads.showsBanner) }
            )
            .navigationDestination(for: GameRoute.self) { route in
                switch route {
                case .stageSelect:
                    StageSelectView(stages: myStages, progress: myProgressSnapshot,
                                     isUnlocked: myUnlockRule, onSelect: { coordinator.startStage($0.id, attempt: 1) },
                                     onBack: { coordinator.goHome() })
                case .game(let stageID):
                    MyGameplayView(stageID: stageID) { outcome in
                        Task { _ = await coordinator.completeStage(stageID, outcome: outcome) }
                    }
                case .result(let stageID, let outcome):
                    ResultView(outcome: outcome,
                               onAdvance: { Task { await coordinator.advanceFromResult(nextStageID: myNextStage(after: stageID)) } },
                               onRetry: { coordinator.retryStage(stageID, attempt: 2) })
                case .settings:
                    SettingsView(purchases: coordinator.purchases,
                                 // Shared across the whole portfolio — see docs/privacy/README.md.
                                 privacyPolicyURL: URL(string: "https://jacobnko.github.io/ios-game-portfolio/privacy/"),
                                 onResetProgress: { try? coordinator.progress.deleteAll() },
                                 onBack: { coordinator.pop() })
                }
            }
        }
    }
}
```

**게임이 직접 만드는 건 딱 하나, `.game` 케이스의 `MyGameplayView`뿐이다.** 나머지 네 화면은
`CoreKitUI`가 제공한다. 퍼즐 그리드든 SpriteKit 씬이든, `outcome`을 만들어
`coordinator.completeStage(stageID, outcome:)`를 부르기만 하면 진행도 저장·광고 페이싱·분석 로깅이
전부 자동으로 따라온다.

### 지켜야 할 규칙 하나

**전면 광고는 `completeStage`가 아니라 `advanceFromResult`에서만 시도된다.** 승리 연출이
Result 화면에서 재생되는 동안 광고가 끼어들면 안 되기 때문이다 (`GameFlowCoordinator.swift`의
`advanceFromResult` 주석 참조). 이 순서를 게임 코드에서 바꾸지 않는다.

## 7. `StageDescriptor` 구현

```swift
struct ChordlineStage: StageDescriptor {
    let id: String            // ProgressStore 키와 일치해야 한다
    let displayNumber: Int
    let puzzleData: PuzzleDefinition  // 게임 고유 데이터
}
```

## 8. 출시 직전 체크 (여기서 하지 않는다 — 표시만)

- [ ] `AdUnitIDs.production(...)`로 전환 + `COREKIT_PRODUCTION_ADS=1`
- [ ] CloudKit Console → Deploy Schema to Production
- [ ] `GADApplicationIdentifier`를 실제 앱 ID로 교체
- [ ] 스토어 표시명 확정 (`docs/architecture/naming.md` §확정 시점)

### 첫 제출 — 광고는 켜고, 배너만 숨긴다 (Chordline D-107)

`AdCoordinator`는 스위치 두 개를 따로 갖는다. `adsEnabled`(전체 킬 스위치)와
`bannerEnabled`(배너만). Chordline은 처음에 전체를 끄는 쪽(D-106)을 검토했다가, 실제로는
**전면·보상형(힌트)·Settings의 Remove Ads/Restore Purchases는 켜둔 채 배너만 숨기는** 쪽으로
정했다(D-107) — 배너는 화면에 상시 떠 있어서 스크린샷과 첫인상에 항상 걸리지만, 전면·보상형은
뭔가 일어나야만(클리어, 힌트 요청) 뜨기 때문에 노출이 훨씬 적다.

```swift
// App 진입점(§6) 최상단에 이 한 줄을 둔다 — 플립 지점은 여기 하나뿐이다.
private let bannerEnabledAtLaunch = false   // 리뷰 이력이 쌓이면 true로

// AdCoordinator에만 전달한다. SettingsView는 그대로 둔다 — 배너를 숨기는 것과
// 구매 로직 노출 여부는 무관하다.
let ads = AdCoordinator(purchases: purchases, presenter: presenter, bannerEnabled: bannerEnabledAtLaunch)
```

전체를 다 끄고 싶은 경우(예: QA 빌드, 또는 첫 제출 전략을 D-106처럼 더 보수적으로 가고 싶은
게임)를 위해 `adsEnabled`(디폴트 `true`)도 별도로 남아 있다 — 그땐 `bannerEnabled`와 함께
`adsEnabled: false`를 넘긴다. 이 경우 `SettingsView`는 구매할 것도 복원할 것도 없어지므로
호출부에서 Remove Ads/Restore Purchases를 직접 조건부로 감싸야 한다(D-106 당시엔 이걸 위해
`SettingsView(adsEnabled:)` 파라미터를 만들었다가, 배너만 숨기는 쪽으로 정해지면서 다시
빼냈다 — 필요해지면 그 커밋을 참조).

**`AdSetup.start()`를 실제로 호출하고 있는지 확인한다.** ATT 프롬프트와
`MobileAds.shared.start()`를 트리거하는 게 이 함수 하나뿐인데, Chordline은 처음엔 이 호출
자체가 빠져 있었다(D-106에서 발견, D-107에서 배선). 로딩 화면을 막지 않도록 `Task { await
AdSetup.start() }`로 따로 띄운다 — `await`로 기다리면 ATT 응답이 올 때까지 Home 화면이
로딩 스피너에 묶인다.

---

## 검증

```bash
xcodebuild -scheme <Codename> -destination 'generic/platform=iOS' build
```

기기에서 Home → Play → Stage Select → (임시 스테이지) → Result → Next → Stage Select 순서로
막힘없이 돈다면 배선이 맞다. 게임 로직이 아직 없어도 이 흐름은 완성돼야 한다 — 그게 이 문서의
검증 기준이다.
