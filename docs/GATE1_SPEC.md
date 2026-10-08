# 첫 관문 프로토타입 설계서 (Gate 1)

작성일 2026-10-07. 이 문서는 Codex가 그대로 실행하는 설계서다. 단계(Step)는 순서대로 하나씩 진행하고, 한 단계의 완료 조건을 모두 만족하면 멈추고 보고한다. 다음 단계는 지시가 있을 때만 시작한다.

## 0. 확정 사항

- 엔진: Godot 4.6, GDScript(정적 타입 표기 사용). C#·외부 플러그인 사용 금지.
- 시점: 사이드뷰, 한 화면 고정 아레나(컵헤드식 보스 러시 구조). 카메라는 고정, 흔들림만 적용. 스크롤·레벨 디자인 없음.
- 논리 해상도 1920x1080, stretch mode `canvas_items`, aspect `keep`.
- 그래픽: 전부 도형(ColorRect, Polygon2D, `_draw()`). 스프라이트·애니메이션 에셋 금지.
- 사운드: 이 관문에서는 없음.
- 입력: 키보드 + 게임패드를 처음부터 둘 다 지원.

## 1. 이 관문이 답해야 하는 질문

첫 보스를 잡고 장비를 만든 뒤, 두 번째 보스에 다시 붙고 싶어지는가.

이 질문에 답할 수 있는 최소 루프만 만든다. 루프: 허브 → 보스 전투 → (승리 시) 재료 획득 → 허브에서 제작·장착 → 다음 보스 또는 재도전.

범위: 플레이어 캐릭터 1, 보스 2, 제작 장비 5(+시작 무기 1), 재료 3종.

## 2. 절대 원칙 (모든 단계 공통)

1. 데이터 드리븐. 보스, 보스 패턴, 무기, 장비, 재료, 레시피, 조작감 수치는 전부 `res://data/` 아래 JSON에 있다. 코드는 읽기만 한다. 콘텐츠 수치를 코드에 하드코딩하면 실패로 간주한다.
2. 코드가 구현하는 것은 "부품(primitive)"이다. 보스 패턴은 코드가 제공하는 스텝 타입을 JSON에서 조합해 만든다. 새 패턴 추가가 JSON 편집만으로 가능해야 한다.
3. Fail-closed 로딩. 게임 시작 시 모든 JSON을 검증한다. 필수 필드 누락, 타입 오류, 존재하지 않는 id 참조가 하나라도 있으면 화면 전체에 빨간 오류 목록을 띄우고 게임을 진행시키지 않는다. 조용한 기본값 대체 금지.
4. 조작감 수치는 전부 런타임 디버그 패널(F1)에서 슬라이더로 조절 가능해야 하고, 저장 버튼으로 JSON에 다시 쓸 수 있어야 한다.
5. 기존 코드는 외과적으로 수정한다. 파일을 통째로 다시 쓰지 않는다. 단계 보고 시 수정한 파일과 이유를 나열한다.
6. 협동 대비. "플레이어는 하나"라는 가정을 코드에 박지 않는다(아래 4.3 참고). 이번 관문에서 2인 플레이는 구현하지 않는다.

## 3. 폴더 구조

```
res://
  data/
    tuning/player.json        # 조작감·기본 스탯
    tuning/feedback.json      # 히트스톱·흔들림·넉백 연출 수치
    weapons.json
    equipment.json            # 레시피 포함
    materials.json
    bosses/golem.json
    bosses/wing.json
  autoload/
    DataRegistry.gd           # JSON 로드·검증·조회
    GameState.gd              # 보유 재료·장비·장착·해금, 세이브/로드
    Tuning.gd                 # 런타임 조작감 수치 (DataRegistry에서 초기화)
    Telemetry.gd              # 런 기록
    Feedback.gd               # 히트스톱·화면 흔들림 호출 창구
  scenes/
    hub/Hub.tscn
    arena/Arena.tscn
    player/Player.tscn
    boss/Boss.tscn            # 범용 보스. 데이터로 정체성이 결정됨
    combat/Hitbox.tscn, Hurtbox.tscn, Projectile.tscn, Telegraph.tscn
    ui/DebugPanel.tscn, ResultScreen.tscn, DataErrorScreen.tscn
  scripts/
    boss/PatternRunner.gd     # 스텝 실행기
    boss/steps/*.gd           # 스텝 타입별 구현
    stats/StatCalc.gd
    input/PlayerInput.gd
```

