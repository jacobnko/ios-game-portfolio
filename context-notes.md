# context-notes.md

작업 중 내린 결정과 그 이유를 계속 append한다.
다음 세션(사람이든 에이전트든)이 결정을 다시 유도하지 않아도 되게 하는 것이 목적이다.

---

## 2026-09-14 · S0.1 문서 뼈대

### D-001. 저장소는 모노레포, 게임은 독립 Xcode 프로젝트
- **결정.** `Packages/CoreKit` 하나 + `Apps/<Game>` 다수를 한 저장소에 둔다. 게임끼리는 의존하지 않는다.
- **이유.** `CoreKit`을 고치면 전 게임이 같은 커밋에서 함께 검증된다. 게임별 저장소로 쪼개면 버전 핀 관리 비용이 솔로 개발자에게 과하다.
- **대가.** 저장소가 커진다. 게임이 10개를 넘어가면 재검토한다.

### D-002. `CoreKit`을 3개 타겟으로 분리
- **결정.** `CoreKitJuice`(외부 의존 0) / `CoreKitData`(외부 의존 0) / `CoreKitServices`(AdMob · StoreKit · Firebase).
- **이유.** 광고/분석 SDK를 juice·데이터 레이어에 섞으면 SwiftUI Preview가 느려지고 유닛 테스트가 SDK를 요구하게 된다. juice는 반복해서 미세 조정할 코드라 Preview 속도가 곧 개발 속도다.
- **대가.** 타겟 3개를 관리해야 한다. 단일 타겟보다 초기 설정이 조금 더 든다.

### D-003. 주석과 `CLAUDE.md`는 영어, 작업 문서는 한국어
- **결정.** 코드 주석(파일 헤더 포함)과 `CLAUDE.md`는 영어. `PLAN.md` · `checklist.md` · `context-notes.md` · 디자인 핸드오프는 한국어.
- **이유.** 전역 규칙의 "한국어 파일 헤더 주석"과 프로젝트 규칙의 "주석 전부 영어"가 충돌했다. 공개 포트폴리오 코드라는 점을 근거로 영어를 택했다.
- **되돌리는 법.** `CLAUDE.md` §1의 해당 항목만 바꾸면 된다. 기존 파일은 점진적으로 정리한다.

### D-004. 디자인은 Claude Design으로 opt-out, 핸드오프 문서로만 연결
- **결정.** Claude Code는 에셋을 만들지 않는다. `docs/design/`의 D1~D6 카드를 스텝별 분할 실행한다.
- **이유.** Claude Design은 토큰 소모가 커서 한 세션에 게임 전체를 넘기면 컨텍스트가 터진다. 또한 아트 방향 결정은 사람이 중간에 개입해야 품질이 나온다.
- **운영 규칙.** 한 세션 = 한 카드. 이전 산출물은 원본이 아니라 **텍스트로 요약한 토큰(hex 색상, 폰트명, 키워드)** 만 다음 카드에 넘긴다.

---

## Open Questions — S0.3 착수 전에 답이 필요

### Q1. `CoreKitServices`가 Firebase까지 포함할 것인가
- 광고·결제는 전 게임 공통이 확실하다. 분석은 Firebase 대신 앱 타겟에서 주입하는 방식도 가능하다.
- **C의 제안.** 프로토콜은 `CoreKitServices`에 두고 Firebase 구현체도 같은 타겟에 둔다. 게임 10개가 전부 Firebase를 쓸 것이므로 추상화만 남기는 건 과설계다.
- **상태.** 미확정.

### Q2. 최소 지원 iOS 버전
- SwiftData + CloudKit은 iOS 17+, 일부 SwiftUI API와 String Catalog 개선은 iOS 18+에서 편하다.
- **C의 제안.** **iOS 18.0**. 캐주얼 게임 타깃층의 OS 업데이트율이 높고, 하위 호환 분기 비용이 신규 코드 속도를 깎는다.
- **상태.** 미확정.

### Q3. 번들 ID 규칙
- **확정.** `com.jacobkostudio.<codename>` / IAP `com.jacobkostudio.<codename>.removeads` (D-009).

### Q4. 원격 저장소 공개 여부
- 포트폴리오 목적이면 public이 유리하나, 광고 ID·번들 설정·퍼즐 데이터가 노출된다.
- **C의 제안.** private으로 시작하고, 첫 출시 후 `CoreKit`만 별도 public 저장소로 떼어낸다.
- **상태.** 미확정.

### Q5. 게임 #1 스테이지 데이터 생성 방식
- 손으로 만든 퍼즐 30개 vs 생성기 + 검증기.
- **C의 제안.** 검증기를 먼저 만들고(자동), 퍼즐 자체는 초반 30개만 수작업으로 난이도 곡선을 잡는다. 생성기는 게임 #1이 반응을 얻은 뒤에 만든다.
- **상태.** 미확정. Phase 3 진입 전까지만 답하면 된다.

