# MovieLog — 7주차 회원가입과 평점 쓰기 (6주차 중복 확인·평점 조회 위에)

4주차 Mock Future를 실제 TMDB API로 바꾸고, 화면 코드와 데이터 코드를 MVVM으로 나눴다.
5주차 자체 백엔드(NestJS `movie` 프로젝트)의 닉네임·이메일 중복 체크와 유저별 평점 조회도 화면에 연결했다.
6주차에는 공용 `MovieLogButton`을 만들어 회원가입 중복 확인 버튼을 입력창 옆에 붙이고,
마이페이지에 "내가 등록한 평점" 자식 화면(`/my/ratings`)을 추가했다.
7주차에는 쓰기 API를 연결했다. 회원가입을 실제로 서버에 보내고, 영화 상세에서 평점(별점 + 코멘트)을 등록하고,
마이페이지에서 평점을 수정·삭제한다(Challenge: 회원가입 중 이탈 방지, 편집 모드의 다중 선택 삭제).

> 이 주차의 서버 계약은 **6주차 백엔드**(경로에 `memberId`, 삭제 204)다. 7주차 백엔드는 JWT로 바뀌어
> `memberId` 경로가 사라지므로, 프론트의 토큰 전환은 다음 주차 몫이다(워크북도 같은 순서로 예고한다).

```bash
cp .env.example .env   # TMDB_ACCESS_TOKEN 에 TMDB "API 읽기 액세스 토큰"(긴 값). .env 는 Git 제외
flutter pub get
flutter run -d chrome --web-port 5173   # 자체 백엔드 CORS 허용 출처와 같은 포트
flutter analyze
flutter test                            # 네트워크를 쓰지 않는다 (실서버 테스트 3개는 건너뜀)
MOVIELOG_LIVE=1 flutter test test/live   # 실제 TMDB·백엔드로 인증 화면·로그 생성(evidence/week05)
```

## 7주차 변경

| 위치 | 하는 일 |
| --- | --- |
| `data/models/common_response.dart` | 공통 응답 틀 `CommonResponse<T>`(`isSuccess`·`code`·`message`·`result`) |
| `data/models/create_member_request.dart` · `sign_up_models.dart` | 가입 요청(toJson, 비밀번호는 trim·로그 제외) / 가입 결과 `SignUpResult` |
| `data/models/movielog_dtos.dart` | `CreateRatingRequest`(빈 코멘트 생략) · `UpdateRatingRequest`(코멘트 항상 명시) · `validateServerScore` |
| `data/services/movielog_api_service.dart` | `signUp`(201 틀) · `createRating`(201만 성공) · `updateRating` · `deleteRating`(204, 본문 파싱 안 함), `parseErrorResponse` · `shouldRefreshAfterRatingError`(403·404) |
| `view_models/write_error_message.dart` | 실패 문구: 서버 `message`를 그대로, 응답이 없으면 통신 실패 원인 |
| `view_models/learning_member_session.dart` | 가입 결과의 `memberId`를 메모리에 보관(인증이 아님). 영화 상세·마이페이지가 읽는다 |
| `view_models/sign_up_view_model.dart` | `submit`: `SubmitStatus`, 400(비밀번호) → `passwordErrorText`, 그 밖의 400·409 → Snackbar, 409면 사용 가능 확인을 풀어 다시 확인하게 함 |
| `view_models/movie_detail_view_model.dart` | `createRating`: 요청 `movieId`는 TMDB id, 가입 전에는 요청 없이 안내 |
| `view_models/my_ratings_view_model.dart` | `updateRating`·`deleteRating`: 저장 성공과 재조회 실패 분리(`refreshWarning`), 편집 모드·다중 선택 삭제(`toList()` 복사본 순회, 일부 실패 시 선택 유지) |
| `features/rating/.../movie_rating_dialog.dart` | 등록·수정 공용 Dialog: 코멘트 500자, 별점 선택 후에만 저장, 저장 중 로딩·입력 잠금·`PopScope`+`barrierDismissible: false`, 실패 시 입력 유지 |
| `features/my_page/.../my_ratings_screen.dart` | 카드별 수정·삭제 버튼, "편집" → 체크박스 + "선택한 N개 삭제", 삭제 중 `LoadingOverlay` + `PopScope` |
| `features/sign_up/.../sign_up_screen.dart` | 제출 중 로딩 버튼 + `PopScope`로 이탈 방지, 성공 시 세션에 memberId 보관 후 `/movies` |
| `widgets/loading_overlay.dart` | 어두운 `ModalBarrier` + 가운데 흰 인디케이터(Stack 오버레이) |

## 6주차 변경

