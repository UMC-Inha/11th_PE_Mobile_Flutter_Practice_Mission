# MovieLog — 9주차 즐겨찾기 연동·검색·페이지네이션 (8주차 JWT 로그인 위에)

4주차 Mock Future를 실제 TMDB API로 바꾸고, 화면 코드와 데이터 코드를 MVVM으로 나눴다.
5주차 자체 백엔드(NestJS `movie` 프로젝트)의 닉네임·이메일 중복 체크와 유저별 평점 조회도 화면에 연결했다.
6주차에는 공용 `MovieLogButton`을 만들어 회원가입 중복 확인 버튼을 입력창 옆에 붙이고,
마이페이지에 "내가 등록한 평점" 자식 화면(`/my/ratings`)을 추가했다.
7주차에는 쓰기 API를 연결했다. 회원가입을 실제로 서버에 보내고, 영화 상세에서 평점(별점 + 코멘트)을 등록하고,
마이페이지에서 평점을 수정·삭제한다(Challenge: 회원가입 중 이탈 방지, 편집 모드의 다중 선택 삭제).

8주차에는 서버의 JWT 인증(7주차 NestJS 백엔드)에 맞춰 **로그인·세션 복원·로그아웃**을 붙이고, 평점 쓰기를
`memberId` 경로에서 **토큰 기반**(`POST /ratings`, `PATCH·DELETE /ratings/{id}`)으로 바꿨다.
Challenge: 이메일 저장, 마이페이지 내 정보 로딩·재시도, 가입일 표시(`2026.10.10 가입`), 프로필(닉네임) 수정과 이탈 확인.

9주차에는 영화 상세의 **즐겨찾기 버튼**, 마이페이지의 **내 즐겨찾기**(MovieLog 즐겨찾기 + TMDB 영화 정보를 `movieId`로 결합),
영화 목록의 **더 보기(page 단위)**, **영화 검색**을 붙였다. 늦게 도착한 응답(장르·검색어·계정·세션이 바뀐 뒤)은 버리고,
로그아웃·계정 전환 뒤에는 이전 계정의 즐겨찾기가 화면에 남지 않게 했다.
Challenge: 검색 debounce(500ms), 영화 목록 무한 스크롤, 평점 Dialog의 평점·즐겨찾기 통합 저장(`POST /movie-records`).

> 서버 계약은 **7주차에 만든 NestJS**(경로에 `/v7` 없음)다. 로그인·내 정보 응답에는 `memberId`가 없고 토큰으로
> 내 평점 목록을 읽는 API도 없다. 그래서 "내가 등록한 평점"은 **이번 로그인에서 등록한 평점만** 보여 주며(화면에도 안내),
> 앱을 다시 켜면 비어 있다. JWT claim을 추정해 memberId를 만들거나 6주차 공개 조회로 우회하지 않았다.

```bash
cp .env.example .env   # TMDB_ACCESS_TOKEN 에 TMDB "API 읽기 액세스 토큰"(긴 값). .env 는 Git 제외
flutter pub get
flutter run -d chrome --web-port 5173   # 자체 백엔드 CORS 허용 출처와 같은 포트
flutter analyze
flutter test                            # 네트워크를 쓰지 않는다 (실서버 테스트 3개는 건너뜀)
MOVIELOG_LIVE=1 flutter test test/live   # 실제 TMDB·백엔드로 인증 화면·로그 생성(evidence/week05)
```

## 9주차 변경