---

## 2026-09-14 · S0.2 저장소 초기화

### D-005. Open Question Q1~Q4 확정
| | 질문 | 결정 | 이유 |
|---|---|---|---|
| Q1 | `CoreKitServices`에 Firebase 구현체 포함 | **포함한다** | 게임 10개가 전부 Firebase를 쓴다. 프로토콜만 남기는 건 과설계다 |
| Q2 | 최소 지원 iOS | **iOS 18.0** | 하위 호환 분기 비용이 신규 코드 속도를 깎는다. 캐주얼 타깃층의 OS 업데이트율이 높다 |
| Q3 | 번들 ID 규칙 | **`com.jacobkostudio.<codename>`** / IAP `com.jacobkostudio.<codename>.removeads` | 개인 앱이 아니라 스튜디오 포트폴리오라는 신호를 번들 ID 레벨에서 준다. **코드네임 기준이며 스토어 표시명과 무관하다** |
| Q4 | 원격 저장소 | **private으로 시작** | 첫 출시 후 `CoreKit`만 별도 public 저장소로 분리한다 |

### D-006. 게임 이름은 코드네임과 스토어 이름을 분리한다
- **결정.** 코드네임(폴더·타겟·번들 ID)은 Xcode 프로젝트 생성 시점에 고정하고, App Store 표시명은 출시 3주 전에 확정한다. 둘은 일치할 필요가 없다.
- **이유.** 번들 ID는 사실상 되돌릴 수 없지만 표시명은 새 버전과 함께 바꿀 수 있다. 이름 결정이 개발 착수를 막을 이유가 없다.
- **상세.** `docs/architecture/naming.md`

### D-007. 상표 위험 3건 때문에 코드네임을 미리 교체한다
- **결정.** `Streak Wordle` → `StreakWord`, `Meme Picross` → `MemeGram`, `Flappy Ragdoll` → `RagdollFlap`, `Juicy Flow` → `LineRush`.
- **이유.** "Wordle"은 NYT 등록상표, "Picross"는 Nintendo 상표다. "Flappy"는 2014년 Apple 대량 리젝 전례가 있다. "Flow Free"는 Big Duck Games 상표라 같은 장르에서 "Flow" 사용은 연상이 강하다.
- **시점 근거.** 번들 ID 확정 후에 바꾸면 프로젝트 전체를 따라가야 한다. 지금이 가장 싸다.
- **주의.** `PLAN.md` §Phase 5 표의 이름은 장르 식별용 작업명이므로 그대로 두되, 실제 프로젝트 생성 시 위 코드네임을 쓴다.

### D-008. 이름 중복 확인은 스크립트로 자동화한다
- **결정.** `scripts/check-name.sh <name> [country]` — iTunes Search API로 us/kr/jp 중복을 확인한다.
- **검증.** "Pipely"로 실행했더니 "Pipely - Flow Connect"(Souplin Labs)가 이미 존재했다. 스크립트가 실제로 작동한다.
- **한계.** App Store 등재 여부만 본다. **상표 검색(USPTO/KIPRIS)은 별도로 해야 한다.**

### D-009. 번들 ID 프리픽스를 `com.jacobkostudio`로 확정
- **결정.** `com.jacobkostudio.<codename>`, IAP는 `com.jacobkostudio.<codename>.removeads`.
- **이유.** 게임 10종을 묶는 포트폴리오이므로 개인 이름보다 스튜디오 네임스페이스가 맞다. 기존 `jacobko.app` 포트폴리오 앱들과도 구분된다.
- **주의.** 번들 ID는 App Store Connect에 한 번 등록되면 **삭제도 재사용도 불가능하다.** 오타 하나가 영구히 남으므로 첫 앱 등록 때 프리픽스 철자를 반드시 재확인한다.
- **확인 필요.** Apple Developer 포털의 App ID prefix(Team ID)는 그대로 두고, Bundle ID 문자열만 이 규칙을 쓴다.

### D-010. 커밋은 Claude가 자동으로 한다. AI attribution 트레일러는 붙이지 않는다
- **결정.** 스텝이 끝나면 Claude가 직접 `git add` + `git commit`까지 수행한다. 사용자에게 복붙용 명령을 넘기지 않는다. 커밋 메시지에 `Co-Authored-By` 등 AI 흔적을 남기지 않는다.
- **이유.** 전역 수정이 잦은 문서 작업 단계에서 수동 커밋은 순수 마찰이다. 또한 이 저장소는 공개 포트폴리오로 전환될 예정이라 커밋 로그가 사람의 작업 기록으로 읽혀야 한다.
- **경계.** `git push`는 자동화하지 않는다. 커밋은 되돌릴 수 있지만 push는 외부로 나가는 행위다.
