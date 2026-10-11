#ifndef RECOIL_UTILS_LOG_H
#define RECOIL_UTILS_LOG_H

#include "../core/offsets.h"

#define RCL_LOG_DEBUG 0
#define RCL_LOG_INFO 1
#define RCL_LOG_WARN 2
#define RCL_LOG_ERROR 3

#define RCL_LOG_BATCH_SIZE 32
#define RCL_LOG_FLUSH_MS 100
#define RCL_LOG_MAX_PENDING 512
#define RCL_LOG_TEXT_MAX 128

typedef struct
{
    int level;
    char text[RCL_LOG_TEXT_MAX];
} rcl_log_entry_t;

typedef void (*rcl_log_sink_t)(const rcl_log_entry_t *entries, int count);

void rcl_log_set_enabled(int value);
void rcl_log_debug(const char *format, ...);
void rcl_log_info(const char *format, ...);
void rcl_log_flush(void);

#endif