| 위치 | 하는 일 |
| --- | --- |
| `data/services/favorite_api_service.dart` · `data/models/favorite_*.dart` | `POST·GET /favorites`, `GET·DELETE /favorites/{movieId}`. 해제는 200 + `result: null`. 보호용 Client만 쓴다 |
| `core/network/auth_interceptor.dart` | 보호 경로에 `/favorites`·`/favorites/…`·`/movie-records` 추가(서버에 `/v7`·`/v8` 접두사는 없다). TMDB·외부 URL에는 Bearer를 붙이지 않는다 |
| `core/session/session_guard.dart` · `auth_session_bridge.dart` | 도착한 응답이 **현재 로그인 세션**의 것인지 판정(같은 이메일로 다시 로그인해도 새 세션). 인증 상태의 기준은 8주차 `AuthViewModel`이다 |
| `core/utils/map_bounded.dart` · `safe_notify.dart` · `view_models/load_phase.dart` | 동시에 5개만 처리하는 map · dispose 뒤 알림 방지 mixin · 화면 상태 enum |
| `view_models/favorite_detail_view_model.dart` | 상세 북마크. 서버가 확인한 뒤에만 바뀐다(optimistic 금지). 409·404는 `GET /favorites/{movieId}`로 맞추고 timeout에서 POST를 자동 재시도하지 않는다 |
| `view_models/favorites_view_model.dart` | 목록 → TMDB 정보 보충(최대 5개 동시). 한 건 실패는 그 카드만 placeholder + 그 카드만 재조회 |
| `view_models/paged_movies_view_model.dart` | 영화 목록·검색이 각자 인스턴스로 쓰는 page 모델: 첫 page 교체·다음 page append, 성공 때만 `nextPage`+1, `movieId` 중복 제거, 요청 generation, page 상한 500 |
| `widgets/member_session_gate.dart` | 사용자별 화면을 열기 전에 내 정보·세션 일치 확인(로딩·오류·다시 시도). 사용자별 ViewModel은 `ValueKey('email:generation')` |
| `features/movies/…/movie_search_screen.dart` · `movie_list_screen.dart` · `widgets/movie_page_footer.dart` | 검색(idle·결과·결과 없음·오류, 입력 500ms debounce + 제출) · 첫 page + 무한 스크롤(`extentAfter ≤ 300`) · footer(더 보기·로딩·오류 재시도·끝) |
| `features/my_page/…/favorites_screen.dart` · `my_page_screen.dart` | 마이페이지의 "내 즐겨찾기" 행 → `/my/favorites`(하단 NavigationBar 없음) |
| `data/services/movie_record_api_service.dart` · `features/rating/…/movie_rating_dialog.dart` | Challenge C: 아직 즐겨찾기하지 않은 영화의 평점 Dialog에 "즐겨찾기에도 추가" → `POST /movie-records` |

**5주차 동작이 바뀐 곳**: 영화 목록은 "Discover 여러 번 호출 · 최대 30개 모으기"에서 page당 20편 이어 붙이기로 바뀌었고, 5주차의 `RetryDialog`·`retryNoticeCount`는 없앴다(첫 page 실패는 전체 화면 오류 + 다시 시도). 홈의 인기 영화 5개는 그대로다.

### 9주차 검증 범위 (정직하게)

- `flutter analyze` 0건, `flutter test` **592개 통과**(실서버·실제 TMDB용 3개는 건너뜀, 모두 가짜 서비스 기반). 일부러 코드를 망가뜨려 테스트가 잡는지 **26가지(29회)** 확인했고, 처음에 못 잡은 3개(상세 Route `ValueKey`, `sessionVersion` 무시, `forVersion` 무시)는 테스트를 더해 잡았다.
- 실제 NestJS(일회용 DB)와 로컬 프록시·**가짜 TMDB 서버**에 연결한 Flutter Web(Chrome 390x844)에서 즐겨찾기 등록·해제, 내 즐겨찾기(한 건 실패·재조회·빈 목록), 더 보기(실패·재시도·마지막 page), 장르·검색어 변경 때의 늦은 응답, 계정 전환, 401·403, 시간 초과, Challenge A·B·C를 확인했다. 실패·지연·마지막 page는 가짜 서버·프록시로 **일부러 만든 것**이다.
- 연결 끊기를 주입한 요청은 브라우저가 한 번 더 보내 성공했다(앱의 자동 재시도가 아니다). 그래서 연결 끊김과 `POST /movie-records`의 시간 초과는 실제 화면이 아니라 **테스트로만** 확인했다.
- 이 맥에는 Xcode·Android SDK·TMDB 토큰이 없다. iOS/Android·Keychain/Keystore는 확인하지 못했고 영상도 없다(정지 화면과 요청 기록만).

## 8주차 변경

인증 상태는 `AuthViewModel`의 `AuthStatus { initializing, signedOut, authenticating, signedIn, retryRequired }` 하나가 갖고,
Router(`authRedirect`)가 **상태만 보고** 이동을 정한다. 화면은 로그인·로그아웃 때 직접 `go`하지 않는다.

