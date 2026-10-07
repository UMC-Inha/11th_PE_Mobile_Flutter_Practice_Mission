import 'package:flutter/material.dart';

/// 표시할 영화가 없을 때 빈 Grid 대신 보여주는 Empty 상태입니다.
class MovieListEmpty extends StatelessWidget {
  const MovieListEmpty({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('조건에 맞는 영화가 없습니다.'),
    );
  }
}
