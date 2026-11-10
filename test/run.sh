#!/bin/sh
# Every case runs against a real daukle and a real pnpm, because what this
# plugin produces is the closure pnpm computed; a stub of either would be
# testing the stub.
#
# A case reaching the registry carries a "needs-registry" marker and is skipped
# unless DAUKLE_PNPM_E2E=1. CI sets it on every runner: pinning is the whole of
# what this plugin does, so a run that skipped those proved only that bad input
# is refused.
#
# A case holds a daukle.toml, optionally a "task" line (default
# "pnpm:resolve --resolve"), and either expect-error.txt (one literal the failure
# must carry) or expect-contains.txt (literals daukle/pnpm/lock.lua must carry,
# one per line). Literals rather than a whole expected file, because a range
# deep in the closure moves when the registry publishes a release.
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
work="$root/test/.work"

daukle=${DAUKLE:-}
if [ -z "$daukle" ]; then
  for candidate in \
    "$root/.daukle/build/daukle" \
    "$root/.daukle/build/daukle.exe" \
    "$root/.daukle/build/Release/daukle.exe" \
    "$root/.daukle/build/Debug/daukle.exe"
  do
    [ -x "$candidate" ] && daukle=$candidate && break
  done
fi
if [ -z "$daukle" ] || [ ! -x "$daukle" ]; then
  echo "no daukle binary: set DAUKLE, or check out daukle/daukle into .daukle and build it" >&2
  exit 1
fi

only_case=${DAUKLE_CASE:-}
passed=0
failed=0
skipped=0

fail() {
  echo "FAIL $1: $2" >&2
  failed=$((failed + 1))
}

show_stderr() {
  echo "--- stderr ---" >&2
  cat "$sandbox/stderr.txt" >&2
}

expect_failure() {
  if (cd "$sandbox" && "$daukle" "$@" </dev/null >stdout.txt 2>stderr.txt); then
    fail "$name" "expected a failure, got success"
    return
  fi
  clause=$(cat "$case_dir/expect-error.txt")
  if ! grep -qF "$clause" "$sandbox/stderr.txt" "$sandbox/stdout.txt"; then
    show_stderr
    fail "$name" "message does not carry: $clause"
    return
  fi
  passed=$((passed + 1))
}

expect_pins() {
  if ! (cd "$sandbox" && "$daukle" "$@" </dev/null >stdout.txt 2>stderr.txt); then
    show_stderr
    fail "$name" "$* failed"
    return
  fi
  produced="$sandbox/daukle/pnpm/lock.lua"
  if [ ! -f "$produced" ]; then
    fail "$name" "no daukle/pnpm/lock.lua was written"
    return
  fi
  while IFS= read -r literal || [ -n "$literal" ]; do
    [ -n "$literal" ] || continue
    if ! grep -qF "$literal" "$produced"; then
      fail "$name" "lock.lua does not carry: $literal"
      return
    fi
  done < "$case_dir/expect-contains.txt"
  # The file must also LOAD and GENERATE: a text assertion passes on a file daukle would refuse.
  if ! (cd "$sandbox" && "$daukle" sync </dev/null >load.txt 2>load-stderr.txt); then
    cat "$sandbox/load-stderr.txt" >&2
    fail "$name" "a sync after the resolve fails"
    return
  fi
  expect_after_an_edit || return 0
  expect_a_re_pin "$@" || return 0
  passed=$((passed + 1))
}

