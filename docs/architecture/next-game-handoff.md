# 다음 게임 핸드오프 — Chordline에서 배운 것 전부

**대상.** 게임 #2~#10을 **새 세션에서** 시작하는 사람(또는 Claude).
**목적.** Chordline이 실제로 밟은 지뢰를 다시 밟지 않는 것.

이 문서는 **절차서가 아니라 지뢰 지도**다. 기계적인 셋업 절차는
`docs/architecture/new-game-setup.md`에 있고 여기서 중복하지 않는다.
여기 있는 것은 **그 절차대로 했는데도 터졌던 것들**이다.

> 모든 경로는 저장소 루트 `/Users/jacobko/Document/01_iOS/00_Games/` 기준이다.

---

## 0. 세션 시작 시 읽을 것 — 이 순서대로

| 순서 | 파일 | 왜 |
|---|---|---|
| 1 | `CLAUDE.md` | 작업 규칙. §6 화면 제작 게이트와 §7 모델 전환이 특히 중요 |
| 2 | `PLAN.md` (gitignored) | Phase 5 사이클 = 게임 하나를 만드는 전체 흐름 |
| 3 | `checklist.md` | Chordline이 실제로 무엇을 했는지. 그대로 복사해 쓸 틀 |
| 4 | `context-notes.md` | **D-104 ~ D-110이 이 문서의 근거다.** 결정의 이유가 필요하면 여기 |
| 5 | `docs/architecture/new-game-setup.md` | 프로젝트 생성 절차 (XcodeGen · Info.plist · 5개 화면 배선) |
| 6 | `docs/design/README.md` | D1~D6 카드 운영 방식 |
| 7 | 이 문서 | 지뢰 지도 |

**게임 #2는 Pixlaugh다.** 브리프와 D1~D6 카드가 이미 채워져 있다 →
`docs/design/02-pixlaugh/`. 컨셉은 `docs/concepts/game-concepts.md`(gitignored).

---

## 1. 순서를 틀리면 작업을 두 번 한다 — 가장 비싼 실수

Chordline은 **화면 5개를 먼저 만들고**, D3/D4/D5가 나온 뒤 **전부 다시 만들었다**(D-104).
그 첫 번째 작업은 전부 버려졌다.

### 올바른 순서

```
게임 Phase 시작
   ├─ [디자인 트랙]  D1 → D2 → D3 → D4 → D5   (Claude Design, 각각 별도 세션, Opus)
   └─ [로직 트랙]    보드/상태 모델 · 솔버 · 제스처 · 저장/광고/juice 배선
                     ↑ 여기까지는 디자인과 병렬로 진행해도 된다

   ══════ D3·D4 전달 + 리뷰 완료 ══════   ← 게이트. 넘기 전엔 화면 금지

   └─ [화면 트랙]    Home · Stage Select · Settings · Result · 게임 고유 화면
```

**게이트의 정의(`CLAUDE.md` §6).** 숫자나 상태만 찍는 디버그용 `Text`·리스트는 화면이
아니다. 그것을 "실제처럼 보이게" 꾸미는 순간부터 화면이고, 그때부터 게이트가 적용된다.

D6(스토어 스크린샷)은 **출시 직전**에만 필요하다. 미리 하지 않는다.

---

## 2. 로직 트랙에서 터진 것

### 2.1 스테이지 생성을 런타임에 하지 않는다

Chordline은 처음에 앱 실행 중 솔버를 돌려 스테이지를 만들었다. 느리고, 매번 같은 결과를
낼 거면서 비용만 냈다. **빌드 시점에 구워서 소스로 커밋**하는 방식으로 바꿨다.

- 생성기: `Apps/Chordline/Sources/StageGen/`
- 산출물: `Apps/Chordline/Sources/ChordlineCore/GeneratedStages.swift`
- 실행: `cd Apps/Chordline && swift run StageGen`

**해 유일성은 테스트로 고정한다.** `tutorialStagesAreAllUniquelySolvable`이 그 예다.
스토어 문안에 "정답은 하나"라고 쓸 거라면 그 주장의 근거가 테스트여야 한다.

