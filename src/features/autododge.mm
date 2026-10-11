#include "../recoil.h"

#define RCL_WALK_EVERY 1

__thread int rcl_in_move = 0;

int32_t rcl_pl_mine[12];

int rcl_cand_now[3];

int rcl_cand_seen = 0;

int32_t rcl_prev_x = 0;

int32_t rcl_prev_y = 0;

int rcl_cal_off_seen = -1;

float rcl_cal_rad_seen = 0.0f;

int rcl_cal_n = 0;

int rcl_ok(float v, float lo, float hi)
{
    return (v >= lo && v <= hi) ? 1 : 0;
}

int rcl_rad_off = -1;

float rcl_own_r = 0.0f;

#define RCL_DODGE_CHAR_SPEED 1440.0f
#define RCL_DODGE_SPEED_MIN 300
#define RCL_DODGE_SPEED_MAX 8500

static float rcl_dodge_speed = RCL_DODGE_CHAR_SPEED;
static uint64_t rcl_dodge_speed_ms = 0;
static void rcl_dodge_speed_probe(void)
{
    void *def = nullptr;
    int32_t raw = 0;
    if (!rcl_own_elem)
    {
        return;
    }
    if (!rcl_read_ptr(rcl_own_elem + (uintptr_t)RCL_ELEM_DEF_OFF, &def) || !def)
    {
        return;
    }
    if (!rcl_read_int((uintptr_t)def + (uintptr_t)OFF_CHARDATA_SPEED, &raw))
    {
        return;
    }
    if (raw < RCL_DODGE_SPEED_MIN || raw > RCL_DODGE_SPEED_MAX)
    {
        return;
    }
    rcl_dodge_speed = (float)raw;
}

#define RCL_AD_AWARE 3200.0f
#define RCL_AD_T_AHEAD 0.9f
#define RCL_AD_DIR_COUNT 64
#define RCL_AD_SKIN 50.0f
#define RCL_AD_REACH 600.0f
#define RCL_TAU 6.28318531f
#define RCL_MS_PER_S 1000.0f
#define RCL_AD_HOLD_TAN 0.12f
#define RCL_AD_DIR_MIN 24.0f
#define RCL_DODGE_PROBE_MS 120
#define RCL_AD_WALL_BODY 240.0f
#define RCL_AD_TICK_MS 16.0f
#define RCL_AD_TICK_MAX_MS 250.0f
#define RCL_AD_MINE_SPAWN 220.0f
#define RCL_AD_DT_MIN 4.0f
#define RCL_BDC_ALONG_BACK 50.0f
#define RCL_BDC_REACH_K 0.85f
#define RCL_BDC_THROWER_STICK 420.0f

typedef struct
{
    float x;
    float y;
    float vx;
    float vy;
    float rad;
    float hitr;
    float age;
    float fade_base;
    float fade_k;
    float ax;
    float ay;
    float bx;
    float by;
    int has_segment;
    const char *name;
    int thrower;
    int style;
    float left;
    float boom;
} rcl_ad_hazard_t;

#define RCL_AD_HAZARD_MAX 96
#define RCL_AD_CAP_MAX 16

static rcl_ad_hazard_t rcl_ad_hazards[RCL_AD_HAZARD_MAX];
static rcl_hazard_t rcl_ad_caps[RCL_AD_CAP_MAX];
static float rcl_ad_ring[RCL_AD_DIR_COUNT][2];
static int rcl_ad_dir_built = 0;
static int rcl_ad_hazard_n = 0;

#define RCL_BD_SEG_SAMPLES 4
#define RCL_BD_SAFETY_MARGIN 28.0f
#define RCL_BD_T_FIELD 1.8f
#define RCL_BD_INTENT_DEAD_SQ 900.0f
#define RCL_BD_THREAT_MAX 160
#define RCL_STY_PLAIN 0
#define RCL_STY_LONG 1
#define RCL_STY_SPREAD 2
#define RCL_STY_ARC 3
#define RCL_STY_BEAM 4
#define RCL_STY_BURST 5

typedef struct
{
    float x;
    float y;
    float vx;
    float vy;
    float rad;
    float hitr;
    int thrower;
    int style;
    float left;
    float boom;
} rcl_bd_threat_t;

static rcl_bd_threat_t rcl_bd_threats[RCL_BD_THREAT_MAX];
static int rcl_bd_threat_n = 0;

static uint64_t rcl_ad_now_ms(void)
{
    return (uint64_t)(CFAbsoluteTimeGetCurrent() * 1000.0);
}

static void rcl_ad_build_ring(void)
{
    int i;
    if (rcl_ad_dir_built)
    {
        return;
    }
    for (i = 0; i < RCL_AD_DIR_COUNT; i++)
    {
        float a = RCL_TAU * (float)i / (float)RCL_AD_DIR_COUNT;
        rcl_ad_ring[i][0] = cosf(a);
        rcl_ad_ring[i][1] = sinf(a);
    }
    rcl_ad_dir_built = 1;
}

static int rcl_bd_style(const char *name, const rcl_kind_t *spec, int thrower, int beam)
{
    const char *n = name ? name : "";
    if (spec && (spec->flags & RCL_K_DROP))
    {
        return RCL_STY_ARC;
    }
    if (thrower)
    {
        return RCL_STY_ARC;
    }
    if (beam)
    {
        return RCL_STY_BEAM;
    }
    if (spec && spec->maxRange >= 1800)
    {
        return RCL_STY_LONG;
    }
    if (strstr(n, "Sniper") || strstr(n, "Piper") || strstr(n, "Rail") || strstr(n, "Ricochet"))
    {
        return RCL_STY_LONG;
    }
    if (strstr(n, "Mechanic") || strstr(n, "Spike") || strstr(n, "Rat") || strstr(n, "Minigun"))
    {
        return RCL_STY_BURST;
    }
    if (strstr(n, "Shotgun") || strstr(n, "Gun") || strstr(n, "Sweep") || strstr(n, "Burst"))
    {
        return RCL_STY_SPREAD;
    }
    return RCL_STY_PLAIN;
}

static float rcl_ad_ball_radius(const rcl_proj_t *p)
{
    float r = p->radius;
    if (r > 0.0f)
    {
        return r;
    }
    return rcl_proj_radius(p, 1.0f);
}

static float rcl_ad_traveled(const rcl_proj_t *p)
{
    float dx;
    float dy;
    if (!p->spawnX && !p->spawnY)
    {
        return 0.0f;
    }
    dx = (float)(p->x - p->spawnX);
    dy = (float)(p->y - p->spawnY);
    return sqrtf(dx * dx + dy * dy);
}

