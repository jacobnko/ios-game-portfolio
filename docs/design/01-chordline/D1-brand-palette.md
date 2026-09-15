# D1. 브랜드 방향 · 팔레트 · 타이포 — Chordline

**목적.** 이 게임의 시각 정체성을 텍스트 토큰으로 확정한다. 이후 모든 카드가 이 결과만 참조한다.
**선행.** `00-brief.md` 작성 완료. (완료됨)
**예상 규모.** 짧음. 이미지 생성 없이 팔레트 보드 1장이면 충분하다.
**모델.** Opus (`docs/design/README.md` 참조 — 브랜드 정체성은 일회성 고부가 결정).

## Claude Design에 붙여넣을 프롬프트

```
모바일 캐주얼 퍼즐 게임의 시각 정체성을 잡아줘. 아트워크 말고 팔레트 보드 1장만 필요해.

게임: Chordline
장르: 같은 색 점을 이어 격자를 채우는 Numberlink 변형 논리 퍼즐
핵심 순간: 선을 이을 때마다 음이 반음씩 올라가고, 완성되면 화면의 모든 파이프가 동시에 빛을 뿜어낸다
한 판 길이: 10~30초
타깃 감정: 정리 욕구 해소, 완성했을 때의 손맛 + 청각적 쾌감

세계관 참고 (그대로 재현하지 말고 방향으로만 참고):
밤의 회로 기판. 꺼져 있는 신호선을 이어 붙이면 전류가 흐르고, 흐르는 순간 소리가 난다.
어두운 배경에 형광 라인이 살아나는 신스웨이브 톤.

이 게임이 포트폴리오의 첫 번째 게임이라 아직 피해야 할 색은 없어. 대신:
- 라이트/다크 모드 양쪽에서 성립해야 함
- 색맹 사용자가 게임 요소를 구분할 수 있어야 함 (색만으로 구분하지 않는 보조 신호 제안 포함) —
  특히 이 게임은 "같은 색 점 구분"이 핵심 규칙이라 이 제약이 중요함
- 글로우/네온 효과가 어울리는 팔레트로 (완성 시 파이프가 빛을 뿜는 연출이 있음)

출력 형식:
1. 팔레트 보드 1장 — primary / secondary / accent / background / surface, hex 포함
2. 타이포 추천 1세트 — 헤드라인 폰트 + 숫자 표시용 폰트, 이름과 이유 (기하학적 산세리프 계열 선호)
3. 스타일 키워드 5개
4. 아이콘 모티프 한 줄 제안
텍스트 요약은 복사하기 쉽게 마지막에 한 블록으로 모아줘.
```

## 산출물

- [x] 팔레트 보드 → `assets/Chordline D1 Palette Board.html` (Claude Design 번들, 다크/라이트 양쪽 보드 + 5x5 데모 그리드)
- [x] 아래 표 채우기 (이게 진짜 산출물이다)

### 코어 팔레트

| 역할 | dark (기본 룩) | light | 이름 |
|---|---|---|---|
| primary | `#1FE3CF` | `#0E8F85` | Signal Cyan |
| secondary | `#7C5CFF` | `#4B32C8` | Circuit Violet |
| accent | `#FFB03A` | `#9A5B00` | Pulse Amber |
| background | `#070B14` | `#EEF1F7` | Board Black / Paper |
| surface | `#121B2E` | `#FFFFFF` | Etch Navy / Card |
| onSurface (ink) | `#E6F1FF` | `#0B1220` | |

**다크가 기본 룩이다.** 라이트는 대응용이지 축소판이 아니다 — 라이트 값은 종이 위에서
살아남아야 해서 명도가 완전히 다르게 잡혀 있다.

### 시그널 리드 6종 (보드 색)

`Puzzle`의 색 인덱스 0~5이 그대로 이 순서다. 앞쪽일수록 대비가 크므로,
색을 적게 쓰는 보드는 자동으로 가장 잘 구분되는 색만 쓰게 된다.