### 2.2 `swift test`는 호스트 빌드다

`#if canImport(UIKit)` 뒤에 있는 것은 **한 번도 컴파일되지 않는다.** 그래서
`./scripts/verify.sh`가 있다 — 호스트 테스트 + 실제 iOS 빌드 2종.

**코드를 건드렸으면 `./scripts/verify.sh`를 돌리기 전에 "됐다"고 말하지 않는다.**

---

## 3. 화면 트랙에서 터진 것

### 3.1 앱 아이콘이 빌드에 안 들어감

`Resources/AppIcon.appiconset`만 만들어두면 **빌드 시스템이 못 본다.** 반드시
`App/Assets.xcassets/` 안에 있어야 하고, `project.yml`에
`ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon`이 있어야 한다.

확인: 빌드 산출물의 `Assets.car`와 `CFBundleIconName`.

### 3.2 언어 전환 메뉴가 아예 안 뜸

문자열을 7개 언어로 다 번역해놓고도 iOS가 언어 메뉴를 안 띄웠다. 원인은
`project.yml`의 `CFBundleLocalizations` 미선언 — 앱 **번들 자체**가 다국어라고
말해야 iOS가 per-app 언어 전환을 제공한다. 문자열이 패키지 번들에 있는 것만으로는 부족하다.

```yaml
CFBundleLocalizations: [en, ko, ja, de, es-MX, pt-BR, fr]
```

### 3.3 back 버튼이 두 개

`NavigationStack`의 시스템 back과 화면이 직접 그린 back이 동시에 뜬다.
화면이 자기 back을 그린다면 `.navigationBarBackButtonHidden()`을 같이 붙인다.

### 3.4 macOS `ImageRenderer`는 `ScrollView` 안을 그리지 않는다

스냅샷 도구(`Apps/Chordline/Sources/UISnapshot/`)로 화면을 PNG로 뽑을 때,
`ScrollView` 안의 내용은 **빈 이미지**로 나온다. 그래서 `SettingsView`(화면 전체)와
`SettingsContent`(스크롤 내용물)가 분리돼 있다. 새 게임도 같은 구조를 따른다.

---

## 4. 광고 — 여기가 지뢰밭이었다

### 4.1 🔴 프로덕션 광고가 **영구히** 안 나가는 상태였다

게이트가 이렇게 돼 있었다.

```swift
ProcessInfo.processInfo.environment["COREKIT_PRODUCTION_ADS"] == "1"
```

**환경변수는 앱을 실행한 프로세스가 넘겨준 것만 보인다.** Xcode가 실행할 때는 스킴이
넘겨주지만, 사용자가 홈 화면에서 아이콘을 탭해 켠 앱에는 그 변수가 **없다.** 즉
`true`여야 하는 유일한 빌드에서만 항상 `false`였고, 모든 실사용자가 Google 테스트
광고를 보고 수익은 0이 됐을 것이다.

지금은 영수증 파일명으로 판별한다 — `Packages/CoreKit/Sources/CoreKitServices/CoreKitServices.swift`

| 빌드 | 영수증 | 실제 광고 |
|---|---|---|
| Debug | — | 아니오 |
| TestFlight | `sandboxReceipt` | 아니오 (베타 테스터 탭도 무효 트래픽) |
| App Store | `receipt` | **예** |

**교훈이 하나 더 있다.** 이 결함이 오래 살아남은 이유는 **테스트할 수 없는 구조**였기
때문이다. 지금은 규칙이 순수 함수(`CoreKitServices.allows(receiptNamed:)`)로 분리돼
있고 테스트가 있다. 새 게임에서 이런 게이트를 만들면 **반드시 테스트 가능한 형태로 쪼갠다.**

### 4.2 실제 광고 ID를 소스에 쓰지 않는다

ID는 비밀이 아니다(IPA에서 추출된다). 문제는 **남이 그걸 자기 앱에 박고 트래픽을 만들면
우리 계정이 정지**된다는 것이다.

구조 — `Apps/Chordline/`:

