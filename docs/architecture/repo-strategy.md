# 저장소 전략 — 공용 하나 + 게임마다 하나

## 구조

```
github.com/jacobnko/ios-game-portfolio   (public)   ← 이 저장소
   └─ CoreKit · 문서 · 디자인 템플릿 · 스크립트

github.com/jacobnko/<game-repo>          (게임별)   ← 게임마다 새로 생성
   └─ Xcode 프로젝트 · 게임 로직 · 스테이지 데이터 · 에셋
```

| 게임 | 저장소 | 로컬 경로 |
|---|---|---|
| Chordline | `jacobnko/Chordline-ios-game` (private) | `Apps/Chordline/` |

저장소 이름은 코드네임과 정확히 같을 필요가 없다. 번들 ID와 폴더명이 코드네임을 따르면 충분하다.

로컬 디스크에서는 게임이 `Apps/<Codename>/` 아래 놓이지만, 그 폴더는 이 저장소의 `.gitignore`가 막는다.
즉 **한 폴더 안에 저장소 두 개가 겹쳐 있는 것이 아니라, 부모가 자식을 안 보는 구조**다.

## 이렇게 하는 이유

- 게임 하나의 히스토리가 다른 게임 커밋에 파묻히지 않는다. 게임별 이슈·릴리즈 태그가 독립적이다.
- 게임마다 공개/비공개를 따로 정할 수 있다. 공용 아키텍처는 공개하고 특정 게임 소스는 닫아둘 수 있다.
- 저장소 하나가 10개 게임 에셋으로 비대해지지 않는다.

## 대가 — 알고 감수하는 것

`CoreKit`을 고치면 **게임 저장소들이 자동으로 따라오지 않는다.** 각 게임에서 따로 확인해야 한다.

지금은 local package 경로 참조(`../../Packages/CoreKit`)라서 디스크 상으로는 즉시 반영되지만,
CI나 다른 머신에서는 성립하지 않는다. 게임이 3개를 넘어가면 `CoreKit`을 **버전 태그가 붙은 원격 패키지**로 전환한다.

> 전환 시점 신호. "CoreKit을 고쳤더니 어떤 게임이 깨졌는지 모르겠다"는 상황이 처음 생기면 그때다.

## 새 게임 저장소 만들 때

1. GitHub에서 저장소 생성 (이름은 게임 코드네임 기준, 예 `linerush`)
2. `cd Apps && git clone <url> <Codename>`
3. Xcode 프로젝트 생성. 번들 ID `com.jacobkostudio.<codename>`
4. `CoreKit`을 local package로 추가 (`../../Packages/CoreKit`)
5. 게임 저장소의 `.gitignore`에 시크릿 패턴 복사 (`GoogleService-Info.plist`, `Secrets.xcconfig`, `*.p8`)

**5번을 빠뜨리지 말 것.** 새 저장소는 이 저장소의 `.gitignore` 보호를 받지 않는다.