| # | 이름 | dark | light | 노드 글리프 | 라인 텍스처 |
|---|---|---|---|---|---|
| 0 | Cyan Lead | `#1FE3CF` | `#0E8F85` | circle | solid |
| 1 | Magenta Lead | `#FF4FA3` | `#C21D6B` | square | dashed |
| 2 | Amber Lead | `#FFB03A` | `#9A5B00` | triangle | dotted |
| 3 | Violet Lead | `#7C5CFF` | `#4B32C8` | diamond | double |
| 4 | Lime Lead | `#A6E831` | `#4F7A00` | hexagon | chevron |
| 5 | Ice Lead | `#BFD8FF` | `#2C4A7A` | cross | beaded |

### 타이포

- 헤드라인 폰트: **Sora** (300/600/800) — 기하학적, 각진 종단, 한글 조판 안정
- 숫자 폰트: **JetBrains Mono** (400/700) — tabular, slashed zero, 타이머 흔들림 없음
- ⚠️ **아직 코드에 넣지 않았다.** 폰트 파일이 번들에 없는 상태에서 `Font.custom`에 이름만
  적으면 **경고 없이 시스템 폰트로 떨어진다** (B-15과 같은 부류). `.ttf`가 들어오는 시점에
  `ThemeTypography.displayFamily` / `bodyFamily`를 함께 채운다.

### 나머지

- 스타일 키워드 5개: Night Circuit / Charged Minimal / Bloom on Black / Orthogonal Grid / Audible Light
- 아이콘 모티프: 직각으로 꺾여 만나는 두 신호선이 C자 회로를 이루고 **양 끝 노드만 발광**
- 색 외 보조 구분 신호 (CVD 대응):
  1. **노드 글리프 6종이 1차 신호** — 짝 찾기는 모양으로 성립하고, 색은 강화 신호다
  2. **라인 텍스처 6종이 2차 신호** — 선이 엉킨 구간에서 한 줄을 끝까지 추적할 수 있다
  3. **L\* 12 이상 간격의 명도 계단** — 흑백으로 떨어뜨려도 서열이 유지된다
- 글로우 규칙: **라인 코어는 항상 불투명**, 번짐은 `box-shadow`(iOS에서는 `.shadow`)로만.
  라이트 모드에서는 글로우를 컬러 드롭섀도로 번역한다.

## 코드 반영 위치

| 값 | 위치 |
|---|---|
| 리드 6종 (hex·글리프·텍스처) | `Apps/Chordline/Sources/ChordlineCore/SignalLead.swift` |
| 코어 팔레트 · 타이포 · 메트릭 | `Apps/Chordline/Sources/ChordlineUI/GameTheme+Chordline.swift` |
| hex → `Color` 변환 | `Packages/CoreKit/Sources/CoreKitUI/Color+Hex.swift` |

글리프와 텍스처가 **순수 로직 타깃에 있는 이유**: 이건 장식이 아니라 가독성 계약이다.
렌더러가 이걸 빠뜨리면 그냥 밋밋해지는 게 아니라 색맹 플레이어에게 **게임이 성립하지 않는다.**

## 미해결 — S3.7로 넘김

D1은 **한 판 최대 5색**을 전제하는데, `PuzzleGenerator.balancedConfiguration`은 격자 넓이에
비례해서 색을 늘린다. 실측값:

| 보드 | 실제 생성된 색 수 | 팔레트로 칠할 수 있나 |
|---|---|---|
| 5x5 | 5~6 | 리드 6종 안에는 들어옴 (5색 캡은 이미 초과) |
| 6x6 | 7~9 | ❌ |
| 7x7 | 9~12 | ❌ |
| 8x8 | 11~16 | ❌ |

`ChordlinePalette.lead(for:)`는 6 이상에서 `nil`을 돌려주므로 조용히 깨지지는 않는다.
`Tests/ChordlineCoreTests/PaletteCapacityTests.swift`가 이 격차를 측정값으로 고정해 둔다.
자세한 내용은 `context-notes.md` D-076.

## 완료 조건
- [x] `docs/concepts/palette-ledger.md`에 한 줄 추가 (이 게임이 첫 줄이 된다 — 이후 게임들이 이 팔레트를 피함)
- [x] 위 표 값이 코드의 `GameTheme.chordline`으로 옮겨졌다 (`docs/architecture/new-game-setup.md` §5 참조)
- [ ] Sora / JetBrains Mono `.ttf` 번들 후 `ThemeTypography` 채우기
- [ ] S3.7에서 생성기 색 수를 팔레트 용량에 맞추기