| 위치 | 하는 일 |
| --- | --- |
| `core/storage/token_storage.dart` | `TokenStorage`(읽기·쓰기·삭제) + `SecureTokenStorage`(`flutter_secure_storage`, 키 한 곳). 토큰은 SharedPreferences에 두지 않는다 |
| `core/storage/email_preference.dart` | "이메일 저장" Challenge: **이메일만** SharedPreferences에. 비밀번호·토큰은 저장하지 않는다 |
| `core/network/auth_interceptor.dart` | **보호 경로**(`/members/me`, `/ratings`, `/ratings/{id}`)에만 `Authorization: Bearer`를 붙인다. host·port·경로를 함께 보고, 저장소를 못 읽으면 401처럼 보이지 않는 오류로 중단 |
| `core/network/movielog_api_client.dart` | 공개 Client(로그인·가입·중복 확인, 토큰 없음) / 보호 Client(Interceptor). TMDB Client와 합치지 않는다 — 서로의 토큰을 모른다 |
| `core/network/log_redaction.dart` | 로그에서 `accessToken`·`password`·`token`·`authorization` 값과 JWT 모양 문자열을 가림 |
| `core/network/api_error.dart` | 오류 `code` 해석. **`AUTH401_2/3/4`만 세션 만료**, 로그인 입력 오류 `AUTH401_1`은 아님 |
| `data/services/auth_api_service.dart` · `member_api_service.dart` · `rating_api_service.dart` | `POST /auth/login` / `GET·PATCH /members/me` / 평점 등록(201)·수정·삭제(200 + `result: null`) |
| `view_models/auth_view_model.dart` | `login` · `restoreSession` · `loadMember` · `logout` · `expireSession`. `sessionVersion`으로 로그아웃·계정 전환 뒤 **늦게 온 응답과 지난 세션의 401**을 버린다. `statusListenable`은 상태가 바뀔 때만 Router를 새로 고친다 |
| `view_models/session_ratings.dart` | 이번 로그인에서 등록한 평점을 메모리에 보관(세션이 바뀌면 비움) |
| `view_models/edit_profile_view_model.dart` | 닉네임 수정: 길이(2~12자)는 먼저 검사, 같은 닉네임은 요청 없이 완료, 409는 입력칸 오류(입력 유지), 통신 실패는 Snackbar(로그아웃 안 함), 401은 세션 정리 |
| `features/start/.../splash_screen.dart` | 토큰 확인 중 인디케이터, 확인 실패(`retryRequired`)면 안내 + 다시 시도(토큰은 지우지 않음) |
| `features/auth/.../login_screen.dart` | 로그인 Form, 오류 종류별 문구, 만료로 왔을 때만 Snackbar 한 번, 이메일 저장 |
| `features/my_page/.../my_page_screen.dart` · `edit_profile_screen.dart` | 내 정보 로딩·오류·재시도, 가입일, 로그아웃 / 프로필 수정(저장 중·변경 있음 이탈 방지) |
| `app/app_router.dart` | `/login`·`/my/profile/edit` 추가, `authRedirect`, 로그인 전에 요청한 위치를 한 번 기억했다가 로그인 뒤 그곳으로(`pendingLocation`) |

### 인증 흐름과 판단 기준

- **앱 시작**: 시작 화면 → 저장된 토큰이 없으면 `/login`. 있으면 `GET /members/me`로 **서버가 인정한 뒤에만** signedIn(토큰 문자열이 있다는 이유만으로 홈을 열지 않는다).
- **통신 실패·서버 5xx·저장소 읽기 실패**는 로그아웃이 아니다 → `retryRequired`, 토큰 유지, "다시 시도".
- **403**(내 평점이 아님)은 안내만 하고 로그아웃하지 않는다. **401 중 `AUTH401_2/3/4`**만 토큰을 지우고 `/login`에서 만료를 한 번 안내한다.
- 요청을 **보낼 때의 `sessionVersion`**을 기억해 두었다가 응답이 늦게 도착하면 비교한다. 로그아웃 뒤의 성공 응답이 토큰을 다시 저장하거나, 지난 세션의 401이 새 로그인을 지우지 못한다.
- 로그아웃은 기기의 토큰과 메모리 상태만 지운다(서버에서 토큰이 즉시 폐기된다고 보장하지 않는다).
- 로그·화면에 토큰·비밀번호 원문이 남지 않는다(테스트로 확인).

