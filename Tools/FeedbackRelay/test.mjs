// Runs the relay against fake requests: node test.mjs
import assert from 'node:assert/strict';
import worker, { validate, discordPayload } from './src/worker.js';

const posted = [];
globalThis.fetch = async (url, init) => { posted.push({ url, body: JSON.parse(init.body) }); return { ok: true }; };
const env = { APP_KEYS: JSON.stringify({ k1: 'GameOne' }), DISCORD_WEBHOOK: 'https://discord.example/hook' };
const call = (body, key = 'k1', path = '/feedback') => worker.fetch(new Request(`https://relay.example${path}`, {
  method: 'POST', headers: { 'X-Feedback-Key': key, 'Content-Type': 'application/json' }, body: typeof body === 'string' ? body : JSON.stringify(body),
}), env);
const good = { kind: 'bug', message: '  Board froze @everyone  ', appVersion: '1.0.0', build: '1', osVersion: '26.0', device: 'iPhone17,1', context: 'classic.hard.8' };

assert.equal((await call(good)).status, 204);
assert.equal(posted[0].url, env.DISCORD_WEBHOOK);
assert.deepEqual(posted[0].body.allowed_mentions, { parse: [] });
assert.equal(posted[0].body.embeds[0].description, 'Board froze @everyone');
assert.match(posted[0].body.embeds[0].title, /Bug · GameOne 1\.0\.0 \(1\)/);
assert.equal((await call(good, 'nope')).status, 403);
assert.equal((await call(good, 'k1', '/other')).status, 404);
assert.equal((await call({ ...good, message: 'hi' })).status, 400);
assert.equal((await call({ ...good, kind: 'spam' })).status, 400);
assert.equal((await call('{not json')).status, 400);
assert.equal((await call({ ...good, message: 'x'.repeat(9000) })).status, 413);
assert.equal(validate({ ...good, context: 'c'.repeat(500) }).report.context.length, 120);
assert.equal(discordPayload('G', validate({ ...good, kind: 'idea' }).report).embeds[0].color, 0xb8ff2e);
assert.equal(posted.length, 1, 'only the good report reached Discord');
console.log('relay: all checks passed');