| 파일 | 커밋 | 내용 |
|---|---|---|
| `AdMob.xcconfig` | O | 테스트 값 + `#include? "AdMob.local.xcconfig"` |
| `AdMob.local.xcconfig.example` | O | 형식만 |
| `AdMob.local.xcconfig` | **X** | 실제 ID 4개 |

`#include?`의 `?`가 핵심이다 — 로컬 파일이 없는 클론에서도 에러 없이 테스트 값으로 빌드된다.
`project.yml`이 `configFiles`로 걸고 Info.plist에 `$(...)`로 주입하며,
`AdUnitIDs.fromInfoPlist()`가 읽는다. **셋 중 하나라도 비면 세 개 전부 테스트로** 떨어진다 —
반쪽짜리 설정이 실제/테스트 혼합을 만들지 않게.

### 4.3 🔴 `SKAdNetworkItems` 50개가 없었다

SDK가 매 실행 로그로 `50 required SKAdNetwork identifier(s) missing`이라고 외치고
있었다. 없으면 설치 기여도를 못 잡아 **받아야 할 수익을 못 받는다.**

목록 출처는 Google iOS 퀵스타트이고, `Apps/Chordline/project.yml`에 50개가 들어 있다.
새 게임은 거기서 복사하되 **SDK 버전을 올렸으면 목록을 다시 확인한다.**

### 4.4 `AdSetup.start()`를 부르는 걸 잊었다

ATT 프롬프트와 `MobileAds.shared.start()`를 트리거하는 **유일한** 함수인데 어디서도
호출하지 않고 있었다. 지금은 `Apps/Chordline/App/ChordlineApp.swift`의 `setUp()`에서
별도 `Task`로 띄운다. `await`로 기다리면 ATT 응답이 올 때까지 Home이 로딩에 묶인다.

### 4.5 광고 SDK 초기화는 메인 액터 밖에서

Google 문서: `start()`는 "SDK와 미디에이션 어댑터가 끝난 뒤 **또는 30초 뒤**"에 완료된다.
`AdSetup.start()`에서 `@MainActor`를 떼고 ATT만 메인에 남겼다.

### 4.6 UMP(EU 동의)를 붙여야 한다

EEA·영국·스위스에 **개인 맞춤** 광고를 내보내려면 Google 인증 CMP가 필요하다.
UMP SDK는 GoogleMobileAds에 딸려 이미 링크돼 있지만 **product 선언을 따로 해야**
`import`된다(`Packages/CoreKit/Package.swift` 참조).

순서: **동의 → ATT → SDK 시작.** 거부가 가능한 선택을 먼저 묻는다.

- 콘솔 작업: AdMob → 개인 정보 보호 및 메시지 → 유럽 규정 메시지 생성 → **Publish**
  - **"Do not consent" 버튼을 켠다.** GDPR은 거부가 동의만큼 쉬울 것을 요구하고,
    EU 규제기관이 "거부 버튼 없음"을 제재한 사례가 있다. 거부해도 광고가 0이 되는 게
    아니라 비개인화로 내려갈 뿐이다.
  - 주요 EEA 언어를 추가한다(표준 문구는 Google이 번역본을 갖고 있다).
- 코드: `AdSetup.requestConsent()` → 광고 로드 3경로 전부에 `canRequestAds` 게이트
  (전면·보상형·**배너**. 배너를 빠뜨리기 쉽다)
- Settings에 **"Ad Privacy Options" 행** — SDK가 요구할 때만 표시.
  `SettingsView(onPrivacyOptions:)`에 `nil`을 주면 행이 사라진다.

**검증 방법.** 한국에서는 EEA 폼을 볼 수 없다. `AdMob.xcconfig`의
`AD_CONSENT_DEBUG_GEOGRAPHY = EEA`로 지역을 강제한다. 시뮬레이터는 기본적으로 테스트
기기라 기기 ID 등록이 필요 없다. **이 코드는 `#if DEBUG` 안에 있어서 Release에
컴파일조차 되지 않는다** — Google이 "출시 전 삭제하라"고 경고하는 코드를, 삭제를
잊을 수 있는 구조로 만들지 않기 위해서다.