## 4. 시스템 설계

### 4.1 데이터 로딩 (DataRegistry)

- 시작 시 `res://data/` 전체를 로드한다. JSON 파싱은 `FileAccess` + `JSON.parse_string`.
- 각 파일에 대해 스키마 검증 함수를 둔다(손으로 작성한 검증 코드로 충분, 외부 스키마 라이브러리 금지).
- 교차 참조 검증: 레시피의 재료 id, 보스 드롭 id, 장비의 무기 id, 패턴 스텝의 패턴 id가 모두 존재해야 한다.
- 오류가 있으면 `DataErrorScreen`으로 전환하고 `파일:경로:문제` 형식으로 전부 표시한다.
- 조회 API: `get_boss(id)`, `get_weapon(id)`, `get_equipment(id)`, `all_equipment()`, `get_material(id)`.

### 4.2 조작감 수치 (player.json 기본값)

단위는 px, 초. 아래 값은 출발점일 뿐이고 튜닝은 사람이 한다.

```json
{
  "move_speed": 520,
  "ground_accel": 6000,
  "air_accel": 3200,
  "gravity": 3600,
  "fall_gravity_mult": 1.5,
  "max_fall_speed": 1600,
  "jump_velocity": 1350,
  "jump_cut_mult": 0.45,
  "coyote_time": 0.10,
  "jump_buffer": 0.12,
  "dash_distance": 280,
  "dash_duration": 0.16,
  "dash_iframe": 0.20,
  "dash_cooldown": 0.50,
  "perfect_dodge_window": 0.12,
  "parry_enabled": true,
  "parry_window": 0.12,
  "parry_whiff_recovery": 0.35,
  "parry_cooldown": 0.40,
  "hurt_iframe": 0.80,
  "hurt_knockback": 420,
  "max_hp": 100,
  "potion_count": 3,
  "potion_heal": 35,
  "potion_channel": 0.80
}
```

feedback.json:

```json
{
  "hitstop_on_hit": 0.05,
  "hitstop_on_parry": 0.12,
  "hitstop_on_player_hurt": 0.08,
  "shake_on_hit": 6,
  "shake_on_parry": 14,
  "shake_on_player_hurt": 12,
  "shake_decay": 40,
  "boss_hit_flash": 0.06,
  "damage_numbers": true
}
```

- 패리는 `parry_enabled` 플래그로 통째로 켜고 끌 수 있어야 한다. 꺼지면 입력도 무시되고 패리 관련 UI도 숨긴다. 패리 포함 여부를 플레이로 판정하기 위함이다.
- 히트스톱은 `Engine.time_scale`을 0.05로 낮추고 `ignore_time_scale` 타이머로 복구하는 방식으로 구현한다. 히트스톱이 겹치면 더 긴 쪽으로 갱신한다.
- 화면 흔들림은 Camera2D offset에 감쇠 노이즈를 준다.

### 4.3 플레이어

