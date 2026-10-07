import 'package:flutter/material.dart';

class MovieListLoading extends StatelessWidget {
  const MovieListLoading({super.key});
  @override
  Widget build(BuildContext context) => Semantics(
    label: '영화 목록을 불러오는 중',
    child: Column(
      children: [
        const Padding(padding: EdgeInsets.all(16), child: Text('영화를 불러오고 있어요')),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 20,
              crossAxisSpacing: 16,
              childAspectRatio: 0.58,
            ),
            itemCount: 4,
            itemBuilder: (context, index) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8ECF2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 14,
                  width: 110,
                  color: const Color(0xFFE8ECF2),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 12,
                  width: 70,
                  color: const Color(0xFFE8ECF2),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class MovieListEmpty extends StatelessWidget {
  const MovieListEmpty({super.key, required this.onReset});
  final VoidCallback onReset;
  @override
  Widget build(BuildContext context) => ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    children: [
      const SizedBox(height: 90),
      const Icon(Icons.movie_outlined, size: 52),
      const SizedBox(height: 16),
      const Center(child: Text('조건에 맞는 영화가 없습니다.')),
      const SizedBox(height: 8),
      const Center(child: Text('다른 장르를 선택하거나 전체 목록을 확인해 보세요.')),
      Center(
        child: TextButton(onPressed: onReset, child: const Text('전체 영화 보기')),
      ),
    ],
  );
}

class MovieListError extends StatelessWidget {
  const MovieListError({
    super.key,
    required this.onRetry,
    this.timedOut = false,
  });
  final VoidCallback onRetry;
  final bool timedOut;
  @override
  Widget build(BuildContext context) => ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    children: [
      const SizedBox(height: 90),
      const Icon(Icons.cloud_off_outlined, size: 52),
      const SizedBox(height: 16),
      Center(child: Text(timedOut ? '응답이 늦어지고 있어요.' : '영화를 불러오지 못했습니다.')),
      const SizedBox(height: 8),
      const Center(child: Text('잠시 후 다시 시도해 주세요.')),
      const SizedBox(height: 16),
      Center(
        child: FilledButton(onPressed: onRetry, child: const Text('다시 시도')),
      ),
    ],
  );
}
