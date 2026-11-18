import 'package:flutter/material.dart';
import 'package:movielog/core/theme/app_theme.dart';
import 'package:movielog/data/models/movielog_dtos.dart';
import 'package:movielog/features/rating/presentation/widgets/movie_rating_input.dart';
import 'package:movielog/view_models/submit_status.dart';
import 'package:movielog/widgets/movielog_button.dart';

const saveRatingButtonKey = Key('saveRatingButton');
const cancelRatingButtonKey = Key('cancelRatingButton');
const resetRatingButtonKey = Key('resetRatingButton');
const ratingCommentFieldKey = Key('ratingCommentField');
const ratingDialogErrorKey = Key('ratingDialogError');
const ratingDialogPopScopeKey = Key('ratingDialogPopScope');

/// 코멘트 최대 길이. 서버 검증(500자)과 같다.
const ratingCommentMaxLength = 500;

/// 평점 Dialog를 띄운다. 평점 등록(영화 상세)과 수정(내가 등록한 평점)이 같은 Dialog를 쓴다.
///
/// 저장 로직은 [onSubmit] 콜백으로 받아 Dialog 안에서 실행한다. 그래야 저장 중 상태(로딩 버튼,
/// 입력 잠금, 이탈 방지)와 실패 시 입력 유지를 Dialog가 직접 관리할 수 있다.
/// - onSubmit이 예외 없이 끝나면 true, 취소하면 onSubmit을 부르지 않고 false를 돌려준다.
/// - null은 아직 아무 동작도 하지 않은 상태(저장 중에는 닫히지 않는다)를 뜻한다.
/// - `barrierDismissible: false`로 저장 중 바깥 탭으로 닫히는 것도 막는다.
///   Dialog 안의 PopScope는 시스템 뒤로가기만 막으므로 둘을 함께 쓴다.
Future<bool?> showMovieRatingDialog(
  BuildContext context, {
  required String movieTitle,
  required Future<void> Function(int score, String? comment) onSubmit,
  String title = '평점 남기기',
  int initialScore = 0,
  String? initialComment,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => MovieRatingDialog(
      title: title,
      movieTitle: movieTitle,
      initialScore: initialScore,
      initialComment: initialComment,
      onSubmit: onSubmit,
    ),
  );
}

class MovieRatingDialog extends StatefulWidget {
  const MovieRatingDialog({
    super.key,
    required this.movieTitle,
    required this.onSubmit,
    this.title = '평점 남기기',
    this.initialScore = 0,
    this.initialComment,
  });

  final String title;
  final String movieTitle;

  /// 수정 Dialog는 기존 평점·코멘트를 넣어 열자마자 이전 입력을 보여준다.
  /// comment가 null이면 코멘트 칸은 빈 채로 시작한다.
  final int initialScore;
  final String? initialComment;

  /// 저장한다. 실패하면 [RatingSaveException]을 던져 Dialog 안에 그 사유를 보여준다.
  final Future<void> Function(int score, String? comment) onSubmit;

  @override
  State<MovieRatingDialog> createState() => _MovieRatingDialogState();
}

class _MovieRatingDialogState extends State<MovieRatingDialog> {
  late int _score = widget.initialScore;

  // build() 안에서 만들면 별점을 고를 때마다 컨트롤러가 새로 생겨 입력하던 코멘트가 사라진다.
  // State가 살아 있는 동안 한 번만 만들고 dispose에서 정리한다.
  late final TextEditingController _commentController = TextEditingController(
    text: widget.initialComment ?? '',
  );

  bool _isSubmitting = false;
  String? _errorText;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _onConfirm() async {
    if (_isSubmitting) return;
    final comment = _commentController.text.trim();
    if (comment.length > ratingCommentMaxLength) {
      setState(() => _errorText = '코멘트는 $ratingCommentMaxLength자 이하로 입력해 주세요.');
      return;
    }
    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });
    try {
      await widget.onSubmit(_score, comment.isEmpty ? null : comment);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      // 실패해도 입력(별점·코멘트)은 그대로 두고, 버튼이 로딩에 멈추지 않게 되돌린다.
      setState(() {
        _isSubmitting = false;
        _errorText = error is RatingSaveException
            ? error.message
            : '저장하지 못했습니다. 잠시 후 다시 시도해 주세요.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      key: ratingDialogPopScopeKey,
      canPop: !_isSubmitting,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.title,
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.movieTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.mutedText),
              ),
              const SizedBox(height: 20),
              // 서버 score는 1~5 정수라 반 별 없이 고른다.
              MovieRatingInput(
                rating: _score.toDouble(),
                allowHalfRating: false,
                enabled: !_isSubmitting,
                onChanged: (value) =>
                    setState(() => _score = validateServerScore(value)),
              ),
              const SizedBox(height: 10),
              Text(
                _score == 0 ? '별을 눌러 평점을 선택하세요' : '$_score점',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              TextButton.icon(
                key: resetRatingButtonKey,
                onPressed: _score == 0 || _isSubmitting
                    ? null
                    : () => setState(() => _score = 0),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('초기화하고 다시 선택'),
              ),
              const SizedBox(height: 4),
              TextField(
                key: ratingCommentFieldKey,
                controller: _commentController,
                enabled: !_isSubmitting,
                maxLines: 3,
                maxLength: ratingCommentMaxLength,
                decoration: const InputDecoration(hintText: '코멘트를 남겨보세요 (선택)'),
              ),
              if (_errorText != null) ...[
                const SizedBox(height: 4),
                Text(
                  _errorText!,
                  key: ratingDialogErrorKey,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.error),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      key: cancelRatingButtonKey,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(44),
                      ),
                      onPressed: _isSubmitting
                          ? null
                          : () => Navigator.of(context).pop(false),
                      child: const Text('취소'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: MovieLogButton(
                      key: saveRatingButtonKey,
                      label: '저장',
                      width: double.infinity,
                      isLoading: _isSubmitting,
                      // 평점을 고르기 전에는 코멘트를 입력했더라도 저장할 수 없다.
                      onPressed: _score > 0 && !_isSubmitting
                          ? _onConfirm
                          : null,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
