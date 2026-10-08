# Step 0 데이터 계약 보충

## 2026-10-07 Step 1 추가 계약

- 로더 대상은 9파일이다. `training.json`(연습 콘텐츠) 및 `tuning_defaults.json`(공장 기본값)을 추가했다. 원래 보스·무기·장비·재료 데이터는 유지.
- player에 `hurt_recovery=0.20`, `air_dash_count=1`, feedback에 `hitstop_time_scale=0.05`를 추가했다. 이 값도 F1에서 즉시 바꾸고 저장한다.
- F1은 명세의 0~3배를 허용한다. 이에 따라 `dash_duration`, `max_hp`, `jump_cut_mult`는 0을 포함하는 수치 계약으로 변경했다. 0초 대시는 한 physics tick 처리로 0 나눗셈을 막는다. HP=0은 사망하므로 값을 복원한 뒤 R로 연습을 재시작한다.
- 에디터-capable 실행 파일은 원본 tuning JSON에, exported feature 실행은 user override에 저장한다. override도 읽기 시 스키마 검증하며 손상 시 시작을 차단한다. 기본값 복원은 `tuning_defaults.json`를 사용한다.
- 조작감 디버그의 일시정지는 F1 패널이 소유한다. 포션은 채널 완료 시 소모하며 피격 취소 때는 소모하지 않는다. 패리 성공 때는 후딜 없이 돌아오며 실패 때 window+whiff_recovery가 행동을 잠근다.
- 입력 갱신은 physics tick 전 priority −100이다. 프레임별 just_pressed를 렌더 프레임에서 여러 번 소비하지 않는다. 자동 장치 전환은 이번 player_index0 연습용이며 향후 개별 장치 배정 시 auto_device=false.
- 히트/허트박스는 Area2D 사각형을 사용하고 동일 크기의 월드 AABB로 즉시 겹침을 판정한다. F2도 같은 크기를 그린다. 회전하는 히트박스는 이번 단계 범위가 아니다.
- Step 0의 '현재 미구현' 기록은 당시 상태다. 현재 구현 범위는 STEP_1_REPORT.md가 우선하며 보스 실행기/성장/Telemetry는 여전히 미구현.

원본은 GATE1_SPEC.md이며 이 문서는 명세에서 빠져 있거나 서로 다른 부분을 실제 JSON으로 표현한 결정을 기록한다. 전투 실행 결과나 밸런스 확정이 아니다.

## 표현 규칙

- 위치·크기: `[x,y]`, 색: RGBA `[0..1,0..1,0..1,0..1]`. 보스 위치 기준은 몸체 중심으로 예정. `floor_y`는 바닥 상단, `offset_y`는 몸체가 바닥에 접했을 때의 중심 높이로부터의 변위. 발판 `x`는 왼쪽 경계.
- 모든 스텝은 `type`을 포함한다. `patterns`는 보스 내부의 id→정의 map이고 phase의 `{id,weight}` 및 `enter_pattern`은 이 map을 참조한다.
- 원문에는 '패턴 스텝의 패턴 id' 검증이 있지만 열거된 스텝에는 패턴 호출 타입이 없다. 현재 실제 패턴 참조 필드인 phase/enter_pattern을 검증하고 `repeat.steps`는 인라인 재귀 검증한다. 미정의 패턴 호출 타입을 임의 추가하지 않았다.
- `duration/speed`의 phase 배율 적용은 Step 2 책임이다. 현재 JSON은 배율 적용 전 값.
- `attach=self`의 x offset은 facing 기준, `attach=world`는 생성 순간 위치에 고정할 계약. 실제 충돌 좌표는 Step 2에서 검증한다.
- `drop`의 `min/max`는 함께 지정하며 생략 시 `chance`가 필수다. chance만 있는 항목은 성공 시 1개라는 원문 심장 예시 의미. 실행기는 Step 3에 구현한다.
- 무기·장비 ID namespace는 분리된다. 시작 슬롯의 `sword_basic`은 무기 ID, 제작된 `slab_greatsword`는 장비 ID이며 `weapon_id=greatsword_slab`로 실제 공격 데이터를 찾을 예정이다. 저장/장착 해석은 Step 3에서 이 계약을 유지한다.
- `parry_enabled`는 boolean 기능 플래그로 산술 modifier가 될 수 없다. 원문의 'player.json 키'를 수치 키로 해석했다. 활성 여부는 Tuning에서 제어하며 효과의 패리 연관 판정은 Step 3에 구현한다.
- 조회 API는 유효 로딩 완료 전 차단되며 반환된 데이터는 deep copy다. 외부에 없는 ID의 조회도 오류 로그를 내며 빈 딕셔너리를 반환한다. 기본 콘텐츠를 만들어 대체하지 않는다.

## 최소 표현 보충

