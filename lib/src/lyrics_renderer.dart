import 'package:flutter/material.dart';
import 'chord_transposer.dart';
import 'model/chord_lyrics_line.dart';
import 'chord_parser.dart';

class LyricsRenderer extends StatefulWidget {
  final String lyrics;
  final TextStyle textStyle;
  final TextStyle chordStyle;
  final bool showChord;
  final bool showText;
  final bool minorScale;
  final bool underlineChordSyllables;
  final Function onTapChord;

  // Call handler when lyrics is processed (reive a ChordLyricsDocument)
  final Function? onLyricsProcessed;

  /// To help stop overflow, this should be the sum of left & right padding
  final int widgetPadding;

  /// Transpose Increment for the Chords,
  /// default value is 0, which means no transpose is applied
  final int transposeIncrement;

  /// Auto Scroll Speed,
  /// default value is 0, which means no auto scroll is applied
  final int scrollSpeed;

  /// Extra height between each line
  final double lineHeight;

  /// Widget before the lyrics starts
  final Widget? leadingWidget;

  /// Widget after the lyrics finishes
  final Widget? trailingWidget;

  /// Horizontal alignment
  final CrossAxisAlignment horizontalAlignment;

  /// Scale factor of chords and lyrics
  final double scaleFactor;

  /// Notation that will be handled by the transposer
  final ChordNotation chordNotation;

  /// Define physics of scrolling
  final ScrollPhysics scrollPhysics;

  /// If not defined it will be the bold version of [textStyle]
  final TextStyle? chorusStyle;

  /// If not defined it will be the italic version of [textStyle]
  final TextStyle? capoStyle;

  /// If not defined it will be the italic version of [textStyle]
  final TextStyle? commentStyle;

  /// replace current chord names
  final List<String>? chordPresentation;

  /// fixed space between chords when show only chords
  final double fixedChordSpace;

  final double? parentWidth;

  const LyricsRenderer(
      {super.key,
      required this.lyrics,
      required this.textStyle,
      required this.chordStyle,
      required this.onTapChord,
      this.onLyricsProcessed,
      this.chorusStyle,
      this.commentStyle,
      this.capoStyle,
      this.scaleFactor = 1.0,
      this.showChord = true,
      this.showText = true,
      this.minorScale = false,
      this.underlineChordSyllables = true,
      this.widgetPadding = 0,
      this.transposeIncrement = 0,
      this.scrollSpeed = 0,
      this.lineHeight = 8.0,
      this.horizontalAlignment = CrossAxisAlignment.center,
      this.scrollPhysics = const ClampingScrollPhysics(),
      this.leadingWidget,
      this.trailingWidget,
      this.chordNotation = ChordNotation.american,
      this.chordPresentation,
      this.fixedChordSpace = 20.0,
      this.parentWidth});

  @override
  State<LyricsRenderer> createState() => _LyricsRendererState();
}

class _LyricsRendererState extends State<LyricsRenderer> {
  late final ScrollController _controller;
  late TextStyle chorusStyle;
  late TextStyle capoStyle;
  late TextStyle commentStyle;
  bool _isChorus = false;
  bool _isComment = false;

