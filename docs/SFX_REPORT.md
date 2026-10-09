# 효과음 보고 — 2026-10-09

사용자 요청: "새 스레드에서 효과음 작업하자". 기획 스레드가 가장 큰 빈칸으로 꼽은 소리(골렘 발소리, 타격, 피격, 대시 회피, 잡기, 골렘 쓰러짐)를 붙였다.

## 무엇을 했나

- 효과음 25개를 `assets/sfx/make_sfx.py`로 직접 합성했다(파이썬 표준 라이브러리만, 녹음·외부 소스 없음 → 라이선스 걱정 없음). 다시 만들려면 `python3 assets/sfx/make_sfx.py`.
- `assets/sfx/`에 `.gdignore`가 있어 에디터 가져오기 없이 실행 중에 WAV를 그대로 읽는다(기존 `.godot` 캐시가 있어도 바로 들림).
- 재생은 autoload `Sfx`(`autoload/Sfx.gd`): `Sfx.play("이름")`. 소리마다 음량(dB)과 무작위 음높이 폭이 `MIX`에 있다. 너무 크거나 작은 소리는 여기 숫자만 고치면 된다.

## 소리 목록

| 상황 | 소리 |
|---|---|
| 골렘 한 걸음 | `golem_step` 쿵 |
| 골렘 공격 준비 | `golem_windup` 돌 긁는 소리 |
| 내려찍기 / 발구르기 착지 | `golem_slam` / `golem_stomp` + 돌 튀는 `rock_pop` |
| 휘두르기 | `golem_sweep` 휙 |
| 무릎 꿇음 / 바닥에 닿음 | `golem_kneel` 우르르 / `golem_land` 쿵 |
| 골렘 사망 | `golem_die` 무너짐 + `win` 팡파르 |
| 등에서 털어냄 | `golem_shake` |
| 돌이 골렘에 맞음 | `rock_hit` |
| 약점 / 몸 타격 | `weak_hit` 결정 깨지는 소리 / `body_hit` 둔탁 |
| 칼 휘두름 | `swing` |
| 피격 / 대시 회피 | `hurt` / `dodge` |
| 잡기(튕기기 시작) / 발사 | `grab` / `launch` |
| 점프 / 벽 점프 / 대시 | `jump` / `wall_jump` / `dash` |
| 점프 방 사망 / 체크포인트 / 골 | `death` / `checkpoint` / `goal` |

## 검사

- 새 `SfxSuite`(30개): 25개 소리 모두 읽힘, 피격·회피·내려찍기(준비→착지)·골렘 사망에서 해당 소리 재생.
- 기존 23개 모음 전부 통과(`tests/run_suites.py`).
- 확인 못 한 것: 실제로 귀로 들은 느낌과 음량 균형. 컨테이너에서는 소리를 들을 수 없어 파형 크기만 맞췄다. 사람 판정 필요.