- 캐릭터: 48x96 사각형. 바라보는 방향을 작은 삼각형으로 표시.
- 상태: idle, run, jump, fall, dash, attack, parry, hurt, potion, dead. 상태 머신은 단순 enum + match로 충분하다.
- 조작: 이동, 점프(길게 누르면 높이 점프, 떼면 `jump_cut_mult`), 대시(공중 1회, 무적), 공격(무기 데이터에 따른 콤보), 패리, 포션.
- 위·아래 + 공격: 공중에서 아래 공격은 하단 판정, 위 공격은 상단 판정. 판정 크기·오프셋은 무기 데이터.
- 완벽 회피: 적 Hitbox가 대시 시작 후 `perfect_dodge_window` 안에 플레이어와 겹치면 "완벽 회피" 이벤트를 발생시킨다(장비 효과 트리거용). 화면에 짧은 텍스트 표시.
- 패리: 입력 후 `parry_window` 동안 `parriable: true`인 Hitbox·투사체를 막는다. 성공 시 피해 0, 히트스톱·흔들림, 보스 스태거 게이지 증가, 투사체는 반사(반대 방향, 보스에게 피해). 실패(헛패리) 시 `parry_whiff_recovery` 동안 행동 불가.
- 협동 대비 규칙:
  - Player 노드는 `player_index: int`를 가진다.
  - 입력은 `PlayerInput`(device id 기반)을 통해서만 읽는다. Player 코드에서 `Input.is_action_pressed`를 직접 호출하지 않는다.
  - 보스는 `players` 그룹에서 타깃을 고른다(살아있는 플레이어 중 가장 가까운 대상). 전역 "the player" 참조 금지.
  - 이번 관문은 player_index 0만 스폰한다.

### 4.4 무기와 공격 (weapons.json)

```json
[
  {
    "id": "sword_basic",
    "name": "낡은 검",
    "combo": [
      {"damage": 10, "startup": 0.08, "active": 0.08, "recovery": 0.18, "reach": 110, "height": 70, "knockback": 60, "lunge": 40},
      {"damage": 10, "startup": 0.07, "active": 0.08, "recovery": 0.18, "reach": 110, "height": 70, "knockback": 60, "lunge": 40},
      {"damage": 16, "startup": 0.12, "active": 0.10, "recovery": 0.30, "reach": 130, "height": 80, "knockback": 160, "lunge": 60}
    ],
    "combo_window": 0.25,
    "air_attack": {"damage": 10, "startup": 0.06, "active": 0.10, "recovery": 0.16, "reach": 100, "height": 70},
    "down_attack": {"damage": 12, "startup": 0.06, "active": 0.14, "recovery": 0.20, "reach": 60, "height": 110, "pogo_velocity": 900},
    "up_attack": {"damage": 10, "startup": 0.08, "active": 0.10, "recovery": 0.20, "reach": 60, "height": 120},
    "flags": []
  }
]
```

- 콤보 단계 수는 배열 길이로 결정된다.
- 아래 공격이 적에게 맞으면 `pogo_velocity`만큼 튕겨 오른다(할로우나이트식).
- `flags`는 코드가 아는 문자열 목록: `"dash_cancel"`(공격 recovery 중 대시로 캔슬 가능).

### 4.5 스탯과 장비 (equipment.json, materials.json)

장착 슬롯 3개: `weapon`, `armor`, `charm`. 시작 장착은 `sword_basic`.

최종 스탯 = (기본값 + 덧셈 보정 합) × (1 + 곱셈 보정 합). 계산은 `StatCalc` 한 곳에서만 한다. 플레이어는 전투 시작 시 한 번 계산된 스탯을 받는다. 보정 가능한 스탯 키는 player.json의 키 + `damage_mult`.

효과(effect)는 코드에 구현된 고정 타입만 쓴다:
- `on_perfect_dodge_damage_buff` {mult, duration}: 완벽 회피 후 다음 N초 공격 피해 배율
- `potion_bonus` {count}
- `parry_window_bonus` {seconds}
- `on_parry_heal` {amount}

materials.json:

```json
[
  {"id": "golem_shard", "name": "골렘 파편"},
  {"id": "golem_core", "name": "골렘 핵"},
  {"id": "golem_heart", "name": "골렘 심장", "rare": true}
]
```

equipment.json (5개, 전부 첫 보스 재료로 제작):

