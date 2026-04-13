#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');
const os = require('os');

const PKG_ROOT = path.join(__dirname, '..');
const SKILL_SRC = path.join(PKG_ROOT, 'skills', 'gsd-town-setup');
const SKILL_DEST = path.join(os.homedir(), '.claude', 'skills', 'gsd-town-setup');
const EXECUTE_PHASE = path.join(os.homedir(), '.claude', 'get-shit-done', 'workflows', 'execute-phase.md');
const GASTOWN_SOURCE_LINE = '  source "${HOME}/.claude/get-shit-done/bin/lib/gastown.sh"';
const GASTOWN_SH_VAR = 'GASTOWN_SH="${HOME}/.claude/get-shit-done/bin/lib/gastown.sh"';

try {
  console.log('gsd-town postinstall:');

  // 1. Install skill — copy all files from skills/gsd-town-setup/ to ~/.claude/skills/gsd-town-setup/
  fs.mkdirSync(SKILL_DEST, { recursive: true });
  const skillFiles = fs.readdirSync(SKILL_SRC);
  for (const f of skillFiles) {
    fs.copyFileSync(path.join(SKILL_SRC, f), path.join(SKILL_DEST, f));
  }
  console.log(`  [ok] skill installed: ${SKILL_DEST}/SKILL.md`);

  // 2. Patch execute-phase.md — insert source line after GASTOWN_SH= assignment
  if (!fs.existsSync(EXECUTE_PHASE)) {
    console.log(`  [skip] execute-phase.md not found at ${EXECUTE_PHASE} — GSD not installed`);
  } else {
    const content = fs.readFileSync(EXECUTE_PHASE, 'utf8');

    // Idempotency check: if the file already contains a source line for gastown.sh, skip
    if (content.includes('source') && content.includes('gastown.sh')) {
      console.log('  [skip] execute-phase.md already patched');
    } else {
      const lines = content.split('\n');
      const varIdx = lines.findIndex(l => l.includes(GASTOWN_SH_VAR));
      const detectIdx = lines.findIndex(l => l.includes('detect_gastown'));

      if (varIdx >= 0) {
        lines.splice(varIdx + 1, 0, GASTOWN_SOURCE_LINE);
        fs.writeFileSync(EXECUTE_PHASE, lines.join('\n'), 'utf8');
        console.log('  [ok] execute-phase.md patched with gastown source line');
      } else if (detectIdx >= 0) {
        lines.splice(detectIdx, 0, GASTOWN_SOURCE_LINE);
        fs.writeFileSync(EXECUTE_PHASE, lines.join('\n'), 'utf8');
        console.log('  [ok] execute-phase.md patched with gastown source line (before detect_gastown)');
      } else {
        console.log('  [warn] execute-phase.md patch skipped — anchor not found. Add manually:');
        console.log(`         ${GASTOWN_SOURCE_LINE}`);
      }
    }
  }

  console.log('');
  console.log('Setup complete. Run /gsd-town-setup in any GSD project to configure polecat dispatch.');
} catch (e) {
  process.stderr.write(`gsd-town postinstall error: ${e.message}\n`);
}
process.exit(0);
