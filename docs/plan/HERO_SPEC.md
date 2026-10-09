# 주인공 설계서 — 사막여우 전투형 문관 (철릭)

2026-10-09 사용자 결정: 주인공은 **new-game 저장소에서 잡아 둔 사막여우 전투형 문관(철릭)**. 작업 방식은 "Claude가 아이디어·구조 설계 → 이미지 제작"(2026-10-09부터 이미지는 Codex 내장 image_gen). 작업 순서와 Codex 지시는 `docs/plan/HERO_ART_PLAN.md`.

- 기준 그림: `docs/plan/hero_refs/side.png`, `front.png`, `back.png` (new-game `codex/fennec-idle-sample-v1` 브랜치 `game/fennec_idle/`, 각 384×448 투명 PNG, 발 기준점 약 (190, 416)). 당시 상태는 "시안 시험 승인"이고 최종 디자인 승인은 아님.
- 잘못 가져왔던 game2의 크림색 판타지 관복 시트는 기준이 아니다(2026-10-09 사용자 정정). 다만 **털색만** game2 여우의 크림색을 쓴다(같은 날 사용자 결정: 주황은 너무 쨍함). `hero_refs/`의 세 장은 털만 크림색으로 바꾼 것이고, 주황 원본은 new-game 브랜치에 그대로 있다.
- **디자인은 확정이 아니다.** 사용자와 같이 맞춰 간다. 바꿀 때마다 이 문서와 비교 페이지를 갱신한다.
- 비교 페이지(실제 화면 크기, 카메라·골렘 크기 바꿔 보기): https://claude.ai/artifact/5KBz3NkyGcp3mf3GaYupcd

## 1. 생김새 (기준 그림 그대로)

