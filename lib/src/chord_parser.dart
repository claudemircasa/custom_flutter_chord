import 'dart:math';

import 'package:flutter/material.dart';
import 'model/chord_lyrics_document.dart';
import 'model/chord_lyrics_line.dart';
import 'chord_transposer.dart';

class ChordProcessor {
  final BuildContext context;
  final ChordNotation chordNotation;
  final ChordTransposer chordTransposer;
  final double media;
  late double _textScaleFactor;
  final double? parentWidth;

  ChordProcessor(this.context,
      [this.chordNotation = ChordNotation.american, this.parentWidth])
      : chordTransposer = ChordTransposer(chordNotation),
        media = parentWidth ?? MediaQuery.of(context).size.width;

  /// Process the text to get the parsed ChordLyricsDocument
  ChordLyricsDocument processText({
    required String text,
    required TextStyle lyricsStyle,
    required TextStyle chordStyle,
    required TextStyle chorusStyle,
    double scaleFactor = 1.0,
    int widgetPadding = 0,
    int transposeIncrement = 0,
  }) {
    final List<String> lines = text.split('\n');
    final MetadataHandler metadata = MetadataHandler();
    _textScaleFactor = scaleFactor;
    chordTransposer.transpose = transposeIncrement;

    /// List to store our updated lines without overflows
    final List<String> newLines = <String>[];
    String currentLine = '';

    ///loop through the lines
    for (int i = 0; i < lines.length; i++) {
      currentLine = lines[i];

      ///If it finds some metadata skip to the next line
      if (metadata.parseLine(currentLine)) {
        continue;
      }

      //check if we have a long line
      if (textWidth(currentLine, lyricsStyle) >= media) {
        _handleLongLine(
            currentLine: currentLine,
            newLines: newLines,
            lyricsStyle: lyricsStyle,
            widgetPadding: widgetPadding);
      } else {
        //otherwise just add the regular line
        newLines.add(currentLine.trim());
      }
    }

    List<ChordLyricsLine> chordLyricsLines = newLines
        .map<ChordLyricsLine>(
            (line) => _processLine(line, lyricsStyle, chordStyle, chorusStyle))
        .toList();

    return ChordLyricsDocument(chordLyricsLines,
        capo: metadata.capo,
        artist: metadata.artist,
        title: metadata.title,
        key: metadata.key);
  }

  void _handleLongLine(
      {required List<String> newLines,
      required String currentLine,
      required TextStyle lyricsStyle,
      required int widgetPadding}) {
    String character = '';
    int characterIndex = 0;
    String currentCharacters = '';
    bool chordHasStartedOuter = false;
    int lastSpace = 0;

    //print('found a big line $currentLine');

    //work our way through the line and split when we need to
    for (var j = 0; j < currentLine.length; j++) {
      character = currentLine[j];
      if (character == '[') {
        chordHasStartedOuter = true;
      } else if (character == ']') {
        chordHasStartedOuter = false;
      } else if (!chordHasStartedOuter) {
        currentCharacters += character;
        if (character == ' ') {
          //use this marker to only split where there are spaces. We can trim later.
          lastSpace = j;
        }

        //This is the point where we need to split
        //widgetPadding has been added as a parameter to be passed from the build function
        //It is intended to allow for padding in the widget when comparing it to screen width
        //An additional buffer of around 10 might be needed to definitely stop overflow (ie. padding + 10).
        if (textWidth(currentCharacters, lyricsStyle) + widgetPadding >=
            media) {
          newLines.add(currentLine.substring(characterIndex, lastSpace).trim());
          currentCharacters = '';
          characterIndex = lastSpace;
        }
      }
    }
    //add the rest of the long line
    newLines
        .add(currentLine.substring(characterIndex, currentLine.length).trim());
  }

