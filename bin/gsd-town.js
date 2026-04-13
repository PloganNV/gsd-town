#!/usr/bin/env node
'use strict';

const path = require('path');
const { execSync } = require('child_process');
const pkg = require('../package.json');

const GASTOWN_SH = path.join(__dirname, '..', 'lib', 'gastown.sh');
const cmd = process.argv[2];

const HELP = `
gsd-town v${pkg.version} — Multi-agent GSD execution via Gas Town polecats

Commands:
  status      Check gastown daemon and detect availability
  path        Print path to bundled gastown.sh
  version     Print version
  help        Show this message

After installing:
  source "$(gsd-town path)"   # in your shell or execute-phase.md

Run /gsd-town-setup in any GSD project to configure polecat dispatch.
`.trim();

switch (cmd) {
  case 'status': {
    try {
      const out = execSync(`bash -c 'source "${GASTOWN_SH}" && detect_gastown'`, {
        encoding: 'utf8',
        timeout: 10000,
      }).trim();
      console.log(`gastown available: ${out}`);
      process.exit(out === 'true' ? 0 : 1);
    } catch (e) {
      console.error('gastown detection failed:', e.message);
      process.exit(1);
    }
  }
  case 'path':
    console.log(GASTOWN_SH);
    break;
  case 'version':
    console.log(pkg.version);
    break;
  case 'help':
  case undefined:
    console.log(HELP);
    break;
  default:
    console.error(`Unknown command: ${cmd}\nRun: gsd-town help`);
    process.exit(1);
}
