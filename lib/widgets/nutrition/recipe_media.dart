import 'package:flutter/material.dart';

import '../../core/theme.dart';

class RecipeMedia extends StatelessWidget {
  const RecipeMedia({
    super.key,
    required this.imageUrl,
    required this.width,
    required this.height,
    required this.borderRadius,
    required this.iconSize,
  });

  final String? imageUrl;
  final double width;
  final double height;
  final double borderRadius;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final primary = context.cfPrimary;
    final cleanUrl = imageUrl?.trim() ?? '';

    return Container(
      width: width,
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: context.cfPrimaryTint,
        borderRadius: BorderRadius.all(Radius.circular(borderRadius)),
        border: Border.all(color: context.cfPrimaryTintStrong),
      ),
      child: cleanUrl.isEmpty
          ? Center(
              child: Icon(
                Icons.restaurant_menu,
                color: primary,
                size: iconSize,
              ),
            )
          : Image.network(
              cleanUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Center(
                child: Icon(
                  Icons.broken_image_outlined,
                  color: primary,
                  size: iconSize,
                ),
              ),
            ),
    );
  }
}