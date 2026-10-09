# 최신 정정: 두 번째 대시는 즉시 방향 전환

사용자 재확인에 따라 아래의 첫 대시 종료 후 예약 방식은 폐기했습니다. 이제 첫 대시 도중이라도 Shift를 다시 누르면 남은 첫 대시를 버리고, 두 번째 입력 방향으로 즉시 새 대시가 시작됩니다. Input.parse_input_event 경로의203검사(native GPU), 기존52+48검사 PASS. 실물키보드 테스트로 주장하지 않습니다.

# 이동 장난감 입력·버그 검수 — 2026-10-09

사용자 보고: 좌우 대시 뒤 두 번째 대시가 안 나오는 느낌, 유사 사례 조사 및 다른 조작감/버그 검수.
현재 남아 있는 작업본 outputs/MovementToy 5를 기준으로 수정했다. 8방·체크포인트 없음·고정줌, 승인된 배시/점프/대시 수치는 유지했다. 새 수치는 dash_input_buffer=0.22초이며 F1에 노출된다.

## 확인 및 수정

|문제|수정 전 재현|수정|
|---|---|---|
|공중 두 번째 대시 누락|첫 대시 0.2초 중 Shift를 다시 눌렀다 떼면 이후 대시가 안 나옴|입력 최대0.22초 보관, 첫 대시 종료 후 실행. 입력 당시 방향도 보관. 한 슬롯만 사용하며 공중 3회째는 거부|
|지상 좌우 연속 대시 불가|지상에서 첫 대시 종료 후 쿨다운0.45초가 남아 두 번째 입력 무시|지상/공중 후속 입력 처리 통일, 대시 도중 횟수 초기화 금지|
|대시 거리 초과|60Hz에서150px 설정이162.5px 이동|마지막 물리 tick의 남은 시간만큼 이동. 30/60/120Hz 모두150px|
|지상 대시 중 점프 누락|Space로 y속도를 줘도 DASH 분기가 덮어씀|지상 점프 시 DASH 종료, 정상 점프로 전환|
|벽 너머 구슬 잡기|플레이어와 구슬 사이에 벽이 있어도 거리만 가까우면 잡힘|환경 충돌 레이어로 시야 검사 후 대상 선택|
|붙잡은 투사체가 플레이어를 타격|K로 잡은 투사체의 물리 이동/피해 처리가 계속됨|잡힌 대상은 움직임·수명·피해 처리 정지. 부활 중 투사체 처리도 정지|
|대상 소멸 후 시간 복구 누락|붙잡은 대상이 사라져도 Engine.time_scale이0.08에 남음|배시 활성 상태를 별도로 추적해 소멸 시 취소·시간 복구|
|방 전환 도중 검은 화면 잔류|respawn() 직후 F7/방 전환하면 이전 tween이 다시 화면을 검게 만듦|진행 중 페이드 tween 종료, 세대 검사 유지|
|새 ZIP 직접 실행 실패|.godot 없는 깨끗한 폴더에서 PlayerInput 등 전역 클래스 미인식|Mac/Windows 실행기에 최초 임포트 추가. Run.cmd도 같은 실행기로 연결|

추가 방어: 메뉴/포커스/입력 장치 이력 변경/방 전환 때 대시 예약 삭제, 이동 보조 상태 및 입력 기록 초기화. 삭제 예정 대상은 선택 제외. HUD에 남은 대시 횟수 표시.

기존48검사는 대시가 완전히 끝난 뒤 다시 누르는 경로만 검사했고 실제 빠른 연타를 보증하지 못했다. 이번 검사는 실제 물리 프레임을 진행시키며 이를 보완한다. 수정 전10검사 중9실패에는 ‘두 번째 실패 뒤 세 번째 시도’의 연쇄 실패1개가 포함되며, 이를 별도 독립 버그로 세지 않았다.

## 검증

