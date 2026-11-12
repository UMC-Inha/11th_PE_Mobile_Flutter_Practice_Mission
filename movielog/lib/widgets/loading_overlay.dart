import 'package:flutter/material.dart';

/// [child] 위에 어두운 ModalBarrier와 가운데 흰색 인디케이터만 올리는 로딩 오버레이.
///
/// Dialog가 아니라 화면 위에 올리는 Stack이라, 요청 중에도 아래 화면이 그대로 보이고
/// 터치만 막힌다. 로딩 문구나 흰 카드는 띄우지 않는다. 화면 이탈은 이 Widget이 아니라
/// 바깥의 PopScope가 막는다.
class LoadingOverlay extends StatelessWidget {
  const LoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
  });

  final bool isLoading;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading) ...const [
          ModalBarrier(dismissible: false, color: Colors.black45),
          Center(child: CircularProgressIndicator(color: Colors.white)),
        ],
      ],
    );
  }
}