  @override
  void initState() {
    super.initState();
    chorusStyle = widget.chorusStyle ??
        widget.textStyle.copyWith(fontWeight: FontWeight.bold);
    capoStyle = widget.capoStyle ??
        widget.textStyle.copyWith(fontStyle: FontStyle.italic);
    commentStyle = widget.commentStyle ??
        widget.textStyle.copyWith(
          fontStyle: FontStyle.italic,
          fontSize: widget.textStyle.fontSize! - 2,
        );
    _controller = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // executes after build
      _scrollToEnd();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  TextStyle getLineTextStyle() {
    if (_isChorus) {
      return chorusStyle;
    } else if (_isComment) {
      return commentStyle;
    } else {
      return widget.textStyle;
    }
  }

  String replaceChord(String chord) {
    String currentChord = chord;
    switch (widget.chordNotation) {
      case ChordNotation.american:
        int i = 0;
        for (var c in americanNotes) {
          if (chord.contains(c)) {
            currentChord =
                chord.replaceAll(RegExp(c), widget.chordPresentation![i]);
            break;
          }
          i += 1;
        }
        break;
      default:
        int i = 0;
        for (var c in italianNotes) {
          if (chord.contains(c)) {
            currentChord =
                chord.replaceAll(RegExp(c), widget.chordPresentation![i]);
            break;
          }
          i += 1;
        }
        break;
    }

    return currentChord;
  }

  String transposeToMinor(String chord) {
    String currentChord = chord;

    // transpose chords into minor natural scale based on 5th circle
    if (widget.minorScale && !chord.contains('m')) {
      for (var c in minorScale.entries) {
        if (chord.contains(c.key)) {
          currentChord = chord.replaceAll(RegExp(c.key), c.value);
        }
      }
    }

    return currentChord;
  }

  Widget getFinalText(MapEntry<int, Chord> chord) {
    if (widget.minorScale) {
      return RichText(
        text: TextSpan(
            text: transposeToMinor(chord.value.chordText),
            style: widget.chordStyle),
        textScaler: TextScaler.linear(widget.scaleFactor),
      );
    }
    return RichText(
      text: TextSpan(
        text: widget.chordPresentation != null
            ? replaceChord(chord.value.chordText)
            : chord.value.chordText,
        style: widget.chordStyle,
      ),
      textScaler: TextScaler.linear(widget.scaleFactor),
    );
  }

  @override
  Widget build(BuildContext context) {
    ChordProcessor chordProcessor =
        ChordProcessor(context, widget.chordNotation, widget.parentWidth);
    final chordLyricsDocument = chordProcessor.processText(
      text: widget.lyrics,
      lyricsStyle: widget.textStyle,
      chordStyle: widget.chordStyle,
      chorusStyle: chorusStyle,
      widgetPadding: widget.widgetPadding,
      scaleFactor: widget.scaleFactor,
      transposeIncrement: widget.transposeIncrement,
    );

    if (widget.onLyricsProcessed != null) {
      widget.onLyricsProcessed!(chordLyricsDocument);
    }

    if (chordLyricsDocument.chordLyricsLines.isEmpty) return Container();
    return SingleChildScrollView(
      controller: _controller,
      physics: widget.scrollPhysics,
      child: Column(
        crossAxisAlignment: widget.horizontalAlignment,
        children: [
          if (widget.leadingWidget != null) widget.leadingWidget!,
          if (chordLyricsDocument.capo != null)
            Text('Capo: ${chordLyricsDocument.capo!}', style: capoStyle),
          ListView.separated(
            shrinkWrap: true,
            scrollDirection: Axis.vertical,
            physics: const NeverScrollableScrollPhysics(),
            separatorBuilder: (context, index) => SizedBox(
              height: widget.lineHeight,
            ),
            itemBuilder: (context, index) {
              final ChordLyricsLine line =
                  chordLyricsDocument.chordLyricsLines[index];

              if (line.isStartOfChorus()) {
                _isChorus = true;
              }
              if (line.isEndOfChorus()) {
                _isChorus = false;
              }
              if (line.isComment()) {
                _isComment = true;
              } else {
                _isComment = false;
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.showChord)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: line.chords
                            .asMap()
                            .entries
                            .map((chord) => Row(
                                  children: [
                                    SizedBox(
                                      width: !widget.showText
                                          ? (chord.key == 0
                                              ? 0
                                              : widget.fixedChordSpace)
                                          : chord.value.leadingSpace,
                                    ),
                                    GestureDetector(
                                      onTap: () => widget
                                          .onTapChord(chord.value.chordText),
                                      child: getFinalText(chord),
                                    )
                                  ],
                                ))
                            .toList(),
                      ),
                    ),
                  if (widget.showText)
                    _formatLineWithUnderlines(line)
                ],
              );
            },
            itemCount: chordLyricsDocument.chordLyricsLines.length,
          ),
          if (widget.trailingWidget != null) widget.trailingWidget!,
        ],
      ),
    );
  }

  @override
  void didUpdateWidget(covariant LyricsRenderer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollSpeed != widget.scrollSpeed) {
      _scrollToEnd();
    }
  }
  
  Widget _formatLineWithUnderlines(ChordLyricsLine line) {
    List<TextSpan> textParts = [];
    TextStyle underDecorator = getLineTextStyle().merge(const TextStyle(decoration: TextDecoration.underline));
    
    int lastIndex = 0;

    for (var element in line.underlines) {
      try {
        textParts.add(TextSpan(text: line.lyrics.substring(lastIndex, element.first), style: getLineTextStyle()));
        textParts.add(TextSpan(text: line.lyrics.substring(element.first, element.last), style: underDecorator));
      } catch (e) {
        continue;
      }
      lastIndex = element.last;
    }
    textParts.add(TextSpan(text: line.lyrics.substring(lastIndex, line.lyrics.length), style: getLineTextStyle()));

    return RichText(
      text: TextSpan(
          text: '',
          children: textParts
        ),
        textScaler: TextScaler.linear(widget.scaleFactor),
    );
  }

  void _scrollToEnd() {
    if (widget.scrollSpeed <= 0) {
      // stop scrolling if the speed is 0 or less
      _controller.jumpTo(_controller.offset);
      return;
    }

    if (_controller.offset >= _controller.position.maxScrollExtent) return;

    final seconds =
        (_controller.position.maxScrollExtent / (widget.scrollSpeed)).floor();

    _controller.animateTo(
      _controller.position.maxScrollExtent,
      duration: Duration(
        seconds: seconds,
      ),
      curve: Curves.linear,
    );
  }
}

class TextRender extends CustomPainter {
  final String text;
  final TextStyle style;
  TextRender(this.text, this.style);

  @override
  void paint(Canvas canvas, Size size) {
    final textSpan = TextSpan(
      text: text,
      style: style,
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout(
      minWidth: 0,
      maxWidth: size.width,
    );
    textPainter.paint(canvas, Offset.zero);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
