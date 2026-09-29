import 'package:flutter/material.dart';
import 'package:movielog/core/data/mock_movies.dart';
import 'package:movielog/core/theme/app_theme.dart';

const applyFilterButtonKey = Key('applyFilterButton');

/// 장르 필터 BottomSheet를 열고, 확인을 누르면 선택한 장르를 돌려준다.
/// 확인 없이 닫으면 null을 돌려준다.
Future<Set<String>?> showGenreFilterSheet(
  BuildContext context, {
  required Set<String> initialSelection,
}) {
  return showModalBottomSheet<Set<String>>(
    context: context,
    // DraggableScrollableSheet가 화면 높이까지 커질 수 있게 한다.
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => GenreFilterSheet(initialSelection: initialSelection),
  );
}

class GenreFilterSheet extends StatefulWidget {
  const GenreFilterSheet({super.key, required this.initialSelection});

  final Set<String> initialSelection;

  @override
  State<GenreFilterSheet> createState() => _GenreFilterSheetState();
}

class _GenreFilterSheetState extends State<GenreFilterSheet> {
  // 체크하는 동안에는 이 임시 상태만 바뀐다. 목록에는 확인을 눌러야 반영된다.
  late final Set<String> _draft = {...widget.initialSelection};

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.5,
      minChildSize: 0.35,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 12, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      '장르 선택',
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _draft.isEmpty
                        ? null
                        : () => setState(_draft.clear),
                    child: const Text('전체 해제'),
                  ),
                ],
              ),
            ),
            // 목록 영역만 스크롤된다.
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: movieGenres.length,
                itemBuilder: (context, index) {
                  final genre = movieGenres[index];
                  return CheckboxListTile(
                    key: Key('genreCheckbox-$genre'),
                    title: Text(genre),
                    value: _draft.contains(genre),
                    onChanged: (checked) => setState(() {
                      checked == true
                          ? _draft.add(genre)
                          : _draft.remove(genre);
                    }),
                  );
                },
              ),
            ),
            // 확인 버튼은 목록 밖에 있어 스크롤해도 항상 하단에 보인다.
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: ElevatedButton(
                  key: applyFilterButtonKey,
                  onPressed: () => Navigator.of(context).pop({..._draft}),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                  child: Text(
                    _draft.isEmpty ? '전체 보기' : '${_draft.length}개 장르 적용',
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
