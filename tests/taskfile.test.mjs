import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, writeFileSync, mkdtempSync, rmSync, existsSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';

const task = process.env.TASK_BIN;
const taskfile = process.env.TASKFILE;
assert.ok(task && taskfile, 'Run via the taskfile Nix check (TASK_BIN and TASKFILE required)');
const config = JSON.parse(readFileSync(taskfile, 'utf8'));

function run(name, { terminal = false, file = taskfile, cwd } = {}) {
  const args = ['--taskfile', file, name, 'VALUE=private', '--', 'private argument'];
  const quote = value => `'${value.replaceAll("'", "'\\''")}'`;
  const result = terminal
    ? spawnSync('script', process.platform === 'darwin'
      ? ['-q', '/dev/null', task, ...args]
      : ['-qec', [task, ...args].map(quote).join(' '), '/dev/null'], {
      cwd, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'], timeout: 10000,
    })
    : spawnSync(task, args, { cwd, encoding: 'utf8', timeout: 10000 });
  assert.equal(result.error, undefined);
  return result;
}

const titles = output => [...output.matchAll(/\x1b\]0;([^\x07]*)\x07/g)].map(match => match[1]);

test('every generated task gets the same silent command, including mkForce and cmd shorthand', () => {
  const title = config.tasks.example.cmds[0];
  assert.equal(title.silent, true);
  for (const task of Object.values(config.tasks)) {
    assert.deepEqual(task.cmds[0], title);
  }
  assert.deepEqual(config.tasks.example.deps, ['prepare']);
  assert.deepEqual(config.tasks.example.aliases, ['alias']);
  assert.equal(config.tasks.example.cmds[1], "printf 'body\\n'");
  assert.equal(config.tasks.prepare.cmd, undefined);
  assert.equal(config.tasks.prepare.cmds[1], "printf 'prepare\\n'");
});

test('redirected output stays clean and task failures still fail', () => {
  const result = run('example');
  assert.equal(result.status, 0, result.stderr);
  assert.equal(result.stdout, 'prepare\nbody\n');
  assert.ok(!result.stderr.includes('\x1b]'));
  assert.ok(!result.stderr.includes('7501'));
  assert.notEqual(run('failure').status, 0);
});

test('titles follow dependencies and aliases without exposing CLI arguments', () => {
  for (const [name, expected] of [
    ['example', ['task prepare', 'task example']],
    ['alias', ['task prepare', 'task example']],
    ['aggregate', ['task prepare', 'task example', 'task aggregate']],
  ]) {
    const result = run(name, { terminal: true });
    assert.equal(result.status, 0, result.stdout + result.stderr);
    assert.deepEqual(titles(result.stdout), expected);
    assert.ok(result.stdout.includes('\x1b]7501;state=working:app=task\x1b\\'));
    assert.ok(!result.stdout.includes('private'));
    assert.ok(!result.stdout.includes('regexReplaceAll'));
  }
});

test('up-to-date tasks are not forced to run for a title', () => {
  const result = run('cached', { terminal: true });
  assert.equal(result.status, 0, result.stdout + result.stderr);
  assert.deepEqual(titles(result.stdout), []);
});

test('task names are shell-quoted and control characters cannot escape the title', () => {
  const dir = mkdtempSync(join(tmpdir(), 'task-title-'));
  try {
    const name = "odd:'$(touch injected)%\\name\n\x07\x1b\u0085\u202e";
    const file = join(dir, 'Taskfile.yml');
    writeFileSync(file, JSON.stringify({
      version: '3', tasks: { [name]: { cmds: [config.tasks.example.cmds[0]] } },
    }).replace(/[\u007f-\uffff]/g, char => `\\u${char.charCodeAt(0).toString(16).padStart(4, '0')}`));
    const result = run(name, { terminal: true, file, cwd: dir });
    assert.equal(result.status, 0, result.stdout + result.stderr);
    assert.deepEqual(titles(result.stdout), ["task odd:'$(touch injected)%\\name"]);
    assert.equal(existsSync(join(dir, 'injected')), false);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});