static int rcl_ad_spawn_near_own(const rcl_proj_t *p, float mx, float my)
{
    float sx;
    float sy;
    float dx;
    float dy;
    int i;
    sx = p->spawnX ? (float)p->spawnX : (float)p->ownerX;
    sy = p->spawnY ? (float)p->spawnY : (float)p->ownerY;
    if (!sx && !sy)
    {
        return 0;
    }
    dx = sx - mx;
    dy = sy - my;
    if (dx * dx + dy * dy <= RCL_AD_MINE_SPAWN * RCL_AD_MINE_SPAWN)
    {
        return 1;
    }
    for (i = 0; i < rcl_mate_n && i < 8; i++)
    {
        dx = sx - (float)rcl_mate_x[i];
        dy = sy - (float)rcl_mate_y[i];
        if (dx * dx + dy * dy <= RCL_AD_MINE_SPAWN * RCL_AD_MINE_SPAWN)
        {
            return 1;
        }
    }
    return 0;
}

static int rcl_ad_is_mine(const rcl_proj_t *p, float mx, float my)
{
    if (rcl_own_team_seen && p->team >= 0 && p->team == rcl_own_team_a)
    {
        return 1;
    }
    if (rcl_own_team_b >= 0 && p->team >= 0 && p->team == rcl_own_team_b)
    {
        return 1;
    }
    if (p->team >= 0)
    {
        return 0;
    }
    return rcl_ad_spawn_near_own(p, mx, my);
}

static int rcl_ad_crosses_me(const rcl_proj_t *p, float mx, float my, float r)
{
    float px = (float)p->x - mx;
    float py = (float)p->y - my;
    float a = p->vx * p->vx + p->vy * p->vy;
    float t = 0.0f;
    if (a > 1.0f)
    {
        t = -(px * p->vx + py * p->vy) / a;
        if (t < 0.0f)
        {
            return 0;
        }
        if (t > RCL_BD_T_FIELD)
        {
            t = RCL_BD_T_FIELD;
        }
    }
    px += p->vx * t;
    py += p->vy * t;
    return px * px + py * py <= r * r;
}

static float rcl_ad_seg_dist(float px, float py, float ax, float ay, float bx, float by)
{
    float dx = bx - ax;
    float dy = by - ay;
    float len_sq = dx * dx + dy * dy;
    float t;
    float cx;
    float cy;
    t = len_sq < 0.000001f ? 0.0f : ((px - ax) * dx + (py - ay) * dy) / len_sq;
    if (t < 0.0f)
    {
        t = 0.0f;
    }
    else if (t > 1.0f)
    {
        t = 1.0f;
    }
    cx = px - (ax + dx * t);
    cy = py - (ay + dy * t);
    return sqrtf(cx * cx + cy * cy);
}

static void rcl_ad_fade_vel(const rcl_ad_hazard_t *h, float dt, float *vxOut, float *vyOut)
{
    float vx = h->vx;
    float vy = h->vy;
    if (h->fade_base && h->fade_k)
    {
        float nowAge = h->age > 0.0f ? h->age : 0.0f;
        float laterAge = nowAge + dt * 1000.0f;
        float cur = h->fade_base * expf(h->fade_k * nowAge);
        float nxt = h->fade_base * expf(h->fade_k * laterAge);
        if (cur > 0.000001f)
        {
            float r = nxt / cur;
            vx *= r;
            vy *= r;
        }
    }
    *vxOut = vx;
    *vyOut = vy;
}

static int rcl_ad_in_aware(const rcl_ad_hazard_t *h, float mx, float my, float zoneSq)
{
    float dx;
    float dy;
    if (h->has_segment)
    {
        float d = rcl_ad_seg_dist(mx, my, h->ax, h->ay, h->bx, h->by);
        return d * d <= zoneSq;
    }
    dx = h->x - mx;
    dy = h->y - my;
    return dx * dx + dy * dy <= zoneSq;
}

static float rcl_ad_kind_reach(const rcl_proj_t *p, const rcl_kind_t *spec, float spd)
{
    float r = 0.0f;
    if (spec && spec->maxRange > 0)
    {
        r = (float)spec->maxRange;
    }
    if (spec && spec->chargedRange > 0 && spd > 3500.0f)
    {
        r = (float)spec->chargedRange;
    }
    if (r <= 0.0f && p->castRange > 0)
    {
        r = (float)p->castRange;
    }
    if (r <= 0.0f && p->isThrower && (p->targetX || p->targetY) && p->spawnX && p->spawnY)
    {
        float dx = (float)(p->targetX - p->spawnX);
        float dy = (float)(p->targetY - p->spawnY);
        float td = sqrtf(dx * dx + dy * dy);
        if (td > 0.0f)
        {
            r = td;
        }
    }
    if (r > 0.0f && spec && spec->reachAdj)
    {
        r += (float)spec->reachAdj;
    }
    if (r > 0.0f && r < 70000.0f)
    {
        return r;
    }
    return 0.0f;
}

static int rcl_ad_home_pos(const rcl_proj_t *p, float *xOut, float *yOut)
{
    float tx = (float)p->ownerX;
    float ty = (float)p->ownerY;
    if (!rcl_ok(tx, -100000000.0f, 100000000.0f))
    {
        return 0;
    }
    if (!rcl_ok(ty, -100000000.0f, 100000000.0f))
    {
        return 0;
    }
    if (!tx && !ty)
    {
        return 0;
    }
    *xOut = tx;
    *yOut = ty;
    return 1;
}

static float rcl_ad_life_left(const rcl_proj_t *p, const rcl_kind_t *spec, float spd,
                              uint64_t nowMs)
{
    float maxR = rcl_ad_kind_reach(p, spec, spd);
    float homeX = 0.0f;
    float homeY = 0.0f;
    float left;
    if (spec && (spec->flags & RCL_K_FADE))
    {
        float spawned = p->spawnedAt ? (float)p->spawnedAt : (float)nowMs;
        float age = (float)nowMs - spawned;
        if (age < 0.0f)
        {
            age = 0.0f;
        }
        left = maxR * (1.0f - age / RCL_MS_PER_S);
        return left > 0.0f ? left : 0.0f;
    }
    if (spec && (spec->flags & RCL_K_HOME) && rcl_ad_home_pos(p, &homeX, &homeY))
    {
        float dx = homeX - (float)p->x;
        float dy = homeY - (float)p->y;
        return sqrtf(dx * dx + dy * dy);
    }
    left = maxR - rcl_ad_traveled(p);
    return left > 0.0f ? left : 0.0f;
}