### 8주차 검증 범위 (정직하게)

- `flutter analyze` 0건, `flutter test` 374개 통과(실서버 3개는 건너뜀). 위 가드마다 일부러 코드를 망가뜨려 테스트가 실패하는지 확인했다(14가지, 모두 실패).
- 이 맥에는 Xcode·Android SDK가 없어 **Chrome(Flutter Web)에서만** 실행해 볼 수 있다. `flutter_secure_storage`는 웹에서 Keychain·Keystore가 아니라 브라우저 저장소(WebCrypto)를 쓰므로,
  **기기의 보안 저장소 동작은 검증하지 못했다.** 테스트는 `FlutterSecureStorage.setMockInitialValues`와 메모리 저장소 대역으로 읽기·쓰기·삭제·실패 경로를 확인한다.
- 서버에 내 평점 조회 API와 `memberId`가 없어서 "내가 등록한 평점"은 세션 한정이다. 이는 프론트가 아니라 서버 계약의 한계다.

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
- 영화(9주차): Genre API로 Chip, Discover **첫 page만** 표시하고 스크롤이 끝에 가까워지면 다음 page를 이어 붙인다(`movieId` 중복 제거, 성공 때만 `nextPage`+1, 마지막 page는 끝 문구). 검색은 별도 모델로 "더 보기" 버튼.
- 장르 선택 → `with_genres`로 page 1부터 재요청. "전체"는 `with_genres` 없음. 요청 중엔 Chip·필터 비활성.
- BottomSheet 다중 선택 → `List<int>` → `with_genres=28|12`(OR).
- Pull to Refresh: 기존 목록을 둔 채 page 1부터, Loading 중엔 제스처 무시.
- 실패(9주차): 첫 page 실패는 전체 화면 오류 + 다시 시도, 다음 page 실패는 기존 목록을 두고 footer에서 같은 page를 다시 시도(5주차의 재시도 Dialog는 없앴다).
- 늦게 온 응답은 request version으로 버린다. dispose 뒤 notify 없음.
- 상세 Route `/movies/{TMDB id}`. 평점 Dialog(1~5 정수) → `CreateRatingRequest(movieId: TMDB id)`.
- 회원가입: 닉네임(2~12자)·이메일 `중복 확인` → `GET /members/nickname|email/...`. 확인한 값 그대로여야 가입 버튼이 켜진다. 6주차: 버튼은 입력창 오른쪽, 중복이면 입력창이 에러 상태가 되고 버튼이 즉시 비활성, 입력을 바꾸면 해제, 방금 지운 중복 값을 다시 입력하면 요청 없이 즉시 에러.
- 마이페이지(8주차): 닉네임·이메일·가입일 + 프로필 수정·로그아웃. "내가 등록한 평점" 행 → `/my/ratings`는 **이번 로그인에서 등록한 평점**을 보여 주고 movieId로 TMDB 제목·포스터를 찾는다. 평점이 없으면 Empty, TMDB 실패는 그 영화만 `영화 #id` placeholder. (6·7주차의 `GET /members/{memberId}/ratings`·학습용 memberId는 더 쓰지 않는다.)
- 쓰기: 회원가입 `POST /members`(최종 409는 Snackbar, 서버가 거부한 비밀번호는 입력칸 에러, **성공해도 로그인되지 않고** 로그인 화면으로 가 이메일만 채운다) → 영화 상세의 평점 Dialog(별점 + 코멘트) `POST /ratings`(8주차: 토큰, memberId 없음) → 마이페이지에서 수정 `PATCH /ratings/{id}`·삭제 `DELETE`(확인 Dialog 후, 성공은 200 + `result: null`). 응답으로 받은 평점 객체로 목록을 바꾼다(다시 조회할 API가 없다).
- 장르·정렬 저장 키는 `selected_genre_ids`(TMDB ID)·`movie_sort`. 4주차 이름 값은 읽지 않는다.

## 검증 자료 (`evidence/week09`)

