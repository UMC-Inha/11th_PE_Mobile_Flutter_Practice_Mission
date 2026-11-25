enum LoadPhase {
  idle, // 아직 요청하지 않은 상태
  loading, // 첫 로딩 중(검색어·장르가 바뀐 새 조건의 첫 page 포함)
  ready, // 표시할 목록이 있는 상태
  empty, // 요청은 성공했지만 결과가 없는 상태
  error, // 첫 조회에 실패한 상태
}

// 다음 page를 불러오는 중에는 ready 목록을 지우지 않고
// ViewModel의 별도 값(isLoadingMore)으로 구분합니다.
