# FeedbackRelay — 앱 버그 리포트 · 의견 → Discord 중계 (D-126)

게임 앱의 Settings → "Send Feedback"에서 보낸 글을 J의 Discord 채널로 넘겨 주는 Cloudflare Worker(무료 플랜으로 충분).
Discord 웹훅 주소와 게임 이름표는 **Worker 비밀값**에만 있고, 이 저장소와 앱에는 없다.

```
앱 ──POST /feedback (X-Feedback-Key)──▶ Worker ──(웹훅, 비밀값)──▶ Discord 채널
         키 확인 · IP당 분당 5건 · 길이 검사 · 멘션 차단
```

## 처음 한 번 설정 (J, 약 15분)

1. **Discord 웹훅 만들기**
   - 리포트를 받을 채널(예: `#app-feedback`) → 채널 설정(톱니) → **연동(Integrations)** → **웹후크(Webhooks)** → **새 웹후크** → 이름 `Feedback` → **웹후크 URL 복사**.
2. **Cloudflare 계정**(무료) — dash.cloudflare.com 가입.
3. **배포** (터미널, 이 폴더에서)
   ```bash
   cd Tools/FeedbackRelay
   npx wrangler login
   npx wrangler deploy
   ```
   끝나면 주소가 나온다: `https://feedback-relay.<계정이름>.workers.dev`
4. **비밀값 넣기**
   ```bash
   npx wrangler secret put DISCORD_WEBHOOK
   ```
   → 1번에서 복사한 웹후크 URL 붙여 넣기.
   ```bash
   openssl rand -hex 16
   ```
   → 나온 문자열이 그 게임의 **앱 키**. 게임마다 하나씩.
   ```bash
   npx wrangler secret put APP_KEYS
   ```
   → `{"<앱 키>": "<게임 이름>"}` 형태로 붙여 넣기(게임이 늘면 `{"키1": "<게임 1>", "키2": "<게임 2>"}`). 게임 이름은 Discord 메시지 제목에만 쓰인다.
5. **게임에 연결** — 각 게임 폴더(`Apps/<Game>/`)의 `Config/Secrets.xcconfig`(저장소에 안 올라감, 예시는 `Secrets.example.xcconfig`)에:
   ```
   FEEDBACK_HOST = feedback-relay.<계정이름>.workers.dev
   FEEDBACK_APP_KEY = <앱 키>
   ```
   값이 없으면 앱의 버튼은 메일 보내기(`admin@jacobko.app`)로 동작한다 — 중계가 없어도 앱은 깨지지 않는다.

## 확인
```bash
curl -i -X POST https://feedback-relay.<계정이름>.workers.dev/feedback \
  -H 'X-Feedback-Key: <앱 키>' -H 'Content-Type: application/json' \
  -d '{"kind":"bug","message":"relay test from curl","appVersion":"1.0.0","build":"1","osVersion":"26.0","device":"curl","context":"test"}'
```
`204`가 오고 Discord에 🐞 메시지가 뜨면 끝.

## 막기 · 비용
- 모르는 키 403 · IP당 분당 5건 초과 429 · 본문 8KB 초과 413 · 메시지 5–1500자 밖 400.
- 무료 플랜 하루 10만 요청 — 피드백으로는 넘을 일이 없다.
- 스팸이 오면 `APP_KEYS`에서 그 키만 바꾸면 된다(웹훅은 그대로).
- `wrangler deploy`가 `[[ratelimits]]` 블록을 모른다고 하면 wrangler를 최신으로(`npx wrangler@latest deploy`). 그래도 안 되면 그 블록을 지워도 동작한다(한도만 빠짐).

## 개발
`node test.mjs` — 가짜 요청으로 검사(키 · 경로 · 길이 · JSON · 크기 · 멘션 차단 · Discord 형식).
