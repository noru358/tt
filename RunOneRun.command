#!/bin/zsh
# 한 판(점프 방 몇 개 + 골렘) 실행 (엔진 탐색은 RunMovement.command와 같음)
exec "${0:A:h}/RunMovement.command" res://toys/run/run_toy.tscn "$@"