static void rcl_ad_collect(float mx, float my, float myRadius, uint64_t nowMs)
{
    float zoneSq = RCL_AD_AWARE * RCL_AD_AWARE;
    float bodyR = myRadius + RCL_AD_SKIN;
    int i;
    int c;
    rcl_ad_hazard_n = 0;
    for (i = 0; i < rcl_proj_death_n && i < 16; i++)
    {
        rcl_note_burst_death(&rcl_proj_deaths[i]);
    }
    for (i = 0; i < 16; i++)
    {
        const rcl_proj_t *p = &rcl_projs[i];
        const rcl_kind_t *spec = nullptr;
        const rcl_fit_t *fit = nullptr;
        const char *name = nullptr;
        int shaped = 0;
        int lockPath = 0;
        int blob = 0;
        float vx = 0.0f;
        float vy = 0.0f;
        float spd = 0.0f;
        float shotR = 0.0f;
        float rad = 0.0f;
        float ux = 0.0f;
        float uy = 0.0f;
        float playerAlong = 0.0f;
        float left = 0.0f;
        float gap = 0.0f;
        float dx = 0.0f;
        float dy = 0.0f;
        if (!p->elem)
        {
            continue;
        }
        if (p->name && !rcl_addr_readable((uintptr_t)p->name, 1))
        {
            continue;
        }
        if (rcl_ad_is_mine(p, mx, my) && (p->team >= 0 || !rcl_ad_crosses_me(p, mx, my, bodyR)))
        {
            continue;
        }
        shaped = rcl_shape_hazards(p, nowMs, rcl_ad_caps, RCL_AD_CAP_MAX);
        for (c = 0; c < shaped; c++)
        {
            const rcl_hazard_t *cap = &rcl_ad_caps[c];
            float until = (cap->t1 - (float)nowMs) / RCL_MS_PER_S;
            rcl_ad_hazard_t *h = nullptr;
            if (until <= 0.0f)
            {
                continue;
            }
            if (rcl_ad_hazard_n >= RCL_AD_HAZARD_MAX)
            {
                break;
            }
            h = &rcl_ad_hazards[rcl_ad_hazard_n];
            memset(h, 0, sizeof(*h));
            h->rad = cap->radius + bodyR;
            h->hitr = cap->radius + myRadius;
            h->has_segment = cap->has_segment;
            h->name = p->name ? p->name : cap->name;
            h->thrower = p->isThrower ? 1 : 0;
            h->style = rcl_bd_style(p->name, rcl_kind_of(p->name), p->isThrower, p->isBeam);
            h->boom = cap->radius;
            if (cap->has_segment)
            {
                h->ax = cap->ax;
                h->ay = cap->ay;
                h->bx = cap->bx;
                h->by = cap->by;
            }
            else
            {
                h->x = cap->x;
                h->y = cap->y;
            }
            if (rcl_ad_in_aware(h, mx, my, zoneSq))
            {
                rcl_ad_hazard_n++;
            }
        }
        if (shaped > 0 && rcl_blocks_linear(p->name))
        {
            continue;
        }
        name = p->name ? p->name : "";
        spec = rcl_kind_of(name);
        dx = (float)p->x - mx;
        dy = (float)p->y - my;
        {
            float spd0 = sqrtf(p->vx * p->vx + p->vy * p->vy);
            float reach = RCL_AD_AWARE + spd0 * RCL_AD_T_AHEAD;
            if (dx * dx + dy * dy > reach * reach)
            {
                continue;
            }
        }
        vx = p->vx;
        vy = p->vy;
        if (vx == 0.0f && vy == 0.0f)
        {
            if (!rcl_proj_vel(p, &vx, &vy))
            {
                vx = 0.0f;
                vy = 0.0f;
            }
        }
        if (!rcl_ok(vx, -100000000.0f, 100000000.0f) || !rcl_ok(vy, -100000000.0f, 100000000.0f))
        {
            vx = 0.0f;
            vy = 0.0f;
        }
        {
            float flown = rcl_ad_traveled(p);
            if (spec && (spec->flags & RCL_K_LOCKPATH) && flown > 120.0f && p->spawnX && p->spawnY)
            {
                float base = sqrtf(vx * vx + vy * vy);
                if (base < 1.0f)
                {
                    base = 1.0f;
                }
                vx = ((float)p->x - (float)p->spawnX) / flown * base;
                vy = ((float)p->y - (float)p->spawnY) / flown * base;
            }
        }
        spd = sqrtf(vx * vx + vy * vy);
        if (spd < 1.0f && !p->isThrower && !(spec && (spec->flags & RCL_K_DROP)) &&
            (p->spawnX || p->spawnY))
        {
            float sx = (float)p->x - (float)p->spawnX;
            float sy = (float)p->y - (float)p->spawnY;
            float slen = sqrtf(sx * sx + sy * sy);
            float age = (float)nowMs - (float)p->spawnedAt;
            if (slen > RCL_AD_DIR_MIN && age > 1.0f && age < 5000.0f)
            {
                spd = slen / (age / RCL_MS_PER_S);
                vx = sx / slen * spd;
                vy = sy / slen * spd;
            }
        }
        if (spec && spec->speedMul > 0.0f && spd > 3500.0f)
        {
            vx *= spec->speedMul;
            vy *= spec->speedMul;
            spd *= spec->speedMul;
        }
        if (spec && (spec->flags & RCL_K_DROP) && spd < 1.0f)
        {
            continue;
        }
        lockPath = (spec && (spec->flags & RCL_K_LOCKPATH)) || p->isBeam;
        blob = (spec && (spec->flags & RCL_K_BLOB)) || (!lockPath && p->isThrower);
        fit = rcl_fit_of(name);
        shotR = rcl_ad_ball_radius(p) + (spec ? (float)spec->growR : 0.0f);
        rad = shotR + bodyR + fit->pad + shotR * fit->grow;
        if (spd >= 1.0f)
        {
            ux = vx / spd;
            uy = vy / spd;
        }
        if (!blob && spd >= 1.0f)
        {
            playerAlong = (mx - (float)p->x) * ux + (my - (float)p->y) * uy;
            if (playerAlong < -RCL_BDC_ALONG_BACK)
            {
                continue;
            }
            if (!p->isThrower)
            {
                float tHit = playerAlong > 0.0f ? playerAlong : 0.0f;
                float hitX = (float)p->x + ux * tHit;
                float hitY = (float)p->y + uy * tHit;
                if (!rcl_wall_los((float)p->x, (float)p->y, hitX, hitY,
                                  RCL_WALL_BLOCKS_PROJECTILES))
                {
                    continue;
                }
            }
        }
        left = rcl_ad_life_left(p, spec, spd, nowMs);
        if (left > 0.0f && left <= 10.0f)
        {
            continue;
        }
        gap = sqrtf(dx * dx + dy * dy) - bodyR - shotR;
        if (left > 0.0f && left < RCL_BDC_REACH_K * (gap > 0.0f ? gap : 0.0f))
        {
            continue;
        }
        if (left > 0.0f && !blob && spd >= 1.0f && playerAlong > left + shotR)
        {
            continue;
        }
        if (rcl_ad_hazard_n >= RCL_AD_HAZARD_MAX)
        {
            break;
        }
        {
            rcl_ad_hazard_t *h = &rcl_ad_hazards[rcl_ad_hazard_n];
            memset(h, 0, sizeof(*h));
            h->x = (float)p->x;
            h->y = (float)p->y;
            h->vx = vx;
            h->vy = vy;
            h->rad = rad;
            h->hitr = shotR + bodyR;
            h->name = p->name;
            h->age = (spec && (spec->flags & RCL_K_FADE))
                         ? ((float)nowMs - (float)(p->spawnedAt ? p->spawnedAt : nowMs))
                         : 0.0f;
            if (h->age < 0.0f)
            {
                h->age = 0.0f;
            }
            h->fade_base = spec ? spec->fadeBase : 0.0f;
            h->fade_k = spec ? spec->fadeK : 0.0f;
            h->thrower = p->isThrower ? 1 : 0;
            h->style = rcl_bd_style(name, spec, p->isThrower, p->isBeam);
            h->left = left;
            h->boom = shotR;
            rcl_ad_hazard_n++;
        }
    }
}
static void rcl_bd_norm(float x, float y, float *ox, float *oy)
{
    float len = sqrtf(x * x + y * y);
    if (len < 0.000001f)
    {
        *ox = 1.0f;
        *oy = 0.0f;
        return;
    }
    *ox = x / len;
    *oy = y / len;
}