| 위치 | 하는 일 |
|---|---|
| `widgets/movielog_button.dart` | 공용 버튼. 기본·통신 중·비활성 세 상태와 `width`(null / `double.infinity` / 고정) |
| `view_models/sign_up_view_model.dart` | `CheckStatus {idle, checking, available, duplicated, error}`를 닉네임·이메일에 따로 가진다. 입력이 바뀌면 이전 결과 무효화, 중복이었던 값은 기억해 같은 값을 다시 입력하면 서버에 묻지 않고 즉시 에러로 복원 |
| `features/sign_up/presentation/widgets/duplicate_check_field.dart` | 입력창 + 바깥 오른쪽(8px) `MovieLogButton`. 결과 문구는 `TextFormField.errorText`, 체크 표시는 입력창 안쪽 |
| `data/models/rating_with_movie.dart` | 자체 백엔드 평점 + TMDB 영화 한 쌍. TMDB에서 못 찾으면 `movie`가 null |
| `data/services/tmdb_movie_service.dart` | `findMovieById`: TMDB 404는 null, 그 밖의 오류는 던진다 |
| `view_models/my_ratings_view_model.dart` | memberId는 학습용 상수 `sampleMemberId = 1`. Loading/Empty/Error/Success, 영화 캐시(404는 캐시, 일시 실패는 재시도), 400·404·통신 실패 문구 분리 |
| `features/my_page/presentation/my_ratings_screen.dart` | "내가 등록한 평점" 화면. 하단 NavigationBar 없이 BackButton |
| `app/app_router.dart` | `/my/ratings`를 `parentNavigatorKey: rootNavigatorKey`로 root Navigator 위에 열어 NavigationBar를 가린다 |

## 구조

| 위치 | 하는 일 |
|---|---|
| `core/config/tmdb_config.dart` | `.env` 값 읽기와 누락 검사를 한곳에 |
| `core/network/tmdb_client.dart` | TMDB 전용 Dio(Bearer Token). debug에서만 로그 Interceptor |
| `core/network/movielog_api_client.dart` | 자체 백엔드 전용 Dio. TMDB Token을 싣지 않는다 |
| `core/network/tmdb_logging_interceptor.dart` | 요청·응답·오류 로그, `Authorization`은 `Bearer ***` |
| `data/models/` | `TmdbMovieDto`·`TmdbMoviePageDto`·`TmdbGenreDto`, 자체 API DTO·`CreateRatingRequest` |
| `data/services/` | HTTP + JSON→DTO 변환만. 상태 없음(여러 ViewModel이 공유) |
| `view_models/` | 화면마다 하나. 인기 5개·최대 30개·선택 장르 같은 화면 정책과 Loading/Empty/Error/Success |
| `features/*/presentation` | View. 상태를 그리고 입력을 ViewModel에 넘길 뿐 API·JSON을 모른다 |
| `widgets/tmdb_poster_image.dart` | `poster_path` → URL, null·로드 실패 placeholder |

`MovieLogApp`의 `MultiProvider`가 `MaterialApp.router` 바깥에서 Service를 공유하고,
각 GoRoute의 `ChangeNotifierProvider`가 화면별 ViewModel을 만들고 dispose한다.

## 동작

- 홈: Popular 첫 페이지 `take(5)`. 요청은 ViewModel 생성 때 한 번.
- 영화: Genre API로 Chip, Discover page 1부터 TMDB `id`를 Map key로 중복 없이 최대 30개(한 페이지 개수를 코드에 박지 않음).
- 장르 선택 → `with_genres`로 page 1부터 재요청. "전체"는 `with_genres` 없음. 요청 중엔 Chip·필터 비활성.
- BottomSheet 다중 선택 → `List<int>` → `with_genres=28|12`(OR).
- Pull to Refresh: 기존 목록을 둔 채 page 1부터, Loading 중엔 제스처 무시.
- 실패: 최근 목록이 있으면 비우지 않고 재시도 Dialog(취소/다시 시도), 없으면 Error 화면.
- 늦게 온 응답은 request version으로 버린다. dispose 뒤 notify 없음.
- 상세 Route `/movies/{TMDB id}`. 평점 Dialog(1~5 정수) → `CreateRatingRequest(movieId: TMDB id)`.
- 회원가입: 닉네임(2~12자)·이메일 `중복 확인` → `GET /members/nickname|email/...`. 확인한 값 그대로여야 가입 버튼이 켜진다. 6주차: 버튼은 입력창 오른쪽, 중복이면 입력창이 에러 상태가 되고 버튼이 즉시 비활성, 입력을 바꾸면 해제, 방금 지운 중복 값을 다시 입력하면 요청 없이 즉시 에러.
- 마이페이지: "내가 등록한 평점" 행 → `/my/ratings`(`GET /members/{memberId}/ratings`) + movieId로 TMDB 제목·포스터. 평점이 없으면 Empty, 실패하면 Error(원인별 문구), TMDB 실패는 그 영화만 placeholder. 7주차부터 `memberId`는 시드 1번이 아니라 **방금 가입한 회원**의 것이고, 가입 전에는 "학습용 회원가입이 필요합니다"만 보인다.
- 7주차 쓰기: 회원가입 `POST /members`(최종 409는 Snackbar, 서버가 거부한 비밀번호는 입력칸 에러) → 영화 상세의 평점 Dialog(별점 + 코멘트) `POST /members/{id}/ratings` → 마이페이지에서 수정 `PATCH`·삭제 `DELETE`(확인 Dialog 후). 쓰기가 성공하면 목록을 다시 조회하고, 저장은 됐는데 조회만 실패하면 "조회만 다시 시도"를 안내한다.
- 장르·정렬 저장 키는 `selected_genre_ids`(TMDB ID)·`movie_sort`. 4주차 이름 값은 읽지 않는다.

