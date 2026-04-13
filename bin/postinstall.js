#!/usr/bin/env node
'use strict';
// Postinstall hook — wires gastown.sh into GSD's execute-phase.md.
// Full implementation in gsd-town Plan 02 (PKG-03).
// For now, just print the manual sourcing instruction.

const path = require('path');
const GASTOWN_SH = path.join(__dirname, '..', 'lib', 'gastown.sh');

console.log('');
console.log('gsd-town installed.');
console.log(`gastown.sh is at: ${GASTOWN_SH}`);
console.log('');
console.log('To complete setup, run /gsd-town-setup in any GSD project.');
console.log('');
