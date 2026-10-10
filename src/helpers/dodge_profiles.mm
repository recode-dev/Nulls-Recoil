#include "../recoil.h"

#define RCL_DP_PI 3.14159265358979f
#define RCL_DP_TICK_MS 50.0f
#define RCL_DP_SPOKES 6
#define RCL_DP_ARC_N 7
#define RCL_DP_CHILD_RADIUS 50.0f
#define RCL_DP_SPAWN_OFFSET 200.0f
#define RCL_DP_CHILD_TRAVEL 1100.0f
#define RCL_DP_FLIGHT_DIST 2035.0f
#define RCL_DP_FLIGHT_TIME_MS 963.0f
#define RCL_DP_BURST_LIFE_MS 360.0f
#define RCL_DP_BLAST_MS 700.0f
#define RCL_DP_CURVE_DEV_DEG 22.0f
#define RCL_DP_ARM_LENGTH (RCL_DP_SPAWN_OFFSET + RCL_DP_CHILD_TRAVEL)

typedef struct
{
    float child_radius;
    float child_speed;
    float spawn_offset;
    float child_travel;
    float flight_time_ms;
} rcl_cross_spec_t;

static const float rcl_spike_arc[RCL_DP_ARC_N][3] = {
    {0.0f, 200.0f, 0.0f},      {110.0f, 515.0f, 32.0f},   {207.0f, 797.0f, 216.0f},
    {312.0f, 999.0f, 519.0f},  {411.0f, 1066.0f, 930.0f}, {513.0f, 995.0f, 1377.0f},
    {557.0f, 883.0f, 1611.0f},
};

static int rcl_spike_variant = 0;

static void rcl_hz_seg(rcl_hazard_t *h, const char *name, float ax, float ay, float bx, float by,
                       float radius, float t0, float t1)
{
    h->has_segment = 1;
    h->x = 0.0f;
    h->y = 0.0f;
    h->radius = radius;
    h->t0 = t0;
    h->t1 = t1;
    h->ax = ax;
    h->ay = ay;
    h->bx = bx;
    h->by = by;
    h->name = name;
}

static void rcl_hz_blob(rcl_hazard_t *h, const char *name, float x, float y, float radius, float t0,
                        float t1)
{
    h->has_segment = 0;
    h->x = x;
    h->y = y;
    h->radius = radius;
    h->t0 = t0;
    h->t1 = t1;
    h->ax = 0.0f;
    h->ay = 0.0f;
    h->bx = 0.0f;
    h->by = 0.0f;
    h->name = name;
}

static float rcl_dp_time(uint64_t spawned_at, uint64_t now_ms)
{
    return (float)(spawned_at ? spawned_at : now_ms);
}

static int rcl_cross_arms(rcl_hazard_t *out, int max_out, const char *name, float cx, float cy,
                          float arm, float radius, float t0, float t1, int diagonal)
{
    static const float diag = 0.70710678f;
    int n = 0;
    int k;
    for (k = 0; k < 2; k++)
    {
        float dx = 0.0f;
        float dy = 0.0f;
        if (n >= max_out)
        {
            break;
        }
        if (diagonal)
        {
            dx = diag;
            dy = (k == 0) ? diag : -diag;
        }
        else
        {
            dx = (k == 0) ? 1.0f : 0.0f;
            dy = (k == 0) ? 0.0f : 1.0f;
        }
        rcl_hz_seg(&out[n], name, cx - dx * arm, cy - dy * arm, cx + dx * arm, cy + dy * arm,
                   radius, t0, t1);
        n++;
    }
    return n;
}

