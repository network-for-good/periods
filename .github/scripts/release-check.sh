#!/usr/bin/env bash
# Release check for .github/workflows/publish-gem.yml.
#
# Copied verbatim from network-for-good/nfg-devx, .github/workflows/gem-publish.yml (the "Check whether
# this version was already published" step) at 586acd68bdc210adda991b27b77ff9239da67e26
# (gem-workflows-v1.0.0). Interim copy: nfg-devx is private and periods is public, so this repo cannot
# call the shared workflow. Replace it with a thin caller once a shared public workflows repo exists, or
# once periods becomes internal (planned by Platform) and can call nfg-devx directly.
#
# Decides what a push to a release branch needs: nothing, a publish, or only a missing release tag.
# READ-ONLY: it never pushes anything. The publish job (the only one holding write credentials)
# acts on the outputs.
#
# Step outputs (written to $GITHUB_OUTPUT, or stdout when unset):
#   version      the version declared in VERSION_FILE
#   tag          TAG_PREFIX + version
#   publish      "true" only when the version has to be built and published
#   recover_sha  non-empty only when the package is already in the registry but its tag is
#                missing: the commit the published package was built from (verified)
#
# Required env: GEM_NAME VERSION_FILE VERSION_CONST TAG_PREFIX
# Optional env: GEMSPEC (default <GEM_NAME>.gemspec), GITHUB_TOKEN (registry read access),
#               GITHUB_OUTPUT, RELEASE_SOURCE_URL (override the registry, used by tests),
#               RELEASE_REGISTRY_OWNER (default network-for-good),
#               MAX_RECOVERY_CANDIDATES (default 50)
# Run it from the gem's directory (the repo root, or a subdirectory of it) inside a checkout with
# full history and a reachable `origin`.
#
# 1. tag <prefix><version> exists              -> nothing to do
# 2. version is not in the registry            -> publish
# 3. version is in the registry but has no tag -> a previous run published it and then failed
#    to push the tag. Find the commit the package was built from by building the gem at each
#    candidate commit and comparing its files AND its specification (dependencies, required
#    Ruby, ...) with the published package's; report the first match as recover_sha, or fail if
#    none matches (never tag a commit we couldn't verify).
# If the registry can't be queried at all we fall back to step 2, i.e. the behaviour before
# this check existed (a real duplicate is then rejected by the registry).
set -euo pipefail

: "${GEM_NAME:?}" "${VERSION_FILE:?}" "${VERSION_CONST:?}" "${TAG_PREFIX:?}"
GEMSPEC="${GEMSPEC:-${GEM_NAME}.gemspec}"
MAX_RECOVERY_CANDIDATES="${MAX_RECOVERY_CANDIDATES:-50}"
REGISTRY_OWNER="${RELEASE_REGISTRY_OWNER:-network-for-good}"
SOURCE_URL="${RELEASE_SOURCE_URL:-https://x-access-token:${GITHUB_TOKEN:-}@rubygems.pkg.github.com/${REGISTRY_OWNER}}"
OUT="${GITHUB_OUTPUT:-/dev/stdout}"

emit() { echo "$1=$2" >> "$OUT"; }

# The gem may live in a subdirectory of the repository: git paths are relative to the repo root.
PREFIX="$(git rev-parse --show-prefix)" # "" at the root, "sub/dir/" in a subdirectory

VERSION="$(ruby -r "./${VERSION_FILE%.rb}" -e "puts ${VERSION_CONST}")"
TAG="${TAG_PREFIX}${VERSION}"
emit version "$VERSION"
emit tag "$TAG"
emit recover_sha ""

if git ls-remote --exit-code --tags origin "refs/tags/${TAG}" > /dev/null 2>&1; then
  echo "Tag ${TAG} already exists: version ${VERSION} was already released, nothing to do."
  emit publish false
  exit 0
fi

WORK="$(mktemp -d)"
cleanup() {
  git worktree prune > /dev/null 2>&1 || true
  rm -rf "$WORK"
}
trap cleanup EXIT

# Is this exact version already in the registry? A failed fetch (not found, or no access) is
# treated as "not published" so the normal publish path is never blocked by this check.
mkdir -p "$WORK/published"
if ! (cd "$WORK/published" && gem fetch "$GEM_NAME" --version "$VERSION" --clear-sources --source "$SOURCE_URL" > "$WORK/fetch.log" 2>&1) \
   || [ ! -s "$WORK/published/${GEM_NAME}-${VERSION}.gem" ]; then
  echo "Version ${VERSION} is not in the registry (or the registry could not be read): publishing."
  emit publish true
  exit 0