- `01~44_*.jpg`: 실제 Chrome(Flutter Web 390x844)의 MovieLog 웹이 **9주차 NestJS**(`brownglasses/week09`, 일회용 MySQL DB)와 로컬 프록시·가짜 TMDB 서버를 호출한 화면(화면을 찍을 때의 로컬 커밋은 `3a51c9b`이고, 여기에 테스트 4개 파일·증거 파일을 더해 다시 만든(amend) 것이 최종 커밋 `a8af17a`다. 두 커밋의 `lib/`·`pubspec`은 같다. `3a51c9b`는 push되지 않는다). 상세 즐겨찾기 등록·해제, 내 즐겨찾기(한 건 실패·재조회·빈 목록·계정 전환), 더 보기(실패·재시도·끝), 장르 늦은 응답, 검색(결과 없음·오류·재시도), 401·403·시간 초과, Challenge A(debounce)·B(무한 스크롤)·C(통합 저장)
- `logs/proxy-requests.ndjson` · `logs/tmdb-requests.ndjson` · `logs/proxy-summary.txt`: 요청 기록. **토큰·비밀번호·본문은 기록하지 않는다.** 실패·지연·503·403은 프록시·가짜 TMDB가 주입한 것이다
- `logs/check-auth-log.txt`: 보호 경로 41건 모두 Authorization 있음, 공개 경로 6건 모두 없음, TMDB 47건은 TMDB 전용 값만 → 위반 없음
- `logs/storage-check.txt` · `logs/console-log-check.txt`: 웹 저장소(토큰은 JWT 모양이 아닌 암호문)와 콘솔 로그(`Bearer ***`). **웹이라 Keychain/Keystore가 아니다**
- `flutter-analyze.txt`, `flutter-test.txt`: 분석·테스트 결과(592개 통과, 3개 건너뜀)
- 영상은 없다. 한글 글꼴(Pretendard)·viewport meta·TMDB·서버 주소는 임시 복사본에만 넣었고 저장소 코드에는 없다

## 검증 자료 (`evidence/week08`)

- `01~34_*.jpg`: 실제 Chrome(Flutter Web 390x844)의 MovieLog 웹이 **8주차 NestJS**(`brownglasses/week08`, 일회용 MySQL DB)를 호출한 화면. 첫 실행→로그인(실패 두 종류)→마이페이지, 새로고침 복원·통신 실패 재시도·무효/만료 토큰 안내, 토큰 기반 평점 등록·수정·삭제·409·403, 프로필 수정(같은 닉네임·409·검증·나가기 확인·통신 실패), 로그아웃·회원 전환, 이메일 저장, 마이페이지 로딩·재시도
- `21_*.jpg`는 실서버에서 찾은 문제(통신 실패 Snackbar가 [저장] 버튼을 가림)의 **수정 전** 화면이다. 수정 뒤는 위젯 테스트로만 확인했고 화면은 다시 찍지 못했다
- `network-auth-header.txt`: 프록시가 남긴 요청 기록. **Authorization 값은 기록하지 않고 있었는지(none / jwt-like / tmdb-dummy)만** 적었다. 보호 경로에만 JWT가 실렸고 위반은 0건이다. 통신 실패·지연·503·403(ratingId 바꿔치기)은 프록시가 주입한 것이다
- `storage-check.txt`: 웹에서 실제로 무엇이 저장됐는지(토큰은 평문 JWT가 아닌 암호문, 비밀번호는 저장 없음). **웹 구현이라 Keychain/Keystore가 아니다**
- `console-log-check.txt`: 콘솔·서버 출력에서 `eyJ`·비밀번호가 0건(콘솔은 마지막 432건만 검사)
- `flutter-analyze.txt`, `flutter-test.txt`: 분석·테스트 결과(374개 통과, 실서버·실제 TMDB가 필요한 3개는 건너뜀)
- 이 맥에는 Xcode·Android SDK·TMDB Token이 없다. iOS/Android 확인은 하지 못했고 TMDB는 가짜 서버(포스터만 실제 이미지)로 대신했다. 한글 글꼴(Pretendard)·viewport meta·TMDB 주소는 임시 복사본에만 넣었고 저장소 코드에는 없다

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
