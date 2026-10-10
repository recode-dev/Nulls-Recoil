#include "../recoil.h"

uintptr_t rcl_tiles = 0;

int rcl_w = 0;

int rcl_h = 0;

uintptr_t rcl_map_object(void)
{
    void *client = nullptr;
    void *map = nullptr;
    if (!rcl_scene_object)
    {
        return 0;
    }
    if (!rcl_read_ptr((uintptr_t)rcl_scene_object + RCL_MAP_BASE_OFF, &client) || !client)
    {
        return 0;
    }
    if (!rcl_read_ptr((uintptr_t)client + RCL_MAP_PTR_OFF, &map) || !map)
    {
        return 0;
    }
    return (uintptr_t)map;
}

int rcl_cell(int tx, int ty, int *proj, int *move)
{
    void *tile = nullptr;
    void *type = nullptr;
    uint8_t bm = 0;
    uint8_t bp = 0;
    *proj = -1;
    *move = -1;
    if (!rcl_tiles)
    {
        return 0;
    }
    if (tx < 0 || ty < 0 || tx >= rcl_w || ty >= rcl_h)
    {
        return 0;
    }
    if (!rcl_read_ptr(rcl_tiles + (uintptr_t)(ty * rcl_w + tx) * (uintptr_t)RCL_TILE_PTR_STRIDE,
                      &tile))
    {
        return 0;
    }
    if (!tile)
    {
        *proj = 0;
        *move = 0;
        return 1;
    }
    if (!rcl_read_ptr((uintptr_t)tile, &type) || !type)
    {
        return 0;
    }
    if (!rcl_read_bytes((uintptr_t)type + RCL_TILE_TYPE_MOVE_OFF, &bm, 1))
    {
        return 0;
    }
    if (!rcl_read_bytes((uintptr_t)type + RCL_TILE_TYPE_PROJ_OFF, &bp, 1))
    {
        return 0;
    }
    *proj = (int)bp;
    *move = (int)bm;
    return 1;
}

static uint8_t rcl_wall_grid[RCL_WALL_MAX_TOTAL_TILES];

static int rcl_wall_w = 0;

static int rcl_wall_h = 0;

static int rcl_wall_have = 0;

static int rcl_wall_dirty = 1;

static uint64_t rcl_wall_fail_ms = 0;

int rcl_wall_cache_w(void)
{
    return rcl_wall_w;
}

int rcl_wall_cache_h(void)
{
    return rcl_wall_h;
}

int rcl_wall_build(void)
{
    int width = 0;
    int height = 0;
    int total = 0;
    int i = 0;
    if (!rcl_tiles)
    {
        return 0;
    }
    width = rcl_w;
    height = rcl_h;
    if (width <= 0 || width > RCL_WALL_MAX_MAP_TILES)
    {
        return 0;
    }
    if (height <= 0 || height > RCL_WALL_MAX_MAP_TILES)
    {
        return 0;
    }
    total = width * height;
    if (total > RCL_WALL_MAX_TOTAL_TILES)
    {
        return 0;
    }
    for (i = 0; i < total; i++)
    {
        int tx = i % width;
        int ty = i / width;
        int proj = 0;
        int move = 0;
        uint8_t flags = 0;
        if (rcl_cell(tx, ty, &proj, &move))
        {
            if (move)
            {
                flags |= RCL_WALL_BLOCKS_MOVEMENT;
            }
            if (proj)
            {
                flags |= RCL_WALL_BLOCKS_PROJECTILES;
            }
        }
        rcl_wall_grid[i] = flags;
    }
    rcl_wall_w = width;
    rcl_wall_h = height;
    rcl_wall_have = 1;
    rcl_wall_dirty = 0;
    return 1;
}

int rcl_wall_maybe_refresh(uint64_t now_ms)
{
    if (!rcl_wall_dirty)
    {
        return 0;
    }
    if (now_ms - rcl_wall_fail_ms < RCL_WALL_RETRY_MS)
    {
        return 0;
    }
    if (rcl_wall_build())
    {
        return 1;
    }
    rcl_wall_fail_ms = now_ms;
    return 0;
}

void rcl_wall_notify_battle_mode_changed(uint64_t now_ms)
{
    rcl_wall_have = 0;
    rcl_wall_w = 0;
    rcl_wall_h = 0;
    rcl_wall_dirty = 1;
    rcl_wall_fail_ms = 0;
    rcl_wall_maybe_refresh(now_ms);
}

