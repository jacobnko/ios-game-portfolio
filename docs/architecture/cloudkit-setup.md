# CloudKit + SwiftData 설정 가이드

`CoreKitData`는 코드만 제공한다. **동기화가 실제로 동작하려면 앱 타겟 설정이 필요하다.**
여기 적힌 것 중 하나라도 빠지면 로컬 저장은 되는데 동기화만 조용히 안 된다.

---

## 1. 앱 타겟 설정 (게임마다 1회)

1. **Signing & Capabilities → + Capability → iCloud**
2. Services에서 **CloudKit** 체크
3. Containers에서 컨테이너 추가 — `iCloud.com.jacobkostudio.<codename>`
4. **+ Capability → Background Modes → Remote notifications** 체크
   - 빠뜨리면 앱이 실행 중일 때만 동기화된다. 백그라운드 푸시로 받는 변경이 전부 유실된다.

```swift
// App 진입점
let store = ProgressStore(container: try ProgressStore.makeContainer())
```

---

## 2. 스키마 제약 — 어기면 런타임에 죽는다

`@Model`이 CloudKit을 쓰면 컴파일은 되는데 **앱 시작 시 컨테이너 생성에서 크래시**한다. 컴파일러가 잡아주지 않는다.

| 규칙 | 이유 |
|---|---|
| 모든 프로퍼티가 **optional이거나 기본값**을 가져야 한다 | CloudKit에는 NOT NULL 컬럼이 없다 |
| **`@Attribute(.unique)` 사용 불가** | CloudKit에는 유니크 인덱스가 없다 |
| 관계(relationship)는 **optional**이어야 하고 역관계가 있어야 한다 | 부분 동기화 중 한쪽만 도착할 수 있다 |
| `@Attribute(.externalStorage)`는 쓸 수 있다 | 큰 바이너리는 CKAsset으로 간다 |

`StageRecord`는 이 규칙을 전부 지킨다. **새 모델을 추가할 때 같은 규칙을 적용한다.**

### 유니크 제약이 없다는 것의 실제 결과

기기 두 대가 같은 스테이지에 대해 각각 행을 만들면 **둘 다 살아남는다.** DB가 막아주지 않는다.
그래서 `ProgressStore`가 읽기·쓰기마다 중복을 병합하고 여분 행을 지운다.
병합 규칙은 **멱등(idempotent)** 이어야 한다 — 동기화는 여러 번에 걸쳐 수렴하고 그때마다 병합이 다시 돈다.

---

## 3. 출시 직전에 반드시 — 스키마를 Production으로 배포

**이게 가장 흔한 출시 사고다.**

개발 중 SwiftData가 만드는 CloudKit 스키마는 **Development 환경에만** 존재한다.
Production으로 자동 승격되지 않는다. 이 상태로 App Store에 올리면 **실사용자에게만 동기화가 실패한다.**

1. [CloudKit Console](https://icloud.developer.apple.com) → 해당 컨테이너
2. Schema → **Deploy Schema to Production**
3. 배포 후 Development에서 필드를 추가했다면 **다시 배포해야 한다**

> **Production 스키마는 추가만 가능하다.** 필드 이름 변경·삭제·타입 변경이 불가능하다.
> 그래서 첫 출시 전에 스키마를 신중히 확정한다. 이후 변경은 "새 optional 필드 추가"만 가능하다고 생각해야 한다.

---

## 4. 개발 중 주의

- **시뮬레이터 동기화는 신뢰할 수 없다.** 실기기 2대 또는 기기 1대 + 재설치로 검증한다.
- 기기에 **Apple ID가 로그인되어 있고 iCloud Drive가 켜져 있어야** 한다.
- 동기화는 즉시가 아니다. 수 초에서 수 분 걸린다. 안 된다고 단정하기 전에 기다린다.
- 개발 중 스키마를 바꿨는데 이상하게 굴면 CloudKit Console에서 **Development 환경을 Reset**한다. Production은 리셋할 수 없다.

### 삭제 후 재설치 복원 테스트

1. 기기에서 게임 실행, 스테이지 몇 개 클리어
2. 동기화 대기 (1~2분)
3. **앱 삭제**
4. 재설치 후 실행 → 진행도가 돌아와야 한다

---

## 5. 경계 — 광고 제거는 여기 없다

**광고 제거 상태를 CloudKit에 저장하지 않는다.** 유일한 진리는 `Transaction.currentEntitlements`다.

CloudKit 플래그를 신뢰하면 두 가지가 깨진다.
- 동기화가 안 되는 사용자가 **구매한 광고 제거를 못 받는다**
- 반대로 동기화 데이터를 조작해서 **결제 없이 광고를 제거할 수 있다**

진행도는 편의 기능이라 유실돼도 게임이 계속되지만, 엔타이틀먼트는 그렇지 않다.