static void rcl_bd_push(float x, float y, float vx, float vy, float rad, float hitr)
{
    rcl_bd_threat_t *t = nullptr;
    if (rcl_bd_threat_n >= RCL_BD_THREAT_MAX)
    {
        return;
    }
    t = &rcl_bd_threats[rcl_bd_threat_n];
    t->x = x;
    t->y = y;
    t->vx = vx;
    t->vy = vy;
    t->rad = rad;
    t->hitr = hitr > 0.0f ? hitr : rad;
    rcl_bd_threat_n++;
}

static void rcl_bd_push_style(float x, float y, float vx, float vy, float rad, float hitr,
                              int thrower, int style, float left, float boom)
{
    rcl_bd_push(x, y, vx, vy, rad, hitr);
    if (rcl_bd_threat_n > 0)
    {
        rcl_bd_threat_t *t = &rcl_bd_threats[rcl_bd_threat_n - 1];
        t->thrower = thrower;
        t->style = style;
        t->left = left;
        t->boom = boom;
    }
}

static void rcl_bd_build_threats(void)
{
    int i;
    rcl_bd_threat_n = 0;
    for (i = 0; i < rcl_ad_hazard_n; i++)
    {
        const rcl_ad_hazard_t *h = &rcl_ad_hazards[i];
        float vx = 0.0f;
        float vy = 0.0f;
        if (h->has_segment)
        {
            int k;
            for (k = 0; k <= RCL_BD_SEG_SAMPLES; k++)
            {
                float f = (float)k / (float)RCL_BD_SEG_SAMPLES;
                rcl_bd_push_style(h->ax + (h->bx - h->ax) * f, h->ay + (h->by - h->ay) * f, 0.0f,
                                  0.0f, h->rad, h->hitr, 0, h->style, 0.0f, h->boom);
            }
            continue;
        }
        rcl_ad_fade_vel(h, 0.0f, &vx, &vy);
        if (h->thrower && h->left > 0.0f && h->left < RCL_BDC_THROWER_STICK)
        {
            rcl_bd_push_style(h->x, h->y, 0.0f, 0.0f, h->rad, h->hitr, 1, h->style, h->left,
                              h->boom);
            continue;
        }
        rcl_bd_push_style(h->x, h->y, vx, vy, h->rad, h->hitr, h->thrower, h->style, h->left,
                          h->boom);
    }
}

static void rcl_bd_intent(float *ix, float *iy)
{
    uintptr_t ctrl = rcl_controller();
    float rx = 0.0f;
    float ry = 0.0f;
    *ix = 0.0f;
    *iy = 0.0f;
    if (!ctrl)
    {
        return;
    }
    if (!rcl_read_float(ctrl + (uintptr_t)RCL_CTRL_RAW_X_OFF, &rx))
    {
        return;
    }
    if (!rcl_read_float(ctrl + (uintptr_t)RCL_CTRL_RAW_Y_OFF, &ry))
    {
        return;
    }
    if (rx * rx + ry * ry <= RCL_BD_INTENT_DEAD_SQ)
    {
        return;
    }
    rcl_bd_norm(rx, ry, ix, iy);
}

static float rcl_ad_clamp_to_map(float v, int maxTiles)
{
    float maxV = (float)maxTiles * RCL_WALL_TILE_SIZE - 1.0f;
    if (maxV <= 0.0f)
    {
        return v;
    }
    if (v < 0.0f)
    {
        return 0.0f;
    }
    if (v > maxV)
    {
        return maxV;
    }
    return v;
}

static void rcl_ad_clamp_target(float *tx, float *ty)
{
    int w = rcl_wall_cache_w();
    int h = rcl_wall_cache_h();
    if (w <= 0 || h <= 0)
    {
        return;
    }
    *tx = rcl_ad_clamp_to_map(*tx, w);
    *ty = rcl_ad_clamp_to_map(*ty, h);
}

static float rcl_ad_sent_x = 0.0f;
static float rcl_ad_sent_y = 0.0f;
static int rcl_ad_sent_on = 0;

static int rcl_ad_send_move(float tx, float ty, float mx, float my)
{
    int32_t ex;
    int32_t ey;
    float reach;
    float hx;
    float hy;

    if (!isfinite(tx) || !isfinite(ty))
    {
        return 0;
    }
    rcl_ad_clamp_target(&tx, &ty);
    hx = tx - mx;
    hy = ty - my;
    reach = sqrtf(hx * hx + hy * hy) * RCL_AD_HOLD_TAN;
    if (rcl_ad_sent_on)
    {
        float dx = tx - rcl_ad_sent_x;
        float dy = ty - rcl_ad_sent_y;
        if (dx * dx + dy * dy < reach * reach)
        {
            tx = rcl_ad_sent_x;
            ty = rcl_ad_sent_y;
        }
    }
    rcl_ad_sent_x = tx;
    rcl_ad_sent_y = ty;
    rcl_ad_sent_on = 1;
    ex = (int32_t)tx;
    ey = (int32_t)ty;
    rcl_move_to(ex, ey, mx, my);
    return rcl_enqueue(ex, ey);
}

