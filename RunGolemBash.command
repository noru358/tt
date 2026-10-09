#!/bin/zsh
# 골렘 튕기기 장난감 실행 (엔진 탐색은 RunMovement.command와 같음)
exec "${0:A:h}/RunMovement.command" res://toys/golem_bash/golem_bash_toy.tscn "$@"