fi

echo "::warning::${GEM_NAME} ${VERSION} is already in the registry but ${TAG} is missing (a previous run likely published it and failed to tag). Looking for the source commit."
PUBLISHED_GEM="$WORK/published/${GEM_NAME}-${VERSION}.gem"
gem unpack "$PUBLISHED_GEM" --target "$WORK/published/unpacked" > /dev/null

# `gem unpack` only extracts files, and a gemspec is often not part of the payload, so two commits
# can ship identical files but a different specification (dependencies, bindir, licenses,
# metadata, ...). Compare the complete specification, serialized, after neutralizing the
# build-time noise: the build date and the RubyGems version that built it. A false mismatch only
# makes recovery fail safe (no tag); a false match would tag the wrong commit.
spec_fingerprint() {
  ruby -e 'require "rubygems/package"
    s = Gem::Package.new(ARGV[0]).spec
    s.date = Time.at(0)
    s.rubygems_version = "0"
    s.files = s.files.sort
    s.test_files = s.test_files.sort
    puts s.to_yaml' "$1"
}
PUBLISHED_SPEC="$(spec_fingerprint "$PUBLISHED_GEM")"

version_at() { # VERSION literal in the version file at commit $1
  git show "$1:${PREFIX}${VERSION_FILE}" 2> /dev/null \
    | sed -nE "s/^[[:space:]]*VERSION[[:space:]]*=[[:space:]]*['\"]([^'\"]+)['\"].*/\1/p" | head -1 || true
}

# Earliest commit (walking the branch's first-parent history) from which the version has been this value.
# (rev-list pathspecs are relative to the current directory, `git show <sha>:path` is relative to the repo root)
SOURCE=""
for sha in $(git rev-list --first-parent HEAD -- "${VERSION_FILE}"); do
  if [ "$(version_at "$sha")" = "$VERSION" ]; then SOURCE="$sha"; else break; fi
done
if [ -z "$SOURCE" ]; then
  echo "::error::Could not find the commit that set the version to ${VERSION} in ${VERSION_FILE}. Tag ${TAG} manually after confirming which commit the published package was built from."
  exit 1
fi

# Candidates: that commit and every later first-parent commit, oldest first.
CANDIDATES="$(git rev-parse "$SOURCE"; git rev-list --first-parent --reverse "${SOURCE}..HEAD")"

MATCH=""
TRIED=0
for c in $CANDIDATES; do
  TRIED=$((TRIED + 1))
  [ "$TRIED" -gt "$MAX_RECOVERY_CANDIDATES" ] && break
  rm -rf "$WORK/src" "$WORK/cand"
  mkdir -p "$WORK/cand"
  git worktree add --detach --quiet "$WORK/src" "$c"
  # gem unpack names its output directory after the .gem file, so build it under the real name
  # to get a tree directly comparable with the published package's.
  if (cd "$WORK/src/${PREFIX}" && gem build "$GEMSPEC" --output "$WORK/cand/${GEM_NAME}-${VERSION}.gem" > /dev/null 2>&1); then
    gem unpack "$WORK/cand/${GEM_NAME}-${VERSION}.gem" --target "$WORK/cand/unpacked" > /dev/null
    if diff -r "$WORK/published/unpacked/${GEM_NAME}-${VERSION}" "$WORK/cand/unpacked/${GEM_NAME}-${VERSION}" > /dev/null 2>&1 \
       && [ "$(spec_fingerprint "$WORK/cand/${GEM_NAME}-${VERSION}.gem")" = "$PUBLISHED_SPEC" ]; then
      MATCH="$c"
    fi
  fi
  git worktree remove --force "$WORK/src" > /dev/null 2>&1 || true
  [ -n "$MATCH" ] && break
done

if [ -z "$MATCH" ]; then
  echo "::error::${GEM_NAME} ${VERSION} is in the registry but no commit from ${SOURCE:0:7} to HEAD builds a package with identical contents, so ${TAG} will NOT be created. Tag the correct commit manually (git tag -a ${TAG} <sha> && git push origin ${TAG})."
  exit 1
fi

echo "::notice::Package verified identical to a build of ${MATCH:0:7}: ${TAG} is missing and will be created at that commit. Nothing to publish."
emit recover_sha "$MATCH"
emit publish false