int rcl_wall_is_blocked_at(float x, float y, int mask)
{
    int tx = 0;
    int ty = 0;
    if (!rcl_wall_have)
    {
        return 0;
    }
    if (rcl_wall_w <= 0 || rcl_wall_h <= 0)
    {
        return 0;
    }
    tx = (int)(x / RCL_WALL_TILE_SIZE);
    ty = (int)(y / RCL_WALL_TILE_SIZE);
    if (tx < 0 || tx >= rcl_wall_w || ty < 0 || ty >= rcl_wall_h)
    {
        return 0;
    }
    return (rcl_wall_grid[ty * rcl_wall_w + tx] & mask) ? 1 : 0;
}

int rcl_wall_is_blocked_wide(float x, float y, float r, int mask)
{
    float rr = 0.0f;
    if (rcl_wall_is_blocked_at(x, y, mask))
    {
        return 1;
    }
    rr = r > 0.0f ? r : 0.0f;
    if (rr <= 0.0f)
    {
        return 0;
    }
    if (rcl_wall_is_blocked_at(x + rr, y, mask))
    {
        return 1;
    }
    if (rcl_wall_is_blocked_at(x - rr, y, mask))
    {
        return 1;
    }
    if (rcl_wall_is_blocked_at(x, y + rr, mask))
    {
        return 1;
    }
    if (rcl_wall_is_blocked_at(x, y - rr, mask))
    {
        return 1;
    }
    return 0;
}

int rcl_wall_los(float ax, float ay, float bx, float by, int mask)
{
    int cx = 0;
    int cy = 0;
    int tx = 0;
    int ty = 0;
    int dx = 0;
    int dy = 0;
    int sx = 0;
    int sy = 0;
    int err = 0;
    int steps = 0;
    int n = 0;
    if (!rcl_wall_have)
    {
        return 1;
    }
    cx = (int)(ax / RCL_WALL_TILE_SIZE);
    cy = (int)(ay / RCL_WALL_TILE_SIZE);
    tx = (int)(bx / RCL_WALL_TILE_SIZE);
    ty = (int)(by / RCL_WALL_TILE_SIZE);
    if (cx == tx && cy == ty)
    {
        return 1;
    }
    dx = tx - cx;
    if (dx < 0)
    {
        dx = -dx;
    }
    dy = ty - cy;
    if (dy < 0)
    {
        dy = -dy;
    }
    dy = -dy;
    sx = cx < tx ? 1 : -1;
    sy = cy < ty ? 1 : -1;
    err = dx + dy;
    steps = dx - dy + 2;
    for (n = 0; n < steps; n++)
    {
        int e2 = 2 * err;
        if (e2 >= dy)
        {
            err += dy;
            cx += sx;
        }
        if (e2 <= dx)
        {
            err += dx;
            cy += sy;
        }
        if (cx == tx && cy == ty)
        {
            return 1;
        }
        if (cx < 0 || cx >= rcl_wall_w || cy < 0 || cy >= rcl_wall_h)
        {
            continue;
        }
        if (rcl_wall_grid[cy * rcl_wall_w + cx] & mask)
        {
            return 0;
        }
    }
    return 1;
}

float rcl_wall_trace(float x, float y, float dx, float dy, float max_dist, int mask)
{
    float dist = 0.0f;
    if (!rcl_wall_have || max_dist <= 0.0f)
    {
        return max_dist;
    }
    if (rcl_wall_w <= 0 || rcl_wall_h <= 0)
    {
        return max_dist;
    }
    while (dist < max_dist)
    {
        int tx = 0;
        int ty = 0;
        dist += RCL_WALL_TRACE_STEP;
        if (dist > max_dist)
        {
            dist = max_dist;
        }
        tx = (int)((x + dx * dist) / RCL_WALL_TILE_SIZE);
        ty = (int)((y + dy * dist) / RCL_WALL_TILE_SIZE);
        if (tx < 0 || tx >= rcl_wall_w || ty < 0 || ty >= rcl_wall_h)
        {
            float hit = dist - RCL_WALL_TRACE_BACKOFF;
            return hit > 0.0f ? hit : 0.0f;
        }
        if (rcl_wall_grid[ty * rcl_wall_w + tx] & mask)
        {
            float hit = dist - RCL_WALL_TRACE_BACKOFF;
            return hit > 0.0f ? hit : 0.0f;
        }
    }
    return max_dist;
}
