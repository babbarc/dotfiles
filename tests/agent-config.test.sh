#!/usr/bin/env bash
# tests/agent-config.test.sh - behavior tests for the pi/Claude agent config
# merge scripts and the create-only models.json seed.
#
# Coverage:
# - dot_pi/agent/modify_settings.json merges its full default set (theme,
#   hideThinkingBlock, steeringMode, followUpMode, images.blockImages,
#   terminal.showImages, quietStartup, collapseChangelog) into arbitrary
#   existing content, including nested objects pi itself writes;
# - dot_claude/modify_settings.json merges autoCompactWindow while preserving
#   the herdr SessionStart hook and any other existing key;
# - dot_pi/agent/create_models.json is created only when ~/.pi/agent/models.json
#   is absent, and a real chezmoi apply never touches a pre-existing one;
# - dot_pi/agent/create_models.json caps every model override's contextWindow
#   at 272000 (mirroring Claude's autoCompactWindow cap), including the
#   deepseek-v4-* overrides.
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

test_models_json_seed_caps_context_window_at_272k() {
  local create_src="$ROOT/dot_pi/agent/create_models.json" deepseek_windows max_window
  [ -f "$create_src" ] || fail "dot_pi/agent/create_models.json is missing"
  jq -e . "$create_src" >/dev/null 2>&1 || fail "dot_pi/agent/create_models.json is not valid JSON"

  deepseek_windows=$(jq -r '.providers.deepseek.modelOverrides | to_entries[] | select(.key | startswith("deepseek-v4-")) | "\(.key)=\(.value.contextWindow)"' "$create_src")
  [ -n "$deepseek_windows" ] || fail "no deepseek-v4-* model overrides found in create_models.json"
  while IFS= read -r line; do
    case "$line" in
      *=272000) ;;
      *) fail "deepseek-v4-* override not capped at 272000: $line" ;;
    esac
  done <<<"$deepseek_windows"

  max_window=$(jq -r '[.providers[].modelOverrides[].contextWindow] | max' "$create_src")
  [ "$max_window" -le 272000 ] || fail "a model override in create_models.json exceeds 272000: $max_window"

  pass "create_models.json caps every deepseek-v4-* override (and all overrides) at 272000"
}

test_pi_settings_modify_script_merges_and_preserves() {
  local script="$ROOT/dot_pi/agent/modify_settings.json" existing out
  [ -x "$script" ] || fail "dot_pi/agent/modify_settings.json is not executable"

  existing='{"defaultProvider":"deepseek","packages":["foo"],"images":{"custom":1},"lastChangelogVersion":"1.2.3"}'
  out=$(printf '%s' "$existing" | "$script") || fail "pi modify_settings.json script exited non-zero"

  assert_contains "$out" '"theme": "rose-pine-moon"' "pi settings merge missing theme default"
  assert_contains "$out" '"hideThinkingBlock": true' "pi settings merge missing hideThinkingBlock default"
  assert_contains "$out" '"steeringMode": "all"' "pi settings merge missing steeringMode default"
  assert_contains "$out" '"followUpMode": "all"' "pi settings merge missing followUpMode default"
  assert_contains "$out" '"blockImages": false' "pi settings merge missing images.blockImages default"
  assert_contains "$out" '"showImages": false' "pi settings merge missing terminal.showImages default"
  assert_contains "$out" '"quietStartup": true' "pi settings merge missing quietStartup default"
  assert_contains "$out" '"collapseChangelog": true' "pi settings merge missing collapseChangelog default"

  # Pi-written fields and nested keys neither side shares must survive untouched.
  assert_contains "$out" '"defaultProvider": "deepseek"' "pi settings merge dropped a pi-written field"
  assert_contains "$out" '"foo"' "pi settings merge dropped the packages array"
  assert_contains "$out" '"custom": 1' "pi settings merge dropped a nested key under images"
  assert_contains "$out" '"lastChangelogVersion": "1.2.3"' "pi settings merge dropped lastChangelogVersion"

  # This script must not manage packages/extensions itself - it must only pass
  # through whatever pi (or the pre-existing file) already had for them.
  assert_not_contains "$(cat "$script")" '"packages"' "pi modify_settings.json declares its own packages default"
  assert_not_contains "$(cat "$script")" '"extensions"' "pi modify_settings.json declares its own extensions default"

  pass "pi modify_settings.json merges the full default set and preserves every pi-written and nested key"
}

