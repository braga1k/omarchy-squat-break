#!/bin/bash
set -euo pipefail
source_dir=$(cd -- "$(dirname -- "$0")/.." && pwd)
qa_dir=$(mktemp -d /tmp/squat-qml-XXXXXX)
trap 'rm -rf -- "$qa_dir"' EXIT
mkdir "$qa_dir/plugin"
cp -- "$source_dir/"*.qml "$source_dir/"*.js "$source_dir/store.py" "$source_dir/manifest.json" "$qa_dir/plugin/"
cp -r -- "$source_dir/i18n" "$qa_dir/plugin/i18n"
cp -- "$source_dir/tests/smoke.qml" "$qa_dir/shell.qml"
ln -s /usr/share/omarchy/shell/Commons "$qa_dir/Commons"
ln -s /usr/share/omarchy/shell/Ui "$qa_dir/Ui"
XDG_DATA_HOME="$qa_dir/data" timeout 15 qs -p "$qa_dir" --no-color > "$qa_dir/result.log" 2>&1
cat -- "$qa_dir/result.log"
rg -q SQUAT_TEST_PASSED "$qa_dir/result.log"
if rg -q 'SQUAT_TEST_FAILED|ERROR|TypeError|ReferenceError' "$qa_dir/result.log"; then exit 1; fi
