// Relays in-app bug reports and ideas to a Discord channel; the webhook and app names live in Worker secrets (D-126).

const MAX_BODY = 8000;
const KINDS = { bug: { label: '🐞 Bug', color: 0xff4d2e }, idea: { label: '💡 Idea', color: 0xb8ff2e } };

const clip = (value, length) => String(value ?? '').slice(0, length);

/** Checks a report from the app. Returns the cleaned report, or a reason it was refused. */
export function validate(body) {
  if (!body || typeof body !== 'object') return { error: 'not json' };
  const kind = KINDS[body.kind] ? body.kind : null;
  const message = typeof body.message === 'string' ? body.message.trim() : '';
  if (!kind) return { error: 'kind' };
  if (message.length < 5 || message.length > 1500) return { error: 'message length' };
  return {
    report: {
      kind,
      message,
      appVersion: clip(body.appVersion, 20),
      build: clip(body.build, 20),
      osVersion: clip(body.osVersion, 20),
      device: clip(body.device, 40),
      context: clip(body.context, 120),
    },
  };
}

/** The Discord message: one embed, no pings ever. */
export function discordPayload(app, report, now = new Date()) {
  const kind = KINDS[report.kind];
  return {
    username: 'Feedback',
    allowed_mentions: { parse: [] },
    embeds: [{
      title: clip(`${kind.label} · ${app} ${report.appVersion} (${report.build})`, 256),
      description: report.message,
      color: kind.color,
      fields: [
        { name: 'Device', value: clip(`${report.device || '?'} · iOS ${report.osVersion || '?'}`, 1024), inline: true },
        { name: 'Context', value: clip(report.context || '—', 1024), inline: true },
      ],
      timestamp: now.toISOString(),
    }],
  };
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (request.method !== 'POST' || url.pathname !== '/feedback') return new Response('Not found', { status: 404 });

    // APP_KEYS secret: {"<key>": "<App name>"} — unknown keys are dropped quietly.
    let keys = {};
    try { keys = JSON.parse(env.APP_KEYS || '{}'); } catch { keys = {}; }
    const app = keys[request.headers.get('X-Feedback-Key') || ''];
    if (!app) return new Response('Forbidden', { status: 403 });

    if (env.LIMITER) {
      const { success } = await env.LIMITER.limit({ key: request.headers.get('CF-Connecting-IP') || 'unknown' });
      if (!success) return new Response('Too many', { status: 429 });
    }

    const text = await request.text();
    if (text.length > MAX_BODY) return new Response('Too large', { status: 413 });
    let body;
    try { body = JSON.parse(text); } catch { return new Response('Bad request', { status: 400 }); }
    const { report, error } = validate(body);
    if (error) return new Response(error, { status: 400 });

    const sent = await fetch(env.DISCORD_WEBHOOK, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(discordPayload(app, report)),
    });
    return new Response(null, { status: sent.ok ? 204 : 502 });
  },
};
