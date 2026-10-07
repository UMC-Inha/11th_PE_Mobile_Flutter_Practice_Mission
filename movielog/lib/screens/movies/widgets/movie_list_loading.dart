import 'package:flutter/material.dart';

/// 영화 목록을 기다리는 동안 표시하는 Loading 상태입니다.
class MovieListLoading extends StatelessWidget {
  const MovieListLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }
}
