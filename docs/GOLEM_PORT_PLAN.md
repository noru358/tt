# 골렘 컷아웃 이식 작업 계획

2026-10-08. 사용자 지정 GitHub 대상: noru358/tt. 저장소 main은 파일이 없는 초기 상태이므로 이번 채팅에서 검증한 Gate1 마법 활 버전을 기준으로 준비했다. 이 문서는 계획이며 이식 완료 보고서가 아니다.

## 기존 구조

- `scenes/boss/Boss.tscn` / `scripts/boss/Boss.gd`: 공통 CharacterBody2D 보스, 루트 중심 좌표.
- `scripts/boss/PatternRunner.gd`와 `scripts/boss/steps/`: JSON 스텝 실행, phase speed_mult 시간 배율, interrupt 정리.
- `scripts/combat/Hitbox.gd` / `Hurtbox.gd`: 팀 구분, 박스 판정, 동일 타격 중복 방지.
- `data/bosses/golem.json`: 골렘 외형/패턴/페이즈/피해/드롭. `DataSchema`와 `DataRegistry`가 fail-closed 검증.
- `DebugPanel.gd` / `Tuning.gd`: 화면 버튼·Tab/Esc/패드 기반 조절·저장. F키 전용 조작을 추가하지 않는다.

## 예정 추가

- `assets/bosses/golem/parts/`: 원본 PNG 7개만 복사.
- `scenes/boss/golem/GolemRig.tscn`: 원본 리그의 리소스 경로만 본 프로젝트 경로로 조정. 내부 계층·애니메이션 트랙 보존.
- 리그 표시/애니메이션 연결 스크립트와 기존 패턴 시스템에 맞는 데이터 기반 내려찍기 스텝.
- 타이밍/좌우 판정/착지 이벤트/중단/튜닝 회귀 검사 및 실제 화면 증거.

## 예정 수정

- 공통 Boss에는 선택적인 시각 리그 연결점을 추가한다. 골렘 외 보스 동작은 유지한다.
- 골렘 JSON, 검증 스키마와 튜닝 UI에 windup/active_start/active_end/punish_end, hitbox 위치·크기, 리그 배율을 추가한다.
- 보스 중심 좌표와 발바닥 원점 간 오프셋을 어댑터에서 처리한다. 방향은 리그 루트의 scale.x만 반전한다.
- 착지 이벤트는 active_start와 동일한 데이터 시간에서 발생시킨다. 약점 허트박스 옵션은 기본 비활성으로 둔다.
- 테스트 실행기, README, WORK_LOG, Claude 검수용 보고서를 갱신한다.

## 현재 필요한 파일

이식 지시서만 제공되었고 GolemCutoutLab의 실제 폴더/ZIP은 아직 확인하지 못했다. 원본 scenes/golem.tscn 및 assets/parts/*.png가 도착하기 전에는 리그의 실제 트랙·좌표·키 값을 추측해서 구현하지 않는다. GolemCutoutLab 자체는 수정하지 않는다.

## 업로드

이식과 검증이 끝나면 소스·실행 안내·테스트·확인/미확인 구분 보고서를 tt에 업로드한다. 엔진, .godot, 개인 저장, 임시 시험 디렉터리는 제외한다. 아직 원격 업로드하지 않았다.