- MovementAuditSuite: headless52/52 및 native GPU52/52 PASS. 8방향×5입력시점(0.02/0.08/0.16/0.20/0.24초), 방향키 해제 후 방향 보존, 지상/공중, 3번째 거부, 메뉴/포커스/방 재로딩, 벽, 투사체, 대상 소멸, 페이드 포함.
- MovementToySuite: 기존48/48 PASS.
- MovementDashRateProbe: 30/60/120Hz 모두 실제150.00000px PASS.
- 기존15개 회귀 suite: 981검사 PASS. 기존 골렘·플레이어·입력·성장·활·전투 회귀 포함.
- 새 ZIP과 같은 캐시 없는 복사본의 실행기: 최초 자동 임포트 후 기본 room_01 진입 및 종료 로그 확인, SCRIPT ERROR 없음. Windows 실행기는 코드만 갱신했으며 Windows 실기 검증 없음.
- 증거: docs/evidence/input-audit. 자동 입력/물리 검사이며 실물 키보드·패드/장시간 손맛 검증은 아니다.

## 유사 사례와 근거

- [Godot 4.6 Input 공식 문서](https://docs.godotengine.org/en/4.6/classes/class_input.html#class-input-method-is-action-just-pressed): just_pressed는 누른 물리 tick/프레임에만 참이다. 그때 DASH 상태라 거부하면 입력을 따로 저장하지 않는 한 다음 프레임에 사라진다. 이번 누락의 직접적인 코드 원인과 맞는다.
- [점프 직후 is_on_floor가 남는 사례](https://forum.godotengine.org/t/method-is-on-floor-is-true-first-frame-after-jump/95230): 사용자 재현 코드와 답변에서 이동 호출 전 상태 검사 순서를 다룬다. 같은 버그라는 뜻이 아니라, 충돌 상태와 동작 횟수 초기화 순서를 점검할 때 참고한 사례다.
- [Godot CharacterBody2D 문서](https://docs.godotengine.org/en/4.6/classes/class_characterbody2d.html#class-characterbody2d-method-is-on-floor): 바닥 여부는 마지막 move_and_slide의 충돌 결과. 지상/공중 분기를 입력 순간의 추정 상태처럼 사용하면 안 된다.
- [입력 버퍼가 제대로 동작하지 않은 사용자 사례](https://forum.godotengine.org/t/jump-buffer-wont-work-properly/111787): 점프 버퍼·대시 횟수·지면/벽 상태가 함께 얽힌 재현 사례. 게시글의 해법을 그대로 가져오지 않고 우리 코드에서 따로 재현했다.

## 아직 별도 확인할 부분

8개 방 전체의 현재 수치 기준 사람 완주·난도, 실제 패드의 장치 전환, 키보드 동시입력 하드웨어 한계는 미확인이다. 현재 검사가 모든 버그가 없음을 보증하지 않는다. 특히 테스트가 보장하는 것은 입력 누락과 확인된 상태 경계이며 전체 맵 밸런스는 아니다.

## 변경 파일

- toys/movement/ToyMotion.gd: 대시 예약/방향/거리/점프 취소/대상 및 입력 경계.
- toys/movement/MovementToy.gd: 초기화·페이드 취소·남은 대시 HUD.
- toys/movement/Bashable.gd: 붙잡힘/부활 중 이동·피해 중단.
- movement_tuning.json / movement_schema.json: dash_input_buffer 추가.
- tests/MovementAuditSuite.*, MovementDashRateProbe.*: 재현과 회귀.
- RunMovement.command / RunMovement.cmd / Run.cmd: 최초 임포트 및 기본 씬 실행.

## Direction input order correction (2026-10-09)
The previous test pressed direction before Shift. Four overlapping old-direction + Shift-before-new-direction cases reproduced a stale aim snapshot. The toy now updates same-tick direction snapshots and accepts new direction edges for 0.06 seconds after dash start. Combat remains opt-out. Third dash presses cannot redirect the second dash.
225 synthetic key-event checks passed with normal automatic physics in both headless and GPU runs, including jump -> horizontal dash -> opposite/diagonal, and 1-2 frame late direction. Movement48, Audit52, existing981 regression checks passed. This is not physical keyboard validation; user confirmation remains necessary. HUD now shows Shift receipts, dash starts, and final direction.
