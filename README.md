# flutter_chord

[![Test](https://github.com/claudemircasa/custom_flutter_chord/actions/workflows/test.yml/badge.svg)](https://github.com/claudemircasa/custom_flutter_chord/actions/workflows/test.yml)

Chord parser for Flutter apps.
Original repository at: [paurakhsharma](https://github.com/paurakhsharma/flutter_chord)

## Features

- Transpose Chord
- Auto Scroll

<img src="https://raw.githubusercontent.com/claudemircasa/custom_flutter_chord/main/screenshot.png"></img>

## Usage

**1) Render the Lyrics and Chords directly.**

```dart
final textStyle = TextStyle(fontSize: 18, color: Colors.white);
final chordStyle = TextStyle(fontSize: 20, color: Colors.green);

final lyrics = '''
[C]Give me Freedom, [F]Give me fire
[Am] Give me reason, [G]Take me higher
''';

@override
  Widget build(BuildContext context) {
    return LyricsRenderer(
    lyrics: _lyrics,
    textStyle: textStyle,
    chordStyle: chordStyle,
    widgetPadding: 50,
    onTapChord: (String chord) {
      print('pressed chord: $chord');
    },
    transposeIncrement: 0,
    scrollSpeed: 0,
    showChord: true, // if false, show only lyrics
    showText: true,
    minorScale: false, // transpose to minor scale
    // you can replace default presentation by a list of 7 string elements
    // chordPresentation: List<String>['DO', 'RÉ', ...]
  );
}
```

**2. Get a parsed `ChordLyricsDocument` and style it as you like.**

```dart

final textStyle = TextStyle(fontSize: 18, color: Colors.white);
final chordStyle = TextStyle(fontSize: 20, color: Colors.green);

final lyrics = '''
[C]Give me Freedom , [F]Give me fire
[Am] Give me reason , [G]Take me higher
''';

ChordProcessor _chordProcessor = ChordProcessor(context);
ChordLyricsDocument chordLyricsDocument = _chordProcessor.processText(
  text: lyrics,
  lyricsStyle: textStyle,
  chordStyle: chordStyle,
  transposeIncrement: 0,
);
```
