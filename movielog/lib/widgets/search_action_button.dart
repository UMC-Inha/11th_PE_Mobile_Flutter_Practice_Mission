import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// AppBar 오른쪽의 검색 아이콘입니다. 누르면 영화 검색 화면(/movies/search)으로 이동합니다.
class SearchActionButton extends StatelessWidget {
  const SearchActionButton({super.key, this.color});

  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: IconButton(
        tooltip: '검색',
        icon: Icon(Icons.search, color: color),
        onPressed: () => context.push('/movies/search'),
      ),
    );
  }
}
