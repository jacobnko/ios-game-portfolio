# 게임 이름 규칙 — 코드네임과 스토어 이름을 분리한다

## 결론부터

이름을 **두 개**로 나눠서 관리한다. 이게 "지금 정해야 하나" 문제를 없앤다.

| | 코드네임 | 스토어 이름 |
|---|---|---|
| 예시 | `LineRush` (번들 `com.jacobkostudio.linerush`) | `Loopflow` |
| 쓰이는 곳 | 폴더명 · Xcode 타겟 · 번들 ID(`com.jacobkostudio.<codename>`) · 내부 문서 | App Store 표시명 · 앱 아이콘 아래 이름 |
| 사용자에게 보이나 | **안 보인다** | 보인다 |
| 확정 시점 | **Xcode 프로젝트 만들 때** (Phase 2~3 초입) | **출시 3주 전** |
| 바꾸는 비용 | 높다. 번들 ID는 사실상 못 바꾼다 | 낮다. App Store Connect에서 새 버전과 함께 변경 가능 |

**번들 ID와 표시 이름은 일치할 필요가 전혀 없다.** `com.jacobkostudio.linerush`로 만들어 놓고 스토어에는 "Pipe Rush"로 내도 아무 문제 없다.
그래서 **코드네임만 지금 고정하고, 유니크한 스토어 이름은 디자인(D1) 끝난 뒤 천천히 고른다.**

---

## 지금 `PLAN.md`에 있는 이름들의 상표 위험

현재 목록은 **장르를 알아보기 위한 작업명**이다. 이대로 스토어에 내면 안 되는 것이 3개 있다.

| 현재 이름 | 위험도 | 내용 |
|---|---|---|
| **Streak Wordle** | **높음** | "Wordle"은 The New York Times 소유 등록상표다. NYT는 2022년 인수 후 Wordle 유사 앱에 실제로 DMCA/상표 조치를 해왔다. 이름에 쓰면 리젝 또는 퇴출 대상이다 |
| **Meme Picross** | **높음** | "Picross"는 Nintendo 상표다. 장르 일반명사는 **Nonogram**이다. 이쪽을 쓴다 |
| **Flappy Ragdoll** | **중간** | Flappy Bird 사태(2014) 이후 Apple은 이름에 "Flappy"가 들어간 앱을 대량 리젝한 전례가 있다. 상표는 아니지만 심사 마찰 비용이 크다 |
| **Juicy Flow** | 낮음~중간 | "Flow Free"는 Big Duck Games 상표다. "Flow" 단독은 일반어지만 같은 장르라 연상이 강하다. 피하는 편이 안전하다 |
| Domino Sudoku / Vault Breaker / Spicy Roller / Jelly Stack / Chain Buster / Chaos Breakout | 낮음 | Sudoku · Kakuro · Nonogram · Numberlink는 일반명사라 안전하다 |

**대응.** 코드네임은 장르 식별용으로 그대로 두되, 위험 3건은 **코드네임 단계에서 미리 갈아둔다.**
나중에 바꾸려면 번들 ID까지 따라가야 해서 비용이 커진다.

| # | 기존 | 권장 코드네임 |
|---|---|---|
| 1 | Juicy Flow | `LineRush` |
| 2 | Meme Picross | `MemeGram` (Nonogram 계열) |
| 3 | Streak Wordle | `StreakWord` |
| 6 | Flappy Ragdoll | `RagdollFlap` |

---

## 유니크한 스토어 이름 고르는 법

### 함정 하나
**완전히 독창적인 조어는 검색 유입이 0이다.** "Zyblo"는 아무도 검색하지 않는다.
그래서 표준 전략은 이렇다.

```
앱 이름 (30자)  =  유니크한 브랜드명            ← 중복 회피 + 상표 안전
부제 (30자)     =  장르 키워드 덩어리           ← ASO 검색 유입 담당
```

예시.
- 이름 `Loopflow` / 부제 `Color Pipe Connect Puzzle`
- 이름 `Gridwake` / 부제 `Nonogram Picture Logic`

App Store 검색 인덱스는 **이름과 부제 둘 다** 읽는다. 키워드는 부제에 몰아넣고, 이름은 중복 회피에만 쓴다.

### 조어 만드는 패턴
1. **합성** — 게임 동사 + 짧은 명사 (`Loopflow`, `Gridwake`, `Tapmire`)
2. **접미 변형** — 명사 + `-ly` / `-io` / `-ify` / `-eo` (단, `-ly`는 포화 상태다)
3. **의성어/의태어** — 도파민 트위스트의 소리에서 따온다 (`Klonk`, `Fizzle`, `Thunk`)
4. **오타 조어** — 실제 단어를 한 글자 비틀기 (`Puzzel`, `Konnect`)

이 포트폴리오는 도파민 트위스트가 게임마다 다르므로, **3번(소리에서 따오기)이 가장 잘 맞는다.** 이름 자체가 게임의 감각을 설명한다.

### 검증 4단계 — 순서대로, 하나라도 걸리면 버린다

```bash
# 1. App Store 중복 확인 (us / kr / jp 각각)
./scripts/check-name.sh "Loopflow" us
./scripts/check-name.sh "Loopflow" kr
./scripts/check-name.sh "Loopflow" jp
```

2. **상표 검색.** 미국 [USPTO TESS](https://tmsearch.uspto.gov), 한국 [KIPRIS](http://www.kipris.or.kr) 에서 클래스 9(소프트웨어) · 41(게임 서비스) 확인.
3. **도메인/핸들.** `.com` 또는 `.app` 하나는 잡아둔다. 웹 게임 트랙(§9)에서 쓴다.
4. **App Store Connect 예약.** 여기서 앱 레코드를 만드는 순간 이름이 선점된다. **이 단계가 진짜 확정이다.**

> 주의. App Store Connect는 90일 안에 앱을 제출하지 않으면 예약한 이름을 회수한다. 출시가 확실해진 뒤에 예약한다.

### 하지 말 것
- 이름에 `Free`, `Best`, `#1`, `Pro` 같은 수식어 넣기 — Apple 심사에서 마찰이 생긴다
- 다른 인기 게임 이름을 변형해서 쓰기 — 4.3(스팸)과 상표 양쪽에 걸린다
- 이모지·특수문자 — 검색이 안 된다
- 30자 꽉 채우기 — 홈 화면에서는 12자 정도만 보인다. **아이콘 아래 잘리는 길이까지 고려한다**

---

## 확정 시점 정리

```
Phase 2 (앱 템플릿)   → 코드네임 확정. 번들 ID 고정. 되돌리기 비쌈
D1 (브랜드/팔레트)    → 스타일 키워드가 나오면 이름 후보 5~10개 뽑기 시작
D2 (아이콘)           → 후보 좁히기. 아이콘과 이름이 같이 읽히는지 본다
출시 3주 전           → check-name.sh + 상표 검색 통과 → App Store Connect 예약
```
