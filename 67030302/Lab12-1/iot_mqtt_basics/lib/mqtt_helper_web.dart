// mqtt_helper_web.dart
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_browser_client.dart';

MqttClient createMqttClient(String broker, String clientId) {
  var wsUrl = broker.trim();
  // ถ้าไม่ได้ขึ้นต้นด้วย ws:// หรือ wss:// ให้เติม ws://
  if (!wsUrl.startsWith('ws://') && !wsUrl.startsWith('wss://')) {
    wsUrl = 'ws://$wsUrl';
  }
  // MqttBrowserClient ต้องการ path หรือ root
  final client = MqttBrowserClient(wsUrl, clientId);
  client.port = 9001; // Mosquitto WebSocket port
  client.setProtocolV311();
  client.websocketProtocols = MqttClientConstants.protocolsSingleDefault;
  return client;
}

