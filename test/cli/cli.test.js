// CLI smoke tests for gsd-town using Node's built-in test runner.
// Run: node --test test/cli/
'use strict';

const { test } = require('node:test');
const assert = require('node:assert/strict');
const { execSync } = require('node:child_process');
const path = require('node:path');

const CLI = path.join(__dirname, '..', '..', 'bin', 'gsd-town.js');

function run(args = '', opts = {}) {
  try {
    return {
      stdout: execSync(`node "${CLI}" ${args}`, { encoding: 'utf8', ...opts }),
      code: 0,
    };
  } catch (e) {
    return { stdout: e.stdout || '', stderr: e.stderr || '', code: e.status };
  }
}

test('version prints semver', () => {
  const { stdout, code } = run('version');
  assert.equal(code, 0);
  assert.match(stdout, /^\d+\.\d+\.\d+/);
});

test('help lists commands', () => {
  const { stdout, code } = run('help');
  assert.equal(code, 0);
  assert.match(stdout, /setup/);
  assert.match(stdout, /teardown/);
  assert.match(stdout, /status/);
});

test('bare invocation shows help', () => {
  const { stdout, code } = run('');
  assert.equal(code, 0);
  assert.match(stdout, /gsd-town/);
});

test('unknown command exits non-zero', () => {
  const { code } = run('nonsense-command');
  assert.notEqual(code, 0);
});

test('path prints gastown.sh location', () => {
  const { stdout, code } = run('path');
  assert.equal(code, 0);
  assert.match(stdout, /gastown\.sh$/m);
  // The printed path should exist on disk
  const printedPath = stdout.trim();
  const fs = require('node:fs');
  assert.ok(fs.existsSync(printedPath), `path does not exist: ${printedPath}`);
});

test('status exits 0 or 1 (never crashes)', () => {
  const { code } = run('status');
  // gastown may or may not be available — both 0 and 1 are acceptable
  // What matters is we don't crash with some other exit code
  assert.ok(code === 0 || code === 1, `unexpected exit code: ${code}`);
});
