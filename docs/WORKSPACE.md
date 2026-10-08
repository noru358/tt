# 워크스페이스 시작

저장소: https://github.com/noru358/tt

## 로컬 실행

1. 저장소를 clone한다: `git clone https://github.com/noru358/tt.git`
2. Godot **4.6 stable 표준판**에서 루트 `project.godot`를 import하고 실행한다. C#/.NET판은 필요 없다.
3. 허브 → 연습 모드 → 골렘 연습. 실제 게임에서는 보상·진행 저장이 적용된다.
4. Tab/Esc 또는 화면 조작감 버튼 → 골렘 탭에서 수치 조정. F키는 사용하지 않는다.

Windows Run.cmd는 `GODOT_BIN` 환경변수 또는 PATH의 godot.exe를 사용한다. macOS는 앱 내부 `Godot.app/Contents/MacOS/Godot`, Linux는 godot 실행파일을 CLI에 지정한다. 엔진 바이너리와 개인 저장파일은 저장소에 포함하지 않는다.

## 자동 검사

Python 3와 Godot 4.6만 필요하며 pip 설치는 없다.

```sh
python3 tests/run_suites.py --godot /absolute/path/to/godot --output /tmp/gate1-tests-fresh
```

매번 fresh 출력 경로를 사용한다. runner가 외부 테스트 저장/튜닝/재정렬 경로를 분리한다. `.godot/`는 엔진이 다시 생성한다. 오류 fixture의 의도된 데이터 오류 로그와 `SCRIPT ERROR`/`FAIL:`는 구분한다.

GitHub Actions는 Ubuntu에서 같은 headless 검사를 실행하고 로그를 artifact로 남긴다. GitHub/Claude 원격 워크스페이스에서는 코드 검수와 headless 테스트를 수행하고, 실제 화면·입력 검수는 로컬 Godot에서 한다. 자동으로 외부 Claude 계정이나 프로젝트를 생성하지는 않는다.

## 기획 ↔ 구현 인계

Claude 검수 시작점은 루트 `CLAUDE.md`와 `REVIEW_FOR_CLAUDE.md`. 최신 변경은 `docs/GOLEM_MOBILITY_WETLAND.md`, 최초 이식·부족한 모션은 `docs/GOLEM_PORT_REPORT.md`, 전투 입력은 `docs/INDEPENDENT_REVIEW_FIX_REPORT.md`, 활은 `docs/MAGIC_BOW.md`다. 다음 지시를 이슈/문서로 남기면 변경 근거와 검증 결과를 `docs/WORK_LOG.md`에 누적한다. 과거 문서를 새 지시로 간주하지 않는다.
