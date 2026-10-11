#include "../recoil.h"

#include <stdio.h>

static const char *rcl_probe_names[8] = {"6c", "74", "a0", "a4", "a8", "b0", "ec", "1c4"};

static const uint32_t rcl_probe_offsets[8] = {0x6c, 0x74, 0xa0, 0xa4, 0xa8, 0xb0, 0xec, 0x1c4};

static char rcl_probe_kind(int32_t v)
{
    if (v >= 200 && v <= 2000)
    {
        return 's';
    }
    if (v >= 20 && v <= 400)
    {
        return 'r';
    }
    return ' ';
}

void rcl_offsets_probe(uintptr_t elem)
{
    uintptr_t ptrs[8];
    int n = 0;
    int i = 0;

    if (!elem)
    {
        return;
    }

    for (i = 0; i < 8; i++)
    {
        void *raw = nullptr;
        uintptr_t value = 0;

        if (!rcl_read_ptr(elem + (uintptr_t)i * 8, &raw))
        {
            continue;
        }

        value = (uintptr_t)raw;

        if (!rcl_pointer_plausible(value) || value == elem)
        {
            continue;
        }

        ptrs[n] = value;
        n++;
    }

    rcl_log_info("probe elem=%#llx ptrs=%d", (unsigned long long)elem, n);

    for (i = 0; i < n; i++)
    {
        char line[192];
        int32_t v[8];
        int used = 0;
        int k = 0;

        for (k = 0; k < 8; k++)
        {
            v[k] = -1;

            if (rcl_read_int(ptrs[i] + rcl_probe_offsets[k], &v[k]))
            {
                continue;
            }

            v[k] = -1;
        }

        used = snprintf(line, sizeof(line), "probe p%d=%#llx", i, (unsigned long long)ptrs[i]);

        for (k = 0; k < 8 && used > 0 && used < (int)sizeof(line) - 24; k++)
        {
            used += snprintf(line + used, sizeof(line) - (size_t)used, " %s=%d%c", rcl_probe_names[k], v[k],
                             rcl_probe_kind(v[k]));
        }

        rcl_log_info("%s", line);
    }
}