```json
[
  {"id": "slab_greatsword", "name": "석판 대검", "slot": "weapon", "weapon_id": "greatsword_slab",
   "recipe": {"golem_shard": 3, "golem_core": 1}, "modifiers": {"move_speed": {"mul": -0.08}}, "effects": []},
  {"id": "twin_daggers", "name": "쌍단검", "slot": "weapon", "weapon_id": "daggers_twin",
   "recipe": {"golem_shard": 4}, "modifiers": {}, "effects": []},
  {"id": "rock_mail", "name": "바위 갑옷", "slot": "armor",
   "recipe": {"golem_shard": 5}, "modifiers": {"max_hp": {"add": 30}, "move_speed": {"mul": -0.05}}, "effects": []},
  {"id": "core_ward", "name": "핵 부적", "slot": "charm",
   "recipe": {"golem_core": 1, "golem_shard": 2}, "modifiers": {}, "effects": [{"type": "parry_window_bonus", "seconds": 0.05}, {"type": "on_parry_heal", "amount": 5}]},
  {"id": "heart_ring", "name": "심장 반지", "slot": "charm",
   "recipe": {"golem_heart": 1, "golem_shard": 2}, "modifiers": {}, "effects": [{"type": "on_perfect_dodge_damage_buff", "mult": 1.5, "duration": 2.0}]}
]
```

weapons.json에 `greatsword_slab`(느리고 강함: 3타 대신 2타 콤보, 타당 피해 약 2.2배, 선딜 약 2배, 넉백 큼)과 `daggers_twin`(빠름: 4타 콤보, 타당 피해 약 0.6배, 선후딜 짧음, flags `["dash_cancel"]`)을 추가한다. 정확한 수치는 위 배율 근처로 잡고 데이터에서 조절한다.

패리가 꺼져 있으면 `core_ward`는 제작 목록에서 숨긴다(효과가 무의미하므로). 이 판정은 효과 타입이 전부 패리 관련인지로 자동 결정한다.

### 4.6 보스 프레임워크

보스는 하나의 범용 씬 `Boss.tscn`이고, 정체성은 JSON이 결정한다.

보스 JSON 최상위 필드:
- `id`, `name`, `max_hp`, `body` {shape: "rect"|"triangle"|"circle", size, color}, `contact_damage`, `gravity`(0이면 비행), `arena` {floor_y, platforms: [{x, y, w}]}, `stagger` {threshold, duration, decay_per_sec}, `phases`, `drops`, `unlocks`.
- `phases`: HP 비율 하한이 높은 순. 각 phase는 `hp_above`, `speed_mult`, `patterns`(패턴 id 목록과 weight), `enter_pattern`(진입 시 1회 실행할 패턴 id, 선택).
- `patterns`: id → { `cooldown`, `min_distance`, `max_distance`, `steps`: [...] }.
- `drops`: `[{"id": "golem_shard", "min": 3, "max": 5}, {"id": "golem_core", "min": 1, "max": 1}, {"id": "golem_heart", "chance": 0.25}]`.
- `unlocks`: 처치 시 해금되는 보스 id 목록.

패턴 선택 규칙: 현재 phase의 패턴 중 쿨다운이 끝났고 거리 조건을 만족하는 것들에서 weight 랜덤. 직전 패턴은 후보가 2개 이상이면 제외. 후보가 없으면 `wait 0.3` 후 재선택.

스텝 타입 (PatternRunner가 실행, 각각 `scripts/boss/steps/`에 파일 하나):
- `wait` {duration}
- `face_target`
- `telegraph` {shape, offset 또는 target: "player_x"|"self", size, duration, color} — 경고 표시만. 판정 없음.
- `move_to` {target: "player_x"|"arena_left"|"arena_right"|"arena_center"|"above_player", speed, offset_y?}
- `dash` {direction: "facing"|"to_target", speed, distance, hitbox?}
- `jump` {target, height, duration} — 포물선 이동, 착지 시 다음 스텝으로.
- `hitbox` {offset, size, duration, damage, knockback, parriable, attach: "self"|"world"}
- `shockwave` {direction: "left"|"right"|"both", speed, height, damage, parriable} — 바닥을 따라 이동하는 판정. 점프로 피한다.
- `projectile` {count, spread_deg, aim: "target"|"down"|"forward", speed, size, damage, parriable, gravity?}
- `falling` {count, x_mode: "random"|"around_player", spread, warn_time, size, damage} — 위에서 떨어지는 판정. 낙하 위치에 경고 표시 자동 생성.
- `set_vulnerable` {value: bool} — false면 피해 무시(시각적으로 회색 테두리).
- `repeat` {times, steps: [...]}