#define RCL_BDC_EXTRA 12
#define RCL_BDC_DANGER 1000000.0f
#define RCL_BDC_T_FIELD 2.4f
#define RCL_BDC_T_URGENT 0.9f
#define RCL_BDC_KEEP 0.15f
#define RCL_BDC_KEEP_IMPACT 0.90f
#define RCL_BDC_TIE 1.05f
#define RCL_BDC_WALL_HIT 200000.0f
#define RCL_BDC_WALL_BAND 170.0f
#define RCL_BDC_WALL_PROBE 3
#define RCL_BDC_EXTRA_BLEND 120.0f
#define RCL_BDC_HIT_GATE 1.15f
#define RCL_BDC_FAR 1.0e18f
#define RCL_BDC_EPS 1.0f
#define RCL_BDC_DIR_MAX (RCL_AD_DIR_COUNT + RCL_BDC_EXTRA)

static int rcl_bdc_sel[RCL_BD_THREAT_MAX];
static int rcl_bdc_sel_n = 0;
static float rcl_bdc_dirs[RCL_BDC_DIR_MAX][2];
static float rcl_bdc_scores[RCL_BDC_DIR_MAX];
static float rcl_bdc_impacts[RCL_BDC_DIR_MAX];
static float rcl_bdc_last_x = 0.0f;
static float rcl_bdc_last_y = 0.0f;
static int rcl_bdc_have_last = 0;
static uint64_t rcl_bdc_log_ms = 0;
static uint64_t rcl_bdc_seen = 0;
static uint64_t rcl_bdc_idle = 0;

static int rcl_bd_danger(float mx, float my, float myR)
{
    int i;
    for (i = 0; i < rcl_bd_threat_n; i++)
    {
        const rcl_bd_threat_t *p = &rcl_bd_threats[i];
        float r = myR + p->rad + RCL_BD_SAFETY_MARGIN * 2.5f;
        float dx = mx - p->x;
        float dy = my - p->y;
        float distSq = dx * dx + dy * dy;
        float c1;
        float c2;
        float tHit;
        float cx;
        float cy;
        if (distSq <= r * r)
        {
            return 1;
        }
        c1 = dx * p->vx + dy * p->vy;
        if (c1 <= 0.0f)
        {
            continue;
        }
        c2 = p->vx * p->vx + p->vy * p->vy;
        if (c2 <= 0.0f)
        {
            continue;
        }
        tHit = c1 / c2;
        if (tHit > RCL_BD_T_FIELD)
        {
            continue;
        }
        cx = p->x + p->vx * tHit;
        cy = p->y + p->vy * tHit;
        if ((mx - cx) * (mx - cx) + (my - cy) * (my - cy) <= r * r)
        {
            return 1;
        }
    }
    return 0;
}

static int rcl_bdc_aimed_one(const rcl_bd_threat_t *p, float mx, float my, float myR)
{
    float r = myR + p->rad + RCL_BD_SAFETY_MARGIN;
    float vx = p->vx;
    float vy = p->vy;
    float px = p->x - mx;
    float py = p->y - my;
    float a = vx * vx + vy * vy;
    float b = 2.0f * (px * vx + py * vy);
    float c = px * px + py * py;
    float tm = 0.0f;
    float minD2 = c;
    if (a > 0.000001f)
    {
        tm = -b / (2.0f * a);
        if (tm < 0.0f)
        {
            tm = 0.0f;
        }
        if (tm > RCL_BDC_T_FIELD)
        {
            tm = RCL_BDC_T_FIELD;
        }
        minD2 = c + b * tm + a * tm * tm;
    }
    if (minD2 <= (r * RCL_BDC_HIT_GATE) * (r * RCL_BDC_HIT_GATE))
    {
        return 1;
    }
    return 0;
}

static float rcl_bdc_wall_cost(float mx, float my, float dx, float dy)
{
    float raw = 0.0f;
    int s;
    for (s = 1; s <= RCL_BDC_WALL_PROBE; s++)
    {
        float d = RCL_BDC_WALL_BAND * (float)s / (float)RCL_BDC_WALL_PROBE;
        if (rcl_wall_is_blocked_wide(mx + dx * d, my + dy * d, RCL_AD_WALL_BODY, RCL_WALL_BLOCKS_MOVEMENT))
        {
            raw += RCL_BDC_WALL_HIT * (float)(RCL_BDC_WALL_PROBE - s + 1);
        }
    }
    return raw;
}

static float rcl_bdc_score_dir(float dx, float dy, float mx, float my, float myR, float speed)
{
    float score = 0.0f;
    int i;
    for (i = 0; i < rcl_bdc_sel_n; i++)
    {
        const rcl_bd_threat_t *p = &rcl_bd_threats[rcl_bdc_sel[i]];
        float r = myR + p->rad + RCL_BD_SAFETY_MARGIN;
        float vx = p->vx - dx * speed;
        float vy = p->vy - dy * speed;
        float px = p->x - mx;
        float py = p->y - my;
        float a = vx * vx + vy * vy;
        float b = 2.0f * (px * vx + py * vy);
        float c = px * px + py * py;
        float tm = 0.0f;
        float minD2 = c;
        if (a > 0.000001f)
        {
            tm = -b / (2.0f * a);
            if (tm < 0.0f)
            {
                tm = 0.0f;
            }
            if (tm > RCL_BDC_T_FIELD)
            {
                tm = RCL_BDC_T_FIELD;
            }
            minD2 = c + b * tm + a * tm * tm;
        }
        if (minD2 < RCL_BDC_EPS)
        {
            minD2 = RCL_BDC_EPS;
        }
        score += RCL_BDC_DANGER * (r * r) / minD2;
    }
    return score;
}

static float rcl_bdc_impact_dir(float dx, float dy, float mx, float my, float myR, float speed)
{
    float best = RCL_BDC_FAR;
    int i;
    for (i = 0; i < rcl_bdc_sel_n; i++)
    {
        const rcl_bd_threat_t *p = &rcl_bd_threats[rcl_bdc_sel[i]];
        float r = myR + p->rad + RCL_BD_SAFETY_MARGIN;
        float vx = p->vx - dx * speed;
        float vy = p->vy - dy * speed;
        float px = p->x - mx;
        float py = p->y - my;
        float a = vx * vx + vy * vy;
        float b = 2.0f * (px * vx + py * vy);
        float c = px * px + py * py - r * r;
        float disc;
        float t1;
        if (c < 0.0f)
        {
            return 0.0f;
        }
        if (a > 0.000001f)
        {
            disc = b * b - 4.0f * a * c;
            if (disc >= 0.0f)
            {
                t1 = (-b - sqrtf(disc)) / (2.0f * a);
                if (t1 > 0.0f && t1 < best)
                {
                    best = t1;
                }
            }
        }
    }
    return best;
}

