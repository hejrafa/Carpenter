#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ADDON_NAME="Carpenter"

fail() {
  echo "release: $*" >&2
  exit 1
}

version() {
  awk -F': ' '/^## Version:/{print $2; exit}' "$ROOT/Carpenter.toc"
}

validate_tocs() {
  local toc line path expected_version toc_version
  expected_version="$(version)"

  for toc in Carpenter.toc Carpenter_TBC.toc Carpenter_Vanilla.toc; do
    toc_version="$(awk -F': ' '/^## Version:/{print $2; exit}' "$ROOT/$toc")"
    [[ "$toc_version" == "$expected_version" ]] || fail "$toc version is $toc_version, expected $expected_version"

    while IFS= read -r line || [[ -n "$line" ]]; do
      line="${line//$'\r'/}"
      [[ -z "$line" || "${line:0:1}" == "#" ]] && continue
      path="${line//\\//}"
      [[ -e "$ROOT/$path" ]] || fail "$toc references missing file: $path"
    done < "$ROOT/$toc"
  done
}

validate_changelog() {
  local release_version
  release_version="$(version)"
  grep -q "^## ${release_version}$" "$ROOT/CHANGELOG.md" || fail "CHANGELOG.md has no ## ${release_version} section"
}

generate_release_changelog() {
  local release_version out
  release_version="${1:-$(version)}"
  out="${2:-$ROOT/.packager/changelog.md}"
  [[ "$out" = /* ]] || out="$ROOT/$out"

  mkdir -p "$(dirname "$out")"
  awk -v release_version="$release_version" '
    BEGIN { found = 0 }
    /^## / {
      if ($0 == "## " release_version) {
        found = 1
        print
        next
      }
      if (found) {
        exit
      }
    }
    found {
      print
    }
  ' "$ROOT/CHANGELOG.md" > "$out"

  grep -q "^## ${release_version}$" "$out" || fail "could not generate latest-version changelog for ${release_version}"
  [[ "$(grep -c '^## ' "$out")" == "1" ]] || fail "$out contains more than one release section"
}

validate_pkgmeta() {
  [[ -f "$ROOT/.pkgmeta" ]] || fail ".pkgmeta is missing"
  grep -q '^package-as:[[:space:]]*Carpenter$' "$ROOT/.pkgmeta" || fail ".pkgmeta must package as Carpenter"
  grep -q '^manual-changelog:[[:space:]]*CHANGELOG.md$' "$ROOT/.pkgmeta" || fail ".pkgmeta must use CHANGELOG.md as the default manual changelog"
}

lua_files() {
  find "$ROOT" \
    -path "$ROOT/.git" -prune -o \
    -path "$ROOT/tools" -prune -o \
    -name '*.lua' -print
}

check() {
  validate_tocs
  validate_changelog
  validate_pkgmeta
  generate_release_changelog "$(version)" "$ROOT/.packager/changelog.md"

  local files=()
  while IFS= read -r file; do
    files+=("$file")
  done < <(lua_files)
  luac -p "${files[@]}" "$ROOT/tools/chat-cleaner-fixtures.lua" "$ROOT/tools/smart-macro-fixtures.lua" "$ROOT/tools/check-localization.lua" "$ROOT/tools/check-assets.lua"
  lua "$ROOT/tools/chat-cleaner-fixtures.lua" "$ROOT"
  lua "$ROOT/tools/smart-macro-fixtures.lua" "$ROOT"
  lua "$ROOT/tools/check-localization.lua" "$ROOT"
  lua "$ROOT/tools/check-assets.lua" "$ROOT"

  echo "release: checks passed"
}

package_zip() {
  local release_version zip_path tmp
  release_version="${1:-$(version)}"
  zip_path="$ROOT/.release/${ADDON_NAME}-${release_version}.zip"

  check

  tmp="$(mktemp -d)"
  mkdir -p "$tmp/$ADDON_NAME"
  rsync -a "$ROOT/" "$tmp/$ADDON_NAME/" \
    --exclude='.git' \
    --exclude='.git*' \
    --exclude='.DS_Store' \
    --exclude='.packager' \
    --exclude='.release' \
    --exclude='dev' \
    --exclude='tools' \
    --exclude='*.zip'

  rm -f "$zip_path"
  (cd "$tmp" && zip -qr "$zip_path" "$ADDON_NAME" -x '*/.*' '__MACOSX/*')
  rm -rf "$tmp"

  echo "release: wrote $zip_path"
}

process_worktree() {
  local path="$1"
  local is_bare="$2"
  local commit="$3"
  local branch status

  [[ "$is_bare" == "1" ]] && return
  [[ -d "$path" ]] || return

  status="$(git -C "$path" status --porcelain)"
  [[ -z "$status" ]] || fail "$path has local changes"

  branch="$(git -C "$path" symbolic-ref --short -q HEAD || true)"
  if [[ "$branch" == "main" ]]; then
    git -C "$path" merge --ff-only "$commit"
  else
    git -C "$path" checkout --detach "$commit"
  fi
}

update_worktrees() {
  local commit current is_bare line
  commit="$(git -C "$ROOT" rev-parse --verify "${1:-HEAD}")"
  current=""
  is_bare=0

  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" == worktree\ * ]]; then
      if [[ -n "$current" ]]; then
        process_worktree "$current" "$is_bare" "$commit"
      fi
      current="${line#worktree }"
      is_bare=0
    elif [[ "$line" == "bare" ]]; then
      is_bare=1
    fi
  done < <(git -C "$ROOT" worktree list --porcelain)

  if [[ -n "$current" ]]; then
    process_worktree "$current" "$is_bare" "$commit"
  fi

  echo "release: worktrees updated to $(git -C "$ROOT" rev-parse --short "$commit")"
}

usage() {
  cat <<EOF
Usage: tools/release.sh <command>

Commands:
  check                 Validate TOCs, changelog, Lua syntax, fixtures, localization, and assets.
  changelog [version] [out]
                        Extract one changelog section for packager publishing.
  zip [version]         Create .release/Carpenter-[version].zip without hidden/dev/tools files.
  update-worktrees [ref] Fast-forward main worktrees and update detached worktrees to ref.
EOF
}

case "${1:-check}" in
  check)
    check
    ;;
  changelog)
    shift
    generate_release_changelog "${1:-$(version)}" "${2:-$ROOT/.packager/changelog.md}"
    ;;
  zip)
    shift
    package_zip "${1:-}"
    ;;
  update-worktrees)
    shift
    update_worktrees "${1:-HEAD}"
    ;;
  *)
    usage
    exit 1
    ;;
esac