모든 duration·speed에 phase의 `speed_mult`를 적용한다(duration은 나누고 speed는 곱한다). 텔레그래프 duration도 포함.

스태거: 패리 성공과 강공격이 스태거 게이지를 올린다. threshold 도달 시 진행 중 패턴 중단, `duration` 동안 무력화(받는 피해 1.25배). 패리를 끄면 강공격만 게이지를 올린다.

### 4.7 보스 1: 골렘 (golem.json)

- 큰 사각형 360x300, 지상형. HP 900. 접촉 피해 15.
- phase 1 (hp_above 0.5): 
  - `slam`: 플레이어 x로 천천히 이동 → 텔레그래프 0.6초 → 자기 앞 대형 hitbox(피해 25, 패리 불가) → 양방향 shockwave(피해 15, 패리 불가) → wait 0.8 (공격 기회)
  - `charge`: 텔레그래프 0.5 → 아레나 끝까지 dash(피해 20, 패리 불가) → wait 1.0
  - `rock_drop`: telegraph 0.4 → falling 4개 around_player(피해 15) → wait 0.6
  - `punch`: 근거리 전용(max_distance 300). 텔레그래프 0.35 → hitbox(피해 18, 패리 가능) → wait 0.5
- phase 2 (hp_above 0): speed_mult 1.2, enter_pattern `roar`(set_vulnerable false 1.0초 + 양방향 shockwave), 패턴: 위 4개 + `double_slam`(slam을 repeat 2, 두 번째는 반대편으로 jump 후).
- 드롭: 파편 3~5, 핵 1, 심장 25%.
- unlocks: ["wing"].

### 4.8 보스 2: 날개 (wing.json)

- 큰 삼각형 300x220, 비행형(gravity 0). HP 1400. 접촉 피해 15. 골렘보다 확실히 어려워야 한다. 기본 검·기본 장비로는 숙련 없이는 깨기 힘들고, 제작 장비 2개 정도면 해볼 만한 수준을 목표로 한다.
- phase 1 (hp_above 0.6):
  - `fan_shot`: 공중 유지, 텔레그래프 0.4 → projectile 5발 spread 50도 aim target(피해 12, 가운데 1발만 parriable) → wait 0.6
  - `dive`: above_player로 이동 → 텔레그래프 0.5 → 아래로 dash(피해 22) → 착지 상태 wait 1.2 (공격 기회, 아래 공격 없이도 때릴 수 있는 높이) → 원위치 복귀
  - `sweep`: arena_left 또는 right로 이동 → 낮은 높이로 반대편까지 dash(피해 18). 대시나 점프로 피한다.
- phase 2 (hp_above 0.25): speed_mult 1.15, `feather_rain`(falling 8개 random) 추가, fan_shot 7발.
- phase 3 (hp_above 0): speed_mult 1.3, enter_pattern 큰 반사 가능 투사체 1발(parriable, 반사 시 보스에게 피해 80 + 스태거 대량).
- 드롭: 이번 관문에서는 `wing_feather` 재료 1~2개를 추가하되 쓰는 레시피는 없다(materials.json에 추가). 처치 기록만 남으면 된다.
- unlocks: [].

### 4.9 허브 (Hub.tscn)

UI만 있는 화면. 꾸미지 않는다.
- 왼쪽: 보유 재료 목록.
- 가운데: 제작 목록. 재료 충분하면 제작 버튼 활성. 이미 가진 장비는 "보유" 표시. 각 항목에 수치 변화 요약 표시(예: 최대 HP +30, 이동속도 −5%).
- 오른쪽: 장착 슬롯 3개, 클릭하면 보유 장비 중 선택. 현재 최종 스탯 요약.
- 아래: 보스 선택 버튼. 잠긴 보스는 "골렘을 처치하면 해금"처럼 표시. 각 보스 옆에 처치 횟수와 최고 기록 시간.
- 조작은 마우스와 게임패드 둘 다.

