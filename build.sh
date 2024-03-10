#!/usr/bin/env bash
set -euo pipefail
# set -v

main() {
    if git diff-index --quiet HEAD --; then
        # Working tree is clean
        echo "$(git rev-parse HEAD)" > gitsha.txt
    else
        # Working tree is not clean
        echo "$(git rev-parse HEAD)+dirty" > gitsha.txt
    fi

    zip -r ../aipacenotes.zip ./* -x '*.git*' -x 'art*.png' -x 'docs' -x 'build.sh'
    rm -fv gitsha.txt
}

main "$@"
