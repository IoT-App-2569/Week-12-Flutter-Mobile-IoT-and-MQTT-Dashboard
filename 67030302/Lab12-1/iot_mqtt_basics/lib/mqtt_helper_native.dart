// mqtt_helper_native.dart
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

MqttClient createMqttClient(String broker, String clientId) {
  final client = MqttServerClient(broker, clientId);
  client.port = 1883;
  return client;
}