### 4.10 전투 흐름과 결과

- 아레나 진입 → 0.8초 보스 이름 표시 → 전투.
- HUD: 플레이어 HP 바, 포션 수, 대시 쿨다운 표시, 보스 HP 바(phase 경계 눈금), 보스 스태거 게이지.
- 사망 시: 결과 화면에 "다시"(즉시 같은 보스 재시작)와 "허브" 버튼. 재시작은 버튼 하나, 1초 안에 전투가 다시 시작되어야 한다. 키보드 R, 패드 A로도 재시작.
- 승리 시: 드롭 목록 표시 → 허브로. 처치 시간 표시.
- 사망해도 잃는 것은 없다.
- ESC/Start: 일시정지(재개, 허브로 포기).

### 4.11 세이브 (GameState)

- `user://save.json`에 보유 재료, 보유 장비, 장착 상태, 보스별 처치 횟수·최고 기록 저장. 허브 진입 시·제작 시·장착 시 자동 저장.
- 디버그 패널에 "세이브 초기화" 버튼.

### 4.12 텔레메트리 (Telemetry)

판정용 기록이다. 전투가 끝날 때마다 `user://runs.jsonl`에 한 줄 추가:

```json
{"ts": "...", "session_id": "...", "boss": "golem", "result": "win|death|quit", "duration": 84.2,
 "boss_hp_left_ratio": 0.0, "phase_reached": 2, "damage_taken": 85, "potions_used": 2,
 "parries": 4, "perfect_dodges": 7, "death_by": "golem.slam",
 "loadout": {"weapon": "sword_basic", "armor": null, "charm": null}, "retry_within_sec": null}
```

- `death_by`는 마지막으로 플레이어에게 피해를 준 `보스id.패턴id`.
- `retry_within_sec`: 다음 전투가 시작될 때 직전 기록을 갱신하지 말고, 새 줄에 "이전 전투 종료 후 몇 초 만에 시작했는지"를 기록한다(이 필드는 새 줄 기준). 재도전 욕구 측정용.
- 디버그 패널에 "기록 폴더 열기" 버튼(`OS.shell_open`).

### 4.13 디버그 (DebugPanel)

- F1: 조작감 패널 토글. player.json·feedback.json의 모든 수치를 슬라이더(범위는 기본값의 0~3배, 정수/실수 구분)로 노출. 변경 즉시 반영. "저장"은 에디터 실행일 때 `res://data/tuning/*.json`에, 내보낸 빌드일 때 `user://tuning_override.json`에 쓴다. 로딩 시 override가 있으면 덮어쓴다. "기본값으로" 버튼.
- F2: 판정 박스 표시 토글(Hitbox 빨강, Hurtbox 초록, 패리 판정 파랑).
- F3: 재료 각 10개 지급.
- F4: 보스 HP 10%로.
- F5: 플레이어 무적 토글.
- F6: 게임 속도 0.25 / 0.5 / 1.0 순환(패턴 확인용).
- 디버그 키는 내보낸 빌드에서도 동작하게 둔다(친구 테스트 시 기록 확인용). 단 F3~F6 사용 시 해당 런 텔레메트리에 `"debug_used": true`.

## 5. 단계별 작업

### Step 0. 골격과 데이터 로더
- 프로젝트 생성, 폴더 구조, 오토로드 등록, 입력 맵(키보드+패드) 정의.
- DataRegistry 전체 검증 구현. 이 단계에서 모든 JSON 파일을 위 예시대로 작성(보스는 패턴까지 전부).
- 완료 조건: 실행하면 "데이터 OK"와 각 파일 항목 수가 표시된다. 레시피 재료 id를 일부러 틀리게 바꾸면 오류 화면에 정확한 위치가 뜬다(이 확인 결과를 보고에 포함).

