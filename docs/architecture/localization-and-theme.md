# 로컬라이즈와 테마

게임끼리 **달라야 하는 것은 `GameTheme` 하나**, **같아야 하는 것은 공통 문자열**이다.

---

## 1. `GameTheme` — Guideline 4.3 대응의 실체

```swift
ContentView().gameTheme(.myGameTheme)
```

게임플레이 코드는 색이나 폰트를 **절대 하드코딩하지 않고** `@Environment(\.gameTheme)`에서 읽는다.
테마 값 하나를 바꾸면 화면 전체가 바뀐다.

| 구성 | 왜 필요한가 |
|---|---|
| `ThemePalette` | 색. 라이트/다크 각각 |
| `ThemeTypography` | **폰트 패밀리까지 포함.** 10개 게임이 전부 시스템 폰트면 심사자에게 같은 앱으로 보인다 |
| `ThemeMetrics` | 모서리 반경·간격·그림자. 바꾸기 싸고 체감 차이는 색보다 크다 |

색만 바꾸는 것으로는 부족하다. **팔레트 · 타이포 · 모서리 세 축을 같이 벌려야** 나란히 놓았을 때 다른 앱으로 보인다.
`GameTheme.placeholder`는 중립 기본값일 뿐이고, **그대로 출시하면 그게 바로 "다 똑같아 보이는" 문제다.**

### 승리 연출도 테마를 따라간다
```swift
.victorySequence(isPresented: $won, configuration: theme.victoryConfiguration(multiplier: 4))
```
타이밍과 물리는 공유해서 "같은 손이 만든 느낌"을 유지하고, **팔레트와 시드만 게임마다 다르다.**

### 다크 모드
`ThemeColor`는 라이트·다크 두 값을 가진다. 한 색으로 양쪽을 때우면 절반의 기기에서 망가져 보인다.

---

## 2. 문자열

### 공통 문자열은 `CoreKitUI`에 있다
`CommonStrings`는 모든 게임이 쓰는 26개 키를 갖는다 — 버튼, 설정 항목, 구매 복원, 개인정보처리방침 등.

```swift
Text(CommonStrings.settingsRestorePurchases.text)
```

**게임마다 따로 번역하지 않는다.** "구매 복원"이 10개 앱에서 3가지로 번역되는 일을 막고,
번역 누락이 10번이 아니라 1번만 생기게 한다.

게임 고유 문자열은 게임의 자체 `.xcstrings`에 넣는다. 하드코딩은 어느 쪽이든 금지다.

### ⚠️ String Catalog와 SwiftPM
**`swift build`는 `.xcstrings`를 컴파일하지 않는다.** 원본 파일을 번들에 복사만 한다.
카탈로그 컴파일러(`xcstringstool`)는 Xcode 빌드 단계이므로, `xcodebuild`로 빌드해야
`en.lproj/Common.strings`가 생긴다.

결과적으로 **호스트(`swift test`)에서는 모든 키가 자기 자신으로 해석된다.**
그래서 테스트는 런타임 해석이 아니라 **카탈로그 JSON을 데이터로 검증**한다 — 키 존재, 출시 언어 번역 존재, 고아 키 없음.
런타임 해석은 iOS 빌드와 JuiceLab이 확인한다.

또한 `Package.swift`에 **`defaultLocalization: "en"`이 없으면 로컬라이즈 리소스가 아예 처리되지 않는다.**
있으나 없으나 빌드는 성공하고, 런타임에 키가 그대로 노출되는 것으로만 알게 된다.

---

## 3. 언어 변경 — 앱이 직접 하지 않는다

```swift
LanguageSettings.openSystemLanguageSettings()
```

**`AppleLanguages` UserDefaults를 덮어쓰지 않는다.** iOS 13 이후로 신뢰할 수 없고,
앱과 시스템이 다음 실행까지 서로 다른 언어를 믿는 상태가 될 수 있다.
설정 앱의 앱별 언어 선택기로 보내는 것이 유일하게 지원되는 경로다.

### 언어 목록
출시는 **영어 + 한국어**로 시작한다. 나머지 5개(일본어·독일어·스페인어(중남미)·포르투갈어(브라질)·프랑스어)는
Analytics에서 트래픽이 잡히는 국가부터 게임별로 추가한다.

**번역 품질이 낮은 화면은 전환율을 오히려 깎는다.** 7개를 한 번에 채우는 것이 목표가 아니다.

스페인어는 `es-MX`, 포르투갈어는 `pt-BR`을 쓴다. 캐주얼 게임 다운로드 볼륨이 그쪽에 있다.

---

## 4. 새 게임에서 할 일

1. `GameTheme`을 만든다 — `docs/concepts/palette-ledger.md`에서 인접 게임과 겹치지 않는지 확인
2. 루트에 `.gameTheme(...)` 적용
3. 게임 고유 `.xcstrings` 생성 (공통 키는 만들지 않는다)
4. 설정 화면에 언어 버튼 → `LanguageSettings.openSystemLanguageSettings()`
5. 색·폰트 하드코딩이 없는지 확인
