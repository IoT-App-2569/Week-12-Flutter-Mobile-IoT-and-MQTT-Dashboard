// mqtt_helper.dart
import 'package:mqtt_client/mqtt_client.dart';

import 'mqtt_helper_native.dart'
    if (dart.library.js_interop) 'mqtt_helper_web.dart' as helper;

MqttClient setupMqttClient(String broker, String clientId) {
  return helper.createMqttClient(broker, clientId);
}

