import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter/foundation.dart';

class SocketClient {
  late IO.Socket _socket;
  String? _token;

  SocketClient() {
    _initializeSocket();
  }

  void _initializeSocket() {
    _socket = IO.io(
      'http://localhost:3000', // TODO: Replace with your backend URL
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .enableForceNew()
          .disableAutoConnect()
          .setExtraHeaders({})
          .setAuth({'token': _token}) // Передаем токен через опцию auth
          .build(),
    );

    _socket.onConnect((_) => {});
    _socket.onDisconnect((_) => {});
    _socket.onError((error) => {});
  }

  void setToken(String token) {
    _token = token;
    _socket.dispose(); // Dispose old socket
    _initializeSocket(); // Reinitialize with new token
  }

  void connect() {
    if (_token == null) {
      // Token is not set. Cannot connect to Socket.IO.
      return;
    }
    if (!_socket.connected) {
      _socket.connect();
    }
  }

  void disconnect() {
    _socket.disconnect();
  }

  IO.Socket get socket => _socket;
} 