| 부위 | 내용 |
|---|---|
| 털 | 크림(약 #ecd9bd), 가슴·주둥이·귀 안쪽·꼬리 끝은 더 밝은 미색. 외곽선은 따뜻한 갈색 |
| 얼굴 | 갈색 눈(밝은 하이라이트), 짧은 목, 귀 제외 약 3등신 |
| 귀 | 아주 큼. 가장 높은 실루엣 |
| 옷 | 남색 철릭(앞섶 겹침), 크림색 깃, 녹슨 주홍 허리띠(매듭 끝이 늘어짐) |
| 무장 | 검은 가죽 견갑·토시(작게) |
| 아래 | 검은 바지, 흰 행전, 검은 가죽 신 |
| 꼬리 | 하나, 크고 풍성함. 뿌리는 허리띠 아래 등 중앙 |

## 2. 크기와 판정 (2026-10-09 적용, 같은 날 2차 수정)

예전 수치(카메라 세로 384, 판정 20×28, 골렘 0.42)로는 720p 화면에서 주인공이 작고 골렘과 차이가 컸다. 1차로 카메라를 1.3배 당겼더니 사용자가 "크기는 딱 좋은데 화면이 답답하다"고 했다. 그래서 **카메라는 예전 시야로 되돌리고, 그만큼 주인공과 골렘을 맵 안에서 키웠다**(사용자 선택). 화면 속 크기는 1차와 같고 시야는 예전과 같다.

| 항목 | 예전 | 지금 | 파일 |
|---|---|---|---|
| 카메라 보이는 범위 | 800×384 | 800×384 (그대로) | `movement_tuning.json` |
| 주인공 판정 | 20×28 | 30×46 (약 1.4칸 키) | `movement_tuning.json` |
| 골렘 배율 | 0.42 | 0.43 (키 약 215px) | `golem_bash_tuning.json` |
| 골렘 공격 시작 거리 | 260 | 265 | `golem_bash_tuning.json` |
| 주인공 공격 범위 | 44×36 | 66×56 (몸이 커진 만큼) | `golem_bash_tuning.json` |

- 판정은 **그림의 몸(정수리~발바닥)** 에 맞춘다. 귀와 꼬리는 맞지 않는 장식이다. 그림을 붙일 때 정수리를 판정 윗변에, 발바닥을 아랫변에 맞춘다(side.png 기준 정수리 y≈156, 발바닥 y=416, 몸 260px → 판정 46이면 배율 약 0.177).
- 점프 높이·대시 거리·벽 점프는 그대로(칸 기준 같은 거리). 주인공이 타일보다 커져서 방이 조금 좁게 느껴질 수 있다. 방 8개 모두 1칸짜리 세로 틈이 없고 경로 검사도 통과한다(방 6은 배시 경로에서 시험 봇 사망이 3→5회로 늘어 가장 빠듯함).
- 720p 화면 기준 주인공 약 128px(귀 포함), 골렘 약 400px, 점프 방 가로 시야 약 21칸.

## 3. 게임용 기능 (코드로 처리)

- **여우불 = 남은 공중 대시.** 머리 뒤를 따라다니는 작은 여우불 2개, 대시할 때마다 하나씩 꺼지고 착지하면 켜진다(new-game의 여우불 동행과 같은 뿌리). 지금 글자로만 보이는 정보를 그림으로 바꾼다.
- 귀·꼬리·철릭 자락·허리띠 매듭은 **코드가 흔든다**(속도 반대 방향으로 늘어짐). 그림은 정지 부품만 있으면 된다.
- 대시 무적 표시는 몸 외곽 빛, 피격 깜빡임은 지금 그대로.

## 4. 무기 — 철부채 (2026-10-09 사용자 선택)

문관이 들고 다니는 쇠 부채(철선). 칼 대신 부채라서 문관 설정과 맞고, 접고 펴는 두 모양으로 동작을 나눌 수 있다.

- **모양:** 검은 쇠 부챗살 10~12개, 사슬 없이 굵은 사북(고정 못)은 놋쇠색, 부채면은 짙은 남색 비단에 크림색 구름 문양 하나. 손잡이 끝에 허리띠와 같은 녹슨 주홍 술.
- **J 옆 휘두르기:** 접은 부채로 가로 베기. 휘두르는 끝에 반쯤 펴진 부채꼴 잔상.
- **위 휘두르기:** 머리 위로 활짝 펴며 반원을 그린다.
- **아래 내려찍기(포고):** 접은 부채 끝으로 내려찍는다. 튕길 때 잠깐 펴서 받친다.
- 판정은 지금 휘두르기 상자(52×44) 그대로. 그림이 판정을 따라가고, 판정이 그림을 따라가지 않는다.
- 다른 후보(환도, 맨손 마력)는 보류.

## 5. 제작 방식

new-game·game2 모두 GPT로 방향·프레임을 한 장씩 뽑을 때 꼬리 위치·다리·옷이 장마다 달라지는 문제가 반복됐다. 그래서 **프레임 애니메이션이 아니라 골렘과 같은 부품(컷아웃) 방식**으로 간다.

1. 옆모습 원화는 이미 있다(`side.png`). 이걸 기준으로 **부품 시트 1장**만 GPT로 받는다(프롬프트 B).
2. Claude가 부품을 잘라 Godot에 뼈대를 세우고 대기·달리기·점프·대시·벽 매달리기·휘두르기·피격·튕기기 자세를 코드로 만든다.
3. 그 전에 지금 `side.png` 한 장을 네모 자리에 임시로 붙여서(좌우 뒤집기만) 크기와 여우불을 플레이로 먼저 확인할 수 있다.

### 프롬프트 B — 부품 시트

첨부: `side.png`

```
Create a cutout animation parts sheet of exactly this fennec fox character: same face, pale cream fur (around #ecd9bd) with lighter off-white chest, muzzle and tail tip, huge ears, navy cheollik coat with cream collar, rust-orange sash, small black leather shoulder pads and bracers, black trousers, white leg wraps, black leather shoes. Same painterly style, outline, colors and scale as the attached image. Strict side view facing right.
Every part separated with wide empty space around it, on one flat solid bright green background (#00b140) with no gradient, no floor, no shadows, no text or numbers. Parts in the listed order, left to right, top to bottom. No discs, bolts or caps covering the joints.
Parts: 1 head without ears (eye open), 2 near ear, 3 far ear (slightly darker), 4 torso with coat top, collar and sash (no arms, no skirt flaps), 5 coat skirt hanging straight as one piece, 6 sash knot tails, 7 near upper arm with shoulder pad, 8 near forearm with bracer, 9 near paw (open), 10 far upper arm, 11 far forearm, 12 far paw, 13 near thigh, 14 near shin with leg wrap and shoe, 15 far thigh, 16 far shin with shoe, 17 tail as one piece pointing straight back, 18 closed Korean iron war fan (cheolseon) horizontal: black iron ribs, brass pivot rivet, small rust-orange tassel at the handle end, 19 the same iron fan fully opened as a half circle: dark navy silk face with one cream cloud motif, black iron ribs.
Limb parts need rounded joint ends so they can rotate at the joint. Keep one consistent pixel scale across all parts.
```

받은 그림은 `assets/hero/raw/`에 원본 그대로 넣는다. Claude가 자르고 등록한다.

## 6. 사람이 정할 것

- 크림색 털 톤이 괜찮은지 (더 노랗게, 더 하얗게)
- 철부채 모양(색, 문양, 술)
- 임시로 `side.png`를 먼저 게임에 붙일지(추천)
