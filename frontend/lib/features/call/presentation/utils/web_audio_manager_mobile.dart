import 'package:webrtc_interface/webrtc_interface.dart';

/// Stub-реализация для мобильных платформ.
/// Методы пусты, так как логика с AudioElement не нужна.
class WebAudioManager {
  void createAudioElement() {
    // Ничего не делаем на мобильных устройствах
  }

  void attachStream(MediaStream stream) {
    // Ничего не делаем на мобильных устройствах
  }

  void dispose() {
    // Ничего не делаем на мобильных устройствах
  }
}