### 4.7 ⚠️ 디버거를 붙이면 광고 앱이 30초 멈춘 것처럼 보인다 — 결함이 아니다

**Chordline에서 실제로 한 번 결함으로 오진했다(D-110).**

AdMob은 초기화할 때 WKWebView로 시그널을 수집하고, 그래서 WebKit 보조 프로세스 셋이
뜬다. **Xcode 디버거가 붙어 있으면 그 생성이 각 7~10초**가 걸리고 하나는
`didBecomeUnresponsive`까지 남긴다. 총 지연이 Google의 30초 타임아웃과 일치한다.

```
GPU process took 8.270797 seconds to launch
WebContent process took 9.930426 seconds to launch
WebProcessProxy::didBecomeUnresponsive
Service "com.apple.CARenderServer" failed bootstrap look up
```

**판별: Xcode를 정지(⌘.)하고 기기에서 아이콘으로 직접 실행한다.** 정상 속도면 끝이다.
`docs/DEVICE-TEST.md` §0에도 박아뒀다.

**오진을 피한 방법이 더 중요하다.** 로그 키워드로 흔한 수정을 갖다 붙이지 않고
**코드 경로를 먼저 확인**했다 — 눌린 버튼은 `showStageSelect()`이고 본문이
`path = [.stageSelect]` 한 줄이라 30초가 걸릴 경로가 **아예 없다**는 게 먼저
확정됐다. 그래서 원인을 코드 밖에서 찾을 수 있었다.

---

## 5. 인앱 결제

### 5.1 🔴 로컬 StoreKit 파일이 붙어 있으면 실기기에서도 샌드박스에 안 간다

스킴에 `.storekit`이 연결돼 있으면 **기기·계정과 무관하게** 로컬 시뮬레이션으로 간다.
샌드박스 계정으로 로그인한 실기기에서 결제해도 `[Environment: Xcode]`가 뜬다 —
`[Environment: Sandbox]`가 아니다. 이걸 샌드박스 테스트로 착각하기 쉽다.

**해법: 스킴을 둘로 나눈다**(`Apps/Chordline/project.yml`의 `schemes:`).

| 스킴 | `storeKitConfiguration` | 용도 |
|---|---|---|
| `Chordline` | 있음 | 평소 개발 |
| `Chordline-Sandbox` | **없음** | 진짜 샌드박스 검증 |

`Edit Scheme`에서 수동으로 끄지 않는 이유: 그 조작은 `project.yml`에 안 남아서
`xcodegen generate`를 다시 돌리면 **조용히 원복**된다.

### 5.2 제출 전 반드시 샌드박스에서 구매·복원을 돌린다

**"Restore Purchases가 실제로 동작해야 한다"는 확정 리젝 포인트**이고, 로컬 파일로는
증명되지 않는다. Product ID가 한 글자만 달라도 로컬 테스트는 통과하고 실기기에서만 실패한다.

Product ID 규칙: `<bundle id>.removeads` (`ProductID.removeAds(bundleID:)`가 계산한다)

### 5.3 IAP 문구 길이 제한

- 표시 이름 **2~30자**
- 설명 **45자** ← 넘기기 쉽다. Chordline 초안이 전부 초과했다
- 심사용 스크린샷은 **스토어 스크린샷과 같은 버킷 크기**여야 한다(아래 6.1)

---

## 6. 스토어 자산

### 6.1 스크린샷은 6.9"(1320×2868) 한 벌만 만든다

**자동 축소는 한 방향이다.** 6.9"를 채우면 6.5" 이하가 전부 따라오지만, 6.5"를
채우면 6.9"는 빈 채로 남는다. App Store Connect가 기본으로 열어주는 슬롯이 6.5"라
거기부터 채우기 쉬운데, 그게 함정이다. (한 번 왕복한 뒤 확정했다.)

**시뮬레이터 원본은 어느 버킷에도 안 맞는다.** 재촬영할 필요 없다 — **원본을 규격
캔버스 안의 기기 프레임에 합성**하면 원본 해상도가 무관해진다.

