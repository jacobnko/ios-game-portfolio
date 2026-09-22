# 인앱 결제 (광고 제거) 설정 가이드

`CoreKitServices`의 `PurchaseManager`는 코드만 제공한다. 실제로 팔리려면 아래가 필요하다.

---

## 1. 제품 규칙

| 항목 | 값 |
|---|---|
| 유형 | **비소모성 (Non-Consumable)** — 게임당 1개 |
| 제품 ID | `com.jacobkostudio.<codename>.removeads` |
| 시작 가격 | **$2.99** (≒ ₩3,900 / ¥450). 고정 규칙이 아니라 출발점이고, 실제 전환 데이터로 재조정한다 |
| 수수료 | 기본 30%. **Small Business Program 신청 시 15%** — 연 매출 100만 달러 미만이면 즉시 신청한다 |

제품 ID는 `ProductID.removeAds(bundleID:)`가 만들어 준다. 문자열을 직접 쓰지 않는다.

---

## 2. App Store Connect

1. 앱 → 기능 → App 내 구입 → **비소모성** 추가
2. 제품 ID를 위 규칙대로 입력. **한 번 만들면 삭제할 수 없다.** 오타를 조심한다
3. 가격 등급 선택
4. 현지화 — 표시 이름과 설명을 **7개 언어 각각** 입력한다 (§11 언어 목록)
5. 심사용 스크린샷 1장 첨부 (구매 버튼이 보이는 화면)
6. 첫 제출 시 **앱 바이너리와 함께** 심사에 올라간다. 별도 제출이 아니다

---

## 3. 개발 중 테스트 — StoreKit Configuration 파일

App Store Connect 없이 구매 흐름을 돌릴 수 있다. `Tools/JuiceLab/JuiceLab.storekit`이 그 예다.

**Xcode에서 확인할 것 — Edit Scheme → Run → Options → StoreKit Configuration 드롭다운.**
파일이 선택되어 있어야 한다. 비어 있으면 직접 고른다.

> 주의. 이 설정은 **Xcode에서 실행할 때만** 적용된다. `xcrun simctl launch`로 띄우면 무시되고
> 제품 조회가 `productNotFound`로 실패한다. 콘솔 확인으로는 검증되지 않는다.

### Debug → StoreKit 메뉴로 할 수 있는 것
- **Manage Transactions** — 구매 취소·환불·취소(revoke)
- Ask to Buy 시뮬레이션 → `pending` 경로 확인
- 구매 실패·지연 시뮬레이션

**환불 테스트를 반드시 한다.** 환불 후 `adsRemoved`가 `false`로 돌아와야 한다.
이게 엔타이틀먼트를 캐시하지 않고 `currentEntitlements`에서 파생하는 이유 전부다.

### 실제 샌드박스 테스트
App Store Connect → 사용자 및 액세스 → Sandbox 테스터 계정 생성 후, 기기의
설정 → App Store → Sandbox 계정으로 로그인한다. StoreKit Configuration 파일보다 느리지만 실제에 가깝다.

> ⚠️ **실기기에서 실행해도 로컬 파일이 붙어 있으면 무조건 로컬로 간다.**
> `Chordline` 스킴은 `Chordline.storekit`을 물고 있어서(개발 편의), 샌드박스
> 계정으로 로그인한 실기기에서 실행해도 결제 시트에 `[Environment: Xcode]`가
> 뜬다 — `[Environment: Sandbox]`가 아니다. 실기기인지 여부와 무관하게 **스킴에
> StoreKit Configuration이 붙어 있는지**가 결정한다.
>
> 진짜 샌드박스로 확인하려면 **`Chordline-Sandbox` 스킴**을 실행한다. 로컬 파일이
> 빠진 것만 다른 동일한 스킴이다. `Edit Scheme`에서 매번 껐다 켰다 하지 않는
> 이유는 그 조작이 project.yml에 없어서 `xcodegen generate`를 다시 돌리면
> 조용히 원복되기 때문 — 스킴을 둘로 나눠서 실수로 되돌아갈 여지를 없앴다.

---

## 4. 코드에서 지켜야 할 것

```swift
// 앱 시작 시 1회
let purchases = PurchaseManager()
purchases.start()

// 광고 호출부는 전부 이 하나의 게이트 뒤에
if !purchases.adsRemoved { adManager.showInterstitial() }
```

- **`adsRemoved`를 직접 세팅하지 않는다.** 항상 `currentEntitlements`에서 파생된다.
- **`start()`를 앱 시작 시 호출한다.** 구매 업데이트 리스너가 없으면 Ask to Buy 승인, 다른 기기에서의 구매, 중단됐다 완료된 결제를 놓친다. 사용자는 돈을 냈는데 아무 일도 안 일어난다.
- **`.pending`을 실패로 처리하지 않는다.** 승인 대기 상태이고 나중에 도착한다.
- **`.unverified`는 구매가 아니다.** 서명이 검증되지 않은 거래는 아무것도 부여하지 않는다.
- **"구매 복원" 버튼은 필수다.** 비소모성은 자동 복원되지만 버튼이 없으면 심사에서 리젝된다.

---

## 5. 심사 체크

- [ ] 구매 복원 버튼이 존재하고 **실제로 동작한다**
- [ ] 제품 설명이 7개 언어로 현지화되어 있다
- [ ] 구매 실패·취소 시 앱이 멈추지 않는다
- [ ] 광고 제거 후 **모든** 광고 지점이 사라진다 (전면·배너·보상형 중 하나라도 남으면 안 된다)
- [ ] 가격을 직접 포맷하지 않고 `displayPrice`를 쓴다
