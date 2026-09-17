# App Store Connect 등록 절차

**게임마다 1회.** 순서를 지킨다 — 특히 번들 ID와 In-App Purchase 제품 ID는
**한 번 만들면 이름을 바꾸거나 지울 수 없다.**

---

## 0. 선행 조건

- [ ] Apple Developer Program 가입 완료 (연 $99, 갱신 필요)
- [ ] 코드네임·번들 ID 확정 (`docs/architecture/naming.md`)
- [ ] D2(아이콘)·D6(스크린샷) 완료
- [ ] `docs/architecture/app-review-checklist.md` 1차 통과

---

## 1. 번들 ID 등록 (Apple Developer 사이트, App Store Connect 아님)

1. [developer.apple.com](https://developer.apple.com) → Certificates, Identifiers & Profiles → Identifiers
2. **+** → App IDs → App
3. Bundle ID: `com.jacobkostudio.<codename>` (Explicit, 와일드카드 아님)
4. Capabilities에서 **iCloud**, **Push Notifications** 체크 (CloudKit + 백그라운드 동기화용)
5. 등록 후 Xcode의 Signing & Capabilities가 자동으로 인식

> 오타 확인은 여기서 한다. 등록 후에는 이 문자열이 CloudKit 컨테이너 이름, 인앱 구매 ID
> 접두사에 전부 박혀서 사실상 되돌릴 수 없다.

## 2. App Store Connect에 앱 생성

1. [App Store Connect](https://appstoreconnect.apple.com) → 앱 → **+** → 신규 앱
2. **Primary Language: English (U.S.)** — 그 외 언어는 나중에 추가해도 되지만 Primary는 처음에 고정된다
3. 이름: 브랜드명 그대로 (`app-store-metadata.md` §1 규칙)
4. Bundle ID: 위에서 등록한 것 선택
5. SKU: 아무 내부 식별자 (예: `chordline-ios-2026`), 사용자에게 안 보임

## 3. 가격 및 사용 가능 여부

- 가격: **무료** (광고+IAP 모델)
- 사용 가능 국가: 전체 선택 (특정 국가 제외할 이유 없음)

## 4. App 정보

| 필드 | 값 |
|---|---|
| 카테고리(1차) | Games → Puzzle (게임마다 실제 장르로) |
| 카테고리(2차) | 선택 사항, 비워도 됨 |
| 콘텐츠 저작권 | `© 2026 jacobkostudio` |
| 연령 등급 | 질문지 작성 (§6) |

## 5. In-App Purchase 등록 (`iap-setup.md` §2 참조)

1. 기능 → **앱 내 구입** → **+** → 비소모성(Non-Consumable)
2. 참조 이름: `Remove Ads`
3. 제품 ID: `com.jacobkostudio.<codename>.removeads` — **여기서 오타 나면 영구히 못 지운다**
4. 가격 등급 선택 (시작가 $2.99, `iap-setup.md` 참조)
5. 현지화 — 최소 en/ko (`app-store-metadata.md` §11 언어 목록)
6. 심사용 스크린샷 첨부 (구매 버튼이 보이는 화면 1장)

## 6. 연령 등급 질문지

- 시뮬레이션 도박: **Wordjack만 "있음"** (카지노 테마 시각적 메타포, 실제 배팅 없음 — 그래도 질문지에는 정직하게 신고)
- 폭력: 전부 "없음" (Noodlewing·Tickroll의 실패 연출은 슬랩스틱, 유혈 없음 — `CLAUDE.md` §5 하드룰)
- 나머지 항목(성적 콘텐츠, 도박 등): 전부 "없음"

## 7. 앱 개인정보 (Privacy) 라벨

`docs/architecture/app-review-checklist.md` §5의 데이터 수집 표를 그대로 입력한다.
**AdMob 관련 데이터만 "추적 목적"으로 표시**하고, Firebase Analytics/Crashlytics는
"추적 안 함"으로 표시한다 (기기 식별에 안 쓰기 때문).

## 8. 가격·개인정보처리방침 URL

- Privacy Policy URL: `docs/privacy/README.md`에서 정한 호스팅 URL을 넣는다
- 출시 전 반드시 **실제로 열리는지** 확인 (404면 제출 자체가 막힌다)

## 9. 빌드 업로드 & 심사 제출

1. Xcode → Product → Archive (Release 스킴, `COREKIT_PRODUCTION_ADS=1` 확인)
2. Organizer → Distribute App → App Store Connect
3. App Store Connect에서 빌드 선택, 스크린샷·설명·키워드 최종 입력
4. **App Review 정보** — 리뷰어 연락처, IAP 테스트 계정 필요 시 데모 계정 정보 기재
5. 제출

---

## 10. Small Business Program — 첫 게임 출시 전에 신청

**연 매출 100만 달러 미만이면 즉시 신청한다.** 수수료가 30% → **15%**로 줄고,
이 포트폴리오처럼 저가 IAP($2.99) 다수 판매 모델에서는 순수익에 직접적인 차이를 만든다.

### 신청 절차

1. [Small Business Program 페이지](https://developer.apple.com/app-store/small-business-program/)에서 자격 확인
   - 자격: 전년도 전 세계 매출(모든 앱 합산) $1M 미만, 또는 신규 개발자
2. App Store Connect → Business → Agreements, Tax, and Banking
3. Small Business Program 등록 신청서 제출 (매출 자진 신고)
4. 승인은 보통 며칠 내. **승인 전 판매분은 30%가 적용되고 소급되지 않으므로, 첫 게임 출시 전에 신청을 끝내는 게 유리하다**
5. 매년 초 자격 재확인 필요 — 전년도 매출이 기준을 넘으면 자동으로 표준 수수료로 복귀

### 주의

- 이 포트폴리오 10개 앱은 **같은 개발자 계정**이므로 매출은 전부 합산된다. 게임이 늘어나면서
  총매출이 기준을 넘으면 프로그램에서 자동 제외되니, 연 매출을 주기적으로 확인한다.
