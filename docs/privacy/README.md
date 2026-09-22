# 개인정보처리방침 — 호스팅

## 현재 방식 — 게임마다 자기 페이지 (D-109)

각 게임은 스튜디오 사이트(`jacobko.app`)에 자기 서브도메인 페이지를 갖는다.

| 게임 | 방침 URL |
|---|---|
| Chordline | <https://chordline.jacobko.app/privacy> |

**애초 계획은 포트폴리오 전체가 공유하는 단일 문서**(이 폴더의 `index.html`, GitHub
Pages로 호스팅)였다. 10개 게임이 같은 `CoreKit` 수집 구조를 쓰니 한 번 쓰고 끝내려는
의도였다. **그 계획은 Chordline에서 폐기했다.** 실제로 써보니 게임마다 사실관계가
갈린다:

- 애널리틱스 — `AnalyticsHub`는 CoreKit에 있지만 **리포터를 등록하는 건 게임 쪽**이다.
  Chordline은 하나도 등록하지 않아서 "애널리틱스 없음"이 참이지만, 다음 게임이
  Firebase를 붙이면 같은 문서가 그 게임에서는 거짓이 된다.
- 광고 배치 — Chordline은 배너를 숨기고 전면·보상형만 켰다(D-107). 게임마다 다르다.
- 동기화 대상 — 무엇이 CloudKit에 올라가는지는 게임의 `@Model`이 정한다.

공유 문서는 이걸 담으려면 "게임에 따라 다를 수 있음"으로 흐려져야 하는데, 그건
방침으로서 쓸모가 없다. 그래서 **게임별 페이지**로 간다.

`index.html`과 아래 GitHub Pages 절차는 **더 쓰지 않는다.** 기록으로만 남긴다.

## 새 게임의 방침 페이지 만들기

1. `Apps/<Game>/Marketing/web-handoff.md`를 쓴다 — Chordline의 것이 레퍼런스다.
   **주장마다 코드 근거를 표로 붙인다**(`web-handoff.md` §4). 이게 나중에 카피를
   수정할 때 사실관계가 조용히 깨지는 걸 막는 유일한 장치다.
2. 그 문서를 웹 세션에 넘겨 `<game>.jacobko.app` + `/privacy` 두 페이지를 만든다.
3. 완성된 URL을 **두 곳**에 넣는다.
   - App Store Connect → 앱 정보 → **개인정보처리방침 URL**
   - 앱 코드의 `SettingsView(privacyPolicyURL:)` — `new-game-setup.md` §6 참조

## 확인

- [ ] 방침 URL이 실제로 열리는지 확인 (404는 리젝의 흔한 원인)
- [ ] 앱 안 Settings의 링크가 같은 URL을 가리키는지 확인 — 두 곳이 갈라지기 쉽다
- [ ] 연락처 이메일이 실제로 확인하는 주소인지 재확인

## 내용이 바뀌면

페이지를 고치고 `Last updated` 날짜를 갱신한다. 단, **수집하는 데이터 종류가 실제로
바뀌면**(새 SDK 추가 등) App Store Connect의 "앱 개인정보" 라벨도 같이 갱신해야 한다 —
페이지만 고치고 라벨을 놔두면 그 자체로 5.1.1 리젝 사유다.

---

## (폐기) GitHub Pages 호스팅 절차

`index.html`을 쓰던 시절의 절차다. 토글은 켜지 않았고, 켤 필요도 없어졌다.

1. GitHub 저장소 → **Settings → Pages**
2. **Build and deployment → Source: Deploy from a branch**
3. Branch: **main**, 폴더: **/docs**
4. Save 후 `https://jacobnko.github.io/ios-game-portfolio/privacy/`에서 열린다