### Step 1. 플레이어와 조작감
- Player 전체(이동, 점프, 대시, 공격 콤보, 상하 공격, 포고, 패리, 포션, 피격).
- 테스트 아레나: 바닥 + 발판 2개 + 허수아비 타깃(HP 무한, 맞으면 깜빡임·피해 숫자, 3초마다 parriable 공격 하나를 해서 패리 연습 가능).
- Feedback(히트스톱, 흔들림), DebugPanel F1·F2·F5·F6.
- 완료 조건: 키보드와 패드로 모든 동작 가능. F1 슬라이더 변경이 즉시 반영되고 저장 후 재실행해도 유지된다. `parry_enabled` false면 패리 입력이 무시된다.
- 이 단계 끝나면 반드시 멈춘다. 사람이 조작감을 직접 튜닝한 뒤 다음 단계로 간다.

### Step 2. 보스 프레임워크와 골렘
- Boss.tscn, PatternRunner, 모든 스텝 타입, phase 전환, 스태거, 패턴 선택 규칙.
- golem.json으로 골렘 전투가 동작. HUD, 사망/승리 결과 화면, 즉시 재시작.
- 완료 조건: 골렘의 모든 패턴이 나온다. F6 0.25배속에서 각 텔레그래프와 판정이 맞물리는지 확인 가능. golem.json에서 패턴 하나의 스텝 순서를 바꾸면 코드 수정 없이 반영된다(보고에 포함).

### Step 3. 성장 루프
- 드롭, GameState, 세이브, 허브(재료·제작·장착·보스 선택·해금), StatCalc, 장비 효과 4종, 무기 2종 추가.
- 완료 조건: 골렘 처치 → 재료 획득 → 허브에서 제작·장착 → 다시 전투했을 때 스탯·무기가 반영된다. 날개 보스가 해금된다. 재실행 후에도 상태 유지.

### Step 4. 날개
- wing.json 작성분으로 날개 전투. 필요한 스텝 타입이 부족하면 새 스텝 타입을 추가하되, 날개 전용 코드(보스 id 분기)는 금지.
- 완료 조건: 3 phase가 모두 동작하고 반사 투사체가 보스에게 피해를 준다.

### Step 5. 텔레메트리와 테스트 빌드
- Telemetry, 디버그 F3·F4, 기록 폴더 열기.
- Windows 내보내기 프리셋 추가, 실행 파일 하나로 친구에게 줄 수 있는 빌드.
- 완료 조건: 전투 3번(승리 1, 사망 1, 포기 1) 후 runs.jsonl에 3줄이 정확한 값으로 기록된다.

## 6. 이번 관문에서 하지 않는 것

아트, 사운드, 애니메이션, 스토리, 대사, 설정 메뉴, 키 리바인딩, 2인 플레이, 네트워크, 스팀 연동, 로컬라이제이션, 보스 3 이상, 새 장비 슬롯. 요청받지 않은 리팩터링과 "있으면 좋을" 기능도 금지.

## 7. 단계 보고 형식 (Codex → 사람)

1. 이번 단계에서 한 것 (기능 단위로 짧게)
2. 수정·생성한 파일 목록과 각 이유
3. 완료 조건별 확인 결과 (확인 방법 포함, 확인 못 한 것은 못 했다고 명시)
4. 데이터로 빼지 못하고 코드에 남긴 수치가 있으면 전부 나열
5. 다음 단계 전에 사람이 결정해야 할 것

## 8. 관문 판정 (사람용)

Step 5 빌드로 혼자 최소 3세션, 친구 1명 1세션.
- 골렘을 처음 잡은 뒤 바로 제작하러 갔는가, 아니면 끄고 싶었는가.
- 날개에서 죽었을 때 "다시"를 바로 눌렀는가. (runs.jsonl의 retry_within_sec)
- 장비를 바꾼 뒤 전투 체감이 실제로 달랐는가, 숫자만 바뀐 느낌인가.
- 패리 켬/끔 중 어느 쪽이 더 하고 싶었는가.
- 친구가 시키지 않았는데 한 판 더 했는가.

이 중 "다시 붙고 싶다"는 신호가 약하면 폴리싱으로 메우지 않는다. 루프(보상 구조, 보스 간 관계, 장비 차별성)부터 다시 설계한다.