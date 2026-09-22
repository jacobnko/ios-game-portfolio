# App Store Connect "앱 개인정보" 라벨 — 작성 기준

App Store Connect → 앱 개인정보(App Privacy)의 답을 정하는 문서다. 라벨이 실제 동작과
어긋나면 **5.1.1 리젝**이고, 앱 심사와 무관하게 언제든 수정 가능한 항목이라 SDK를
추가·제거할 때마다 다시 봐야 한다.

근거 두 곳:
- Apple, [App privacy details on the App Store](https://developer.apple.com/app-store/app-privacy-details/)
- Google, [App Store 데이터 공개 (Mobile Ads SDK for iOS)](https://developers.google.com/admob/ios/privacy/data-disclosure)

---

## 판단의 출발점 — "수집"의 정의

> "Collect" refers to transmitting data off the device **in a way that allows you
> and/or your third-party partners to access it** for a period longer than what is
> necessary to service the transmitted request in real time.
> — Apple

기기 밖으로 나가는 것만으로는 수집이 아니다. **우리(또는 제3자)가 접근할 수 있어야**
수집이다. 이 한 줄이 아래 두 결정을 가른다.

### CloudKit 진행 데이터는 신고하지 않는다

`StageProgress`는 CloudKit으로 동기화되지만 목적지는 **사용자 본인 Apple 계정의 비공개
데이터베이스**다. 개발자는 읽을 수 없다. 기기 밖으로 나가긴 하지만 "우리가 접근할 수
있는 방식"이 아니므로 위 정의의 수집에 해당하지 않는다.

> 보수적으로 가고 싶다면 `게임플레이 콘텐츠`(User Content) → 목적 `앱 기능`,
> `사용자와 연결 안 됨`, `추적 안 함`으로 신고해도 리젝 사유는 아니다. 다만 그건
> 실제와 다른 라벨이 되므로 기본은 신고하지 않는 쪽이다.

### 결제 정보도 신고하지 않는다

Apple이 명시한다.

> If your app uses a payment service, the payment information is entered outside
> your app, and you as the developer never have access to the payment information,
> **it is not collected and does not need to be disclosed.**

StoreKit이 전부 처리하고 앱은 권한 보유 여부만 읽는다. `결제 정보` 신고 없음.

### 애널리틱스도 없다

`AnalyticsHub`는 CoreKit에 있지만 **리포터 등록은 게임의 몫**이고, Chordline은 하나도
등록하지 않았다. 벤더 SDK가 없으니 보낼 곳이 없다. **게임마다 반드시 재확인할 항목** —
다음 게임이 Firebase를 붙이면 이 줄이 거짓이 된다.

---

## Chordline이 신고하는 것 — 전부 AdMob 때문이다

수집 주체는 우리가 아니라 Google Mobile Ads SDK다. Apple은 "제3자 파트너"의 수집도
개발자가 신고하게 한다.

**출처는 산문 설명이 아니라 SDK가 번들에 넣어 배포하는 매니페스트다.**
`GoogleMobileAds.framework/PrivacyInfo.xcprivacy`를 직접 읽어서 옮긴 값이 아래 7개다.
Apple의 privacy report가 집계하는 것도 바로 이 파일이므로, 라벨을 여기에 맞추면 report와
라벨이 어긋날 일이 없다. Google의 산문 도움말만 보고 추론하면 **연결·추적 칸이 틀린다** —
실제로 한 번 틀렸다.

| Apple 데이터 타입 | 분류 | 목적 | 연결 | 추적 |
|---|---|---|---|---|
| 대략적인 위치 (Coarse Location) | 위치 | 서드 파티 광고, 자사 광고, 분석 | **연결됨** | 아니요 |
| 기기 ID (Device ID) | 식별자 | 서드 파티 광고, 분석, 자사 광고 | **연결됨** | **예** |
| 제품 상호 작용 (Product Interaction) | 사용 데이터 | 분석, 자사 광고, 서드 파티 광고 | **연결됨** | 아니요 |
| 광고 데이터 (Advertising Data) | 사용 데이터 | 서드 파티 광고, 자사 광고, 분석 | **연결됨** | 아니요 |
| 실적 데이터 (Performance Data) | 진단 | 서드 파티 광고, 자사 광고, 분석 | 연결 안 됨 | 아니요 |
| 충돌 데이터 (Crash Data) | 진단 | 분석 | 연결 안 됨 | 아니요 |
| 기타 진단 데이터 (Other Diagnostic Data) | 진단 | 서드 파티 광고, 자사 광고, 분석 | 연결 안 됨 | 아니요 |

### 헷갈리는 칸들

- **"연결됨"이 4개나 되는 이유.** Apple의 "연결"은 신원과의 연결이다. Chordline에는 계정이
  없으니 *우리는* 아무것도 연결하지 못한다 — 그래서 "전부 연결 안 됨"으로 추론하기 쉽다.
  하지만 연결은 제3자가 하는 것도 포함하고, Google은 자기 매니페스트에서 이 4개를
  `Linked = true`로 선언한다. Google 쪽에서 연결된다는 뜻이므로 "연결됨"이 맞다.
- **추적은 기기 ID 하나만 "예".** 광고 데이터·제품 상호 작용까지 추적으로 볼 것 같지만,
  SDK 매니페스트는 `Tracking = true`를 **DeviceID에만** 붙인다. 추적의 매개가 광고
  식별자이기 때문이다. 나머지는 전부 아니요.
- **그래도 앱 전체로는 "추적함"이다.** 기기 ID 한 줄이 예이면 앱은 추적하는 앱이고, 그래서
  ATT 프롬프트가 필수다. `AdSetup.start()`가 실제로 띄운다 — 라벨과 코드가 일치한다.
- **대략적인 위치** — 앱은 위치 권한을 요청조차 하지 않는다. IP 주소로 추정되는 것이고,
  그것도 Apple의 Coarse Location에 해당한다.
- **"자사 광고"(Developer's Advertising or Marketing)도 목적에 들어간다.** Google이
  매니페스트에 `DeveloperAdvertising`을 넣어두었다. 우리가 자체 광고를 하지 않더라도 SDK의
  선언을 따른다.

### SDK 버전을 올리면 다시 읽는다

이 표는 특정 SDK 버전의 매니페스트를 옮긴 것이다. 버전을 올린 뒤에는 추측하지 말고 같은
파일을 다시 읽는다.

```bash
find "${TMPDIR:-/tmp}" -name PrivacyInfo.xcprivacy -path '*GoogleMobileAds*' \
  -exec plutil -p {} \;
```

Apple이 권하는 정석은 Xcode에서 **Product → Archive → Generate Privacy Report**로
앱과 모든 SDK의 매니페스트를 집계한 보고서를 뽑아, 그걸 보면서 라벨을 채우는 것이다.

---

## 입력 순서

1. **"이 앱에서 데이터를 수집합니까?"** → **예**
   (우리가 아니라 AdMob이 수집하지만, 제3자 파트너의 수집도 신고 대상이다)
2. 위 표의 6개 타입 선택
3. 타입마다 목적 · 연결 여부 · 추적 여부를 표대로 지정
4. **개인정보처리방침 URL** — `docs/privacy/README.md`의 게임별 URL

## 라벨을 다시 봐야 하는 때

- 애널리틱스·크래시 SDK를 추가할 때 (Chordline은 지금 없다)
- 광고 SDK 버전을 올릴 때 — Google이 목록을 갱신하면 위 표도 갱신된다
- 비개인화 광고를 강제하도록 바꿀 때 → 추적 칸이 "아니요"로 바뀐다
- 계정·로그인을 추가할 때 → "연결 안 됨"이 전부 무너진다

---

## 앱의 privacy manifest

`Apps/Chordline/App/PrivacyInfo.xcprivacy`에 있다. XcodeGen이 `sources: [App]`으로 자동
포함해서 앱 번들 최상단에 들어간다(빌드로 확인).

내용이 거의 비어 있는 것이 정상이다. Apple이 명시한다.

> Your app's privacy manifest file **doesn't need to cover data collected by
> third-party SDKs** that your app links to.

- `NSPrivacyCollectedDataTypes` — **빈 배열.** 우리 코드가 자체적으로 수집하는 건 없다
  (CloudKit은 사용자 본인 DB, 결제는 StoreKit, 애널리틱스 없음). AdMob의 수집은
  `GoogleMobileAds.framework`가 자기 매니페스트로 선언한다.
- `NSPrivacyTracking` — **false.** 추적하는 주체는 광고 SDK이고 그건 SDK 매니페스트에
  `DeviceID / Tracking = true`로 이미 선언돼 있다. Xcode의 privacy report가 앱과 SDK를
  **집계**하므로 여기서 false로 두어도 감춰지는 것은 없다. 앱 자체 코드는 추적하지 않는다.
- `NSPrivacyAccessedAPITypes` — `UserDefaults`(`CA92.1`). `CoreKitServices`의
  `NotificationScheduler`가 `UserDefaults`를 쓰고, 그 타겟이 앱에 링크되므로 호출 여부와
  무관하게 심볼이 바이너리에 들어간다. 그래서 선언한다.
- 그 외 required-reason API는 우리 코드에 없다 — 시스템 부팅 시각·디스크 용량·파일
  타임스탬프·활성 키보드 전부 미사용(광고 SDK는 자기 것을 자기 매니페스트에 선언한다).

**API를 추가할 때 다시 본다.** `@AppStorage`를 새로 쓰거나 파일 날짜를 읽기 시작하면 이
파일에 항목을 추가해야 하고, 빠지면 업로드 경고(ITMS-91053)로 돌아온다.
