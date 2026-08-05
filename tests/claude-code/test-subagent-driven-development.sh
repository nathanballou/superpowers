#!/usr/bin/env bash
# Test: subagent-driven-development skill
# Verifies that the skill is loaded and follows correct workflow
#
# No drill coverage: this test asks the agent to *describe* SDD (string-
# matches its verbal explanation against expected keywords like
# "self-review", "skeptical", "worktree", "Step 1", "loop"). Drill scenarios
# test behavior (real subagent dispatch, plan-following, review loops),
# not description-recall. Kept by design.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/test-helpers.sh"

CLAUDE_PROMPT_TIMEOUT="${CLAUDE_PROMPT_TIMEOUT:-90}"

echo "=== Test: subagent-driven-development skill ==="
echo ""

# Test 1: Verify skill can be loaded
echo "Test 1: Skill loading..."

output=$(run_claude "What is the subagent-driven-development skill? Describe its key steps briefly." "$CLAUDE_PROMPT_TIMEOUT")

if assert_contains "$output" "subagent-driven-development\|Subagent-Driven Development\|Subagent Driven" "Skill is recognized"; then
    : # pass
else
    exit 1
fi

if assert_contains "$output" "Load Plan\|read.*plan\|extract.*tasks" "Mentions loading plan"; then
    : # pass
else
    exit 1
fi

echo ""

# Test 2: Verify skill describes correct workflow order
echo "Test 2: Workflow ordering..."

