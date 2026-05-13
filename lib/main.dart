import "package:flutter/material.dart";
import "package:media_lib/app/app.dart";
import "package:media_lib/core/audio/audiobook_audio_handler.dart";

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initAudiobookBackgroundAudio();
  runApp(const MediaLibApp());
}
