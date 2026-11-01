import 'package:mqtt_client/mqtt_client.dart';
import 'mqtt_setup_stub.dart'
    if (dart.library.io) 'mqtt_setup_native.dart'
    if (dart.library.html) 'mqtt_setup_web.dart'
    if (dart.library.js_interop) 'mqtt_setup_web.dart';

MqttClient getMqttClient(String broker, String clientId) =>
    createMqttClient(broker, clientId);
