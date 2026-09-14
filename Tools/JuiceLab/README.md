# JuiceLab

`CoreKit`의 피드백 계층을 **손으로 만져보고 귀로 들어보기 위한** 하네스 앱이다.
게임이 아니고 출시 대상도 아니다. 실기기에서만 확인 가능한 것들을 확인하는 용도다.

- 햅틱은 **시뮬레이터에서 아예 발생하지 않는다.** 실기기 필수.
- 오디오 피치 상승, 승리 연출 타이밍도 여기서 먼저 검증하고 게임에 넣는다.

## 열기

```bash
cd Tools/JuiceLab && xcodegen generate && open JuiceLab.xcodeproj
```

`.xcodeproj`는 생성물이라 git에 포함되지 않는다. **직접 수정하지 말고 `project.yml`을 고친 뒤 다시 생성한다.**

## 기기에서 실행

1. Xcode에서 프로젝트를 연다
2. `JuiceLab` 타겟 → Signing & Capabilities → **Team 선택** (최초 1회)
3. 상단 실행 대상을 연결된 iPhone으로 바꾸고 ⌘R
4. 기기에서 최초 실행 시 설정 → 일반 → VPN 및 기기 관리에서 개발자 앱 신뢰

## Haptics 화면에서 확인할 것

| 항목 | 기대 |
|---|---|
| Rich haptics | `CoreHaptics`로 표시되어야 한다. `Fallback`이면 기기가 지원하지 않거나 엔진 생성에 실패한 것이다 |
| Micro 슬라이더 0 → 12 | 탭이 점점 단단해진다. 수치도 같이 오른다 |
| Play full sequence | 9번의 상승 후 마지막에 확연히 무거운 milestone |
| Micro peak → Milestone | **두 번째가 확실히 더 무거워야 한다.** 구분이 안 되면 강도 곡선을 다시 잡아야 한다 |
| Milestone → Error | 무게가 아니라 **날카로움**이 다르게 느껴져야 한다. 성공과 실패가 헷갈리면 안 된다 |
| Haptics enabled 끄기 | 모든 버튼이 조용해진다 |
| 홈으로 나갔다가 복귀 | **복귀 후에도 계속 동작해야 한다.** 죽어 있으면 엔진 재시작 핸들러 문제다 |
