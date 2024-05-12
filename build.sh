#!/usr/bin/env bash
set -euo pipefail
# set -v

main() {
    if git diff-index --quiet HEAD --; then
        echo Working tree is clean
        sha=$(git rev-parse HEAD)
        # Attempt to get the tag name exactly on HEAD
        tag=$(git describe --tags --exact-match HEAD 2> /dev/null)
        if [ -n "$tag" ]; then
            # If there is a tag exactly on HEAD, append it to the SHA
            echo "${sha} (${tag})"
            echo "${sha} (${tag})" > version.txt
        else
            # If no tag on HEAD, just write the SHA
            echo "$sha"
            echo "$sha" > version.txt
        fi
    else
        echo Working tree is not clean
        sha=$(git rev-parse HEAD)
        # Attempt to get the tag name exactly on HEAD
        tag=$(git describe --tags HEAD 2> /dev/null)
        # echo foo
        if [ -n "$tag" ]; then
            # If there is a tag exactly on HEAD, append it to the SHA and mark as dirty
            echo "${sha}+dirty (${tag})"
            echo "${sha}+dirty (${tag})" > version.txt
        else
            # If no tag on HEAD, just write the SHA and mark as dirty
            echo "${sha}+dirty"
            echo "${sha}+dirty" > version.txt
        fi
    fi

    cat version.txt

    rm -fv "${BIRD}/build/aipacenotes.zip"
    zip -r "${BIRD}/build/aipacenotes.zip" ./* -x '*.git*' -x 'art*.png' -x 'docs*' -x 'build.sh' -x 'dev.txt'
    rm -fv version.txt
    ls -ltrh "${BIRD}/build/"
}

main "$@"