static float rcl_bdc_threat_d2(int k, float mx, float my)
{
    const rcl_bd_threat_t *p = &rcl_bd_threats[rcl_bdc_sel[k]];
    float dx = p->x - mx;
    float dy = p->y - my;
    return dx * dx + dy * dy;
}

static int rcl_bdc_extra_dirs(float mx, float my)
{
    int first = -1;
    int second = -1;
    int at = RCL_AD_DIR_COUNT;
    int i;
    int j;
    for (i = 0; i < rcl_bdc_sel_n; i++)
    {
        const rcl_bd_threat_t *p = &rcl_bd_threats[rcl_bdc_sel[i]];
        float dx = p->x - mx;
        float dy = p->y - my;
        float d2 = dx * dx + dy * dy;
        float f2;
        float s2;
        if (first < 0)
        {
            first = i;
            continue;
        }
        f2 = rcl_bdc_threat_d2(first, mx, my);
        if (d2 < f2)
        {
            second = first;
            first = i;
            continue;
        }
        if (second < 0)
        {
            second = i;
            continue;
        }
        s2 = rcl_bdc_threat_d2(second, mx, my);
        if (d2 < s2)
        {
            second = i;
        }
    }
    for (j = 0; j < 2; j++)
    {
        int k = (j == 0) ? first : second;
        const rcl_bd_threat_t *p;
        float pxv;
        float pyv;
        float px;
        float py;
        float len;
        if (k < 0 || at + 3 > RCL_BDC_DIR_MAX)
        {
            continue;
        }
        p = &rcl_bd_threats[rcl_bdc_sel[k]];
        pxv = -p->vy;
        pyv = p->vx;
        len = sqrtf(pxv * pxv + pyv * pyv);
        if (len < 0.000001f)
        {
            continue;
        }
        px = pxv / len;
        py = pyv / len;
        rcl_bdc_dirs[at][0] = px;
        rcl_bdc_dirs[at][1] = py;
        rcl_bdc_dirs[at + 1][0] = -px;
        rcl_bdc_dirs[at + 1][1] = -py;
        pxv = (mx - p->x) + px * RCL_BDC_EXTRA_BLEND;
        pyv = (my - p->y) + py * RCL_BDC_EXTRA_BLEND;
        len = sqrtf(pxv * pxv + pyv * pyv);
        if (len < 0.000001f)
        {
            pxv = -px;
            pyv = -py;
            len = 1.0f;
        }
        rcl_bdc_dirs[at + 2][0] = pxv / len;
        rcl_bdc_dirs[at + 2][1] = pyv / len;
        at += 3;
    }
    return at - RCL_AD_DIR_COUNT;
}

