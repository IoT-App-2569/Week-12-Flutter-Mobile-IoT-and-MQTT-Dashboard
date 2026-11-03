idf_component_register(SRCS "main.c"
                    INCLUDE_DIRS "."
                    REQUIRES mqtt json esp_wifi esp_event nvs_flash esp_adc driver)
