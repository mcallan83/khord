#!/bin/zsh
set -eu
cd "${0:A:h:h}"
if [[ ! -f build/Khord.app/Contents/MacOS/Khord ]]; then
  ./build.sh
fi
original_hash="$(shasum -a 256 build/Khord.app/Contents/MacOS/Khord)"
test_dir="$(mktemp -d "$PWD/build/.build-test.XXXXXX")"
trap 'rm -rf -- "$test_dir"' EXIT
cat > "$test_dir/xcrun" <<'STUB'
#!/bin/sh
exit 42
STUB
chmod +x "$test_dir/xcrun"
if PATH="$test_dir:$PATH" ./build.sh > "$test_dir/build.log" 2>&1; then
  echo "FAIL: expected compiler failure" >&2
  exit 1
else
  result=$?
fi
[[ "$result" -eq 42 ]]
[[ "$(shasum -a 256 build/Khord.app/Contents/MacOS/Khord)" == "$original_hash" ]]
stage_files=(build/.stage.*(N))
[[ "${#stage_files}" -eq 0 ]]
echo "PASS failed-build preservation and staging cleanup"