static int rcl_cross_profile(const rcl_proj_t *p, uint64_t now_ms, rcl_hazard_t *out, int max_out,
                             const rcl_cross_spec_t *spec, int diagonal)
{
    float arm_length = spec->spawn_offset + spec->child_travel;
    float burst_life = spec->child_travel / spec->child_speed * 1000.0f;
    float cx = (float)p->targetX;
    float cy = (float)p->targetY;
    float land_at = 0.0f;
    float t0 = 0.0f;
    float t1 = 0.0f;
    if (cx == 0.0f && cy == 0.0f)
    {
        float flight_s = spec->flight_time_ms / 1000.0f;
        cx = (float)p->spawnX + p->vx * flight_s;
        cy = (float)p->spawnY + p->vy * flight_s;
    }
    if (cx == 0.0f || cy == 0.0f)
    {
        return 0;
    }
    if (cx > 1.0e6f || cx < -1.0e6f || cy > 1.0e6f || cy < -1.0e6f)
    {
        return 0;
    }
    land_at = rcl_dp_time(p->spawnedAt, now_ms) + spec->flight_time_ms;
    t0 = land_at - RCL_DP_TICK_MS;
    t1 = land_at + burst_life + RCL_DP_TICK_MS;
    return rcl_cross_arms(out, max_out, p->name, cx, cy, arm_length, spec->child_radius, t0, t1,
                          diagonal);
}

static void rcl_spike_endpoint(const rcl_proj_t *p, float *ex, float *ey, float *edist)
{
    float ang = p->angle;
    float rad = 0.0f;
    float dir_x = 0.0f;
    float dir_y = 0.0f;
    float dist = 0.0f;
    if (ang != ang)
    {
        ang = 0.0f;
    }
    rad = ang * RCL_DP_PI / 180.0f;
    dir_x = cosf(rad);
    dir_y = sinf(rad);
    dist = rcl_wall_trace((float)p->spawnX, (float)p->spawnY, dir_x, dir_y, RCL_DP_FLIGHT_DIST,
                          RCL_WALL_BLOCKS_PROJECTILES);
    *ex = (float)p->spawnX + dir_x * dist;
    *ey = (float)p->spawnY + dir_y * dist;
    *edist = dist;
}

static int rcl_cactus_profile(const rcl_proj_t *p, uint64_t now_ms, rcl_hazard_t *out, int max_out)
{
    float end_x = 0.0f;
    float end_y = 0.0f;
    float end_dist = 0.0f;
    float burst_at = 0.0f;
    int n = 0;
    rcl_spike_endpoint(p, &end_x, &end_y, &end_dist);
    burst_at =
        rcl_dp_time(p->spawnedAt, now_ms) + RCL_DP_FLIGHT_TIME_MS * (end_dist / RCL_DP_FLIGHT_DIST);
    if (p->spawnAreaRadius > 0)
    {
        if (n < max_out)
        {
            rcl_hz_blob(&out[n], p->name, end_x, end_y, (float)p->spawnAreaRadius, burst_at,
                        burst_at + (float)(p->spawnAreaActiveTime ? p->spawnAreaActiveTime
                                                                  : (int)RCL_DP_BLAST_MS));
            n++;
        }
    }
    if (rcl_spike_variant == 1)
    {
        float t0 = burst_at - RCL_DP_TICK_MS;
        float t1 = burst_at + RCL_DP_BURST_LIFE_MS + RCL_DP_TICK_MS;
        int i = 0;
        for (i = 0; i < 3; i++)
        {
            float a = (float)i * RCL_DP_PI / 3.0f;
            float dx = cosf(a) * RCL_DP_ARM_LENGTH;
            float dy = sinf(a) * RCL_DP_ARM_LENGTH;
            if (n < max_out)
            {
                rcl_hz_seg(&out[n], p->name, end_x - dx, end_y - dy, end_x + dx, end_y + dy,
                           RCL_DP_CHILD_RADIUS, t0, t1);
                n++;
            }
        }
        return n;
    }
    {
        int s = 0;
        for (s = 0; s < RCL_DP_SPOKES; s++)
        {
            float rot = (float)s * (2.0f * RCL_DP_PI / (float)RCL_DP_SPOKES);
            float cr = cosf(rot);
            float sr = sinf(rot);
            int k = 0;
            for (k = 0; k + 1 < RCL_DP_ARC_N; k++)
            {
                float ta = rcl_spike_arc[k][0];
                float ax = rcl_spike_arc[k][1];
                float ay = rcl_spike_arc[k][2];
                float tb = rcl_spike_arc[k + 1][0];
                float bx = rcl_spike_arc[k + 1][1];
                float by = rcl_spike_arc[k + 1][2];
                if (n < max_out)
                {
                    rcl_hz_seg(&out[n], p->name, end_x + ax * cr - ay * sr,
                               end_y + ax * sr + ay * cr, end_x + bx * cr - by * sr,
                               end_y + bx * sr + by * cr, RCL_DP_CHILD_RADIUS, burst_at + ta,
                               burst_at + tb);
                    n++;
                }
            }
        }
    }
    return n;
}

