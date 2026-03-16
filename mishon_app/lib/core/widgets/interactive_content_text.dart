import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class InteractiveContentText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final TextStyle? mentionStyle;
  final TextStyle? linkStyle;
  final int? maxLines;
  final TextOverflow overflow;
  final ValueChanged<String>? onMentionTap;
  final ValueChanged<String>? onUrlTap;

  const InteractiveContentText({
    super.key,
    required this.text,
    this.style,
    this.mentionStyle,
    this.linkStyle,
    this.maxLines,
    this.overflow = TextOverflow.clip,
    this.onMentionTap,
    this.onUrlTap,
  });

  @override
  State<InteractiveContentText> createState() => _InteractiveContentTextState();
}

class _InteractiveContentTextState extends State<InteractiveContentText> {
  static final RegExp _tokenPattern = RegExp(
    r'(?:https?:\/\/|www\.)[^\s]+|@[A-Za-z0-9._]{3,50}',
    multiLine: true,
  );
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _disposeRecognizers();

    return Text.rich(
      TextSpan(children: _buildSpans()),
      maxLines: widget.maxLines,
      overflow: widget.overflow,
    );
  }

  List<InlineSpan> _buildSpans() {
    final spans = <InlineSpan>[];
    final text = widget.text;
    var currentIndex = 0;

    for (final match in _tokenPattern.allMatches(text)) {
      final start = match.start;
      final end = match.end;
      if (start > currentIndex) {
        spans.add(
          TextSpan(
            text: text.substring(currentIndex, start),
            style: widget.style,
          ),
        );
      }

      final token = text.substring(start, end);
      if (_isValidMention(text, start, token)) {
        final username = token.substring(1);
        spans.add(
          TextSpan(
            text: token,
            style: widget.mentionStyle ?? _defaultLinkStyle(),
            recognizer: _addRecognizer(
              () => widget.onMentionTap?.call(username),
            ),
          ),
        );
      } else if (_isUrlToken(token)) {
        final normalized = _normalizeUrlToken(token);
        final display = token.substring(0, normalized.displayLength);
        spans.add(
          TextSpan(
            text: display,
            style: widget.linkStyle ?? _defaultLinkStyle(),
            recognizer: _addRecognizer(
              () => widget.onUrlTap?.call(normalized.url),
            ),
          ),
        );
        if (normalized.trailingText.isNotEmpty) {
          spans.add(
            TextSpan(text: normalized.trailingText, style: widget.style),
          );
        }
      } else {
        spans.add(TextSpan(text: token, style: widget.style));
      }

      currentIndex = end;
    }

    if (currentIndex < text.length) {
      spans.add(
        TextSpan(text: text.substring(currentIndex), style: widget.style),
      );
    }

    if (spans.isEmpty) {
      spans.add(TextSpan(text: text, style: widget.style));
    }

    return spans;
  }

  bool _isValidMention(String text, int start, String token) {
    if (!token.startsWith('@')) {
      return false;
    }

    if (start == 0) {
      return true;
    }

    final previousChar = text[start - 1];
    return !_isUsernameChar(previousChar);
  }

  bool _isUrlToken(String token) {
    return token.startsWith('http://') ||
        token.startsWith('https://') ||
        token.startsWith('www.');
  }

  bool _isUsernameChar(String char) {
    return RegExp(r'[A-Za-z0-9._]').hasMatch(char);
  }

  _NormalizedUrl _normalizeUrlToken(String token) {
    var displayLength = token.length;
    while (displayLength > 0 && '.,!?;:)'.contains(token[displayLength - 1])) {
      displayLength--;
    }

    final display = token.substring(0, displayLength);
    final trailingText = token.substring(displayLength);
    final url = display.startsWith('www.') ? 'https://$display' : display;
    return _NormalizedUrl(
      url: url,
      displayLength: display.length,
      trailingText: trailingText,
    );
  }

  TextStyle _defaultLinkStyle() {
    return (widget.style ?? const TextStyle()).copyWith(
      color: const Color(0xFF1D5FE9),
      fontWeight: FontWeight.w700,
      decoration: TextDecoration.underline,
      decorationColor: const Color(0xFF1D5FE9).withValues(alpha: 0.55),
    );
  }

  TapGestureRecognizer _addRecognizer(VoidCallback onTap) {
    final recognizer = TapGestureRecognizer()..onTap = onTap;
    _recognizers.add(recognizer);
    return recognizer;
  }

  void _disposeRecognizers() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }
}

class _NormalizedUrl {
  final String url;
  final int displayLength;
  final String trailingText;

  const _NormalizedUrl({
    required this.url,
    required this.displayLength,
    required this.trailingText,
  });
}
