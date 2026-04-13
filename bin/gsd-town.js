#!/usr/bin/env node
'use strict';

const path = require('path');
const fs = require('fs');
const os = require('os');
const { execSync } = require('child_process');
const pkg = require('../package.json');

const GASTOWN_SH = path.join(__dirname, '..', 'lib', 'gastown.sh');
const AUTO_SETUP_SH = path.join(__dirname, '..', 'lib', 'auto-setup.sh');
const cmd = process.argv[2];

const HELP = `
gsd-town v${pkg.version} — Multi-agent GSD execution via Gas Town polecats

Commands:
  setup       Detect/install/bootstrap gastown for this project
  teardown    Stop daemon (--remove-data to also delete ~/.gsd-town)
  status      Check gastown daemon and managed town
  path        Print path to bundled gastown.sh
  version     Print version
  help        Show this message

Zero-config usage:
  Set workflow.use_gastown: auto in your GSD config (or leave unset) to enable
  automatic dispatch. "auto" is treated as enabled — no extra setup needed.

After installing:
  source "$(gsd-town path)"   # in your shell or execute-phase.md

Run \`gsd-town setup\` in any GSD project to configure polecat dispatch manually.
`.trim();

// ---------------------------------------------------------------------------
// runBash(script, opts)
//
// Sources both gastown.sh and auto-setup.sh before running the given bash
// snippet. All auto-setup function calls go through this helper.
//
// Security note: project_dir comes from process.cwd() (not user input) and
// rig_name is derived from path.basename(process.cwd()) with sanitization
// applied in the setup case. JSON.stringify safely escapes the script string
// for the shell — no user-controlled input reaches execSync directly.
// ---------------------------------------------------------------------------

function runBash(script, opts = {}) {
  const fullScript = [
    `source "${GASTOWN_SH}"`,
    `source "${AUTO_SETUP_SH}"`,
    script,
  ].join('\n');
  return execSync(`bash -c ${JSON.stringify(fullScript)}`, {
    encoding: 'utf8',
    timeout: opts.timeout || 300000, // 5 min default for installs
    stdio: opts.stdio || 'pipe',
  });
}

switch (cmd) {
  case 'setup': {
    const projectDir = process.cwd();
    const rigName = path.basename(projectDir).toLowerCase().replace(/[^a-z0-9-]/g, '-');
    console.log(`gsd-town setup: configuring ${rigName} at ${projectDir}`);
    try {
      // Step 1: check deps
      console.log('\nChecking dependencies...');
      runBash('check_and_install_deps', { stdio: 'inherit' });

      // Step 2: detect or bootstrap town
      console.log('\nDetecting town...');
      let townPath;
      try {
        townPath = runBash('detect_town').trim();
        console.log(`Town found: ${townPath}`);
      } catch (_) {
        console.log('No town found — bootstrapping...');
        runBash(`bootstrap_town "${projectDir}" "${rigName}"`, { stdio: 'inherit' });
        townPath = process.env.GSD_TOWN_ROOT || path.join(os.homedir(), '.gsd-town');
      }

      console.log('\nSetup complete.');
      console.log(`  Town: ${townPath}`);
      console.log(`  Rig:  ${rigName}`);
      console.log('\nTo dispatch polecats: set workflow.use_gastown: auto in your GSD project config.');
    } catch (e) {
      console.error('Setup failed:', e.message);
      process.exit(1);
    }
    break;
  }

  case 'teardown': {
    const removeData = process.argv.includes('--remove-data');
    console.log('gsd-town teardown: stopping daemon...');
    try {
      const townRoot = process.env.GSD_TOWN_ROOT || path.join(os.homedir(), '.gsd-town');
      // [T-03-07] --remove-data requires explicit flag; no accidental deletion path
      const removeSnippet = removeData
        ? `rm -rf "$TOWN" && echo "Town data removed: $TOWN"`
        : '# --remove-data not set, keeping town data';
      runBash(`
        TOWN="${townRoot}"
        if [ -d "$TOWN" ]; then
          cd "$TOWN" && gt daemon stop 2>/dev/null || true
          echo "Daemon stopped."
        else
          echo "No managed town found at $TOWN"
        fi
        ${removeSnippet}
      `, { stdio: 'inherit' });
      console.log('Teardown complete.');
      if (!removeData) {
        console.log('Town data preserved. Run with --remove-data to delete ~/.gsd-town.');
      }
    } catch (e) {
      console.error('Teardown error:', e.message);
      process.exit(1);
    }
    break;
  }

  case 'status': {
    try {
      const gastown = execSync(`bash -c 'source "${GASTOWN_SH}" && detect_gastown'`, {
        encoding: 'utf8',
        timeout: 10000,
      }).trim();
      console.log(`gastown available: ${gastown}`);
      // Also report managed town
      const townRoot = process.env.GSD_TOWN_ROOT || path.join(os.homedir(), '.gsd-town');
      if (fs.existsSync(townRoot)) {
        console.log(`managed town: ${townRoot}`);
      } else {
        console.log('managed town: not initialized (run: gsd-town setup)');
      }
      process.exit(gastown === 'true' ? 0 : 1);
    } catch (e) {
      console.error('gastown detection failed:', e.message);
      process.exit(1);
    }
    break;
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
