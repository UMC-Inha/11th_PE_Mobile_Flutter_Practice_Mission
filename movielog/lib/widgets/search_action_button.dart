import 'package:flutter/material.dart';

/// AppBar 오른쪽의 검색 아이콘입니다. 검색 기능은 이후 주차에 연결합니다.
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
        onPressed: () {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              const SnackBar(
                content: Text('검색 기능은 준비 중이에요.'),
                behavior: SnackBarBehavior.floating,
              ),
            );
        },
      ),
    );
  }
}
