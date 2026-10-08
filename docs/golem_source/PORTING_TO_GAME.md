# 골렘 컷아웃 보스 → 본 게임 이식 지시서 (Codex용)

이 문서는 GolemCutoutLab(독립 시험 프로젝트)의 골렘 리그와 애니메이션을 본 게임(Godot 4.6)에 옮기는 작업 지시서다. 시험 프로젝트 자체는 수정하지 말고 필요한 파일만 복사한다.

## 0. 먼저 할 것

1. 본 게임 레포의 기존 보스/적 구조(씬 구성, 상태머신, 히트박스·허트박스 방식, 데이터 리소스 위치, 폴더 규칙)를 읽고 그 규칙을 따른다. 아래 경로는 예시이며 레포 규칙이 우선한다.
2. 본 게임에 이미 있는 F키 전용 조작 금지 등 기존 제약을 그대로 지킨다.
3. 작업 전에 변경 계획(추가 파일, 수정 파일)을 짧게 남기고 진행한다.

## 1. 복사할 것 / 복사하지 말 것

복사한다:

- `assets/parts/` 의 PNG 7개: `torso.png head.png arm_upper.png arm_lower.png fist.png leg_upper.png leg_lower.png`
- `scenes/golem.tscn` (시각 리그 + AnimationPlayer. 애니메이션: `idle`, `slam`, `slam_heavy`, `slam_high`, `RESET`)
- 선택: `assets/source/parts_sheet_v2.png` (원본 시트 보존용, 아트 원본 폴더에)

복사하지 않는다: `scripts/lab.gd`, `scenes/lab.tscn`, `evidence/`, `assets/parts_v1/`, `fist_large*`, `tools_py/`, `RUN.cmd`, `EDIT.cmd`.

복사 후 `golem.tscn` 상단 `ext_resource` 의 `res://assets/parts/...` 경로를 새 위치로 고친다. (예: `res://bosses/golem/art/torso.png`) 파일명은 바꾸지 않는 것을 권장한다.

## 2. 리그 규칙 (깨면 안 되는 것)

- `golem.tscn` 루트(`Golem`, Node2D)의 원점 = 발바닥 높이(y=0이 지면). 기본자세에서 앞발 뒤꿈치 x≈-20, 앞발 끝 x≈114.
- 그림은 **오른쪽을 바라보도록** 그려져 있다. 방향 전환은 리그 인스턴스 루트의 `scale.x = -1` 로만 한다. 개별 Sprite2D를 뒤집지 않는다.
- 노드 계층·이름을 바꾸지 않는다. 애니메이션 트랙이 `Torso`, `Torso/TorsoSkin`, `Torso/Head`, `Torso/ArmFront_Upper/ArmFront_Lower/FistFront` 등의 경로를 참조한다.
- `Torso`는 텍스처 없는 Node2D(관절 기준점)이고 몸통 그림은 `TorsoSkin`이다. 착지 스쿼시는 `TorsoSkin:scale`에만 걸려 있다.
- 뒷팔·뒷다리는 같은 PNG에 modulate 0.7. 아래팔은 `show_behind_parent = true`(팔꿈치 바위 뒤로 들어감). 그리기 순서를 바꾸지 않는다.
- 크기: 리그 단위로 서 있는 키 약 440(머리 꼭대기 y≈-460). 실험실에서는 0.6배로 표시했다. 게임 내 크기는 리그 인스턴스의 uniform scale로만 맞춘다.
- 텍스처는 칠한 그림이다. 프로젝트 기본 필터가 Nearest면 리그 루트에 `texture_filter = Linear`를 지정한다.

## 3. 보스 씬 구성 (권장)

```
GolemBoss (CharacterBody2D 또는 레포의 보스 기본 타입)
  CollisionShape2D            ← 몸 충돌(기본자세 기준 박스)
  Rig (golem.tscn 인스턴스)   ← 시각 전용. 방향 전환은 Rig.scale.x
  Hurtbox (Area2D)            ← 몸통 피격. Rig/Torso 아래에 붙이면 숙임을 자동으로 따라감
  SlamHitbox (Area2D)         ← 내려찍기 공격 판정. 평소 비활성
  (상태머신/AI 스크립트)
```

