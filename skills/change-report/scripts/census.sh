#!/bin/sh
# change-report census: groups the source files of one change set and counts them
# Usage: census.sh [current | <commit>]; output records are documented in SKILL.md
# census.ps1 mirrors this file; after a change to either, check parity on a few commits:
#   diff <(sh census.sh <commit>) <(powershell -NoProfile -ExecutionPolicy Bypass -File census.ps1 <commit>)
set -eu
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
rules="$here/../rules.tsv"
die() { printf 'error: %s\n' "$1" >&2; exit 2; }
g() { git -c core.quotePath=false "$@"; }

[ $# -le 1 ] || die "expected at most one argument"
arg=${1-}
top=$(git rev-parse --show-toplevel 2>/dev/null) || die "not inside a git work tree"
cd "$top"
git rev-parse --verify --quiet HEAD >/dev/null || die "the repository has no commits"
empty=$(git hash-object -t tree /dev/null)
new= branch= base=
case $arg in
  '')
    scope=worktree
    old=$(git rev-parse HEAD) ;;
  current)
    scope=current
    branch=$(git symbolic-ref --short -q HEAD) || die "HEAD is detached: there is no current branch"
    case $branch in main|master|develop) die "the current branch $branch is itself a base candidate: name a commit instead" ;; esac
    best=
    for c in main master develop; do
      for ref in "refs/heads/$c" "refs/remotes/origin/$c"; do
        git rev-parse --verify --quiet "$ref" >/dev/null || continue
        n=$(git rev-list --count "$ref..HEAD")
        if [ -z "$best" ] || [ "$n" -lt "$best" ]; then best=$n; base=${ref#refs/heads/}; base=${base#refs/remotes/}; fi
        break
      done
    done
    [ -n "$base" ] || die "no base branch: none of main, master, develop exists"
    old=$(git merge-base "$base" HEAD) || die "no merge base between $branch and $base (shallow clone?)"
    new=$(git rev-parse HEAD) ;;
  *)
    scope=commit
    new=$(git rev-parse --verify --quiet "$arg^{commit}") || die "not a commit: $arg"
    old=$(git rev-parse --verify --quiet "$new^1") || old=$empty ;;
esac

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
d() { g diff --no-color --no-ext-diff -M "$@" "$old" ${new:+"$new"} 2>/dev/null; }
d --name-status > "$tmp/status"
d --numstat > "$tmp/numstat"
{ g ls-tree -r --name-only "$old"; if [ -n "$new" ]; then g ls-tree -r --name-only "$new"; else g ls-files; fi; } | LC_ALL=C sort -u > "$tmp/tree"
sdk=$(awk -F'\t' '$1 == "test-sdk" { s = s (s == "" ? "" : "|") $2 } END { print s }' "$rules")
sdkgrep() { g grep -l -E -e "$sdk" "$@" -- '*.csproj' '*.fsproj' '*.vbproj' || true; }
{ sdkgrep "$old" | sed "s|^$old:||"; if [ -n "$new" ]; then sdkgrep "$new" | sed "s|^$new:||"; else sdkgrep; fi; } > "$tmp/sdk"
awk -F'\t' '{ print $NF }' "$tmp/status" | g check-attr --stdin linguist-generated linguist-vendored |
  awk -F': ' '$3 == "set" || $3 == "true" { print $1 }' > "$tmp/attr"

printf 'M\tscope\t%s\nM\told\t%s\nM\tnew\t%s\n' "$scope" "$old" "${new:-WORKTREE}"
[ -z "$branch" ] || printf 'M\tbranch\t%s\nM\tbase\t%s\n' "$branch" "$base"
LC_ALL=C awk -v rules="$rules" -v tree="$tmp/tree" -v sdks="$tmp/sdk" -v attrs="$tmp/attr" \
  -v status="$tmp/status" -v numstat="$tmp/numstat" '
