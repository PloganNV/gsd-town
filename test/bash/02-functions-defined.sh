#!/usr/bin/env bash
# Verify all expected functions are defined in each module.
# Run: bash test/bash/02-functions-defined.sh

set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PASS=0
FAIL=0

# Source modules in a subshell so we don't pollute the test process
assert_function_exists() {
  local module="$1"
  local func="$2"

  if (source "$REPO_ROOT/lib/$module" >/dev/null 2>&1 && declare -F "$func" >/dev/null); then
    echo "  ok — $module: $func"
    PASS=$((PASS + 1))
  else
    echo "  FAIL — $module: $func not defined"
    FAIL=$((FAIL + 1))
  fi
}

echo "function definition checks:"

# gastown.sh — dispatch and monitoring functions
for func in \
  detect_gastown \
  gt_cmd \
  bd_cmd \
  create_plan_bead \
  create_phase_convoy \
  add_bead_to_convoy \
  check_polecat_state \
  dispatch_plan_to_polecat \
  format_plan_notes \
  wait_for_polecats \
  reconstruct_summary_from_bead \
  write_results_to_bead \
  store_bead_mapping \
  check_escalation_status \
  check_capacity \
  queue_or_dispatch \
  resolve_plan_from_bead \
  seance_context_block \
  launch_convoy \
  poll_convoy_status \
  tail_witness_events \
  check_witness_status \
  wait_for_refinery_merge \
  detect_refinery_active
do
  assert_function_exists "gastown.sh" "$func"
done

# auto-setup.sh — lifecycle functions
for func in detect_town check_and_install_deps bootstrap_town; do
  assert_function_exists "auto-setup.sh" "$func"
done

# bead-state.sh — state management
for func in \
  generate_state_from_beads \
  read_plan_result_from_bead \
  check_phase_completion_from_convoy \
  sync_requirements_from_beads
do
  assert_function_exists "bead-state.sh" "$func"
done

# seance.sh — continuity
for func in \
  get_seance_predecessors \
  build_seance_context \
  inject_seance_into_notes
do
  assert_function_exists "seance.sh" "$func"
done

echo ""
echo "results: $PASS passed, $FAIL failed"
[ $FAIL -eq 0 ]
