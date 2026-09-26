import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

enum AppImageKind { network, asset, file, memory }

class AppImage extends StatelessWidget {
  const AppImage._({
    super.key,
    required this.kind,
    this.source,
    this.bytes,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.placeholder,
    this.errorWidget,
    this.borderRadius,
    this.isSvg,
  });

  const AppImage.network(
    String url, {
    Key? key,
    BoxFit fit = BoxFit.cover,
    double? width,
    double? height,
    Widget? placeholder,
    Widget? errorWidget,
    BorderRadius? borderRadius,
    bool? isSvg,
  }) : this._(
         key: key,
         kind: AppImageKind.network,
         source: url,
         fit: fit,
         width: width,
         height: height,
         placeholder: placeholder,
         errorWidget: errorWidget,
         borderRadius: borderRadius,
         isSvg: isSvg,
       );

  const AppImage.asset(
    String path, {
    Key? key,
    BoxFit fit = BoxFit.cover,
    double? width,
    double? height,
    Widget? placeholder,
    Widget? errorWidget,
    BorderRadius? borderRadius,
    bool? isSvg,
  }) : this._(
         key: key,
         kind: AppImageKind.asset,
         source: path,
         fit: fit,
         width: width,
         height: height,
         placeholder: placeholder,
         errorWidget: errorWidget,
         borderRadius: borderRadius,
         isSvg: isSvg,
       );

  const AppImage.file(
    String path, {
    Key? key,
    BoxFit fit = BoxFit.cover,
    double? width,
    double? height,
    Widget? placeholder,
    Widget? errorWidget,
    BorderRadius? borderRadius,
    bool? isSvg,
  }) : this._(
         key: key,
         kind: AppImageKind.file,
         source: path,
         fit: fit,
         width: width,
         height: height,
         placeholder: placeholder,
         errorWidget: errorWidget,
         borderRadius: borderRadius,
         isSvg: isSvg,
       );

  const AppImage.memory(
    Uint8List bytes, {
    Key? key,
    BoxFit fit = BoxFit.cover,
    double? width,
    double? height,
    Widget? placeholder,
    Widget? errorWidget,
    BorderRadius? borderRadius,
    bool? isSvg,
  }) : this._(
         key: key,
         kind: AppImageKind.memory,
         bytes: bytes,
         fit: fit,
         width: width,
         height: height,
         placeholder: placeholder,
         errorWidget: errorWidget,
         borderRadius: borderRadius,
         isSvg: isSvg,
       );

  final AppImageKind kind;
  final String? source;
  final Uint8List? bytes;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget? placeholder;
  final Widget? errorWidget;
  final BorderRadius? borderRadius;
  final bool? isSvg;

  /// True when [pathOrUrl] looks like SVG (case-insensitive `.svg`, ignoring query).
  static bool looksLikeSvg(String pathOrUrl) {
    final noQuery = pathOrUrl.split('?').first;
    return noQuery.toLowerCase().endsWith('.svg');
  }

  static bool _memoryLooksLikeSvg(Uint8List data) {
    const maxLen = 512;
    final len = data.length < maxLen ? data.length : maxLen;
    if (len == 0) {
      return false;
    }
    final text = utf8
        .decode(data.sublist(0, len), allowMalformed: true)
        .toLowerCase();
    return text.contains('<svg');
  }

  bool get _useSvg {
    if (isSvg != null) {
      return isSvg!;
    }
    return switch (kind) {
      AppImageKind.memory => _memoryLooksLikeSvg(bytes ?? Uint8List(0)),
      AppImageKind.network ||
      AppImageKind.asset ||
      AppImageKind.file => looksLikeSvg(source ?? ''),
    };
  }

  Widget _buildErrorOrShrink() => errorWidget ?? const SizedBox.shrink();

  Widget _wrap(Widget child) {
    if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius!, child: child);
    }
    return child;
  }

  @override
  Widget build(BuildContext context) {
    if (kind != AppImageKind.memory && (source ?? '').isEmpty) {
      return _buildErrorOrShrink();
    }

    final child = _useSvg ? _buildSvg() : _buildRaster();
    return _wrap(child);
  }

  Widget _buildSvg() {
    final placeholderBuilder = placeholder != null ? (_) => placeholder! : null;
    Widget errorBuilder(BuildContext context, Object error, StackTrace stack) =>
        _buildErrorOrShrink();

    return switch (kind) {
      AppImageKind.network => SvgPicture.network(
        source!,
        fit: fit,
        width: width,
        height: height,
        placeholderBuilder: placeholderBuilder,
        errorBuilder: errorBuilder,
      ),
      AppImageKind.asset => SvgPicture.asset(
        source!,
        fit: fit,
        width: width,
        height: height,
        placeholderBuilder: placeholderBuilder,
        errorBuilder: errorBuilder,
      ),
      AppImageKind.file => SvgPicture.file(
        File(source!),
        fit: fit,
        width: width,
        height: height,
        placeholderBuilder: placeholderBuilder,
        errorBuilder: errorBuilder,
      ),
      AppImageKind.memory => SvgPicture.memory(
        bytes!,
        fit: fit,
        width: width,
        height: height,
        placeholderBuilder: placeholderBuilder,
        errorBuilder: errorBuilder,
      ),
    };
  }

  Widget _buildRaster() {
    return switch (kind) {
      AppImageKind.network => CachedNetworkImage(
        imageUrl: source!,
        fit: fit,
        width: width,
        height: height,
        placeholder: placeholder != null ? (_, _) => placeholder! : null,
        errorWidget: (_, _, _) => _buildErrorOrShrink(),
      ),
      AppImageKind.asset => Image.asset(
        source!,
        fit: fit,
        width: width,
        height: height,
        errorBuilder: (_, _, _) => _buildErrorOrShrink(),
      ),
      AppImageKind.file => Image.file(
        File(source!),
        fit: fit,
        width: width,
        height: height,
        errorBuilder: (_, _, _) => _buildErrorOrShrink(),
      ),
      AppImageKind.memory => Image.memory(
        bytes!,
        fit: fit,
        width: width,
        height: height,
        errorBuilder: (_, _, _) => _buildErrorOrShrink(),
      ),
    };
  }
}
