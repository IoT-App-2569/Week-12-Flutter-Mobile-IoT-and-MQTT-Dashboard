#include <stdio.h>
#include <stdint.h>
#include <stddef.h>
#include <string.h>
#include <stdlib.h>
#include "esp_wifi.h"
#include "esp_system.h"
#include "nvs_flash.h"
#include "esp_event.h"
#include "esp_netif.h"
#include "esp_log.h"
#include "esp_timer.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "freertos/event_groups.h"
#include "driver/gpio.h"
#include "esp_adc/adc_oneshot.h"
#include "mqtt_client.h"
#include "cJSON.h"

#define WIFI_SSID           "brown"
#define WIFI_PASS           "jjjjjjjj"
#define MQTT_BROKER_URI     "mqtt://172.20.10.3:1883" // IP ของ Mac

#if CONFIG_IDF_TARGET_ESP32C3
#define LED_PIN             GPIO_NUM_8
#define ADC_CHANNEL         ADC_CHANNEL_0   // GPIO 0
#else
#define LED_PIN             GPIO_NUM_2
#define ADC_CHANNEL         ADC_CHANNEL_6   // GPIO 34
#endif

#define TOPIC_STATUS    "iot/esp32/status"
#define TOPIC_CONTROL   "iot/esp32/control"
#define TOPIC_ACK       "iot/esp32/led_ack"
#define TOPIC_TELEMETRY "iot/esp32/telemetry"

static const char *TAG = "LAB12_4";
static EventGroupHandle_t s_wifi_event_group;
#define WIFI_CONNECTED_BIT  BIT0

static esp_mqtt_client_handle_t s_mqtt_client = NULL;
static adc_oneshot_unit_handle_t s_adc_handle = NULL;
static bool s_led_state = false;
static volatile bool s_mqtt_connected = false;

/* ===== 1. Wi-Fi ===== */
static void wifi_event_handler(void* arg, esp_event_base_t event_base, int32_t event_id, void* event_data)
{
    if (event_base == WIFI_EVENT && event_id == WIFI_EVENT_STA_START) {
        esp_wifi_connect();
    } else if (event_base == WIFI_EVENT && event_id == WIFI_EVENT_STA_DISCONNECTED) {
        ESP_LOGW(TAG, "Wi-Fi disconnected, reconnecting...");
        esp_wifi_connect();
        xEventGroupClearBits(s_wifi_event_group, WIFI_CONNECTED_BIT);
    } else if (event_base == IP_EVENT && event_id == IP_EVENT_STA_GOT_IP) {
        ip_event_got_ip_t* event = (ip_event_got_ip_t*) event_data;
        ESP_LOGI(TAG, "Got IP Address: " IPSTR, IP2STR(&event->ip_info.ip));
        xEventGroupSetBits(s_wifi_event_group, WIFI_CONNECTED_BIT);
    }
}

static void wifi_init_sta(void)
{
    s_wifi_event_group = xEventGroupCreate();
    ESP_ERROR_CHECK(esp_netif_init());
    ESP_ERROR_CHECK(esp_event_loop_create_default());
    esp_netif_create_default_wifi_sta();

    wifi_init_config_t cfg = WIFI_INIT_CONFIG_DEFAULT();
    ESP_ERROR_CHECK(esp_wifi_init(&cfg));

    esp_event_handler_instance_t instance_any_id;
    esp_event_handler_instance_t instance_got_ip;
    ESP_ERROR_CHECK(esp_event_handler_instance_register(WIFI_EVENT, ESP_EVENT_ANY_ID, &wifi_event_handler, NULL, &instance_any_id));
    ESP_ERROR_CHECK(esp_event_handler_instance_register(IP_EVENT, IP_EVENT_STA_GOT_IP, &wifi_event_handler, NULL, &instance_got_ip));

    wifi_config_t wifi_config = {
        .sta = {
            .threshold.authmode = WIFI_AUTH_WPA2_PSK,
        },
    };
    size_t ssid_len = strlen(WIFI_SSID);
    if (ssid_len > sizeof(wifi_config.sta.ssid)) ssid_len = sizeof(wifi_config.sta.ssid);
    memcpy(wifi_config.sta.ssid, WIFI_SSID, ssid_len);

    size_t pass_len = strlen(WIFI_PASS);
    if (pass_len > sizeof(wifi_config.sta.password)) pass_len = sizeof(wifi_config.sta.password);
    memcpy(wifi_config.sta.password, WIFI_PASS, pass_len);

    ESP_ERROR_CHECK(esp_wifi_set_mode(WIFI_MODE_STA));
    ESP_ERROR_CHECK(esp_wifi_set_config(WIFI_IF_STA, &wifi_config));
    ESP_ERROR_CHECK(esp_wifi_start());
    ESP_LOGI(TAG, "Wi-Fi Initialization finished.");
}

/* ===== 2. MQTT ===== */
static void publish_ack(esp_mqtt_client_handle_t client)
{
    char ack_msg[64];
    snprintf(ack_msg, sizeof(ack_msg),
             "{\"led_state\": %s, \"ack\": true}", s_led_state ? "true" : "false");
    esp_mqtt_client_publish(client, TOPIC_ACK, ack_msg, 0, 1, 0);
    ESP_LOGI(TAG, "ACK Published: %s", ack_msg);
}

