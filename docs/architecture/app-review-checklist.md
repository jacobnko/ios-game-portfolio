# App Review 리젝 체크리스트

**출시 직전, 제출 버튼을 누르기 전에** 이 문서 전체를 다시 훑는다. 항목 대부분은
Phase 1~3에서 이미 코드로 막아뒀다 — 여기서는 "그 방어가 실제로 켜져 있는지"를 확인한다.
코드가 맞아도 설정(Info.plist, App Store Connect 필드)이 빠지면 리젝된다.

포트폴리오 10개 게임이 `CoreKit` 위에서 똑같은 구조를 쓰므로, 이 체크리스트는
**게임마다 반복**한다. 첫 게임(Chordline)에서 걸린 항목은 나머지 9개도 걸린다.

---

## 1. Guideline 2.3 — 정확한 메타데이터

| 항목 | 확인 방법 | 근거 |
|---|---|---|
| [ ] 스크린샷이 실제 앱 화면과 일치 | 스크린샷 속 배너 광고 위치가 실제 배치와 같은지 | D6 체크리스트, 허위 표현 리젝 방지 |
| [ ] 부제(Subtitle)에 키워드 욱여넣기 없음 | "Brandname - Puzzle Free Best" 형태 금지 | `app-store-metadata.md` |
| [ ] 배너 광고가 인터랙티브 UI를 가리거나 밀지 않음 | `AdBannerSlot`이 로드 전에도 높이 확보하는지 실기기 확인 | Guideline 2.3.1, `admob-setup.md` §3 |
| [ ] 소리 있는 광고가 사용자 동작 없이 자동재생 안 됨 | 전면/보상형 노출 시 직접 확인 | `admob-setup.md` §5 |

## 2. Guideline 2.1 — 앱 완성도 (크래시·깨진 링크)

| 항목 | 확인 방법 |
|---|---|
| [ ] `GADApplicationIdentifier`가 실제 Info.plist에 들어있음 (`INFOPLIST_KEY_*` 아님) | `plutil -extract GADApplicationIdentifier raw <App>.app/Info.plist` |
| [ ] CloudKit 스키마가 Production에 배포됨 | CloudKit Console → 해당 컨테이너 → Schema |
| [ ] 개인정보처리방침 링크가 실제로 열림 (404 아님) | 실기기에서 Settings → 개인정보처리방침 탭 |
| [ ] "구매 복원"이 실제로 복원함 | Sandbox 계정으로 구매 → 삭제·재설치 → 복원 |
| [ ] 진행도가 삭제 후 재설치에서 복원됨 | `cloudkit-setup.md` §4 "삭제 후 재설치 복원 테스트" |

## 3. Guideline 5.1 — 개인정보 (가장 흔한 리젝 원인 중 하나)

| 항목 | 확인 방법 |
|---|---|
| [ ] ATT 프롬프트가 앱이 active 상태가 된 **후에** 뜸 (즉시 아님) | `admob-setup.md` — active 이전 요청은 조용히 거부됨 |
| [ ] `NSUserTrackingUsageDescription` 문구가 실제로 트래킹 목적을 설명함 | Info.plist 직접 확인 |
| [ ] App Store Connect의 "앱 개인정보" 라벨이 실제 수집 데이터와 일치 | §5 참조 — AdMob·Firebase·StoreKit이 실제로 뭘 모으는지 |
| [ ] 개인정보처리방침이 앱이 실제로 하는 일을 설명함 (템플릿 복붙 아님) | `docs/privacy/` 참조 |
| [ ] 위치 정보를 요청하지 않음 (이 포트폴리오는 위치 데이터 불필요) | 코드에 `CLLocationManager` 없음 확인 |

## 4. Guideline 4.3 — 스팸 (템플릿 게임 10개로 몰릴 위험)

**이 포트폴리오 전체가 가장 취약한 지점.** 게임 10개가 같은 `CoreKit` 위에서 만들어지므로,
심사관이 "같은 앱을 복붙했다"고 판단하면 전부 몰려서 리젝될 수 있다.

| 항목 | 확인 방법 |
|---|---|
| [ ] 이 게임의 팔레트·아이콘 스타일·폰트가 **직전에 출시한 게임과 겹치지 않음** | `docs/concepts/palette-ledger.md`, D1 카드의 "인접 위험" 문단 |
| [ ] 핵심 메커닉이 실제로 다름 (스킨만 바꾼 게 아님) | `docs/concepts/game-concepts.md`의 "포트폴리오 차별화 점검" 표 |
| [ ] 앱 설명·스크린샷이 이 게임 고유의 도파민 트위스트를 보여줌 | D6 카드 |
| [ ] 번들 ID·앱 이름·아이콘이 다른 게임과 시각적으로 혼동되지 않음 | 나란히 놓고 비교 (D2 완료 조건) |

## 5. 데이터 수집 실사 — 이 포트폴리오가 실제로 모으는 것

개인정보 라벨과 개인정보처리방침을 쓰려면 **실제로 뭘 모으는지** 정확히 알아야 한다.
추측해서 쓰면 실제 수집과 라벨이 어긋나고, 그 자체가 리젝 사유다 (5.1.1).

| SDK | 수집 데이터 | 용도 | 사용자 연결 |
|---|---|---|---|
| **Google AdMob** | 광고 ID(IDFA, ATT 허용 시), 기기 정보, 대략적 위치 | 광고 게재·기여도 측정 | 추적 목적 (ATT 대상) |
| **Firebase Analytics** | 이벤트 이름·파라미터(`stage_id`, `duration_s` 등 — 전부 게임 진행 데이터, PII 없음), 익명 설치 ID | 제품 분석 | 추적 아님 (기기 식별에 안 씀) |
| **Firebase Crashlytics** | 크래시 스택트레이스, `context`로 붙인 게임 상태 문자열 | 안정성 | 추적 아님 |
| **StoreKit 2** | 거래 내역(Apple이 처리, 앱은 `Transaction`만 읽음) | 구매 검증 | Apple ID에 연결되지만 Apple이 관리 |
| **CloudKit** | 스테이지 진행도(`StageProgress`) | 기기 간 동기화 | 사용자의 Apple ID (Apple이 관리, 앱은 익명 컨테이너로만 접근) |
| **로컬 알림** | 없음 (기기 로컬 스케줄링, 서버 전송 없음) | 재참여 | 해당 없음 |

**AdMob이 유일한 "추적" 카테고리다.** ATT를 거부한 사용자는 비개인화 광고로 자동 전환된다
(`AdSetup`이 이미 이 순서를 강제한다). 나머지는 전부 "추적 아님"으로 신고한다.

---

## 6. 제출 전 마지막 확인

- [ ] Release 스킴에 `COREKIT_PRODUCTION_ADS=1` (테스트 광고 ID로 제출하면 리젝은 안 되지만 수익이 0)
- [ ] 실제 AdMob 앱 ID·Ad Unit ID 3종으로 교체 (`admob-setup.md` §5)
- [ ] 실제 `GoogleService-Info.plist` (테스트/개발용 프로젝트 아님)
- [ ] `SKAdNetworkItems` 최신 목록
- [ ] 연령 등급 질문지에서 도박성 콘텐츠(카지노 테마 게임 있음 — Wordjack) 정확히 신고
- [ ] Export Compliance — 암호화 사용 안 함으로 신고 (표준 HTTPS만 사용)

> 리젝당하면 침착하게: Resolution Center에서 정확한 사유를 읽고, 이 문서에서 해당 섹션을
> 찾아 그것만 고친다. 관련 없는 것까지 같이 고치면 재제출이 늦어지고 새 문제를 만들 수 있다.