  /// Return the textwidth of the text in the given style
  double textWidth(String text, TextStyle textStyle) {
    return (TextPainter(
      textScaler: TextScaler.linear(_textScaleFactor),
      text: TextSpan(text: text, style: textStyle),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout())
        .size
        .width;
  }

  bool isChorus = false;
  ChordLyricsLine _processLine(String line, TextStyle lyricsStyle,
      TextStyle chordStyle, TextStyle chorusStyle) {
    ChordLyricsLine chordLyricsLine = ChordLyricsLine();
    String lyricsSoFar = '';
    String chordsSoFar = '';
    bool chordHasStarted = false;
    if (line.contains("{soc}") || line.contains("{start_of_chorus}")) {
      isChorus = true;
    } else if (line.contains("{eoc}") || line.contains("{end_of_chorus}")) {
      isChorus = false;
    }
    int counter = 0;
    line.split('').forEach((character) {
      if (character == ']') {
        final sizeOfLeadingLyrics = isChorus
            ? textWidth(lyricsSoFar, chorusStyle)
            : textWidth(lyricsSoFar, lyricsStyle);

        final lastChordText = chordLyricsLine.chords.isNotEmpty
            ? chordLyricsLine.chords.last.chordText
            : '';

        final lastChordWidth = textWidth(lastChordText, chordStyle);
        // final sizeOfThisChord = textWidth(_chordsSoFar, chordStyle);

        double leadingSpace = max(0, sizeOfLeadingLyrics - lastChordWidth);

        final transposedChord = chordTransposer.transposeChord(chordsSoFar);

        chordLyricsLine.chords.add(Chord(leadingSpace, transposedChord));
        chordLyricsLine.lyrics += lyricsSoFar;
        lyricsSoFar = '';
        chordsSoFar = '';
        chordHasStarted = false;

        final withoutChords = line.replaceAll(RegExp(r"\[(.*?)\]"),"").trim();
        if (counter+2 < withoutChords.length) {
          chordLyricsLine.underlines.add([counter, counter+2]);
        }
      } else if (character == '[') {
        chordHasStarted = true;
      } else {
        if (chordHasStarted) {
          chordsSoFar += character;
        } else {
          lyricsSoFar += character;
          counter+=1;
        }
      }
    });

    chordLyricsLine.lyrics += lyricsSoFar;

    return chordLyricsLine;
  }
}

class MetadataHandler {
  /// As specifications says "meta data is specified using “tags” surrounded by { and } characters"
  final RegExp regMetadata = RegExp(r'^ *\{.*}');
  final RegExp regCapo = RegExp(r'^\{capo:.*[0-9]+\}');
  final RegExp regArtist = RegExp(r'^\{artist:.*\}');
  final RegExp regTitle = RegExp(r'^\{title:.*\}');
  final RegExp regKey = RegExp(r'^\{key:.*\}');
  int? capo;
  String? artist;
  String? title;
  String? key;

  /// Try to find and parse metadata in the string.
  /// Return true if there was a match
  bool parseLine(String line) {
    return _setCapoIfMatch(line) ||
        _setArtistIfMatch(line) ||
        _setKeyIfMatch(line) ||
        _setTitleIfMatch(line);
  }

  /// Get key in line if it's present
  /// Return true if match was found
  bool _setKeyIfMatch(String line) {
    String? tmpKey =
        regKey.hasMatch(line) ? _getMetadataFromLine(line, 'key:') : null;
    key ??= tmpKey;
    return tmpKey != null;
  }

  /// Get capo in line if it's present
  /// Return true if match was found
  bool _setCapoIfMatch(String line) {
    int? tmpCapo = regCapo.hasMatch(line)
        ? int.parse(_getMetadataFromLine(line, 'capo:'))
        : null;
    capo ??= tmpCapo;
    return tmpCapo != null;
  }

  /// Get artist in line if it's present
  /// Return true if match was found
  bool _setArtistIfMatch(String line) {
    String? tmpArtist =
        regArtist.hasMatch(line) ? _getMetadataFromLine(line, 'artist:') : null;
    artist ??= tmpArtist;
    return tmpArtist != null;
  }

  /// Get title in line if it's present
  /// Return true if match was found
  bool _setTitleIfMatch(String line) {
    String? tmpTitle =
        regTitle.hasMatch(line) ? _getMetadataFromLine(line, 'title:') : null;
    title ??= tmpTitle;
    return tmpTitle != null;
  }

  String _getMetadataFromLine(String line, String key) {
    return line.split(key).last.split('}').first.trim();
  }
}