생성기: `Apps/Chordline/Marketing/build_frames.py`
→ 복사해서 `LOCALES`의 카피만 갈아끼우면 7개 언어 × 5장이 한 번에 나온다.

```bash
cd Apps/<Game>/Marketing && python3 build_frames.py        # 전체
cd Apps/<Game>/Marketing && python3 build_frames.py ko     # 한 언어만
```

### 6.2 폰트 — D1 문서가 틀렸다

D1이 "Sora — 한글 조판 안정"이라고 적었지만 **Sora에는 한글·일본어 글리프가 없다.**
한국어는 Pretendard, 일본어는 Noto Sans JP를 따로 지정한다(둘 다 OFL).
둘 다 같은 포인트에서 라틴보다 빽빽해서 **크기를 낮추고 행간을 벌려야** 한다.
독일어·프랑스어는 단어가 길어 영어 크기로는 캔버스를 넘친다.

### 6.3 스크린샷 속 주장은 코드로 확인한 것만 쓴다

- 화면에 없는 걸 카피가 약속하면 **2.3.1 리젝**이다. Chordline 초안이 결과 화면에
  "Watch it ignite"라고 썼다가 화면에 실제로 있는 것으로 고쳤다.
- **버튼에 가격을 박지 않는다.** 스크린샷은 전 지역 스토어에 공용이라 다른 통화권
  독자에게 틀린 값을 보여주고, 티어를 바꾸면 바로 낡는다. Chordline은 Remove Ads
  버튼에서 가격 표시를 코드에서 아예 뺐다.

### 6.4 웹 페이지 — 게임마다 따로 만든다

공용 단일 방침 문서는 **폐기했다(D-109).** `CoreKit`이 같아도 게임마다 사실관계가
갈리기 때문이다 — `AnalyticsHub`는 CoreKit에 있지만 **리포터 등록은 게임이 결정**하고,
광고 배치도 다르고, CloudKit에 올라가는 필드도 다르다.

- 핸드오프 레퍼런스: `Apps/Chordline/Marketing/web-handoff.md`
  - **§4의 "주장별 코드 근거표"를 반드시 만든다.** 카피를 나중에 고칠 때
    사실관계가 조용히 깨지는 걸 막는 유일한 장치다.
- 레퍼런스 사이트: `bargly.jacobko.app`, `chordline.jacobko.app`
- App Store 링크는 **`/app/id<숫자>`** 형식이다. 슬러그(`/app/chordline`)는 영구히 404다.

---

## 7. App Store Connect

`docs/architecture/appstore-connect-setup.md`가 절차서다. 여기는 헷갈렸던 것만.

| 항목 | 답 / 주의 |
|---|---|
| 앱 개인정보 라벨 | **SDK가 배포하는 매니페스트에서 직접 읽는다.** Google 산문 도움말로 추론하면 연결·추적 칸이 틀린다(실제로 틀렸다). 답안: `docs/privacy/app-privacy-label.md` |
| 콘텐츠 권한 | 광고가 있으면 **"예, 권한 있음"**. 광고는 표시되는 제3자 콘텐츠다 |
| 연령 등급 | 폭력·도박·성인 전부 None, **Advertising만 Yes** → 4+ |
| Small Business Program | 같은 계정 안의 여러 앱은 연관 계정이 **아니다**. 계정이 둘 이상인지만 본다 |
| Partner bidding 체크박스 | **끈다.** 다른 미디에이션 플랫폼을 쓸 때만 켠다. 생성 후 변경 불가 |
| 제출 순서 | 첫 버전은 **앱 + IAP를 같이 제출**한다. IAP를 버전에 첨부하지 않으면 앱만 승인되고 구매는 미승인으로 남는다 |
| TestFlight 광고 | **테스트 광고가 정상이다.** 고장이 아니다(4.1 표 참조) |

`PrivacyInfo.xcprivacy`도 앱 타겟에 필요하다 — `Apps/Chordline/App/PrivacyInfo.xcprivacy`
참조. 내용이 거의 비어 있는 게 정상이다(제3자 SDK 수집은 SDK 자기 매니페스트가 다룬다).

