# 분석 이벤트 스키마

**게임 10개가 같은 이름을 쓴다.** 이름이 게임마다 다르면 비교가 불가능하고,
비교가 이 데이터를 모으는 이유 전부다. 게임별 차이는 **파라미터로만** 표현한다.

---

## 이벤트 목록

### 스테이지 퍼널
| 이벤트 | 파라미터 | 용도 |
|---|---|---|
| `stage_start` | `stage_id`, `attempt` | 진입 |
| `stage_clear` | `stage_id`, `attempt`, `duration_s`, `stars` | 클리어 |
| `stage_abandon` | `stage_id`, `attempt`, `duration_s`, `progress_pct` | **난이도 스파이크를 찾는 신호** |
| `hint_used` | `stage_id`, `source` | 힌트 사용 |

`stage_abandon`이 가장 중요하다. 특정 스테이지에서 이탈률이 튀면 거기가 난이도 벽이다.
`progress_pct`가 낮으면 "이해를 못 함", 높으면 "거의 다 왔는데 못 깸" — 처방이 다르다.

### 수익화
| 이벤트 | 파라미터 |
|---|---|
| `ad_shown` | `placement` (banner / interstitial / rewarded) |
| `ad_suppressed` | `verdict` |
| `reward_earned` | `placement` |
| `remove_ads_view` | `source` |
| `remove_ads_purchase` | `price` |
| `purchases_restore` | `restored` |

`ad_suppressed`는 노출만으로는 절대 안 보이는 것을 보여준다 — **정책이 과한지 모자란지.**
`onboardingGrace`가 대부분이면 유예가 너무 길고, `tooSoon`이 대부분이면 간격이 과하다.

### 바이럴
| 이벤트 | 파라미터 |
|---|---|
| `share_trigger` | `surface`, `stage_id` |

숏폼 영상은 리텐션·ASO와 나란한 세 번째 성장 레버인데, **이걸 로깅하지 않으면 존재 자체가 안 보인다.**

### 설정
| 이벤트 | 파라미터 |
|---|---|
| `setting_toggle` | `setting`, `enabled` |

---

## 쓰는 법

```swift
AnalyticsHub.shared.log(GameEvent.stageCleared(
    stageID: "s12", attempt: 3, durationSeconds: 24.1, stars: 2
))
```

**문자열로 직접 이벤트를 만들지 않는다.** `GameEvent`의 팩토리만 쓴다.
새 공통 이벤트가 필요하면 `GameEvent`에 추가하고, 그러면 10개 게임이 같이 갖게 된다.

게임 고유 이벤트는 `AnalyticsEvent(name:parameters:)`로 직접 만들되, **이름 앞에 게임 약어를 붙인다**
(`cl_pipe_reversed` 등). 그래야 공통 스키마와 섞이지 않는다.

---

## 자동 정규화 — 조용히 버려지는 것을 막는다

분석 백엔드는 잘못된 이벤트를 **에러 없이 그냥 버린다.** 몇 주 뒤 대시보드를 열었을 때
데이터가 없다는 걸로만 알게 된다. 그래서 `AnalyticsEvent`가 생성 시점에 정규화한다.

| 규칙 | 처리 |
|---|---|
| 이름 40자 초과 | 자른다 |
| 소문자·숫자·`_` 외 문자 | `_`로 치환 |
| 첫 글자가 문자가 아님 | 앞부분 제거 |
| `firebase_` `google_` `ga_` 접두사 | 제거 (예약어) |
| 파라미터 25개 초과 | **정렬 후** 자른다 (실행마다 달라지지 않게) |
| 문자열 값 100자 초과 | 자른다 |

`GameEvent`의 모든 이름이 정규화를 통과해도 변하지 않는지 테스트로 고정했다.
그래야 코드에 쓴 이름과 대시보드에 찍히는 이름이 같다.

---

## Firebase 연결

```swift
// 앱 시작 시 1회
FirebaseSetup.start()
```

`GoogleService-Info.plist`가 번들에 있어야 한다. **없으면 `configure()`가 트랩한다.**
이 파일은 `.gitignore` 대상이므로 게임 저장소마다 별도로 넣는다.

### 왜 별도 패키지인가
`CoreKitFirebase`는 `CoreKit`의 타겟이 아니라 **독립 패키지**다.
SwiftPM은 **빌드하는 타겟과 무관하게 패키지의 모든 의존성을 resolve**하기 때문에,
Firebase를 `CoreKit`에 넣으면 JuiceLab과 빠른 테스트 루프까지 전부
약 144MB · 최초 100초를 물게 된다. 실측값이다.

```
verify.sh                    → CoreKit + JuiceLab만 (빠름)
VERIFY_FIREBASE=1 verify.sh  → CoreKitFirebase까지
```

Firebase를 다른 것으로 바꾸게 되면 이 패키지만 교체하면 된다. 프로토콜과 스키마는 `CoreKitServices`에 남는다.

---

## 비치명적 에러도 기록한다

```swift
do { try store.save(progress) }
catch { AnalyticsHub.shared.record(error, context: ["stage": stageID]) }
```

`try?`로 삼킨 에러는 몇 달간 보이지 않는다. **살아남을 수 있는 실패도 보여야 한다.**
`context`가 없으면 Crashlytics 대시보드에 스택만 남고 어느 스테이지였는지 알 수 없다.