# edit.toml replaces daukle.toml and is resolved again: expect-edit-contains.txt is what the new
# pins must carry, and after-edit-task a task that must then succeed against them.
expect_a_re_pin() {
  [ -f "$case_dir/edit.toml" ] || return 0
  cp "$case_dir/edit.toml" "$sandbox/daukle.toml"
  # A re-pin often runs on a fresh clone, so only the committed pins may carry the old lockfile.
  rm -rf "$sandbox/build"
  if ! (cd "$sandbox" && "$daukle" "$@" </dev/null >edit.txt 2>edit-stderr.txt); then
    cat "$sandbox/edit-stderr.txt" >&2
    fail "$name" "resolving after the edit failed"
    return 1
  fi
  while IFS= read -r literal || [ -n "$literal" ]; do
    [ -n "$literal" ] || continue
    if ! grep -qF "$literal" "$sandbox/daukle/pnpm/lock.lua"; then
      fail "$name" "lock.lua does not carry after the edit: $literal"
      return 1
    fi
  done < "$case_dir/expect-edit-contains.txt"
  # Unquoted on purpose: the task line carries its flags.
  # shellcheck disable=SC2046
  if ! (cd "$sandbox" && "$daukle" $(cat "$case_dir/after-edit-task") </dev/null >after.txt 2>after-stderr.txt); then
    cat "$sandbox/after-stderr.txt" >&2
    fail "$name" "the task after the re-pin failed"
    return 1
  fi
  return 0
}

# then.toml replaces daukle.toml after the resolve, and expect-then-error.txt is
# what the next sync must refuse with: the edit a user makes and forgets to resolve.
expect_after_an_edit() {
  [ -f "$case_dir/then.toml" ] || return 0
  cp "$case_dir/then.toml" "$sandbox/daukle.toml"
  if (cd "$sandbox" && "$daukle" sync </dev/null >then.txt 2>then-stderr.txt); then
    fail "$name" "a sync after the edit succeeded, and should have refused"
    return 1
  fi
  clause=$(cat "$case_dir/expect-then-error.txt")
  if ! grep -qF "$clause" "$sandbox/then-stderr.txt"; then
    cat "$sandbox/then-stderr.txt" >&2
    fail "$name" "the refusal after the edit does not carry: $clause"
    return 1
  fi
  return 0
}

run_case() {
  case_dir=$1
  name=$(basename "$case_dir")
  [ -z "$only_case" ] || [ "$name" = "$only_case" ] || return 0

  if [ -f "$case_dir/needs-registry" ] && [ "${DAUKLE_PNPM_E2E:-}" != "1" ]; then
    echo "skip $name: set DAUKLE_PNPM_E2E=1 to run it here" >&2
    skipped=$((skipped + 1))
    return
  fi

  sandbox="$work/$name"
  rm -rf "$sandbox"
  mkdir -p "$sandbox/plugins"
  cp "$case_dir/daukle.toml" "$sandbox/daukle.toml"
  cp "$root/plugin.lua" "$sandbox/plugins/plugin.lua"
  cp -R "$root/lib" "$sandbox/plugins/lib"

  task="pnpm:resolve --resolve"
  [ -f "$case_dir/task" ] && task=$(cat "$case_dir/task")
  # Unquoted on purpose: the task line carries its flags.
  # shellcheck disable=SC2086
  set -- $task

  if [ -f "$case_dir/expect-error.txt" ]; then
    expect_failure "$@"
  else
    expect_pins "$@"
  fi
}

run_unit() {
  sandbox="$work/unit"
  name=unit
  mkdir -p "$sandbox/plugins/unit"
  cp "$root/test/unit/plugin.lua" "$sandbox/plugins/unit/plugin.lua"
  cp -R "$root/test/unit/tests" "$sandbox/plugins/unit/tests"
  cp -R "$root/lib" "$sandbox/plugins/unit/lib"
  printf 'schema = 1\nproject = "daukle/pnpm-unit"\nversion = "1.0.0"\n\n[modules]\n\n[plugins]\nunit = "./plugins/unit"\n\n[toolchains.unit]\n' \
    > "$sandbox/daukle.toml"
  if (cd "$sandbox" && "$daukle" unit:test </dev/null >stdout.txt 2>stderr.txt); then
    passed=$((passed + 1))
  else
    show_stderr
    fail unit "unit:test failed"
  fi
}

rm -rf "$work"
for case_dir in "$root"/test/cases/*/; do
  [ -d "$case_dir" ] || continue
  run_case "${case_dir%/}"
done

if [ -z "$only_case" ] || [ "$only_case" = unit ]; then run_unit; fi
echo "$passed passed, $failed failed, $skipped skipped"
[ "$failed" -eq 0 ]
