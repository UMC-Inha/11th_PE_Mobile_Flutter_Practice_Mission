import 'package:flutter/material.dart';
import 'package:movielog/core/theme/app_theme.dart';
import 'package:movielog/data/models/tmdb_genre_dto.dart';

const applyFilterButtonKey = Key('applyFilterButton');

/// 3주차 장르 필터 BottomSheet를 TMDB 장르 ID 다중 선택용으로 재사용한다.
/// 확인을 누르면 선택한 장르 ID 목록(빈 목록 = 전체)을, 그냥 닫으면 null을 돌려준다.
Future<List<int>?> showGenreFilterSheet(
  BuildContext context, {
  required List<TmdbGenreDto> genres,
  required List<int> initialSelection,
}) {
  return showModalBottomSheet<List<int>>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) =>
        GenreFilterSheet(genres: genres, initialSelection: initialSelection),
  );
}

class GenreFilterSheet extends StatefulWidget {
  const GenreFilterSheet({
    super.key,
    required this.genres,
    required this.initialSelection,
  });

  final List<TmdbGenreDto> genres;
  final List<int> initialSelection;

  @override
  State<GenreFilterSheet> createState() => _GenreFilterSheetState();
}

class _GenreFilterSheetState extends State<GenreFilterSheet> {
  // 체크하는 동안에는 이 임시 상태만 바뀐다. 목록에는 확인을 눌러야 반영된다.
  late final List<int> _draft = List.of(widget.initialSelection);

  void _toggle(int id, bool checked) {
    setState(() {
      checked ? _draft.add(id) : _draft.remove(id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.35,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 12, 4),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      '장르 필터',
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 20,
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
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(
                '여러 장르를 선택할 수 있어요 (하나라도 해당하면 표시)',
                style: TextStyle(color: AppColors.mutedText),
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: widget.genres.length,
                itemBuilder: (context, index) {
                  final genre = widget.genres[index];
                  return CheckboxListTile(
                    key: Key('genreCheckbox-${genre.id}'),
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(genre.name),
                    value: _draft.contains(genre.id),
                    onChanged: (checked) => _toggle(genre.id, checked == true),
                  );
                },
              ),
            ),
            const Divider(height: 1),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                child: FilledButton(
                  key: applyFilterButtonKey,
                  onPressed: () => Navigator.of(context).pop(List.of(_draft)),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                  child: Text(
                    _draft.isEmpty ? '확인 (전체 보기)' : '확인 (${_draft.length}개 장르)',
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