static void rcl_bdc_pick(float mx, float my, float myR, float ix, float iy, float speed, float *ox, float *oy)
{
    float rx = ix;
    float ry = iy;
    int hasRef = (ix != 0.0f || iy != 0.0f) ? 1 : 0;
    int refFromThreat = 0;
    int count;
    int i;
    int best = 0;
    int cand;
    int keptPrev = 0;
    int leastBad = 0;
    float bestScore = RCL_BDC_FAR;
    float impactBest;
    float fence;
    float tBest;
    rcl_ad_build_ring();
    for (i = 0; i < RCL_AD_DIR_COUNT; i++)
    {
        rcl_bdc_dirs[i][0] = rcl_ad_ring[i][0];
        rcl_bdc_dirs[i][1] = rcl_ad_ring[i][1];
    }
    rcl_bdc_sel_n = 0;
    for (i = 0; i < rcl_bd_threat_n; i++)
    {
        if (rcl_bdc_aimed_one(&rcl_bd_threats[i], mx, my, myR))
        {
            rcl_bdc_sel[rcl_bdc_sel_n] = i;
            rcl_bdc_sel_n++;
        }
    }
    if (rcl_bdc_sel_n == 0)
    {
        if (!hasRef && rcl_bd_threat_n > 0)
        {
            int nearest = 0;
            float nd = RCL_BDC_FAR;
            for (i = 0; i < rcl_bd_threat_n; i++)
            {
                float dx = rcl_bd_threats[i].x - mx;
                float dy = rcl_bd_threats[i].y - my;
                float d2 = dx * dx + dy * dy;
                if (d2 < nd)
                {
                    nd = d2;
                    nearest = i;
                }
            }
            rx = mx - rcl_bd_threats[nearest].x;
            ry = my - rcl_bd_threats[nearest].y;
            hasRef = 1;
            refFromThreat = 1;
        }
        if (hasRef && (rx != 0.0f || ry != 0.0f))
        {
            float len = sqrtf(rx * rx + ry * ry);
            *ox = rx / len;
            *oy = ry / len;
        }
        else if (rcl_bdc_have_last)
        {
            *ox = rcl_bdc_last_x;
            *oy = rcl_bdc_last_y;
        }
        else
        {
            *ox = 0.0f;
            *oy = 0.0f;
        }
        rcl_bdc_last_x = *ox;
        rcl_bdc_last_y = *oy;
        rcl_bdc_have_last = 1;
        if (rcl_bd_threat_n > 0 && (*ox != 0.0f || *oy != 0.0f))
        {
            int nearest = 0;
            float nd = RCL_BDC_FAR;
            float tdx;
            float tdy;
            float tl;
            float px;
            float py;
            for (i = 0; i < rcl_bd_threat_n; i++)
            {
                float dx = rcl_bd_threats[i].x - mx;
                float dy = rcl_bd_threats[i].y - my;
                float d2 = dx * dx + dy * dy;
                if (d2 < nd)
                {
                    nd = d2;
                    nearest = i;
                }
            }
            tdx = rcl_bd_threats[nearest].x - mx;
            tdy = rcl_bd_threats[nearest].y - my;
            tl = sqrtf(tdx * tdx + tdy * tdy);
            if (tl > 0.001f && (*ox * tdx + *oy * tdy) / tl > 0.90f)
            {
                px = -tdy / tl;
                py = tdx / tl;
                if (*ox * px + *oy * py >= 0.0f)
                {
                    *ox = px;
                    *oy = py;
                }
                else
                {
                    *ox = -px;
                    *oy = -py;
                }
            }
        }
        rcl_bdc_idle++;
        if (rcl_ad_now_ms() - rcl_bdc_log_ms >= 1000)
        {
            rcl_bdc_log_ms = rcl_ad_now_ms();
            rcl_log_info("dodge idle threat=%d aimed=0 dir=%.2f,%.2f idle=%llu dodge=%llu", rcl_bd_threat_n, *ox, *oy,
                         (unsigned long long)rcl_bdc_idle, (unsigned long long)rcl_bdc_seen);
        }
        return;
    }
    count = RCL_AD_DIR_COUNT + rcl_bdc_extra_dirs(mx, my);
    for (i = 0; i < count; i++)
    {
        rcl_bdc_scores[i] = rcl_bdc_score_dir(rcl_bdc_dirs[i][0], rcl_bdc_dirs[i][1], mx, my, myR, speed) +
                            rcl_bdc_wall_cost(mx, my, rcl_bdc_dirs[i][0], rcl_bdc_dirs[i][1]);
        rcl_bdc_impacts[i] = rcl_bdc_impact_dir(rcl_bdc_dirs[i][0], rcl_bdc_dirs[i][1], mx, my, myR, speed);
        if (rcl_bdc_scores[i] < bestScore)
        {
            bestScore = rcl_bdc_scores[i];
            best = i;
        }
    }
    cand = best;
    impactBest = rcl_bdc_impacts[best];
    if (rcl_bdc_have_last && best < RCL_AD_DIR_COUNT)
    {
        int pi = 0;
        float a = atan2f(rcl_bdc_last_y, rcl_bdc_last_x);
        float len = sqrtf(rcl_bdc_last_x * rcl_bdc_last_x + rcl_bdc_last_y * rcl_bdc_last_y);
        if (len > 0.000001f)
        {
            if (a < 0.0f)
            {
                a += 6.283185307179586f;
            }
            pi = (int)(a / 6.283185307179586f * (float)RCL_AD_DIR_COUNT + 0.5f);
            if (pi >= RCL_AD_DIR_COUNT)
            {
                pi = 0;
            }
        }
        if (rcl_bdc_scores[pi] <= bestScore * (1.0f + RCL_BDC_KEEP) &&
            rcl_bdc_impacts[pi] >= impactBest * RCL_BDC_KEEP_IMPACT)
        {
            cand = pi;
            keptPrev = 1;
        }
    }
    if (rcl_bdc_impacts[cand] <= RCL_BDC_T_URGENT)
    {
        int s = -1;
        float sScore = RCL_BDC_FAR;
        keptPrev = 0;
        for (i = 0; i < count; i++)
        {
            if (rcl_bdc_impacts[i] > RCL_BDC_T_URGENT && rcl_bdc_scores[i] < sScore)
            {
                sScore = rcl_bdc_scores[i];
                s = i;
            }
        }
        if (s >= 0)
        {
            cand = s;
        }
        else
        {
            float tMax = -1.0f;
            int lb = cand;
            leastBad = 1;
            fence = rcl_bdc_scores[cand] * RCL_BDC_TIE + RCL_BDC_EPS;
            for (i = 0; i < count; i++)
            {
                if (rcl_bdc_scores[i] <= fence && rcl_bdc_impacts[i] > tMax)
                {
                    tMax = rcl_bdc_impacts[i];
                    lb = i;
                }
            }
            cand = lb;
        }
    }
    if (!leastBad)
    {
        fence = rcl_bdc_scores[cand] * RCL_BDC_TIE + RCL_BDC_EPS;
        tBest = rcl_bdc_impacts[cand];
        for (i = 0; i < count; i++)
        {
            int sameClass = ((rcl_bdc_impacts[i] > RCL_BDC_T_URGENT) == (rcl_bdc_impacts[cand] > RCL_BDC_T_URGENT));
            if (!sameClass || rcl_bdc_scores[i] > fence)
            {
                continue;
            }
            if (rcl_bdc_impacts[i] > tBest * 1.10f)
            {
                tBest = rcl_bdc_impacts[i];
                cand = i;
            }
        }
    }
    *ox = rcl_bdc_dirs[cand][0];
    *oy = rcl_bdc_dirs[cand][1];
    rcl_bdc_last_x = *ox;
    rcl_bdc_last_y = *oy;
    rcl_bdc_have_last = 1;
    rcl_bdc_seen++;
    if (rcl_ad_now_ms() - rcl_bdc_log_ms >= 1000)
    {
        rcl_bdc_log_ms = rcl_ad_now_ms();
        rcl_log_info("dodge seg=%d safe=%d least=%d keep=%d ref=%d threat=%d aimed=%d score=%.0f imp=%.2f dir=%.2f,%.2f dodge=%llu",
                     cand, (rcl_bdc_impacts[cand] > RCL_BDC_T_URGENT) ? 1 : 0, leastBad, keptPrev, refFromThreat, rcl_bd_threat_n,
                     rcl_bdc_sel_n, rcl_bdc_scores[cand], rcl_bdc_impacts[cand], *ox, *oy, (unsigned long long)rcl_bdc_seen);
    }
}

static int rcl_ad_update(float mx, float my)
{
    uint64_t now = rcl_ad_now_ms();
    float speed = 0.0f;
    float myRadius = 0.0f;
    float ix = 0.0f;
    float iy = 0.0f;
    float dirx = 0.0f;
    float diry = 0.0f;
    float tx = 0.0f;
    float ty = 0.0f;
    if (rcl_dead || !rcl_own_elem)
    {
        rcl_bdc_have_last = 0;
        rcl_bdc_last_x = 0.0f;
        rcl_bdc_last_y = 0.0f;
        return 0;
    }
    if (!rcl_ok(mx, -100000000.0f, 100000000.0f))
    {
        return 0;
    }
    if (!rcl_ok(my, -100000000.0f, 100000000.0f))
    {
        return 0;
    }
    if (now - rcl_dodge_speed_ms >= RCL_DODGE_PROBE_MS)
    {
        rcl_dodge_speed_ms = now;
        rcl_dodge_speed_probe();
    }
    rcl_ad_build_ring();
    speed = rcl_dodge_speed;
    myRadius = rcl_own_radius();
    rcl_ad_collect(mx, my, myRadius, now);
    rcl_bd_build_threats();
    if (rcl_bd_threat_n == 0)
    {
        rcl_bdc_have_last = 0;
        rcl_bdc_last_x = 0.0f;
        rcl_bdc_last_y = 0.0f;
        return 0;
    }
    if (!rcl_bd_danger(mx, my, myRadius))
    {
        return 0;
    }
    rcl_bd_intent(&ix, &iy);
    rcl_bdc_pick(mx, my, myRadius, ix, iy, speed, &dirx, &diry);
    if (dirx == 0.0f && diry == 0.0f)
    {
        return 0;
    }
    tx = roundf(mx + dirx * RCL_AD_REACH);
    ty = roundf(my + diry * RCL_AD_REACH);
    rcl_ad_send_move(tx, ty, mx, my);
    return 1;
}

