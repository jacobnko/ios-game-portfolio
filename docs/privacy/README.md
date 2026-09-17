# 개인정보처리방침 — 호스팅

`index.html`이 실제 방침 본문이다 (EN + KO, 한 페이지). 포트폴리오 전체가 공유하는
**단일 문서**다 — 10개 게임이 같은 데이터 수집 구조(`CoreKit`)를 쓰므로 게임마다
따로 쓸 이유가 없고, 유지보수도 한 곳에서 끝난다.

## 호스팅 — GitHub Pages (한 번만 설정)

이 저장소(`ios-game-portfolio`, public)가 이미 있으니 별도 서버·비용 없이 바로 쓸 수 있다.

1. GitHub 저장소 → **Settings → Pages**
2. **Build and deployment → Source: Deploy from a branch**
3. Branch: **main**, 폴더: **/docs**
4. Save. 몇 분 뒤 `https://jacobnko.github.io/ios-game-portfolio/privacy/`에서 열린다

이 토글은 **J가 GitHub 웹 UI에서 직접 켜야 한다** — Claude Code에게는 저장소 설정을
바꿀 권한이 없다.

## App Store Connect에 넣을 URL

```
https://jacobnko.github.io/ios-game-portfolio/privacy/
```

이 URL을 다음 두 곳에 쓴다.
- App Store Connect → 앱 정보 → **개인정보처리방침 URL**
- 앱 코드의 `SettingsView(privacyPolicyURL:)` — `docs/architecture/new-game-setup.md` §6 참조

## 확인

- [ ] GitHub Pages 활성화 후 위 URL이 실제로 열리는지 확인 (404 리젝의 흔한 원인)
- [ ] 다크 모드에서도 읽히는지 확인 (페이지가 `prefers-color-scheme`를 따른다)
- [ ] 연락처 이메일이 실제로 확인하는 주소인지 재확인

## 내용이 바뀌면

`index.html`을 고치고 `Last updated` 날짜를 갱신한다. GitHub Pages는 push 즉시
반영되므로 별도 재배포 절차가 없다. 단, **수집하는 데이터 종류가 실제로 바뀌면**
(새 SDK 추가 등) App Store Connect의 "앱 개인정보" 라벨도 같이 갱신해야 한다 —
이 문서만 고치고 라벨을 놔두면 그 자체로 5.1.1 리젝 사유다.
