import 'dart:html' as html;
import 'package:webrtc_interface/webrtc_interface.dart';

/// Веб-реализация для управления "невидимым" AudioElement.
class WebAudioManager {
  html.AudioElement? _audioElement;

  /// Создает и добавляет в DOM скрытый <audio> элемент.
  void createAudioElement() {
    _audioElement = html.AudioElement()
      ..autoplay = true
      ..controls = false;
    _audioElement!.setAttribute('playsinline', 'true');
    _audioElement!.style.display = 'none';
    html.document.body?.append(_audioElement!);
  }

  /// Привязывает MediaStream к AudioElement и запускает воспроизведение.
  void attachStream(MediaStream stream) {
    if (_audioElement != null) {
      _audioElement!.srcObject = (stream as dynamic).jsStream;
      _audioElement!.play();
    }
  }

  /// Удаляет AudioElement из DOM.
  void dispose() {
    _audioElement?.remove();
    _audioElement = null;
  }
}
