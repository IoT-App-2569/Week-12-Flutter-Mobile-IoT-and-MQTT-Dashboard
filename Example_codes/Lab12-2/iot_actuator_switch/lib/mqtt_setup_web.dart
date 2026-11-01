import 'package:mqtt_client/mqtt_browser_client.dart';
import 'package:mqtt_client/mqtt_client.dart';

MqttClient createMqttClient(String broker, String clientId) {
  final wsUrl = broker.startsWith('ws://') || broker.startsWith('wss://')
      ? broker
      : 'ws://$broker';
  final client = MqttBrowserClient.withPort(wsUrl, clientId, 9001);
  client.setProtocolV311();
  client.websocketProtocols = MqttClientConstants.protocolsSingleDefault;
  
  final connMessage = MqttConnectMessage()
      .withClientIdentifier(clientId)
      .startClean();
  client.connectionMessage = connMessage;

  return client;
}
