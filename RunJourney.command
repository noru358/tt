#!/bin/zsh
# 여행 구간(긴 횡방향 길 하나) 실행 (엔진 탐색은 RunMovement.command와 같음)
exec "${0:A:h}/RunMovement.command" res://toys/journey/journey_toy.tscn "$@"
