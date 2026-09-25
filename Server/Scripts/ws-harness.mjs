// Node 22+ built-in RFC 6455 client. All identities are synthetic local UUIDs.
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';

const endpoint = process.env.MP2_WS_URL ?? 'ws://127.0.0.1:8080/multiplayer/v2';
assert(['127.0.0.1', '[::1]', 'localhost'].includes(new URL(endpoint).hostname), 'Harness is local-only');

class Client {
  constructor(playerID = randomUUID(), gameplayRevision = 1) {
    this.playerID = playerID;
    this.gameplayRevision = gameplayRevision;
    this.messages = [];
    this.waiters = [];
    this.socket = new WebSocket(endpoint);
    this.socket.addEventListener('message', event => {
      const message = JSON.parse(event.data);
      if (message.room) this.lastRoom = message.room._0;
      this.messages.push(message);
      if (this.messages.length > 4096) this.messages.shift();
      for (const waiter of [...this.waiters]) waiter.check();
    });
    this.socket.addEventListener('error', () => {});
  }
  async open(authenticate = true) {
    await new Promise((resolve, reject) => {
      const timer = setTimeout(() => reject(new Error('socket open timeout')), 5000);
      this.socket.addEventListener('open', () => { clearTimeout(timer); resolve(); }, { once: true });
      this.socket.addEventListener('error', () => { clearTimeout(timer); reject(new Error('socket open failed')); }, { once: true });
    });
    if (authenticate) {
      this.send({ hello: { ticket: `dev:${this.playerID}`, protocolVersion: 2,
        ...(this.gameplayRevision === 1 ? {} : { gameplayRevision: this.gameplayRevision }) } });
      const welcome = await this.wait('welcome');
      assert.equal(welcome.gameplayRevision, this.gameplayRevision);
      let ping = 0;
      this.pinger = setInterval(() => this.send({ ping: { id: ++ping, clientTimeMs: performance.now() | 0 } }), 1000);
    }
    return this;
  }
  send(value) { if (this.socket.readyState === WebSocket.OPEN) this.socket.send(JSON.stringify(value)); }
  wait(kind, predicate = () => true, timeout = 12000) {
    return new Promise((resolve, reject) => {
      const waiter = { check: () => {
        const index = this.messages.findIndex(message => kind in message && predicate(message[kind]._0 ?? message[kind]));
        if (index >= 0) {
          clearTimeout(timer);
          this.waiters = this.waiters.filter(value => value !== waiter);
          const message = this.messages.splice(index, 1)[0][kind];
          resolve(message._0 ?? message);
        }
      } };
      const timer = setTimeout(() => {
        this.waiters = this.waiters.filter(value => value !== waiter);
        reject(new Error(`${kind} timeout; received=${this.messages.map(value => Object.keys(value)[0]).slice(-10)}`));
      }, timeout);
      this.waiters.push(waiter);
      waiter.check();
    });
  }
  close() { clearInterval(this.pinger); this.socket.close(); }
}

