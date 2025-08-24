import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../../../core/services/webrtc_service.dart';
import '../../../../core/socket/call_socket_client.dart';

class CallTestScreen extends StatefulWidget {
  const CallTestScreen({super.key});

  @override
  State<CallTestScreen> createState() => _CallTestScreenState();
}

class _CallTestScreenState extends State<CallTestScreen> {
  final TextEditingController _remoteUserIdController = TextEditingController();
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();

  @override
  void initState() {
    super.initState();
    _initRenderers();
  }

  Future<void> _initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  @override
  void dispose() {
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Тест WebRTC Звонков'),
      ),
      body: Consumer<WebRTCService>(
        builder: (context, webrtcService, child) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Поле для ввода ID удаленного пользователя
                TextField(
                  controller: _remoteUserIdController,
                  decoration: const InputDecoration(
                    labelText: 'ID удаленного пользователя',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                // Кнопки управления звонками
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: webrtcService.callState == CallState.idle
                          ? () => _initiateAudioCall(webrtcService)
                          : null,
                      child: const Text('Аудио Звонок'),
                    ),
                    ElevatedButton(
                      onPressed: webrtcService.callState == CallState.idle
                          ? () => _initiateVideoCall(webrtcService)
                          : null,
                      child: const Text('Видео Звонок'),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Кнопки управления во время звонка
                if (webrtcService.callState == CallState.calling ||
                    webrtcService.callState == CallState.connected)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: () => webrtcService.toggleMicrophone(),
                        child: const Text('Микрофон'),
                      ),
                      if (webrtcService.callType == CallType.video)
                        ElevatedButton(
                          onPressed: () => webrtcService.toggleCamera(),
                          child: const Text('Камера'),
                        ),
                      ElevatedButton(
                        onPressed: () => webrtcService.endCall(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Завершить'),
                      ),
                    ],
                  ),

                const SizedBox(height: 16),

                // Кнопки для входящего звонка
                if (webrtcService.callState == CallState.incoming)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: () => _acceptCall(webrtcService),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Принять'),
                      ),
                      ElevatedButton(
                        onPressed: () => webrtcService.rejectCall(
                          webrtcService.currentCallId!,
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Отклонить'),
                      ),
                    ],
                  ),

                const SizedBox(height: 16),

                // Статус звонка
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Статус: ${_getCallStateText(webrtcService.callState)}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      if (webrtcService.remoteUserId != null)
                        Text('Удаленный пользователь: ${webrtcService.remoteUserId}'),
                      if (webrtcService.currentCallId != null)
                        Text('ID звонка: ${webrtcService.currentCallId}'),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Видео потоки
                if (webrtcService.callType == CallType.video)
                  Expanded(
                    child: Row(
                      children: [
                        // Локальное видео
                        Expanded(
                          child: Container(
                            margin: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.blue),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: RTCVideoView(
                                _localRenderer,
                                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                              ),
                            ),
                          ),
                        ),
                        // Удаленное видео
                        Expanded(
                          child: Container(
                            margin: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.green),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: RTCVideoView(
                                _remoteRenderer,
                                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Информация о CallSocketClient
                Consumer<CallSocketClient>(
                  builder: (context, callSocketClient, child) {
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'CallSocket Status: ${callSocketClient.isConnected ? "Подключен" : "Отключен"}',
                            style: TextStyle(
                              color: callSocketClient.isConnected ? Colors.green : Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (callSocketClient.token != null)
                            Text('Токен: ${callSocketClient.token!.substring(0, 10)}...'),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _initiateAudioCall(WebRTCService webrtcService) async {
    final remoteUserId = _remoteUserIdController.text.trim();
    if (remoteUserId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите ID удаленного пользователя')),
      );
      return;
    }

    final success = await webrtcService.initiateCall(remoteUserId, CallType.audio);
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ошибка инициации звонка')),
      );
    }
  }

  Future<void> _initiateVideoCall(WebRTCService webrtcService) async {
    final remoteUserId = _remoteUserIdController.text.trim();
    if (remoteUserId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите ID удаленного пользователя')),
      );
      return;
    }

    final success = await webrtcService.initiateCall(remoteUserId, CallType.video);
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ошибка инициации видеозвонка')),
      );
    }
  }

  Future<void> _acceptCall(WebRTCService webrtcService) async {
    final success = await webrtcService.acceptCall(
      webrtcService.currentCallId!,
      webrtcService.callType,
    );
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ошибка принятия звонка')),
      );
    }
  }

  String _getCallStateText(CallState state) {
    switch (state) {
      case CallState.idle:
        return 'Ожидание';
      case CallState.calling:
        return 'Звоним...';
      case CallState.incoming:
        return 'Входящий звонок';
      case CallState.connected:
        return 'Подключен';
      case CallState.ended:
        return 'Завершен';
      case CallState.error:
        return 'Ошибка';
    }
  }
}
