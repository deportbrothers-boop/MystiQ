import 'dart:io';
import 'package:flutter/material.dart';

/// A drop-in replacement for Image.asset that decodes the bitmap
/// near the widget's on-screen size at the current devicePixelRatio.
/// This reduces upscaling blur on high-DPI screens.
class SharpImage extends StatelessWidget {
  final String? assetName;
  final File? file;
  final BoxFit fit;
  final Alignment alignment;
  final double? width;
  final double? height;
  final Color? color;
  final BlendMode? colorBlendMode;
  final FilterQuality filterQuality;
  final ImageErrorWidgetBuilder? errorBuilder;

  const SharpImage.asset(
    this.assetName, {
    super.key,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.width,
    this.height,
    this.color,
    this.colorBlendMode,
    this.filterQuality = FilterQuality.high,
    this.errorBuilder,
  }) : file = null;

  const SharpImage.file(
    this.file, {
    super.key,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.width,
    this.height,
    this.color,
    this.colorBlendMode,
    this.filterQuality = FilterQuality.high,
    this.errorBuilder,
  }) : assetName = null;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final dpr = MediaQuery.of(context).devicePixelRatio;
        // Determine target decode size based on layout constraints and DPR
        final targetW = (width ?? constraints.maxWidth);
        final targetH = (height ?? constraints.maxHeight);

        int? cacheWidth;
        int? cacheHeight;

        if (targetW.isFinite && targetW > 0) {
          cacheWidth = (targetW * dpr).clamp(64, 4096).toInt();
        }
        if (targetH.isFinite && targetH > 0) {
          cacheHeight = (targetH * dpr).clamp(64, 4096).toInt();
        }

        final isAsset = assetName != null;
        return (isAsset
            ? Image.asset(assetName!,
                fit: fit,
                alignment: alignment,
                isAntiAlias: true,
                filterQuality: filterQuality,
                cacheWidth: cacheWidth,
                cacheHeight: cacheHeight,
                color: color,
                colorBlendMode: colorBlendMode,
                errorBuilder: errorBuilder,
              )
            : Image.file(
                file!,
                fit: fit,
                alignment: alignment,
                isAntiAlias: true,
                filterQuality: filterQuality,
                cacheWidth: cacheWidth,
                cacheHeight: cacheHeight,
                color: color,
                colorBlendMode: colorBlendMode,
                errorBuilder: errorBuilder,
              ));
      },
    );
  }
}

/// Tries to load a WebP variant first and falls back to the provided PNG/JPG asset on decode error,
/// while preserving SharpImage decode-sizing behavior.
class SharpAssetFallback extends StatefulWidget {
  final String pngAsset;
  final BoxFit fit;
  final Alignment alignment;
  final double? width;
  final double? height;
  final Color? color;
  final BlendMode? colorBlendMode;
  final FilterQuality filterQuality;
  final ImageErrorWidgetBuilder? errorBuilder;

  const SharpAssetFallback(
    this.pngAsset, {
    super.key,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.width,
    this.height,
    this.color,
    this.colorBlendMode,
    this.filterQuality = FilterQuality.high,
    this.errorBuilder,
  });

  @override
  State<SharpAssetFallback> createState() => _SharpAssetFallbackState();
}

class _SharpAssetFallbackState extends State<SharpAssetFallback> {
  bool _usePng = false;

  String get _webpCandidate {
    final a = widget.pngAsset;
    final dot = a.lastIndexOf('.');
    if (dot > 0) return '${a.substring(0, dot)}.webp';
    return '$a.webp';
  }

  @override
  Widget build(BuildContext context) {
    final path = _usePng ? widget.pngAsset : _webpCandidate;
    return LayoutBuilder(builder: (context, constraints) {
      final dpr = MediaQuery.of(context).devicePixelRatio;
      final targetW = (widget.width ?? constraints.maxWidth);
      final targetH = (widget.height ?? constraints.maxHeight);
      int? cacheWidth;
      int? cacheHeight;
      if (targetW.isFinite && targetW > 0) {
        cacheWidth = (targetW * dpr).clamp(64, 4096).toInt();
      }
      if (targetH.isFinite && targetH > 0) {
        cacheHeight = (targetH * dpr).clamp(64, 4096).toInt();
      }
      return Image.asset(
        path,
        fit: widget.fit,
        alignment: widget.alignment,
        isAntiAlias: true,
        filterQuality: widget.filterQuality,
        cacheWidth: cacheWidth,
        cacheHeight: cacheHeight,
        color: widget.color,
        colorBlendMode: widget.colorBlendMode,
        errorBuilder: (c, e, s) {
          if (!_usePng) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _usePng = true);
            });
            return const SizedBox.shrink();
          }
          // If PNG also failed, delegate to provided errorBuilder (if any)
          if (widget.errorBuilder != null) {
            return widget.errorBuilder!(c, e, s);
          }
          return const SizedBox.shrink();
        },
      );
    });
  }
}