test_claude_settings_modify_script_preserves_herdr_hook() {
  local script="$ROOT/dot_claude/modify_settings.json" existing out
  [ -f "$script" ] || fail "dot_claude/modify_settings.json is missing"
  [ -x "$script" ] || fail "dot_claude/modify_settings.json is not executable"

  existing='{"hooks":{"SessionStart":[{"hooks":[{"type":"command","command":"herdr session-start"}]}]},"otherKey":"keep-me"}'
  out=$(printf '%s' "$existing" | "$script") || fail "claude modify_settings.json script exited non-zero"

  assert_contains "$out" '"autoCompactWindow": 272000' "claude settings merge missing autoCompactWindow"
  assert_contains "$out" 'herdr session-start' "claude settings merge dropped the herdr SessionStart hook"
  assert_contains "$out" '"otherKey": "keep-me"' "claude settings merge dropped an unrelated existing key"

  # Empty/absent existing file must not fail the script.
  out=$(printf '' | "$script") || fail "claude modify_settings.json failed on an empty/absent existing file"
  assert_contains "$out" '"autoCompactWindow": 272000' "claude settings merge on empty input missing autoCompactWindow"

  pass "claude modify_settings.json merges autoCompactWindow and preserves the herdr SessionStart hook and other keys"
}

test_models_json_is_create_only() {
  local create_src="$ROOT/dot_pi/agent/create_models.json" scratch_home scratch_dest scratch_cache existing_content
  [ -f "$create_src" ] || fail "dot_pi/agent/create_models.json is missing"
  jq -e . "$create_src" >/dev/null 2>&1 || fail "dot_pi/agent/create_models.json is not valid JSON"

  if ! command -v chezmoi >/dev/null 2>&1; then
    echo "skip: chezmoi not found for models.json create-only contract"
    return 0
  fi

  scratch_home=$(dotfiles_test_tmproot agent-config-home)
  scratch_dest=$(dotfiles_test_tmproot agent-config-dest)
  scratch_cache=$(dotfiles_test_tmproot agent-config-cache)
  # dotfiles_test_tmproot's self-cleaning trap is installed inside the
  # command-substitution subshell that produces each path, so it fires (and
  # removes the directory) as soon as that subshell exits, before this
  # function ever sees the path - mkdir -p it back into existence here, same
  # as every fixture builder in tests/pi-calm.test.sh already does.
  mkdir -p "$scratch_home/.config/dotfiles" "$scratch_dest" "$scratch_cache"
  cp "$ROOT/env.example" "$scratch_home/.config/dotfiles/env"

  HOME="$scratch_home" chezmoi init --source "$ROOT" --destination "$scratch_dest" --cache "$scratch_cache" --no-tty \
    >/dev/null 2>&1 || fail "chezmoi init failed for models.json create-only fixture"
  HOME="$scratch_home" chezmoi apply --source "$ROOT" --destination "$scratch_dest" --cache "$scratch_cache" --no-tty \
    >/dev/null 2>&1 || fail "first chezmoi apply failed for models.json create-only fixture"

  [ -f "$scratch_dest/.pi/agent/models.json" ] || fail "first apply did not create ~/.pi/agent/models.json"
  diff -q "$create_src" "$scratch_dest/.pi/agent/models.json" >/dev/null 2>&1 \
    || fail "first apply's models.json does not match the seed content"

  # Hand-edit models.json the way the captain is expected to, forever after.
  existing_content='{"providers":{"deepseek":{"modelOverrides":{"my-local-model":{"contextWindow":42}}}}}'
  printf '%s' "$existing_content" >"$scratch_dest/.pi/agent/models.json"

  HOME="$scratch_home" chezmoi apply --source "$ROOT" --destination "$scratch_dest" --cache "$scratch_cache" --no-tty \
    >/dev/null 2>&1 || fail "second chezmoi apply failed for models.json create-only fixture"

  [ "$(cat "$scratch_dest/.pi/agent/models.json")" = "$existing_content" ] \
    || fail "second apply overwrote a hand-edited models.json instead of leaving it untouched"

  pass "create_models.json seeds ~/.pi/agent/models.json once and a later apply never touches a hand-edited copy"
}

test_models_json_seed_caps_context_window_at_272k
test_pi_settings_modify_script_merges_and_preserves
test_claude_settings_modify_script_preserves_herdr_hook
test_models_json_is_create_only
