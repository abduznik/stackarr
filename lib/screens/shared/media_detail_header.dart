import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Shared metadata header — poster, title/subtitle, genre chips, rating,
/// overview — used by movie/series/artist detail screens. All three
/// services expose roughly the same shape of metadata (see Movie, Series,
/// Artist models), so one widget avoids three near-identical headers.
class MediaDetailHeader extends StatelessWidget {
  final String? posterUrl;
  final String title;
  final String? subtitle;
  final List<String> genres;
  final double? rating;
  final String? overview;

  const MediaDetailHeader({
    super.key,
    required this.posterUrl,
    required this.title,
    this.subtitle,
    this.genres = const [],
    this.rating,
    this.overview,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 120,
                  height: 180,
                  child: posterUrl != null
                      ? CachedNetworkImage(
                          imageUrl: posterUrl!,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) =>
                              const ColoredBox(color: Colors.black12),
                        )
                      : const ColoredBox(color: Colors.black12),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleLarge),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(subtitle!,
                          style: Theme.of(context).textTheme.bodyMedium),
                    ],
                    if (rating != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star, size: 16, color: Colors.amber),
                          const SizedBox(width: 4),
                          Text(rating!.toStringAsFixed(1)),
                        ],
                      ),
                    ],
                    if (genres.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final genre in genres.take(5))
                            Chip(
                              label: Text(genre,
                                  style: const TextStyle(fontSize: 11)),
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (overview != null && overview!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(overview!, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }
}