| 필드 | 이유 / 계약 |
|---|---|
| `arena.left/right` | 끝 지점과 중앙 타깃을 숫자 하드코딩 없이 정한다. |
| `stagger.parry_gain/heavy_hit_gain/heavy_damage_threshold/damage_mult` | 스태거 증가량·강공격 기준·1.25 피해 배율을 데이터에 둔다. |
| `jump.target=opposite_side` | 자기 위치의 반대쪽 아레나 끝을 generic target으로 표현한다. |
| `repeat.between_steps` (선택) | 반복 사이에만 실행한다. 골렘 double_slam은 slam 2회 사이에 jump 1회이며 마지막에는 jump하지 않는다. |
| `projectile.parriable_indices` (선택) | 0-based 인덱스. 있으면 지정된 발만 패리 가능; 없으면 `parriable`이 모든 발에 적용된다. |
| `projectile.reflect_damage/reflect_stagger` (선택) | 큰 반사탄의 피해 80·스태거 80을 데이터로 표현한다. 일반 탄의 반사는 원래 damage를 사용하며 추가 스태거는 parry_gain만 사용 예정. |
| `falling.fall_speed/spawn_y` | 낙하 속도·생성 높이를 코드에 남기지 않는다. |

Step 2의 공통 실행기가 이 보충 필드를 구현해야 한다. 보스 ID 분기는 금지한다. 현재 스텝 파일 실행기는 골격뿐이다.

## 명세 충돌과 구체화

- 개요의 재료 3종보다 4.8의 `wing_feather` 추가 지시를 적용하여 재료는 **4종**이다.
- Step 0 '모든 JSON 작성'을 적용하여 대검·쌍단검 데이터도 지금 작성했다. 무기 동작 연결은 Step 1/3의 해당 범위에서 진행한다.
- 날개 phase 2/3는 `fan_shot_seven` 별도 패턴을 참조한다. 보스 ID/phase별 코드 분기 없이 5발→7발 변경 가능하다.
- `double_slam`은 전방 slam 본체를 두 번 실행하고 사이에 반대편으로 점프한다. 첫 이동은 기본 slam과 달리 생략해 repeat 본체가 양쪽 끝 이동을 다시 덮어쓰지 않게 했다.
- 날개 sweep은 허용된 양쪽 중 왼쪽에서 시작하도록 고정했다. 랜덤 좌우 선택 부품은 추가하지 않았다.
- 기본 attack 수치는 원문 그대로이며 대검 damage×2.2, 시간×2, 크기×1.25 / 단검 damage×0.6, 시간×0.6, 크기×0.72의 출발값이다. 콤보 수는 2/4. 결과 숫자는 전부 weapons.json에 저장되어 런타임에서 배율을 하드코딩하지 않는다.
- 밸런스·공격 기회·날개 높이·텔레그래프 정합·패드 체감은 플레이 구현 전이므로 미검증이다.

## Step 2 추가 계약 (2026-10-07)
- battle.json 필수: boss_id 참조, player_spawn/boss_spawn 벡터, intro_duration 비음수, selection_retry/projectile_lifetime/shockwave_width/fall_warning_height/platform_thickness 양수.
- player.attack_direction_chain bool은 기본 true, 공격 유지 중 현재 타격 종료 후 다른 방향으로 연계. 저장된 과거 intent가 아니므로 release 후 실행하지 않는다. 기존 override에 필드가 없으면 true만 보충한다.
- move_to.stop_distance 선택 비음수: 목표 x에 접근하며 이 간격을 남김. 목표는 시작 때 고정하며 이미 간격 안이면 수평 이동하지 않는다.
- 스텝 elapsed는 phase 배율을 곱한 시간. 투사체/판정 수명은 생성 시 배율로 나눈다. repeat.between_steps는 마지막 뒤에는 실행하지 않는다.
- 경고는 공격 판정이 없으며 offset은 facing으로 좌우 반전. falling은 고정된 x와 낙하 경고를 만든 뒤 위에서 투사체 생성. phase/stagger/death/quit는 해당 보스 소유 경고·공격을 정리한다.
- 보스 ID 분기 없이 공통 프레임워크를 사용. Step 2 실행 boss_id는 golem. 성장/드롭 저장은 아직 연결하지 않는다.

## 복합 조작 계약 추가
- player bool: attack_during_dash, dash_keeps_attack, attack_hold_repeat, pogo_resets_air_dash. 기본 모두 true. 공장 기본값·패널·전체 저장 동일 계약. 누락된 구 override 필드는 새 기본값으로만 보충.
- 대시 이동은 dash_elapsed, 공격은 action_clock 사용. 공격 종류/attack_facing과 dash_direction 독립. 포고는 대시 궤적을 보존한 뒤 종료 시 상승 적용. 메뉴를 통과한 held 입력은 새 press 전 연속공격을 재개하지 않음.