function lastslash(s,   i, j) { j = 0; while ((i = index(substr(s, j + 1), "/")) > 0) j += i; return j }
function base(s) { return substr(s, lastslash(s) + 1) }
function dir(s,   i) { i = lastslash(s); return i ? substr(s, 1, i - 1) : "." }
function nearest(p,   d, i) {
  d = p
  while ((i = lastslash(d)) > 0) { d = substr(d, 1, i - 1); if (d in label) return d }
  return ("." in label) ? "." : ""
}
function common(pre, p,   d) {
  d = dir(p)
  while (pre != "." && index(d "/", pre "/") != 1) pre = dir(pre)
  return pre
}
function skip(p, lp) { return (p in attr) || lp ~ R["exclude"] || lp ~ R["generated"] }
BEGIN {
  OFS = "\t"
  while ((getline line < rules) > 0) {
    if (line == "" || substr(line, 1, 1) == "#") continue
    t = index(line, "\t"); k = substr(line, 1, t - 1); v = substr(line, t + 1)
    R[k] = (k in R) ? R[k] "|" v : v
  }
  while ((getline p < attrs) > 0) attr[p] = 1
  while ((getline p < sdks) > 0) sdk[p] = 1
  while ((getline p < tree) > 0) {
    lp = tolower(p)
    if (skip(p, lp)) continue
    b = base(lp); d = dir(p)
    if (b ~ R["manifest"] || (d == "." && b ~ R["manifest-root"])) {
      if (!(d in label)) { projects++; label[d] = (d == "." ? "(root)" : d) }
      if (b ~ R["dotnet-manifest"] && !(d in dotnet)) { dotnet[d] = 1; name = base(p); sub(/\.[^.]*$/, "", name); label[d] = name }
      if (p in sdk) testproj[d] = 1
    } else if (lp ~ R["source"]) other = 1
  }
  for (d in label) if (tolower(base(label[d])) ~ R["test-project"]) testproj[d] = 1

  while ((getline line < status) > 0) {
    if ((getline nl < numstat) <= 0) nl = "-\t-"
    ns = split(line, a, "\t"); split(nl, c, "\t")
    st = substr(a[1], 1, 1); p = a[ns]
    if (st != "A" && st != "D" && st != "R") st = "M"
    lp = tolower(p)
    if (c[1] == "-" || skip(p, lp)) { excluded++; continue }
    script = lp ~ R["script"]
    if (!script && lp !~ R["source"]) { excluded++; continue }
    pr = nearest(p)
    if (script && (index(p, "/") == 0 || lp ~ R["script-exclude"] || (pr == "" && other))) { excluded++; continue }
    n++; P[n] = p; S[n] = st; ADD[n] = c[1]; DEL[n] = c[2]
    if (projects >= 2 && pr != "" && (pr in testproj)) { G[n] = label[pr]; K[n] = 2 }
    else if (lp ~ R["test-path"] || p ~ R["test-name"]) { G[n] = "Tests"; K[n] = 3 }
    else if (projects >= 2) { G[n] = (pr == "" ? "(no project)" : label[pr]); K[n] = 1 }
    else { G[n] = ""; K[n] = 1; prefix = (dirs++ ? common(prefix, p) : dir(p)) }
  }
  # ponytail: a single project groups by the first directory below the common prefix of the touched files
  for (i = 1; i <= n; i++) if (G[i] == "") {
    rest = (prefix == ".") ? P[i] : substr(P[i], length(prefix) + 2)
    j = index(rest, "/")
    if (j) G[i] = (prefix == "." ? "" : prefix "/") substr(rest, 1, j - 1)
    else G[i] = (prefix == "." ? "(root)" : prefix)
  }

  for (i = 1; i <= n; i++) {
    g = G[i]
    if (!(g in files)) { groups++; key[groups] = K[i] "\t" g; kind[g] = K[i] }
    files[g]++; count[g, S[i]]++; added[g] += ADD[i]; removed[g] += DEL[i]
  }
  for (i = 2; i <= groups; i++) { v = key[i]; for (j = i - 1; j >= 1 && key[j] > v; j--) key[j + 1] = key[j]; key[j + 1] = v }
  split("source test-project tests", kn, " ")
  print "M", "grouping", (projects >= 2 ? "project" : "directory")
  print "M", "projects", projects + 0
  print "M", "excluded", excluded + 0
  for (i = 1; i <= groups; i++) {
    g = substr(key[i], 3)
    print "G", g, kn[kind[g]], files[g], count[g, "A"] + 0, count[g, "M"] + 0, count[g, "D"] + 0, count[g, "R"] + 0, added[g] + 0, removed[g] + 0
    tf += files[g]; ta += count[g, "A"]; tm += count[g, "M"]; td += count[g, "D"]; tr += count[g, "R"]; tp += added[g]; tn += removed[g]
  }
  print "T", "Total", "-", tf + 0, ta + 0, tm + 0, td + 0, tr + 0, tp + 0, tn + 0
  for (i = 1; i <= n; i++) print "F", G[i], S[i], ADD[i], DEL[i], P[i]
}'
