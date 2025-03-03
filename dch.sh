#!/bin/bash

set -e

DIST=jammy
TAG="$1"
PKG_NAME=$(awk '/^Package:/ { print $2 }' debian/control)
LAST_TAG=$(git tag -l | sort -V | tail -1)

# generates debian change log
generateChangelog () {
  local version=$1
  local range=$2
  local entry
  local cmd

  cmd="dch $([[ -e 'debian/changelog' ]] || echo '--create') --distribution $DIST --package $PKG_NAME --newversion $version-1 --controlmaint"
  git log --pretty=tformat:'%s' $range | while read entry; do
    $cmd $entry
    cmd="dch --append --controlmaint"
  done
}

# check tag name
if [[ "$TAG" != "" ]] ; then
  if ! [[ "$TAG" =~ ^[0-9]+(\.[0-9]+){0,2}$ ]] ; then
    echo "[$TAG] is not a valid tag name."
    exit 1
  fi
  VERSION="$TAG"
  if [[ "$LAST_TAG" != "$TAG" ]] ; then
    RANGE="$([[ "$LAST_TAG" != "" ]] && echo "$LAST_TAG..")HEAD"
  fi
else
  if [[ "$LAST_TAG" != "" ]] && [[ "$LAST_TAG" =~ ^[0-9]+(\.[0-9]+){0,2}$ ]] ; then
    VERSION_PARTS=(${LAST_TAG//./ })
    VERSION_PARTS[-1]=$((${VERSION_PARTS[-1]}+1))
    TAG="$(IFS=. ; echo "${VERSION_PARTS[*]}")"
    RANGE="$LAST_TAG..HEAD"
  else
    TAG="0.0.1"
    RANGE="HEAD"
  fi
  VERSION="$TAG~n$(date +%s)"
fi

# generate changelog
rm debian/changelog 2>/dev/null || true
git tag -l | sort -V | while read CUR_TAG; do
  generateChangelog $CUR_TAG "$PREV_TAG$CUR_TAG"
  PREV_TAG="$CUR_TAG.."
done
if [[ "$RANGE" != "" ]] && [[ "$(git log $RANGE | wc -l)" != 0 ]] ; then
  generateChangelog $VERSION $RANGE
fi
