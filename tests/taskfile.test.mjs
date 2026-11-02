import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';

const task = process.env.TASK_BIN;
const taskfile = process.env.TASKFILE;
assert.ok(task && taskfile, 'Run via the taskfile Nix check (TASK_BIN and TASKFILE required)');
const config = JSON.parse(readFileSync(taskfile, 'utf8'));

function run(name, { terminal = false, mode = 'auto', env = {} } = {}) {
  const args = ['--terminal-status', mode, '--taskfile', taskfile, name];
  const quote = value => `'${value.replaceAll("'", "'\\''")}'`;
  const options = {
    encoding: 'utf8', timeout: 10000,
    env: { ...process.env, TERM: 'xterm-256color', CI: '', ...env },
  };
  const result = terminal
    ? spawnSync('script', process.platform === 'darwin'
      ? ['-q', '/dev/null', task, ...args]
      : ['-qec', [task, ...args].map(quote).join(' '), '/dev/null'], {
      ...options, stdio: ['ignore', 'pipe', 'pipe'],
    })
    : spawnSync(task, args, options);
  assert.equal(result.error, undefined);
  return result;
}

const reports = output => [...output.matchAll(/\x1b\]7501;([^\x07\x1b]*)(?:\x07|\x1b\\)/g)].map(match => match[1]);

test('generated tasks preserve commands, dependencies, and aliases', () => {
  assert.deepEqual(config.tasks.example.deps, ['prepare']);
  assert.deepEqual(config.tasks.example.aliases, ['alias']);
  assert.deepEqual(config.tasks.example.cmds, ["printf 'body\\n'"]);
  assert.equal(config.tasks.prepare.cmd, "printf 'prepare\\n'");
  assert.equal(config.tasks.prepare.cmds, undefined);
  assert.equal(config.tasks.aggregate.cmds, undefined);
});

test('redirected output stays clean even with always, and failures still fail', () => {
  for (const mode of ['auto', 'always']) {
    const result = run('example', { mode });
    assert.equal(result.status, 0, result.stderr);
    assert.equal(result.stdout, 'prepare\nbody\n');
    assert.deepEqual(reports(result.stdout + result.stderr), []);
  }
  assert.notEqual(run('failure').status, 0);
});

test('native status reports execution and completion', () => {
  for (const name of ['example', 'alias', 'aggregate']) {
    const result = run(name, { terminal: true });
    assert.equal(result.status, 0, result.stdout + result.stderr);
    const status = reports(result.stdout);
    assert.ok(status.some(report => report.includes('state=working')), result.stdout);
    assert.ok(status.some(report => report.includes('state=done')), result.stdout);
    assert.ok(status.every(report => report.includes('app=task')));
    assert.ok(result.stdout.includes('prepare'));
    assert.ok(result.stdout.includes('body'));
  }
});

test('native status reports failures', () => {
  const result = run('failure', { terminal: true });
  assert.ok(reports(result.stdout).some(report => report.includes('state=error')), result.stdout);
});

test('never, CI, and dumb terminals suppress automatic status', () => {
  for (const options of [{ mode: 'never' }, { env: { CI: 'true' } }, { env: { TERM: 'dumb' } }]) {
    const result = run('example', { terminal: true, ...options });
    assert.equal(result.status, 0, result.stdout + result.stderr);
    assert.deepEqual(reports(result.stdout), []);
  }
});

test('up-to-date tasks are not forced to execute', () => {
  const result = run('cached', { terminal: true });
  assert.equal(result.status, 0, result.stdout + result.stderr);
  assert.ok(!result.stdout.includes('exit 99'));
});
