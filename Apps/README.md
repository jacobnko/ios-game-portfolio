# Apps/

각 게임은 **이 저장소가 아니라 자기 저장소**에서 관리한다.
그래서 이 디렉토리의 내용물은 `.gitignore`로 제외돼 있고, 이 README만 추적된다.

```
Apps/
├─ README.md          ← 이 파일만 이 저장소에 들어간다
├─ LineRush/          ← 별도 저장소. 여기서는 무시됨
└─ MemeGram/          ← 별도 저장소. 여기서는 무시됨
```

자세한 이유와 운영 방식은 `docs/architecture/repo-strategy.md` 참조.

## 새 게임 클론해오기

```bash
cd Apps && git clone https://github.com/jacobnko/<game-repo>.git <Codename>
```

클론한 게임은 `../../Packages/CoreKit`을 local package로 참조한다.
