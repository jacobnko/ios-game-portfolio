# D4. 보조 화면

**목적.** Home · Stage Select · Result · Settings 4화면.
**선행.** D1, D3 완료. D3의 HUD 스타일을 텍스트로 요약해 넘긴다.
**예상 규모.** 중간. 4장을 **2장씩 두 번**에 나눠 요청해도 된다.

## Claude Design에 붙여넣을 프롬프트 (1차 — Home + Stage Select)

```
iPhone 세로(393x852) 화면 목업 2장.

게임: <게임명>
팔레트: primary <hex> / secondary <hex> / accent <hex> / background <hex> / surface <hex>
스타일 키워드: <키워드 5개>
게임 화면 톤: <D3 요약 한 줄>

1) Home — 로고 영역, 큰 Play 버튼, 설정 아이콘, 하단 배너 320x50 자리
2) Stage Select — 스테이지 그리드(잠김/클리어/현재 3가지 상태가 구분됨), 진행률 표시

제약: 터치 타겟 44pt 이상. 텍스트 최소화. 다국어 대비해 버튼 라벨 길이가 1.5배로 늘어나도 깨지지 않을 것.
```

## Claude Design에 붙여넣을 프롬프트 (2차 — Result + Settings)

```
같은 스타일로 iPhone 세로 화면 목업 2장 더.

3) Result — 클리어 직후 화면. 별/점수 배수, 다음 스테이지 버튼, 공유 버튼.
   전면 광고가 이 화면 직전에 뜨므로, 광고 닫은 직후 눈에 들어오는 구성이어야 함
4) Settings — 사운드/햅틱 토글, 광고 제거 구매 버튼, 구매 복원 버튼, 언어 설정(시스템 설정으로 이동), 개인정보처리방침 링크

제약: Settings의 "구매 복원"은 반드시 눈에 띄는 위치. 심사 항목임.
```

## 산출물
- [ ] `assets/D4-home-stageselect.png`
- [ ] `assets/D4-result-settings.png`

## 완료 조건
- [ ] Settings에 광고 제거 · 구매 복원 · 개인정보처리방침 3종이 모두 있다
- [ ] 버튼 라벨이 독일어처럼 긴 언어에서도 성립하는 여백이 있다