---

## 8. 환경 함정 — 코드 문제가 아닌 것들

이걸 모르면 멀쩡한 코드를 의심하며 시간을 버린다.

### 8.1 `$TMPDIR`의 DerivedData가 날아간다

`verify.sh`/`audit.sh`가 갑자기 이런 에러를 뱉는다.

```
error: There is no Info.plist found at '.../GoogleMobileAds.xcframework/Info.plist'
```

macOS가 임시 디렉토리를 정리하면서 일부를 지운 것이다. **이번 세션에만 두 번 났다.**

```bash
rm -rf "${TMPDIR:-/tmp}/corekit-dd" "${TMPDIR:-/tmp}/corekit-dd-lab" "${TMPDIR:-/tmp}/ck-analyze"*
```

### 8.2 SPM 오브젝트 파일이 stale해진다

CoreKit의 함수 시그니처를 바꾸면 게임 패키지가 **옛 심볼을 참조한 채 링크 실패**한다.

```
Undefined symbols: CoreKitUI.SettingsContent.init(... 옛 시그니처 ...)
```

의존성 문제가 아니다. `rm -rf .build && swift build`로 해결된다.

### 8.3 SourceKit 진단은 자주 거짓말한다

`No such module 'ChordlineCore'`, `Type has no member '...'` 같은 게 편집 중에 뜨지만
`swift build`는 멀쩡히 통과한다. **컴파일러 결과를 믿는다.**

### 8.4 `.xcodeproj`는 gitignore돼 있다

XcodeGen 생성물이다. 소스는 `project.yml`뿐이고, 스킴을 Xcode UI에서 고치면
`xcodegen generate` 시 사라진다. **스킴 변경은 `project.yml`에 한다.**

---

## 9. 모델 전환

`CLAUDE.md` §7이 정본이다. 요약하면:

- **Opus** — 새 `CoreKit` 기능을 처음부터 설계할 때, `CoreKit`에 뿌리를 둔 결함을
  쫓을 때, J가 직접 요청할 때
- **Sonnet** — 그 외 전부. **이미 나온 디자인 시안대로 화면을 만드는 것은 Sonnet으로 충분하다.**
  Chordline의 UI 재작업은 모델 문제가 아니라 **순서 문제**였다(§1)

전환 시점: 게임의 코어 루프가 호스트에서 처음 끝까지 도는 순간(승패 도달 + juice 하나
체감 가능). 그 지점에서 Claude가 먼저 제안한다.

---

## 10. 새 게임 시작 커맨드

```bash
cd /Users/jacobko/Document/01_iOS/00_Games

# 1. 디자인 핸드오프 폴더 — 게임 #2~10은 이미 만들어져 있다
ls docs/design/02-pixlaugh/

# 2. 이름 상표 확인
./scripts/check-name.sh Pixlaugh

# 3. 저장소 — 게임마다 따로 만든다 (docs/architecture/repo-strategy.md)
#    로컬은 Apps/Pixlaugh/, 부모 저장소의 .gitignore가 Apps/*를 막는다

# 4. 프로젝트 생성 — docs/architecture/new-game-setup.md 를 따른다

# 5. 검증 (코드를 건드릴 때마다)
./scripts/verify.sh

# 6. Phase 끝날 때마다
./scripts/audit.sh    # + docs/AUDIT.md §4 의 읽기 패스
```

---

## 11. 한 줄 요약

1. **D3·D4 나오기 전에 화면 만들지 마라.** 가장 비싼 실수였다.
2. **테스트할 수 없는 게이트를 만들지 마라.** 광고 게이트가 그래서 죽어 있었다.
3. **"안 되는데?" 하기 전에 코드 경로부터 확인해라.** 30초 프리징은 우리 코드가 아니었다.
4. **로컬 시뮬레이션과 진짜를 구분해라.** StoreKit도, 광고도, 둘 다 가짜가 기본값이다.
5. **스토어 문안의 주장은 코드로 확인한 것만 써라.**
