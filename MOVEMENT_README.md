# 점프 장난감 — 입력 수정판

Mac: RunMovement.command 실행. Windows: Godot 4.6을 설치하고 GODOT_EXE 또는 GODOT_BIN을 지정한 뒤 Run.cmd 실행. 엔진은 포함하지 않습니다. 최초 실행기는 필요한 임포트를 자동으로 수행합니다. 에디터의 기본 실행(F5)도 장난감 1번 방입니다.

- WASD 이동 / Space 점프·벽 점프 / Shift 대시. 공중 대시 2회, 각150px·0.20초.
- 첫 대시 도중에도 Shift를 떼었다 다시 누르면 즉시 첫 대시를 끊고 두 번째 대시로 전환합니다. 각 입력 순간의 방향을 별도로 기억합니다. 예: D+Shift → Shift 해제 → W+Shift이면 오른쪽에서 즉시 위로 전환. Shift를 계속 누르기만 하면 자동 반복하지 않습니다.
- K 유지 → WASD 8방향 조준 → K 놓으면 배시. 먼저 K를 누른 채 범위에 들어가도 잡힙니다. R은 WASD/방향키 조준 전환. 마우스는 사용하지 않습니다.
- 흰 테두리는 잡을 수 있음, 노란 테두리·연결선·‘잡힘!’은 실제 잡힌 상태. 최대1.2초 후 자동발사. 배시 최고속도600, 시작10%, 가속0.22초·중력 적용.
- F1/Tab 튜닝, F2 판정, F5 무적, F6 속도, F7 방 다시 읽기, F8/Shift+F8 다음/이전 방. 화면 버튼도 제공합니다.
- 총8방, 고정줌, 중간 체크포인트 없음. 사망하면 해당 방 시작점으로 복귀.
- toys/movement/rooms의 텍스트를 수정하고 F7로 반영합니다. F1 저장은 movement_tuning.json에 기록합니다.
- 정상 창 닫기/종료 버튼은 user://toy_movement_log.jsonl에 세션 한 줄을 남깁니다. 강제 종료 기록은 보장하지 않습니다.

검수 결과: docs/MOVEMENT_INPUT_AUDIT.md. 8개 방의 사람 완주 및 Windows 실기는 아직 미검증입니다. 이전 골렘 관련 소스와 문서는 재사용 기반으로 남아 있으며 기본 실행 대상은 점프 장난감입니다.

Direction-order update: Shift and a new direction may overlap; the first 0.06 seconds accept a new direction edge, then aim locks. The HUD displays Shift receipts, actual dash starts and last direction.
