#!/bin/bash

# Copyright (c) 2020 Arm Limited and Contributors. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause

set -e
set -u
set -o pipefail

rc=0

find_cmake_projects() {
    find "$workdir" -name CMakeLists.txt -print0 | xargs -0 --no-run-if-empty grep -l 'option(RUN_CODE_CHECKS ' | xargs --no-run-if-empty dirname
}

usage()
{
  cat <<EOF

usage: clang-tidy-check.sh [OPTION] -- [clang-tidy-check.sh arguments]

  -h, --help            Print brief usage information and exit.
  --workdir PATH        Specify the directory to check. Default PWD.
  -x                    Enable shell debugging in this script.

EOF
}

args=$(getopt -o+hx -l help,workdir: -n "$(basename "$0")" -- "$@")
eval set -- "$args"
while [ $# -gt 0 ]; do
  if [ -n "${opt_prev:-}" ]; then
    eval "$opt_prev=\$1"
    opt_prev=
    shift 1
    continue
  elif [ -n "${opt_append:-}" ]; then
    eval "$opt_append=\"\${$opt_append:-} \$1\""
    opt_append=
    shift 1
    continue
  fi
  case $1 in
  -h | --help)
    usage
    exit 0
    ;;

  --workdir)
    opt_prev=workdir
    ;;

  -x)
    set -x
    ;;

  --)
    shift
    break 2
    ;;
  esac
  shift 1
done

if [ -z "${workdir:-}" ]; then
  workdir="$(pwd)"
fi

workdir=$(readlink -f "$workdir")

CMAKE_PROJECTS=$(printf "%s" "$(find_cmake_projects)")
if [ -z "$CMAKE_PROJECTS" ]; then
    printf "No CMake projects configured for clang-tidy found. Exiting.\n"
    exit 1
fi

this_dir=$(pwd)

for project in $CMAKE_PROJECTS; do
    printf "Building \"%s\" with clang-tidy checks enabled.\n" "$project"
    PROJECT_TMPDIR=/tmp/$(basename "$project")
    cp -r "$project" "$PROJECT_TMPDIR"
    cd "$PROJECT_TMPDIR"
    cmake . \
        --no-warn-unused-cli \
        -DRUN_CODE_CHECKS=ON \
        -DCMAKE_CXX_CLANG_TIDY=clang-tidy-9 \
        -DCMAKE_CXX_COMPILER=clang++-9 \
        -DCMAKE_C_COMPILER=clang-9 \
        -DCMAKE_INSTALL_LIBDIR=/usr/lib \
        -DCMAKE_INSTALL_BINDIR=/usr/bin \
        || rc=1
    make  || rc=1
    cd "$this_dir"
done

exit $rc