async function runRoom(capacity, duplicateInput = false, gameplayRevision = 1) {
  const clients = await Promise.all(Array.from({ length: capacity }, () => new Client(randomUUID(), gameplayRevision).open()));
  try {
    const host = clients[0];
    host.send({ create: { capacity } });
    const created = await host.wait('room');
    for (const client of clients.slice(1)) {
      client.send({ join: { roomID: created.id } });
      await client.wait('room', room => room.id === created.id);
    }
    const rosters = await Promise.all(clients.map(client => client.lastRoom?.players.length === capacity
      ? client.lastRoom : client.wait('room', room => room.players.length === capacity)));
    clients.forEach((client, index) => client.send({ ready: { value: true, intentID: 1, rosterRevision: rosters[index].rosterRevision } }));
    await Promise.all(clients.map(client => client.wait('room', room => room.players.every(player => player.ready))));
    host.send({ start: {} });
    host.send({ start: {} });
    const countdown = await host.wait('room', room => room.phase === 'countdown');
    const duplicate = await host.wait('room', room => room.phase === 'countdown');
    assert.equal(countdown.matchID, duplicate.matchID);
    const initialSnapshots = await Promise.all(clients.map(client => client.wait('snapshot', snapshot => snapshot.phase === 'playing')));
    assert(initialSnapshots.every(snapshot => snapshot.gameplayRevision === gameplayRevision));
    if (duplicateInput) {
      const hostCredential = await host.wait('resumeCredential');
      const payload = { input: { _0: {
        id: 1, seat: 0, targetID: null, cell: -1,
        presentedAtMs: initialSnapshots[0].elapsedMs, contactAtMs: initialSnapshots[0].elapsedMs,
        lastServerRevision: initialSnapshots[0].revision, roomEpoch: created.epoch,
        sessionGeneration: hostCredential.generation,
      } } };
      host.send(payload); host.send(payload);
      const firstReceipt = await host.wait('receipt', receipt => receipt.id === 1);
      const duplicateReceipt = await host.wait('receipt', receipt => receipt.id === 1);
      assert.equal(firstReceipt.accepted, true);
      assert.deepEqual(duplicateReceipt, firstReceipt);
      const corrected = await host.wait('snapshot', snapshot => snapshot.players[0].misses === 1);
      assert.equal(corrected.players[0].lives, 2);
      console.log('PASS duplicate input IDs produce one personal mistake');
    }
    // A real socket reconnect must retain player/seat and rotate its credential.
    const dropped = clients.at(-1);
    const old = await dropped.wait('resumeCredential');
    dropped.close();
    const resumed = await new Client(dropped.playerID, gameplayRevision).open();
    clients[clients.length - 1] = resumed;
    resumed.send({ resume: { roomID: old.roomID, credential: old.credential, generation: old.generation } });
    const credential = await resumed.wait('resumeCredential');
    assert.equal(credential.generation, old.generation + 1);
    assert.notEqual(credential.credential, old.credential);
    const snapshot = await resumed.wait('snapshot');
    assert.equal(snapshot.players.find(player => player.id === dropped.playerID).connected, true);
    const finished = await host.wait('snapshot', snapshot => snapshot.phase === 'finished', 35000);
    assert.equal(finished.players.length, capacity);
    assert(finished.players.every(player => player.score === 0 && player.hits === 0 && player.lives === 0));
    assert.equal(clients.flatMap(client => client.messages).filter(message => message.error).length, 0);
    host.send({ create: { capacity } });
    const nextRoom = await host.wait('room', room => room.id !== created.id && room.phase === 'waiting');
    assert.notEqual(nextRoom.id, created.id, 'Completed results must not block the next room');
    console.log(`PASS revision${gameplayRevision} ${capacity} sockets: duplicate atomic start, ${duplicateInput ? 'duplicate input' : 'zero taps'}, rotating reconnect, independent completion, new create`);
  } finally { clients.forEach(client => client.close()); }
}

async function rejectMalformedAndUnauthenticated() {
  const unauthenticated = await new Client().open(false);
  unauthenticated.send({ create: { capacity: 2 } });
  assert.equal((await unauthenticated.wait('error')).code, 'authentication_required');
  unauthenticated.close();
  const malformed = await new Client().open();
  malformed.socket.send('{broken');
  assert.equal((await malformed.wait('error')).code, 'invalid_message');
  malformed.close();
  const healthy = await new Client().open();
  healthy.send({ list: {} });
  await healthy.wait('list');
  healthy.close();
  console.log('PASS malformed/unauthenticated socket isolation');
}

async function directoryLifecycle() {
  const [host, observer, legacy] = await Promise.all([
    new Client(randomUUID(), 2).open(), new Client(randomUUID(), 2).open(), new Client().open(),
  ]);
  try {
    await observer.wait('list');
    await legacy.wait('list');
    host.send({ create: { capacity: 2 } });
    const first = await host.wait('room');
    await observer.wait('list', list => list.some(room => room.id === first.id));
    legacy.send({ join: { roomID: first.id } });
    assert.equal((await legacy.wait('error')).code, 'cannot_join');
    host.send({ leave: {} });
    await host.wait('left');
    await observer.wait('list', list => !list.some(room => room.id === first.id));
    host.send({ create: { capacity: 2 } });
    const second = await host.wait('room', room => room.id !== first.id);
    await observer.wait('list', list => list.some(room => room.id === second.id));
    observer.send({ join: { roomID: second.id } });
    await observer.wait('room', room => room.id === second.id && room.players.length === 2);
    observer.send({ leave: {} });
    await observer.wait('left');
    await observer.wait('list', list => list.some(room => room.id === second.id && room.playerCount === 1));
    legacy.send({ list: {} });
    assert(!(await legacy.wait('list')).some(room => room.id === second.id));
    console.log('PASS pushed directory create/quick leave/new create/full-seat reopen and legacy revision isolation');
  } finally { [host, observer, legacy].forEach(client => client.close()); }
}

await rejectMalformedAndUnauthenticated();
await directoryLifecycle();
await Promise.all([1, 2].flatMap(revision => [2, 3, 4].map(capacity => runRoom(capacity, false, revision))));
await runRoom(2, true);
console.log('All local real WebSocket checks passed. No WSS/network impairment or physical-device claim.');