## Step 3 추가 계약
- player.defense_buffer 비음수 초, 기본0.10. defense_cancel_hurt bool 기본true. 모든 boolean player 필드는 장비 add/mul 산술 보정 불가.
- StatCalc 결과: stats/effects/weapon_id. stats=(기본+add합)×(1+mul합), 이후 potion_bonus/parry_window_bonus 적용. 기본 damage_mult=1. 전투 장비 스냅샷과 자유 연습 무기 선택을 구분.
- save version1: materials 맵(알려진 ID·비음수 정수), owned 고유 장비ID 배열, equipped 세 슬롯(소유/슬롯일치 또는 빈값), unlocked 고유 보스ID, records(kills 양의 정수, best_time 유한 비음수), last_reward_token 문자열. 기본 검은 weapon 슬롯 빈값의 기본 무기.
- 보상은 보스 JSON의 min/max 또는 chance를 읽음. 승리 토큰 중복 차단. 저장 실패 시 동일 추첨값을 보류하며 재시도; 커밋 성공 전 제작/장착 차감 확정 금지.
- 진행은 user://save.json, 튜닝은 기존 source/override 계약 유지. GATE1_TEST_SAVE는 테스트 전용 분리 경로. 정상 저장은 tmp 교체·직전bak, 초기화는 별도reset 백업, 손상 원본 자동 덮어쓰기 금지.


## 2026-10-07 입력/콤보 갱신
- 기존 attack_buffer 기본 .18초, attack_release_clears_buffer 기본false. 한 슬롯/실제시간 만료, 방어·포커스·메뉴 경계 제거.0/true로 이전 정책 선택 가능.
- canonical 세 무기의 combo 배열은4항목. 같은 숫자 필드·패널을 사용. 구 override에 한해 부족한 항목을 해당 기본무기에서 보충하고 기존 항목을 보존한다. 빈 배열/잘못된 참조 등 오류 차단 유지.
- 동작 press edge는 장치별 방향도 보존한다. 최신 held 조준과 released tap의 의도를 구분한다.
- 연습/실제게임의 mode는 보상/장비 적용 계약이며, 모든 복귀 버튼은 허브를 기본 목적지로 사용한다.

## 2026-10-07 검수 수정 계약(최신)

- boss.initially_unlocked는 필수bool, order는 필수비음수정수. 정렬은 order/id, 초기 해금은 flag이며 시작은 해금 여부를 사용. 보스 파일명 하드코딩 제거.
- 공격 정의 chain_at는 필수비음수초, 후딜 시작 기준이며 runtime에서0~recovery clamp. 콤보/특수공격 모두 적용, 마지막타 전체 recovery. 공격 이동.4/일반hitstop.05/지상combo lunge30/dash300이 최신 기본값.
- player.min_vulnerable_gap는 비음수초. dash_cooldown>=dash_iframe+gap은 밸런스 경고로만 사용하고 오류화면 진입조건 아님. parry_whiff_cancel/parry_whiff_dash_cancel 필수bool 기본false. device_switch_axis는0~1 기본.6.
- move_to.max_duration 선택 양수초, 목적지 도달 또는 제한시간 경과 시 다음스텝. 골렘slam1.5초.
- 저장 로드는 구조 검사→현재 콘텐츠 id 이전→정식 검증→변경 전 원본 .pre-migrate.bak→commit 순서. 추가재료0, 삭제id 제거/경고, 삭제장착 빈슬롯. 구조호환 version만 정규화하며 타입오류·음수는 차단.
- tuning override는 defaults 누락필드 재귀병합, 무기는 id병합·사용자값우선. 운영JSON과 defaults를 같이 갱신해야 새 콘텐츠 이전이 성립.
- 공격/방어/input edge 버퍼는 physics delta 게임 시간. UI알림 표시 수명은 벽시계이며 게임 입력예약과 분리. 메뉴/포커스/장치변경 삭제 유지.
- progression debug_used는 런 동안 무적·배속·튜닝사용 누적. 처치·보상 허용/최고시간 제외. records.best_time=0은 공식 최고기록 없음, 허브는 — 표시. Telemetry 구현 완료를 의미하지 않음.


## 2026-10-08 독립 검수 계약 변경
`dash_direction_grace`(nonnegative, 기본 .05), `dash_attack_continues_after_dash`(bool, 기본 true), battle `result_input_delay`(nonnegative, 기본 .5) 추가. input_edge_lifetime 제거. 구 override의 dash_keeps_attack 값은 새 이름으로 이전, input_edge_lifetime은 제거. 정상 저장은 숫자 표현 차이로 마이그레이션하지 않음. 본 저장 누락 시 유효 tmp/bak 복구, 손상 후보만 있으면 차단. 세부 내용은 INDEPENDENT_REVIEW_FIX_REPORT.md.


## 마법 활
player에 bow_charge_time, bow_cooldown, bow_damage_min/max, bow_speed_min/max, bow_turn_rate, bow_lock_range, bow_lifetime, bow_hit_size 추가. charge_time/speed/lifetime/hit_size/lock_range는 positive, 나머지는 nonnegative. defaults 및 런타임 override 누락 병합 적용. 자세한 기본값과 동작은 MAGIC_BOW.md.
