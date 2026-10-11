#include "../recoil.h"

static const char *g_flag_names[RCL_FEATURE_MAX] = {"aimbot", "autododge", "assist"};

static int g_flag_count = 3;
static uint32_t g_flags = RCL_FLAG_AIMBOT | RCL_FLAG_AUTODODGE;

static int rcl_flag_index(const char *name)
{
    if (!name)
    {
        return -1;
    }
    for (int i = 0; i < g_flag_count; i++)
    {
        if (strcmp(g_flag_names[i], name) == 0)
        {
            return i;
        }
    }
    return -1;
}
void rcl_flag_set(const char *name, int value)
{
    int index = rcl_flag_index(name);
    if (index < 0)
    {
        return;
    }
    if (value)
    {
        g_flags |= (1u << index);
    }
    else
    {
        g_flags &= ~(1u << index);
    }
}

int rcl_flag_state(const char *name)
{
    int index = rcl_flag_index(name);
    if (index < 0)
    {
        return 0;
    }
    return (g_flags & (1u << index)) ? 1 : 0;
}
int rcl_feature_setup(const char *label, void (*setup)(void))
{
    if (!setup)
    {
        return 0;
    }
    setup();
    (void)label;
    return 1;
}