output=$(run_claude "In the subagent-driven-development skill, what comes first: spec compliance review or code quality review? Answer using exactly this structure:
First: <review type>
Second: <review type>" "$CLAUDE_PROMPT_TIMEOUT")

if assert_order "$output" "First:.*spec.*compliance" "Second:.*code.*quality" "Spec compliance before code quality"; then
    : # pass
else
    exit 1
fi

echo ""

# Test 3: Verify self-review is mentioned
echo "Test 3: Self-review requirement..."

output=$(run_claude "Does the subagent-driven-development skill require implementers to self-review before handoff, and can self-review replace the external reviews? Answer using exactly this structure:
Self-review required: <yes or no>
Self-review replaces external review: <yes or no>" "$CLAUDE_PROMPT_TIMEOUT")

if assert_contains "$output" "Self-review required:.*yes" "Mentions self-review"; then
    : # pass
else
    exit 1
fi

if assert_contains "$output" "Self-review replaces external review:.*no" "Self-review does not replace external review"; then
    : # pass
else
    exit 1
fi

echo ""

# Test 4: Verify plan is read once
echo "Test 4: Plan reading efficiency..."

output=$(run_claude "In subagent-driven-development, how many times should the controller read the plan file? When does this happen?" "$CLAUDE_PROMPT_TIMEOUT")

if assert_contains "$output" "once\|one time\|single" "Read plan once"; then
    : # pass
else
    exit 1
fi

if assert_contains "$output" "Step 1\|beginning\|start\|Load Plan" "Read at beginning"; then
    : # pass
else
    exit 1
fi

echo ""

# Test 5: Verify spec compliance reviewer is skeptical
echo "Test 5: Spec compliance reviewer mindset..."

output=$(run_claude "What is the spec compliance reviewer's attitude toward the implementer's report in subagent-driven-development?" "$CLAUDE_PROMPT_TIMEOUT")

if assert_contains "$output" "not.*trust\|don't trust\|skeptical\|verify.*independently\|suspiciously" "Reviewer is skeptical"; then
    : # pass
else
    exit 1
fi

if assert_contains "$output" "read.*code\|inspect.*code\|verify.*code\|read.*diff\|trust.*diff" "Reviewer reads code"; then
    : # pass
else
    exit 1
fi

echo ""

# Test 6: Verify review loops
echo "Test 6: Review loop requirements..."

output=$(run_claude "In subagent-driven-development, what happens if a reviewer finds issues? Is it a one-time review or a loop?" "$CLAUDE_PROMPT_TIMEOUT")

if assert_contains "$output" "loop\|again\|repeat\|until.*approved\|until.*compliant" "Review loops mentioned"; then
    : # pass
else
    exit 1
fi

if assert_contains "$output" "implementer.*fix\|fix.*issues" "Implementer fixes issues"; then
    : # pass
else
    exit 1
fi

echo ""

# Test 7: Verify full task text is provided
echo "Test 7: Task context provision..."

output=$(run_claude "In subagent-driven-development, how does the controller provide task information to the implementer subagent? Answer using exactly this structure:
Controller provides: <directly or by file>
Implementer must read plan file: <yes or no>" "$CLAUDE_PROMPT_TIMEOUT")

if assert_contains "$output" "provide.*directly\|full.*text\|paste\|include.*prompt" "Provides text directly"; then
    : # pass
else
    exit 1
fi

if assert_contains "$output" "Implementer must read plan file:.*no" "Doesn't make subagent read file"; then
    : # pass
else
    exit 1
fi

echo ""

# Test 8: Verify worktree requirement
echo "Test 8: Worktree requirement..."

output=$(run_claude "What workflow skills are required before using subagent-driven-development? List any prerequisites or required skills." "$CLAUDE_PROMPT_TIMEOUT")

if assert_contains "$output" "using-git-worktrees\|worktree" "Mentions worktree requirement"; then
    : # pass
else
    exit 1
fi

echo ""

# Test 9: Verify main branch warning
echo "Test 9: Main branch red flag..."

output=$(run_claude "In subagent-driven-development, is it okay to start implementation directly on the main branch?" "$CLAUDE_PROMPT_TIMEOUT")

if assert_contains "$output" "worktree\|feature.*branch\|not.*main\|never.*main\|avoid.*main\|don't.*main\|consent\|permission" "Warns against main branch"; then
    : # pass
else
    exit 1
fi

echo ""

# Test 10: Verify independent tasks fan out concurrently
echo "Test 10: Parallel fan-out..."

output=$(run_claude "In subagent-driven-development, a plan has three tasks with no dependencies between them. Answer using exactly this structure:
Dispatch: <one at a time or all at once>
Dispatches per message: <one or multiple>" "$CLAUDE_PROMPT_TIMEOUT")

if assert_contains "$output" "Dispatch:.*all at once\|Dispatch:.*parallel\|Dispatch:.*concurrent" "Independent tasks dispatch together"; then
    : # pass
else
    exit 1
fi

if assert_contains "$output" "Dispatches per message:.*multiple" "Multiple dispatches in one message"; then
    : # pass
else
    exit 1
fi

echo ""

# Test 11: Verify shared interfaces are frozen before fan-out
echo "Test 11: Contract freeze before parallel work..."

output=$(run_claude "In subagent-driven-development, two tasks in the same wave both use a shared type. What must happen before they are dispatched, and what should an implementer do if it decides that shared interface is wrong?" "$CLAUDE_PROMPT_TIMEOUT")

if assert_contains "$output" "freez\|frozen\|contract\|settle.*interface\|pin.*interface" "Shared interfaces frozen before dispatch"; then
    : # pass
else
    exit 1
fi

if assert_contains "$output" "CONTRACT_CHANGE\|stop\|halt\|escalat\|report.*controller" "Implementer escalates instead of changing it"; then
    : # pass
else
    exit 1
fi

echo ""

# Test 12: Verify the integration barrier runs the suite
echo "Test 12: Integration barrier..."

output=$(run_claude "In subagent-driven-development, three tasks ran in parallel and each reported its own test suite passing. Answer using exactly this structure:
Full suite re-run after integration: <yes or no>
Reason: <one sentence>" "$CLAUDE_PROMPT_TIMEOUT")

if assert_contains "$output" "Full suite re-run after integration:.*yes" "Runs the suite on the integrated tree"; then
    : # pass
else
    exit 1
fi

echo ""

# Test 13: Verify fix rounds prefer a fresh subagent over messaging a live one
echo "Test 13: Fix rounds dispatch fresh..."

output=$(run_claude "In subagent-driven-development, a task reviewer returns an Important finding. The implementer that wrote the code has already reported and its work is committed. Answer using exactly this structure:
Fix round uses: <fresh subagent or the original implementer>
What carries the prior context: <what>
Message a live subagent when: <when>" "$CLAUDE_PROMPT_TIMEOUT")

if assert_contains "$output" "Fix round uses:.*fresh" "Fix round dispatches a fresh subagent"; then
    : # pass
else
    exit 1
fi

if assert_contains "$output" "report file\|report" "Report file carries the context"; then
    : # pass
else
    exit 1
fi

if assert_contains "$output" "still working\|mid-task\|question\|in flight\|has not reported\|hasn't reported" "Live messaging only for in-flight continuation"; then
    : # pass
else
    exit 1
fi

echo ""

echo "=== All subagent-driven-development skill tests passed ==="
