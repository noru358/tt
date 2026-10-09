# Claude 검수·기획 인계

**가장 먼저 `HANDOFF.md`를 읽는다.** 현재 상태·다음 할 일·세션 인계 규칙이 거기 있고, 아래 내용보다 우선한다. 세션을 끝낼 때 HANDOFF.md와 docs/plan/DIRECTION.md를 갱신한다.

(이하 보스 러시 1차 관문 시기 안내) 먼저 docs/GOLEM_MOBILITY_WETLAND.md, AGENTS.md, docs/GOLEM_PORT_REPORT.md, docs/WORKSPACE.md, REVIEW_FOR_CLAUDE.md를 읽는다.
현재 사용자 승인 범위는 골렘 3패턴 이식과 GitHub 업로드다. 컷아웃 키트·점멸·새 골렘 모션은 다음 작업이다.
현재 구현의 확인/미확인 및 필요한 모션은 GOLEM_PORT_REPORT에 명시되어 있다. 이전 보고서와 충돌하면 최신 사용자 결정과 최신 보고서를 우선한다.
테스트는 tests/run_suites.py로 격리 실행한다. GolemCutoutSuite는 운영 골렘, 이름에 LEGACY_PRIMITIVE_FIXTURE를 출력하는 4개 suite는 옛 범용 패턴 회귀다.

최신 사용자 추가 요청으로 전신 피격·몸박·이동·배경 및 조작감 개선까지 구현했다. 이전 이동 금지/제자리 보스 설명은 해제됐다.
