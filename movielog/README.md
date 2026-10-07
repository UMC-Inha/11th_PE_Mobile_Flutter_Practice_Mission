# MovieLog — 4주차 비동기 처리와 로컬 저장

3주차 Movie 모델·카드·영화 Route를 재사용해 네 상태와 재시도, 장르·정렬 저장을 구현했다. 실제 API 대신 1초 지연 Mock Service를 사용한다.

```bash
flutter pub get
flutter run -d chrome --dart-define=INITIAL_LOCATION=/movies
flutter analyze
flutter test
flutter build web --debug --dart-define=INITIAL_LOCATION=/movies
```

- `initState`에서 최초 Future를 만들고, 재시도/당겨서 새로고침 때 새 Future를 할당한다.
- Loading은 카드 Skeleton, Empty는 전체 보기·새로고침, Error는 다시 시도 버튼을 제공한다.
- Debug 우측 메뉴에서 성공/빈 목록/오류/시간 초과를 재현한다. `?mode=empty`, `?mode=failure`, `?mode=timeout`도 가능하다.
- SharedPreferencesAsync 키: `selected_genre`(쉼표로 구분된 장르), `movie_sort`(`original`, `title`, `rating`). 저장값이 없거나 유효하지 않으면 전체·기본순이다.
- 명시적 `?genres=SF` 딥링크는 저장값보다 우선한다. Query 없는 새 실행에서 저장값을 복원한다.
- 2초 `Future.timeout`, `Future.wait` 병렬 초기화, 저장 큐와 `mounted` 검사 적용.
- TODO(5주차 유저별 평점 조회 API)는 `core/services/fake_movie_service.dart`에 있다.

## 검증 자료

`evidence/00_four_states.jpg`: 실제 Flutter Widget을 렌더링한 Loading·Success·Empty·Error.
`week04-retry.mp4`, `week04-restore.mp4`: 실제 Chrome 앱의 화면 캡처를 연결한 전환 영상. 긴 관찰 대기는 줄였고, 프레임에 합성한 상태는 없다. 복원 영상은 같은 브라우저에서 Query 없는 `/movies`를 새로 실행한다. OS 프로세스 종료를 촬영한 영상은 아니며 iOS/Android 실기기 재실행은 확인하지 않았다.
`08_browser_saved_genre.jpg`와 `09_browser_restored_genre.jpg`: 실제 SharedPreferencesAsync 웹 저장·복원 결과.

17개 테스트가 서비스 성공/빈 목록/실패, 네 상태, 800ms 이상 Loading, 재시도, 타임아웃, 저장 복원, 새로고침, dispose를 확인한다. `evidence_test.dart`는 테스트용 Memory Preferences로 별도의 상태 PNG를 만들며, 실제 브라우저 저장 검증과 구분한다.
