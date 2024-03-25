#!/usr/bin/env bash
set -euo pipefail
# set -v

main() {
    if git diff-index --quiet HEAD --; then
        # Working tree is clean
        sha=$(git rev-parse HEAD)
        # Attempt to get the tag name exactly on HEAD
        tag=$(git describe --tags --exact-match HEAD 2> /dev/null)
        if [ -n "$tag" ]; then
            # If there is a tag exactly on HEAD, append it to the SHA
            echo "${sha} (${tag})" > gitsha.txt
        else
            # If no tag on HEAD, just write the SHA
            echo "$sha" > gitsha.txt
        fi
    else
        # Working tree is not clean
        sha=$(git rev-parse HEAD)
        # Attempt to get the tag name exactly on HEAD
        tag=$(git describe --tags --exact-match HEAD 2> /dev/null)
        if [ -n "$tag" ]; then
            # If there is a tag exactly on HEAD, append it to the SHA and mark as dirty
            echo "${sha}+dirty (${tag})" > gitsha.txt
        else
            # If no tag on HEAD, just write the SHA and mark as dirty
            echo "${sha}+dirty" > gitsha.txt
        fi
    fi

    cat gitsha.txt

    zip -r ../aipacenotes.zip ./* -x '*.git*' -x 'art*.png' -x 'docs*' -x 'build.sh' -x 'dev.txt'
    rm -fv gitsha.txt
}

main "$@"