## 검증 자료 (`evidence/week05`)

- `web-signup-duplicate-check.jpg`, `web-my-ratings.jpg`: 실제 Chrome의 MovieLog 웹(5173)이 실제 NestJS 서버(3000)를 CORS 허용 상태로 호출한 화면
- `network-failure-log.txt`: 실제 TMDB에 잘못된 Token → 401, URL·오류는 남고 Token 원문은 없음, release 조건에선 0줄
- `12_empty_fixture.png`, `13_poster_placeholder_fixture.png`: 가짜 응답으로 만든 Empty·포스터 없음/로드 실패
- `01~11_*.png`, `network-log.txt`: `test/live/live_evidence_test.dart`가 실제 TMDB 응답으로 만든 화면(Token 필요)

## 검증 자료 (`evidence/week07`)

- `01a~12_*.jpg`: 실제 Chrome(Flutter Web 390x844)의 MovieLog 웹이 **6주차 시점의 NestJS**(`brownglasses/week06` 커밋, 일회용 MySQL DB)를 호출한 화면. 회원가입(사용 가능·입력 변경 무효화·서버 비밀번호 400·최종 409)부터 평점 등록·수정·삭제, 저장 성공 후 재조회 실패, 편집 모드의 다중 삭제까지
- `11e_*.jpg`·`09a_*.jpg`: 실서버 검증에서 찾아 고친 버그 2건의 **수정 전** 화면(다중 삭제 중 하단 바가 눌림 / 조회 실패인데 평균 점수만 낡은 값). 수정 후는 `11h_*.jpg`·`09c_*.jpg`
- `network-write-flow.txt`: 위 흐름에서 프록시가 남긴 요청 기록(비밀번호는 `***`). 지연·조회 실패·삭제 실패는 프록시가 주입한 것이고 터미널 curl 요청은 표시해 두었다
- `flutter-analyze.txt`, `flutter-test.txt`: 분석·테스트 결과(193개 통과, 실제 TMDB가 필요한 3개는 건너뜀)
- 이 맥에는 TMDB Token이 없어 TMDB 응답은 로컬 가짜 서버가 대신했다(영화 id·제목·포스터 경로는 실제 값). 한글 글꼴·TMDB 주소는 임시 복사본에만 넣어 빌드했고 저장소 코드에는 없다
- 7주차 백엔드(JWT)와는 연결하지 않았다. 프론트의 토큰 전환은 다음 주차다

## 검증 자료 (`evidence/week06`)

- `01~06_*.jpg`: 실제 NestJS(3000)에 연결한 Flutter Web(Chrome 390x844)의 중복 확인 화면. 사용 가능 · 중복 · 입력 수정 시 해제 · 지운 중복 값 재입력 시 즉시 에러 · 이메일 · 서버 꺼짐
- `07_bug_before_error_truncated.jpg`: 통신 실패 문구가 "다시 …"로 잘리던 수정 전 화면 (`errorMaxLines: 3`으로 수정, `06`이 수정 후)
- `08~09_*.jpg`: 마이페이지 진입 행과 "내가 등록한 평점"(실제 DB 평점 2개). 이 환경에는 TMDB Token이 없어 영화 제목·포스터는 placeholder
- `network-duplicate-check.txt`: 위 시나리오에서 실제로 나간 요청 기록
- `flutter-analyze.txt`, `flutter-test.txt`: 분석·테스트 결과
- 스크린샷은 한글 글꼴을 받지 못하는 환경이라 임시 복사본에 Pretendard를 붙여 빌드한 것으로 찍었다(저장소 코드에는 글꼴 변경 없음)
