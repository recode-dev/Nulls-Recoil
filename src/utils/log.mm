#include "../recoil.h"

static rcl_log_sink_t g_sink = nullptr;
static BOOL g_enabled = NO;
static rcl_log_entry_t g_pending[RCL_LOG_MAX_PENDING];
static int g_pending_count = 0;
static BOOL g_timer_armed = NO;
static uint64_t g_timer_token = 0;

static const char *rcl_log_level_name(int level)
{
    if (level == RCL_LOG_WARN)
    {
        return "warn";
    }
    if (level == RCL_LOG_ERROR)
    {
        return "error";
    }
    if (level == RCL_LOG_INFO)
    {
        return "info";
    }
    return "debug";
}

static void rcl_log_default_sink(const rcl_log_entry_t *entries, int count)
{
    for (int i = 0; i < count; i++)
    {
        NSLog(@"[recoil][%s] %s", rcl_log_level_name(entries[i].level), entries[i].text);
    }
}

static dispatch_queue_t rcl_log_serial(void)
{
    static dispatch_queue_t queue = nullptr;
    static dispatch_once_t once = 0;
    dispatch_once(&once, ^{
        queue = dispatch_queue_create("recoil.log", DISPATCH_QUEUE_SERIAL);
    });
    return queue;
}
static void rcl_log_arm(void)
{
    g_timer_armed = YES;
    uint64_t token = ++g_timer_token;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)RCL_LOG_FLUSH_MS * NSEC_PER_MSEC),
                   dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
                       if (token != g_timer_token)
                       {
                           return;
                       }
                       rcl_log_flush();
                   });
}

void rcl_log_flush(void)
{
    __block int count = 0;
    __block rcl_log_entry_t *batch = nullptr;
    __block rcl_log_sink_t sink = nullptr;
    dispatch_sync(rcl_log_serial(), ^{
        g_timer_armed = NO;
        g_timer_token++;
        count = g_pending_count;
        g_pending_count = 0;
        if (count <= 0)
        {
            return;
        }
        batch = (rcl_log_entry_t *)malloc(sizeof(rcl_log_entry_t) * (size_t)count);
        if (batch)
        {
            memcpy(batch, g_pending, sizeof(rcl_log_entry_t) * (size_t)count);
        }
        sink = g_sink ? g_sink : rcl_log_default_sink;
    });
    if (!batch)
    {
        return;
    }
    sink(batch, count);
    free(batch);
}

static void rcl_log_push(int level, const char *text)
{
    if (!g_enabled)
    {
        return;
    }
    __block BOOL flush_now = NO;
    dispatch_sync(rcl_log_serial(), ^{
        if (g_pending_count >= RCL_LOG_MAX_PENDING)
        {
            memmove(g_pending, g_pending + 1, sizeof(rcl_log_entry_t) * (RCL_LOG_MAX_PENDING - 1));
            g_pending_count = RCL_LOG_MAX_PENDING - 1;
        }
        rcl_log_entry_t *entry = &g_pending[g_pending_count++];
        entry->level = level;
        strncpy(entry->text, text ? text : "", RCL_LOG_TEXT_MAX - 1);
        entry->text[RCL_LOG_TEXT_MAX - 1] = 0;
        if (g_pending_count >= RCL_LOG_BATCH_SIZE)
        {
            g_timer_armed = NO;
            g_timer_token++;
            flush_now = YES;
        }
        else if (!g_timer_armed)
        {
            rcl_log_arm();
        }
    });
    if (flush_now)
    {
        rcl_log_flush();
    }
}

static void rcl_log_emit(int level, const char *format, va_list args)
{
    if (!format)
    {
        return;
    }
    char text[RCL_LOG_TEXT_MAX];
    vsnprintf(text, sizeof(text), format, args);
    rcl_log_push(level, text);
}

void rcl_log_debug(const char *format, ...)
{
    va_list args;
    va_start(args, format);
    rcl_log_emit(RCL_LOG_DEBUG, format, args);
    va_end(args);
}

void rcl_log_info(const char *format, ...)
{
    va_list args;
    va_start(args, format);
    rcl_log_emit(RCL_LOG_INFO, format, args);
    va_end(args);
}
void rcl_log_set_enabled(int value)
{
    BOOL next = value != 0;
    if (next == g_enabled)
    {
        return;
    }
    g_enabled = next;
    if (g_enabled)
    {
        rcl_log_debug("logging enabled");
        return;
    }
    rcl_log_flush();
}