int rcl_shape_hazards(const rcl_proj_t *p, uint64_t now_ms, rcl_hazard_t *out, int max_out)
{
    static const rcl_cross_spec_t cross_bomber = {125.0f, 3000.0f, 200.0f, 800.0f, 1015.0f};
    static const rcl_cross_spec_t cross_ulti = {375.0f, 3000.0f, 100.0f, 1600.0f, 1115.0f};
    if (!p || !p->name)
    {
        return 0;
    }
    if (!out || max_out <= 0)
    {
        return 0;
    }
    if (strstr(p->name, "Overcharged") != nullptr || strstr(p->name, "MegaBoss") != nullptr)
    {
        int n = rcl_cross_profile(p, now_ms, out, max_out, &cross_ulti, 0);
        n += rcl_cross_profile(p, now_ms, out + n, max_out - n, &cross_ulti, 1);
        return n;
    }
    if (strstr(p->name, "CrossBomber") != nullptr && p->name[strlen(p->name) - 1] != '2')
    {
        if (strstr(p->name, "Ulti") != nullptr)
        {
            return rcl_cross_profile(p, now_ms, out, max_out, &cross_ulti, 0);
        }
        return rcl_cross_profile(p, now_ms, out, max_out, &cross_bomber, 0);
    }
    if (strcmp(p->name, "CactusProjectile") == 0)
    {
        if (!rcl_spike_variant)
        {
            return 0;
        }
        return rcl_cactus_profile(p, now_ms, out, max_out);
    }
    if (strcmp(p->name, "CactusSpike") == 0)
    {
        return 0;
    }
    return 0;
}

int rcl_blocks_linear(const char *name)
{
    if (!name)
    {
        return 0;
    }
    if (strstr(name, "CrossBomber") != nullptr && name[strlen(name) - 1] != '2')
    {
        return 1;
    }
    if (strcmp(name, "CactusSpike") == 0)
    {
        return 1;
    }
    return 0;
}

void rcl_note_burst_death(const rcl_proj_death_t *rec)
{
    int dx = 0;
    int dy = 0;
    float angle = 0.0f;
    float chord = 0.0f;
    float deviation = 0.0f;
    if (rcl_spike_variant)
    {
        return;
    }
    if (!rec)
    {
        return;
    }
    if (!rec->name || strcmp(rec->name, "CactusProjectile") != 0)
    {
        return;
    }
    dx = rec->x - rec->spawnX;
    dy = rec->y - rec->spawnY;
    if (dx * dx + dy * dy < 1)
    {
        return;
    }
    angle = rec->angle;
    if (angle != angle)
    {
        angle = 0.0f;
    }
    chord = atan2f((float)dy, (float)dx) * 180.0f / RCL_DP_PI;
    deviation = fmodf(chord - angle, 360.0f);
    deviation = fmodf(deviation + 540.0f, 360.0f) - 180.0f;
    if (deviation < 0.0f)
    {
        deviation = -deviation;
    }
    rcl_spike_variant = deviation > RCL_DP_CURVE_DEV_DEG ? 2 : 1;
}
