#!/bin/zsh
cd "${0:A:h}"
engine="${GODOT_EXE:-}"
if [[ -z "$engine" ]]; then
  for candidate in /Applications/Godot.app/Contents/MacOS/Godot /Users/lty/Documents/Codex/2026-09-19/new-chat-5/work/runtime/Godot.app/Contents/MacOS/Godot; do
    if [[ -x "$candidate" ]]; then engine="$candidate"; break; fi
  done
fi
if [[ -z "$engine" ]]; then engine="$(command -v godot)"; fi
if [[ -z "$engine" ]]; then
  print 'Godot 4.6이 필요합니다. GODOT_EXE에 실행 파일 경로를 지정하세요.'
  read '?Enter를 누르면 닫힙니다.'
  exit 1
fi
exec "$engine" --path "$PWD" res://toys/movement/movement_toy.tscn
