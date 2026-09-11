// Local-only synthetic four-player regression. Requires Node22+ and MP2_DEV_AUTH=1.
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';

const endpoint = process.env.MP2_WS_URL ?? 'ws://127.0.0.1:18089/multiplayer/v2';
assert(['127.0.0.1', '[::1]', 'localhost'].includes(new URL(endpoint).hostname));
const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));
class Client {
  constructor() {
    this.id = randomUUID(); this.messages = []; this.pending = new Set(); this.play = true; this.sequence = 0;
    this.socket = new WebSocket(endpoint);
    this.socket.addEventListener('message', event => {
      const envelope = JSON.parse(event.data);
      this.messages.push(envelope);
      if (this.messages.length > 4096) this.messages.shift();
      if (envelope.room) this.room = envelope.room._0;
      if (envelope.resumeCredential) this.credential = envelope.resumeCredential;
      if (envelope.snapshot) {
        this.snapshot = envelope.snapshot._0;
        const seat = this.snapshot.players.find(player => player.id === this.id)?.seat;
        for (const target of this.snapshot.targets) {
          if (!this.play || target.ownerSeat !== seat || this.pending.has(target.id)) continue;
          this.pending.add(target.id);
          const presented = Math.max(target.activateAtMs, this.snapshot.elapsedMs);
          const contact = presented + 100;
          setTimeout(() => {
            if (!this.play) return;
            this.send({ input: { _0: { id: ++this.sequence, seat, targetID: target.id, cell: target.cell,
              presentedAtMs: presented, contactAtMs: contact, lastServerRevision: this.snapshot.revision,
              roomEpoch: this.room.epoch, sessionGeneration: this.credential.generation } } });
          }, Math.max(100, contact - this.snapshot.elapsedMs));
        }
      }
    });
  }
  send(message) { if (this.socket.readyState === WebSocket.OPEN) this.socket.send(JSON.stringify(message)); }
  async open() {
    await new Promise((resolve, reject) => {
      this.socket.addEventListener('open', resolve, { once: true });
      this.socket.addEventListener('error', reject, { once: true });
    });
    this.send({ hello: { ticket: `dev:${this.id}`, protocolVersion: 2, gameplayRevision: 3 } });
    const welcome = await this.wait('welcome');
    assert.equal(welcome.roomDiscoveryRevision, 2);
    this.ping = setInterval(() => this.send({ ping: { id: 1, clientTimeMs: Math.floor(performance.now()) } }), 1000);
    return this;
  }
  async wait(kind, predicate = () => true, timeout = 12000) {
    const end = performance.now() + timeout;
    while (performance.now() < end) {
      const index = this.messages.findIndex(value => kind in value && predicate(value[kind]._0 ?? value[kind]));
      if (index >= 0) { const value = this.messages.splice(index, 1)[0][kind]; return value._0 ?? value; }
      await sleep(20);
    }
    throw new Error(`${kind} timeout`);
  }
  close() { this.play = false; clearInterval(this.ping); this.socket.close(); }
}

const clients = await Promise.all(Array.from({ length: 4 }, () => new Client().open()));
try {
  const host = clients[0];
  host.send({ create: { capacity: 4 } });
  const initial = await host.wait('room');
  host.send({ setPrivacy: { isPrivate: true, roomID: initial.id, roomRevision: initial.revision } });
  const hidden = await host.wait('room', room => room.isPrivate === true);
  clients[1].send({ search: { query: initial.roomCode, requestID: 1 } });
  const found = await clients[1].wait('searchResults', result => result.requestID === 1);
  assert.equal(found.rooms[0].id, initial.id);
  for (const client of clients.slice(1)) {
    client.send({ join: { roomID: hidden.roomCode } });
    await client.wait('room', room => room.id === initial.id);
  }
  await host.wait('room', room => room.players.length === 4);
  await sleep(100);
  for (const client of clients) client.send({ ready: { value: true, intentID: 1, rosterRevision: client.room.rosterRevision } });
  const ready = await host.wait('room', room => room.players.every(player => player.ready));
  host.send({ setPrivacy: { isPrivate: false, roomID: ready.id, roomRevision: ready.revision } });
  const publicRoom = await host.wait('room', room => room.revision > ready.revision && room.isPrivate === false);
  assert(publicRoom.players.every(player => player.ready));
  host.send({ start: {} });
  await host.wait('snapshot', snapshot => snapshot.elapsedMs >= 12000, 20000);
  assert(host.snapshot.players.every(player => player.hits > 0 && player.lives > 0));
  const score = host.snapshot.players[0].score;
  for (const client of clients.slice(1)) { client.play = false; client.send({ leave: {} }); await client.wait('left'); }
  const solo = await host.wait('snapshot', snapshot => snapshot.players.slice(1).every(player => player.lives === 0));
  assert.equal(solo.phase, 'playing');
  await host.wait('snapshot', snapshot => snapshot.elapsedMs >= solo.elapsedMs + 6000, 12000);
  assert(host.snapshot.players[0].score > score && host.snapshot.players[0].lives > 0);
  assert(host.snapshot.players[0].eligibleAliveMs > solo.players[0].eligibleAliveMs);
  assert(host.snapshot.players.slice(1).every((player, index) => player.eligibleAliveMs === solo.players[index + 1].eligibleAliveMs));
  host.play = false;
  const final = await host.wait('snapshot', snapshot => snapshot.phase === 'finished', 35000);
  assert.equal(final.finalReason, 'allOut');
  assert(final.players.every(player => player.lives === 0));
  assert(final.players[0].score > score);
  assert(final.players[0].maxMultiplier >= 1 && final.players[0].maxMultiplier <= 5);
  assert(clients.every(client => !client.messages.some(message => message.error)));
  host.send({ create: { capacity: 4 } });
  await host.wait('room', room => room.id !== initial.id && room.phase === 'waiting');
  console.log('PASS revision3 four sockets: private toggle/code join/Ready preserved, all seats score, last living seat continues, survivor time advances, spectators freeze, all-out admission drains, fresh room');
  console.log(JSON.stringify({ durationMs: final.elapsedMs, players: final.players.map(({ seat, score, hits, eligibleAliveMs, outAtMs, maxMultiplier }) => ({ seat, score, hits, eligibleAliveMs, outAtMs, maxMultiplier })) }));
} finally { clients.forEach(client => client.close()); }