- 보스 이동은 GolemBoss 루트가 담당한다. 애니메이션의 `Torso:position`은 리그 내부 상대값이므로 루트 이동과 충돌하지 않는다.
- `AnimationPlayer`는 리그 안에 그대로 둔다. 보스 스크립트는 `$Rig/AnimationPlayer`를 호출한다.

## 4. slam 타이밍과 판정

`slam` (1.4초) 키 구간:

| 구간 | 시간 | 의미 |
|---|---|---|
| 예비동작 | 0.0–0.6 | 팔 들어올림, 플레이어가 읽는 텔레그래프 |
| 내려찍기 | 0.6–0.7 | 휘둘러 내림 |
| 착지 | 0.7 | 손날이 지면 접촉, 스쿼시 |
| 공격 기회 | 0.7–1.1 | 주먹 박힌 채 정지 |
| 복귀 | 1.1–1.4 | 기본자세로 직선 복귀 |

`slam_heavy`는 예비동작이 0.8초라 이후 전부 +0.2초. `slam_high`는 시간은 같고 팔을 더 높이 든다.

- SlamHitbox: 착지 시 앞주먹 손날이 리그 좌표 x≈162~277, y=0에 닿는다. 판정은 이 구간을 덮는 지면 박스(예: 중심 x≈220, 폭≈150, 높이≈60, 바닥 기준)로 시작하고 수치는 데이터로 뺀다.
- 판정 활성 시간: 0.7~0.8초(heavy는 0.9~1.0초). **타이밍은 하드코딩하지 말고** 보스 데이터 리소스(예: `GolemSlamData.tres`)에 `windup`, `active_start`, `active_end`, `punish_end`, `hitbox_rect`로 둔다. 기본값은 위 표와 같게.
- 구현은 AnimationPlayer의 `current_animation_position`을 매 프레임 보고 활성/비활성을 토글하거나, 애니메이션 시작 시 데이터 값으로 타이머를 거는 방식 중 레포 기존 방식을 따른다. golem.tscn의 애니메이션 리소스에 메서드 트랙을 직접 추가하지 않는다(리그는 생성 스크립트로 재생성될 수 있다).
- 착지 이벤트(카메라 흔들림, 먼지 이펙트, 사운드)는 같은 데이터의 `active_start` 시점에 신호로 내보낸다.
- 공격 기회(0.7~1.1) 동안 앞주먹/팔에 약점 허트박스를 둘지는 기획 결정 사항이므로 꺼진 상태의 옵션으로만 만들어 둔다.

## 4-1. 추가 패턴 (sweep, stomp)

`golem.tscn`에는 `sweep`(휩쓸기 1.5초), `stomp`(발구르기 1.3초)도 들어 있다. 타이밍·판정 위치·패턴 선택 규칙은 `docs/GOLEM_BOSS_DESIGN.md`를 따른다. slam과 같은 방식(데이터 리소스 + 위치 기반 토글)으로 구현한다.

## 5. 디버그 노출 (원칙: 조작감 수치는 슬라이더로)

레포의 기존 디버그 UI가 있으면 거기에 다음을 노출한다: 예비동작 길이, 판정 활성 구간, 히트박스 크기·위치, 리그 표시 배율. 예비동작 길이를 바꿀 때는 0.6초 이후 키를 모두 같은 양만큼 밀고 length를 늘린다(실험실 `lab.gd`의 `_customize()`가 참고 구현).

## 6. 완료 확인

- 게임을 실행해 골렘이 idle → slam을 반복하는지, 착지 순간 손날이 지면에 닿는지 실제 화면으로 확인한다.
- 좌우 방향 모두에서 판정 위치가 그림과 맞는지 확인한다.
- 판정이 0.7~0.8초에만 켜지는지 로그나 디버그 표시로 확인한다.
- 게임 실제 해상도·배경에서 내려찍기가 읽히는지 스크린샷을 남긴다.
- 기존 게임 기능·저장·조작이 깨지지 않았는지 기존 테스트/실행 확인을 돌린다.
- 확인하지 않은 항목은 완료라고 쓰지 말고 미확인으로 보고한다.
