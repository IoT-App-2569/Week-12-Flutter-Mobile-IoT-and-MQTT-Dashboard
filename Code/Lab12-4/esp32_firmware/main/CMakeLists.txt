idf_component_register(SRCS "main.c"
                    INCLUDE_DIRS "."
                    REQUIRES mqtt cjson esp_wifi esp_event nvs_flash esp_adc driver esp_driver_gpio)

# Read secrets from ../.env (not committed) and generate env_config.h in the build dir.
set(ENV_FILE "${CMAKE_CURRENT_LIST_DIR}/../.env")
if(NOT EXISTS "${ENV_FILE}")
    message(FATAL_ERROR "Missing ${ENV_FILE}. Copy .env.example to .env and fill in WIFI_SSID, WIFI_PASS, MQTT_BROKER_URI.")
endif()
set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS "${ENV_FILE}")

file(STRINGS "${ENV_FILE}" ENV_LINES)
set(ENV_HEADER "// Generated from .env - do not edit, do not commit\n#pragma once\n")
foreach(line IN LISTS ENV_LINES)
    if(line MATCHES "^[ \t]*([A-Za-z_][A-Za-z0-9_]*)[ \t]*=(.*)$")
        set(key "${CMAKE_MATCH_1}")
        set(val "${CMAKE_MATCH_2}")
        string(REPLACE "\\" "\\\\" val "${val}")
        string(REPLACE "\"" "\\\"" val "${val}")
        string(APPEND ENV_HEADER "#define ${key} \"${val}\"\n")
    endif()
endforeach()
file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/env_config.h" "${ENV_HEADER}")
target_include_directories(${COMPONENT_LIB} PRIVATE "${CMAKE_CURRENT_BINARY_DIR}")