static void mqtt_event_handler(void *handler_args, esp_event_base_t base, int32_t event_id, void *event_data)
{
    esp_mqtt_event_handle_t event = (esp_mqtt_event_handle_t)event_data;
    esp_mqtt_client_handle_t client = event->client;

    switch ((esp_mqtt_event_id_t)event_id) {
    case MQTT_EVENT_CONNECTED:
        ESP_LOGI(TAG, "MQTT_EVENT_CONNECTED");
        s_mqtt_connected = true;
        esp_mqtt_client_publish(client, TOPIC_STATUS, "online", 0, 1, 1);
        esp_mqtt_client_subscribe(client, TOPIC_CONTROL, 1);
        ESP_LOGI(TAG, "Subscribed to: %s", TOPIC_CONTROL);
        publish_ack(client);   // แจ้งสถานะ LED ปัจจุบันให้แอป
        break;

    case MQTT_EVENT_DISCONNECTED:
        ESP_LOGW(TAG, "MQTT_EVENT_DISCONNECTED");
        s_mqtt_connected = false;
        break;

    case MQTT_EVENT_DATA:
        ESP_LOGI(TAG, "TOPIC=%.*s DATA=%.*s",
                 event->topic_len, event->topic, event->data_len, event->data);

        if (event->topic_len == (int)strlen(TOPIC_CONTROL) &&
            strncmp(event->topic, TOPIC_CONTROL, event->topic_len) == 0) {

            char buf[64] = {0};
            int len = event->data_len < (int)sizeof(buf) - 1 ? event->data_len : (int)sizeof(buf) - 1;
            memcpy(buf, event->data, len);

            // ถอดรหัส {"led":"ON"} / {"led":"OFF"}
            bool changed = false;
            cJSON *root = cJSON_Parse(buf);
            if (root != NULL) {
                cJSON *led = cJSON_GetObjectItem(root, "led");
                if (cJSON_IsString(led) && led->valuestring != NULL) {
                    if (strcasecmp(led->valuestring, "ON") == 0) {
                        s_led_state = true;
                        changed = true;
                    } else if (strcasecmp(led->valuestring, "OFF") == 0) {
                        s_led_state = false;
                        changed = true;
                    }
                }
                cJSON_Delete(root);
            }

            if (changed) {
                gpio_set_level(LED_PIN, s_led_state ? 1 : 0);
                ESP_LOGI(TAG, "LED -> %s", s_led_state ? "ON" : "OFF");
                publish_ack(client);
            } else {
                ESP_LOGW(TAG, "Invalid control payload: %s", buf);
            }
        }
        break;

    default:
        break;
    }
}

/* ===== 3. Telemetry ทุก 500 ms ===== */
static void telemetry_task(void *pvParameters)
{
    while (1) {
        vTaskDelay(pdMS_TO_TICKS(500));

        if (s_mqtt_client == NULL || !s_mqtt_connected) continue;

        int adc_raw = 0;
        if (s_adc_handle != NULL) {
            adc_oneshot_read(s_adc_handle, ADC_CHANNEL, &adc_raw);
        }
        float voltage = ((float)adc_raw / 4095.0f) * 3.3f;
        int uptime_s = (int)(esp_timer_get_time() / 1000000);

        char json_str[80];
        snprintf(json_str, sizeof(json_str),
                 "{\"voltage\": %.2f, \"raw\": %d, \"uptime\": %d}",
                 voltage, adc_raw, uptime_s);
        esp_mqtt_client_publish(s_mqtt_client, TOPIC_TELEMETRY, json_str, 0, 0, 0);
    }
}

/* ===== 4. app_main ===== */
void app_main(void)
{
    esp_err_t ret = nvs_flash_init();
    if (ret == ESP_ERR_NVS_NO_FREE_PAGES || ret == ESP_ERR_NVS_NEW_VERSION_FOUND) {
        ESP_ERROR_CHECK(nvs_flash_erase());
        ret = nvs_flash_init();
    }
    ESP_ERROR_CHECK(ret);

    gpio_reset_pin(LED_PIN);
    gpio_set_direction(LED_PIN, GPIO_MODE_OUTPUT);
    gpio_set_level(LED_PIN, 0);

    adc_oneshot_unit_init_cfg_t init_config = { .unit_id = ADC_UNIT_1 };
    adc_oneshot_new_unit(&init_config, &s_adc_handle);
    adc_oneshot_chan_cfg_t chan_config = {
        .bitwidth = ADC_BITWIDTH_DEFAULT,
        .atten = ADC_ATTEN_DB_12,
    };
    adc_oneshot_config_channel(s_adc_handle, ADC_CHANNEL, &chan_config);

    wifi_init_sta();
    xEventGroupWaitBits(s_wifi_event_group, WIFI_CONNECTED_BIT, false, true, portMAX_DELAY);

    esp_mqtt_client_config_t mqtt_cfg = {
        .broker = { .address = { .uri = MQTT_BROKER_URI } },
        .session = {
            .keepalive = 15,
            .last_will = {
                .topic = TOPIC_STATUS,
                .msg = "offline",
                .msg_len = 7,
                .qos = 1,
                .retain = 1,
            },
        },
    };

    s_mqtt_client = esp_mqtt_client_init(&mqtt_cfg);
    esp_mqtt_client_register_event(s_mqtt_client, ESP_EVENT_ANY_ID, mqtt_event_handler, NULL);
    esp_mqtt_client_start(s_mqtt_client);

    xTaskCreate(telemetry_task, "telemetry_task", 4096, NULL, 5, NULL);
}