# AdMob 설정 가이드

`CoreKitAdsGoogle`이 SDK 연동을 제공한다. 게임 타겟에서 아래를 설정한다.

---

## 1. 앱 타겟 설정 (게임마다 1회)

### Info.plist
| 키 | 값 |
|---|---|
| `GADApplicationIdentifier` | AdMob 앱 ID. **개발 중에는 `ca-app-pub-3940256099942544~1458002511`** (Google 테스트) |
| `NSUserTrackingUsageDescription` | ATT 프롬프트 문구. 없으면 **프롬프트가 아예 안 뜬다** |
| `SKAdNetworkItems` | AdMob 문서의 목록을 그대로 붙여넣는다. 없으면 기여도 추적이 안 된다 |

`GADApplicationIdentifier`가 없으면 SDK가 **시작 시 크래시**한다
(`GADInvalidInitializationException`). 앱이 즉시 종료되므로 놓칠 수는 없지만, 원인은 엉뚱한 곳에 있다.

### ⚠️ `INFOPLIST_KEY_GADApplicationIdentifier`는 동작하지 않는다

Xcode의 `GENERATE_INFOPLIST_FILE` + `INFOPLIST_KEY_*` 방식은 **Apple이 정한 키 목록에만** 적용된다.
`NSUserTrackingUsageDescription`은 그 목록에 있어서 들어가지만, `GADApplicationIdentifier`는 **없다.**
빌드 설정에 써도 **경고 없이 조용히 버려지고**, 앱은 실행 즉시 위 예외로 죽는다.

실제로 이 저장소의 하네스가 그 상태였고, 시뮬레이터에서 **실행해 보고 나서야** 발견했다.
빌드도 테스트도 전부 통과했었다.

**대응.** 실제 `Info.plist` 파일을 쓴다. XcodeGen이라면 `GENERATE_INFOPLIST_FILE: NO`로 두고
타겟에 `info: path/properties`를 선언한다 (`Tools/JuiceLab/project.yml` 참조).

**검증 방법.** 빌드 산출물의 plist를 직접 확인한다. 이것이 유일하게 확실한 확인이다.
```bash
plutil -extract GADApplicationIdentifier raw <App>.app/Info.plist
```

### 앱 시작
```swift
Task { await AdSetup.start() }   // ATT 먼저, 그 다음 SDK 시작
```

**순서가 중요하다.** SDK는 초기화 시점의 추적 권한을 읽는다. 나중에 물어보면 첫 세션은
사용자가 허용했어도 비개인화 광고가 나간다.

---

## 2. 광고 ID — 기본값은 항상 테스트

```swift
// 개발 중 (기본값)
let ids = AdUnitIDs.test

// 출시 빌드
let ids = AdUnitIDs.production(banner: "...", interstitial: "...", rewarded: "...")
```

`production(...)`은 `CoreKitServices.allowsProductionAdUnits`가 `true`일 때만 실제 ID를 쓰고,
아니면 **조용히 테스트 ID로 떨어진다.** DEBUG 빌드에서는 항상 `false`다.

**실수의 방향이 한쪽으로만 향하게 만든 것이다.** 잘못되면 테스트 광고가 나오지, 계정 정지는 안 난다.
자기 광고를 반복 조회·클릭하는 것은 무효 트래픽이고 AdMob 계정 정지 사유다.

출시 빌드에서 실제 광고를 켜려면 Release 스킴에 환경변수 `COREKIT_PRODUCTION_ADS=1`을 넣는다.

---

## 3. 배너 — 왜 `AdBannerSlot`만 쓰는가

SwiftUI + AdMob에서 가장 흔한 버그는 이것이다.

```swift
// 이렇게 하면 안 된다
func updateUIView(_ view: BannerView, context: Context) {
    let banner = BannerView(adSize: ...)   // 부모가 다시 그려질 때마다 새 배너
    banner.load(Request())
}
```

SwiftUI는 **부모의 state가 바뀔 때마다** `updateUIView`를 부른다. 게임에서는 타이머 한 틱,
점수 한 번 오를 때마다다. 그러면 배너가 계속 리로드되어 깜빡이고, 노출이 낭비되고,
AdMob이 비정상 트래픽으로 볼 수 있다.

`AdBannerView`는 `BannerView` 인스턴스를 **Coordinator가 한 번만 만들어 재사용**한다.
`updateUIView`는 너비만 조정하고, 그것도 **1pt 넘게 실제로 바뀌었을 때만** 다시 로드한다.

```swift
AdBannerSlot(adUnitID: ids.banner, isVisible: ads.showsBanner)
```

`AdBannerSlot`은 광고가 아직 안 왔어도 **높이를 미리 확보**한다. 첫 노출이 도착할 때
화면이 밀리면 사용자가 누르려던 것을 잘못 누르게 되고, 그게 Guideline 2.3.1 위반이다.

---

## 4. 광고 호출은 `AdCoordinator`만 거친다

```swift
let ads = AdCoordinator(purchases: purchases, presenter: GoogleAdPresenter(adUnitIDs: ids))

// 스테이지 클리어마다 (광고를 띄우든 안 띄우든)
ads.recordStageClear()

// 클리어 후
await ads.showInterstitialIfAllowed()

// 힌트 버튼
if await ads.showRewarded() == .earned { giveHint() }
```

SDK를 직접 부르지 않는다. 그래야 **광고 제거 확인이 한 곳에만** 존재한다.
호출부마다 조건을 복사하면 언젠가 하나를 빠뜨리고, 그러면 결제한 사용자가 광고를 본다.

### 기본 빈도 정책 (`AdPolicy.standard`)
| 규칙 | 기본값 | 이유 |
|---|---|---|
| 초반 무광고 클리어 | 3판 | 첫인상 구간을 끊지 않는다 |
| 전면 최소 간격 | 120초 | |
| 전면 사이 최소 클리어 | 2판 | |
| 보상형 후 정숙 시간 | 45초 | 보상형 보고 바로 전면이 뜨면 옵트인한 것에 대한 벌처럼 느껴진다 |

**의도적으로 적게 보여준다.** 캐주얼 퍼즐 세션은 짧고, 매 판마다 전면을 띄우는 것이
2일차 리텐션을 깎는 가장 빠른 방법이다. 잃는 리텐션이 버는 노출보다 비싸다.

보상형은 페이싱하지 않는다. 사용자가 직접 요청한 것이고, 거절하면 사용자가 스스로 벌기로 한
힌트를 뺏는 것이다. 광고를 제거한 사용자는 **광고 없이 보상만 받는다.**

---

## 5. 출시 전 체크

- [ ] `GADApplicationIdentifier`를 실제 앱 ID로 교체
- [ ] `AdUnitIDs.production(...)`에 실제 3개 ID 입력
- [ ] Release 스킴에 `COREKIT_PRODUCTION_ADS=1`
- [ ] `SKAdNetworkItems` 최신 목록 반영
- [ ] 광고 제거 구매 후 **배너·전면·보상형 전부** 사라지는지 확인
- [ ] 배너가 인터랙티브 UI를 가리거나 밀지 않는지 (Guideline 2.3.1)
- [ ] 소리 있는 광고가 사용자 동작 없이 자동 재생되지 않는지
- [ ] App Store Connect의 앱 개인정보 라벨에 광고 SDK 데이터 수집을 정확히 신고
