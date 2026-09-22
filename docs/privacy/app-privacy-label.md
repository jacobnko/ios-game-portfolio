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
개발자가 신고하게 한다. 아래 6개가 Google의 공식 목록을 Apple의 데이터 타입으로 옮긴 것.

| Apple 데이터 타입 | 분류 | 목적 | 연결 | 추적 |
|---|---|---|---|---|
| 대략적인 위치 (Coarse Location) | 위치 | 서드 파티 광고, 분석 | 연결 안 됨 | 예 |
| 기기 ID (Device ID) | 식별자 | 서드 파티 광고, 분석 | 연결 안 됨 | 예 |
| 제품 상호작용 (Product Interaction) | 사용 데이터 | 서드 파티 광고, 분석 | 연결 안 됨 | 예 |
| 광고 데이터 (Advertising Data) | 사용 데이터 | 서드 파티 광고, 분석 | 연결 안 됨 | 예 |
| 성능 데이터 (Performance Data) | 진단 | 서드 파티 광고, 분석, 앱 기능 | 연결 안 됨 | 예 |
| 비정상 종료 데이터 (Crash Data) | 진단 | 앱 기능 | 연결 안 됨 | 아니요 |

### 왜 이렇게 답하는지

- **대략적인 위치** — Google이 "IP 주소가 기기의 대략적인 위치를 예상하는 데 사용될 수
  있다"고 명시한다. 앱은 위치 권한을 요청하지 않지만, IP 기반 추정도 Apple의 Coarse
  Location에 해당하므로 신고한다.
- **전부 "연결 안 됨"** — Apple의 "연결"은 신원(계정·이름·이메일)과의 연결이다.
  Chordline에는 계정이 없어서 연결할 신원 자체가 없다. 예외 없이 전부 연결 안 됨.
- **추적 "예"** — ATT 승인 시 개인 맞춤 광고가 게재되고, 비개인화 광고를 강제하는 설정도
  없다. 광고 관련 타입은 제3자 데이터와 결합되므로 추적에 해당한다. 그래서 ATT 프롬프트가
  필요하고, `AdSetup.start()`가 실제로 그걸 띄운다 — 라벨과 코드가 일치한다.
- **비정상 종료 데이터만 추적 "아니요"** — Google의 표현이 "비사용자 관련 비정상 종료
  로그"이고 용도는 SDK 개선이다. 같은 문서가 "진단 정보도 광고·분석에 사용될 수 있다"고
  덧붙이므로, 더 보수적으로 가려면 여기도 "예"로 둘 수 있다. 판단이 갈리는 유일한 칸이다.

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

## 함께 볼 것 — privacy manifest

Apple은 2024년부터 SDK의 privacy manifest를 요구한다. `GoogleMobileAds.framework`는
자기 `PrivacyInfo.xcprivacy`를 **포함하고 있다**(빌드 산출물에서 확인).

**앱 타겟에는 `PrivacyInfo.xcprivacy`가 없다.** 앱 레벨 매니페스트는 (a) required-reason
API를 직접 쓸 때와 (b) 추적 도메인(`NSPrivacyTrackingDomains`)을 선언할 때 필요하다.
Chordline은 `UserDefaults` 등 required-reason API를 코드에서 직접 쓰지 않아 업로드가
막힐 가능성은 낮지만, 추적하는 앱이므로 `NSPrivacyTracking`과 추적 도메인을 앱 레벨에서
선언해두는 게 정석이다. 출시 전 확인 항목.
