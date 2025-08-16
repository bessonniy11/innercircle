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
          .setExtraHeaders(_token != null ? {'Authorization': 'Bearer $_token'} : {}) // Pass empty map if token is null
          .build(),
    );

    _socket.onConnect((_) => debugPrint('Connected to Socket.IO'));
    _socket.onDisconnect((_) => debugPrint('Disconnected from Socket.IO'));
    _socket.onError((error) => debugPrint('Socket.IO Error: $error'));
  }

  void setToken(String token) {
    _token = token;
    _socket.dispose(); // Dispose old socket
    _initializeSocket(); // Reinitialize with new token
  }

  void connect() {
    if (_token == null) {
      debugPrint('Error: Token is not set. Cannot connect to Socket.IO.');
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