void rcl_autododge(void)
{
    rcl_paircal();
    rcl_obj_t objects[64];
    uintptr_t source = 0;
    int usable = 0;
    int ownIndex = -1;
    int32_t ownTeam = 0;
    int ownX = 0;
    int ownY = 0;
    if (!rcl_base)
    {
        return;
    }
    int sourceIsMode = (rcl_scene_object != 0);
    if (sourceIsMode)
    {
        source = rcl_scene_object;
    }
    else if (rcl_players_object)
    {
        source = rcl_players_object;
    }
    else if (rcl_objvote_best_owner && rcl_objvote_best_teamcount >= RCL_OWNER_VOTE_TEAMS_MIN &&
             rcl_objvote_max_votes >= RCL_OWNER_VOTE_MIN)
    {
        source = rcl_objvote_best_owner;
    }
    else if (rcl_trail_count > 0 && rcl_trail_best >= 0 && rcl_trail_best < rcl_trail_count)
    {
        source = rcl_trail[rcl_trail_best].manager;
    }
    rcl_ticks_a++;
    if (!source)
    {
        return;
    }
    {
        uint64_t probeNow = (uint64_t)(CFAbsoluteTimeGetCurrent() * 1000.0);
        void *resolved = nullptr;
        int changed = (rcl_probe_object != source);
        int managerChanged = 0;
        int periodic = 0;
        if (sourceIsMode && rcl_hop_chosen == 1 && rcl_tick_object)
        {
            resolved = (void *)rcl_tick_object;
        }
        else if (sourceIsMode)
        {
            if (!rcl_read_ptr(source + RCL_MODE_MANAGER_OFF, &resolved) || !resolved)
            {
                resolved = nullptr;
            }
        }
        else
        {
            resolved = (void *)source;
        }
        managerChanged = ((uintptr_t)resolved != rcl_manager_ptr);
        {
            int32_t liveCount = 0;
            if (resolved)
            {
                rcl_read_int((uintptr_t)resolved + RCL_MGR_COUNT_OFF, &liveCount);
            }
            if (resolved && liveCount > 0 && rcl_hop_chosen == 1 &&
                (liveCount != rcl_walk_count ||
                 (rcl_walk_tick != rcl_ticks_b && (rcl_ticks_b % RCL_WALK_EVERY) == 0)))
            {
                rcl_walk_count = liveCount;
                rcl_walk_tick = rcl_ticks_b;
                periodic = 1;
            }
        }
        if (!rcl_probe_done || changed || managerChanged || periodic ||
            (!rcl_coord_ok && probeNow > rcl_probe_last_ms + RCL_REPROBE_MS))
        {
            rcl_probe_object = source;
            rcl_probe_last_ms = probeNow;
            rcl_manager_ptr = (uintptr_t)resolved;
            if (resolved)
            {
                int loud = (changed || managerChanged || !rcl_probe_done);
                rcl_probe((uintptr_t)resolved, rcl_scene_object);
                if (loud)
                {
                    rcl_discriminate((uintptr_t)resolved);
                }
            }
        }
    }
    if (!rcl_coord_ok && rcl_coord_usable < RCL_MIN_USABLE)
    {
        return;
    }
    if (!rcl_scene_object)
    {
        return;
    }
    memset(objects, 0, sizeof(objects));
    usable = rcl_collect(rcl_manager_ptr, objects, 64);
    if (usable < RCL_MIN_USABLE)
    {
        return;
    }
    rcl_own_scan();
    {
        const char *ownFrom = "none";
        if (!rcl_own_latch(objects, usable, &ownIndex, &ownFrom) &&
            !rcl_resolve_own(objects, usable, &ownIndex, &ownFrom) &&
            !rcl_resolve_own_fallback(objects, usable, &ownIndex, &ownFrom))
        {
            return;
        }
        rcl_publish_own(objects[ownIndex].object, ownFrom);
    }
    rcl_own_elem_scan = objects[ownIndex].object;
    ownTeam = (rcl_team_off == (int)RCL_OBJ_TEAM_OFF) ? objects[ownIndex].teamOld
                                                      : objects[ownIndex].teamNew;
    ownX = objects[ownIndex].x;
    ownY = objects[ownIndex].y;
    rcl_death_signals((ownIndex >= 0 && ownIndex < usable) ? objects[ownIndex].object : 0, ownX,
                      ownY);
    rcl_alive(ownX, ownY);
    {
        int32_t projCount = 0;
        if (rcl_manager_ptr)
        {
            rcl_read_int(rcl_manager_ptr + RCL_MGR_COUNT_OFF, &projCount);
        }
        rcl_own_team_a = (int)ownTeam;
        if (ownIndex >= 0 && ownTeam >= 0 && ownTeam <= 15)
        {
            rcl_own_team_seen = 1;
        }
        rcl_roster(rcl_own_elem_scan, ownIndex, (int)ownTeam, objects, usable);
        if (ownIndex < 0 || ownIndex >= usable || ownIndex >= 64)
        {
            return;
        }
        if (rcl_life(objects[ownIndex].object, ownX, ownY))
        {
            return;
        }
        rcl_proj_scan(rcl_manager_ptr, projCount);
        rcl_ad_update((float)ownX, (float)ownY);
    }
}

float rcl_own_radius(void)
{
    if (rcl_own_r <= 1.0f && rcl_own_elem && rcl_rad_off >= 0)
    {
        void *def = nullptr;
        float r = 0.0f;
        if (rcl_read_ptr(rcl_own_elem + (uintptr_t)RCL_ELEM_DEF_OFF, &def) && def &&
            rcl_read_float((uintptr_t)def + (uintptr_t)rcl_rad_off, &r) && r > 1.0f && r < 600.0f)
        {
            rcl_own_r = r;
        }
    }
    return rcl_own_r > 1.0f ? rcl_own_r : 0.0f;
}

int rcl_proj_vel(const rcl_proj_t *p, float *vxOut, float *vyOut)
{
    float dt = 0.0f;
    if (!p->elem || !p->hasPrev)
    {
        return 0;
    }
    dt = (float)(p->qms - p->pms);
    if (dt < RCL_AD_DT_MIN || dt > RCL_AD_TICK_MAX_MS)
    {
        dt = RCL_AD_TICK_MS;
    }
    *vxOut = (float)(p->x - p->px) * 1000.0f / dt;
    *vyOut = (float)(p->y - p->py) * 1000.0f / dt;
    return 1;
}
