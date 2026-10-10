#include "../recoil.h"

#define RCL_AIM_HIST 10
#define RCL_AIM_SHOT_SPEED_FALLBACK 2600.0f
#define RCL_AIM_SHOT_SPEED_MIN 400.0f
#define RCL_AIM_SHOT_SPEED_MAX 12000.0f
#define RCL_AIM_VEL_DEAD 14.0f
#define RCL_AIM_COORD_MAX 200000.0f
#define RCL_AIM_CONF_MIN 0.20f
#define RCL_AIM_LATENCY 0.033f
#define RCL_AIM_T_MAX 2.50f
#define RCL_AIM_LEAD_MAX 6000.0f
#define RCL_AIM_LEAD_HEADROOM 4.0f
#define RCL_AIM_LEAD_RATIO_MAX 2.0f

static uintptr_t rcl_aim_hist_id = 0;
static uintptr_t rcl_aim_lock = 0;
static int rcl_aim_hist_n = 0;
static int rcl_aim_hist_at = 0;
static float rcl_aim_hist_x[RCL_AIM_HIST];
static float rcl_aim_hist_y[RCL_AIM_HIST];
static uint64_t rcl_aim_hist_ms[RCL_AIM_HIST];

static float rcl_aim_own_speed = 0.0f;
static uintptr_t rcl_aim_own_char = 0;
static const char *rcl_aim_own_code = nullptr;

static void rcl_aim_own_reset(void)
{
    rcl_aim_own_speed = 0.0f;
    rcl_aim_own_code = nullptr;
}

static float rcl_aim_shot_speed(void)
{
    float sum = 0.0f;
    float avg;
    int n = 0;
    int i;
    for (i = 0; i < 16; i++)
    {
        const rcl_proj_t *p = &rcl_projs[i];
        float spd;
        if (!p->elem)
        {
            continue;
        }
        if (!rcl_own_team_seen || p->team < 0 || p->team != rcl_own_team_a)
        {
            continue;
        }
        if (p->name)
        {
            const rcl_aim_ahead_t *own = rcl_aim_ahead_by_projectile(p->name);
            if (own)
            {
                rcl_aim_own_code = own->code;
            }
        }
        spd = sqrtf(p->vx * p->vx + p->vy * p->vy);
        if (spd < RCL_AIM_SHOT_SPEED_MIN || spd > RCL_AIM_SHOT_SPEED_MAX)
        {
            continue;
        }
        sum += spd;
        n++;
    }
    if (n > 0)
    {
        avg = sum / (float)n;
        if (avg >= RCL_AIM_SHOT_SPEED_MIN && avg <= RCL_AIM_SHOT_SPEED_MAX)
        {
            rcl_aim_own_speed = avg;
            return avg;
        }
    }
    if (rcl_aim_own_speed >= RCL_AIM_SHOT_SPEED_MIN && rcl_aim_own_speed <= RCL_AIM_SHOT_SPEED_MAX)
    {
        return rcl_aim_own_speed;
    }
    if (rcl_aim_own_code)
    {
        float known = (float)rcl_aim_ahead_speed(rcl_aim_own_code);
        if (known >= RCL_AIM_SHOT_SPEED_MIN && known <= RCL_AIM_SHOT_SPEED_MAX)
        {
            return known;
        }
    }
    return RCL_AIM_SHOT_SPEED_FALLBACK;
}

static void rcl_aim_hist_reset(uintptr_t id)
{
    rcl_aim_hist_id = id;
    rcl_aim_hist_n = 0;
    rcl_aim_hist_at = 0;
}

static void rcl_aim_hist_push(float x, float y)
{
    uint64_t now = (uint64_t)(CFAbsoluteTimeGetCurrent() * 1000.0);
    rcl_aim_hist_x[rcl_aim_hist_at] = x;
    rcl_aim_hist_y[rcl_aim_hist_at] = y;
    rcl_aim_hist_ms[rcl_aim_hist_at] = now;
    rcl_aim_hist_at = (rcl_aim_hist_at + 1) % RCL_AIM_HIST;
    if (rcl_aim_hist_n < RCL_AIM_HIST)
    {
        rcl_aim_hist_n++;
    }
}

static int rcl_aim_target_vel(float *vxOut, float *vyOut, float *confOut)
{
    float tvx = 0.0f;
    float tvy = 0.0f;
    float wsum = 0.0f;
    float lvx = 0.0f;
    float lvy = 0.0f;
    float agree;
    float lmag;
    int i;
    *vxOut = 0.0f;
    *vyOut = 0.0f;
    *confOut = 0.0f;
    if (rcl_aim_hist_n < 2)
    {
        return 0;
    }
    for (i = 1; i < rcl_aim_hist_n; i++)
    {
        int a = (rcl_aim_hist_at - i - 1 + RCL_AIM_HIST * 2) % RCL_AIM_HIST;
        int b = (rcl_aim_hist_at - i + RCL_AIM_HIST * 2) % RCL_AIM_HIST;
        float dt = (float)(rcl_aim_hist_ms[b] - rcl_aim_hist_ms[a]) / 1000.0f;
        float w = (float)(rcl_aim_hist_n - i);
        float sx;
        float sy;
        if (dt <= 0.0f)
        {
            continue;
        }
        sx = (rcl_aim_hist_x[b] - rcl_aim_hist_x[a]) / dt;
        sy = (rcl_aim_hist_y[b] - rcl_aim_hist_y[a]) / dt;
        tvx += sx * w;
        tvy += sy * w;
        wsum += w;
        if (i == 1)
        {
            lvx = sx;
            lvy = sy;
        }
    }
    if (wsum <= 0.0f)
    {
        return 0;
    }
    tvx /= wsum;
    tvy /= wsum;
    if (tvx * tvx + tvy * tvy < RCL_AIM_VEL_DEAD * RCL_AIM_VEL_DEAD)
    {
        return 0;
    }
    lmag = sqrtf(lvx * lvx + lvy * lvy);
    if (lmag < RCL_AIM_VEL_DEAD)
    {
        return 0;
    }
    agree = (lvx * tvx + lvy * tvy) / (lmag * sqrtf(tvx * tvx + tvy * tvy));
    if (agree < RCL_AIM_CONF_MIN)
    {
        return 0;
    }
    *vxOut = tvx;
    *vyOut = tvy;
    *confOut = agree;
    return 1;
}

static float rcl_aim_intercept_iter(float px, float py, float tvx, float tvy, float shot)
{
    float dist = sqrtf(px * px + py * py);
    float t;
    int k;
    if (shot <= 1.0f)
    {
        return 0.0f;
    }
    t = dist / shot;
    for (k = 0; k < 4; k++)
    {
        float ax = px + tvx * t;
        float ay = py + tvy * t;
        t = sqrtf(ax * ax + ay * ay) / shot;
    }
    if (!(t == t) || t < 0.0f)
    {
        return dist / shot;
    }
    if (t > RCL_AIM_T_MAX)
    {
        t = RCL_AIM_T_MAX;
    }
    return t;
}

static float rcl_aim_lead_ceiling(float tvx, float tvy)
{
    const rcl_aim_ahead_t *row;
    int base;
    float speed;
    float ratio;
    if (!rcl_aim_own_code)
    {
        return RCL_AIM_LEAD_MAX;
    }
    row = rcl_aim_ahead_of(rcl_aim_own_code);
    if (!row)
    {
        return RCL_AIM_LEAD_MAX;
    }
    if (row->flags & (RCL_AIM_AHEAD_LOBBED | RCL_AIM_AHEAD_BEAM | RCL_AIM_AHEAD_MELEE))
    {
        return RCL_AIM_LEAD_MAX;
    }
    base = rcl_aim_ahead_lead(rcl_aim_own_code);
    if (base <= 0)
    {
        return RCL_AIM_LEAD_MAX;
    }
    speed = sqrtf(tvx * tvx + tvy * tvy);
    ratio = speed / (float)RCL_AIM_AHEAD_ENEMY_SPEED;
    if (ratio < 1.0f)
    {
        ratio = 1.0f;
    }
    if (ratio > RCL_AIM_LEAD_RATIO_MAX)
    {
        ratio = RCL_AIM_LEAD_RATIO_MAX;
    }
    return (float)base * RCL_AIM_LEAD_HEADROOM * ratio;
}

static int rcl_aim_lead(float px, float py, float *ox, float *oy)
{
    float tvx = 0.0f;
    float tvy = 0.0f;
    float conf = 0.0f;
    float shot;
    float t;
    float lead;
    float ceiling;
    *ox = 0.0f;
    *oy = 0.0f;
    if (!rcl_aim_target_vel(&tvx, &tvy, &conf))
    {
        return 0;
    }
    shot = rcl_aim_shot_speed();
    t = rcl_aim_intercept_iter(px, py, tvx, tvy, shot) + RCL_AIM_LATENCY;
    if (t > RCL_AIM_T_MAX)
    {
        t = RCL_AIM_T_MAX;
    }
    *ox = tvx * t;
    *oy = tvy * t;
    lead = sqrtf((*ox) * (*ox) + (*oy) * (*oy));
    ceiling = rcl_aim_lead_ceiling(tvx, tvy);
    if (lead > ceiling)
    {
        *ox = (*ox) / lead * ceiling;
        *oy = (*oy) / lead * ceiling;
    }
    return 1;
}

void rcl_run_autoaim(void)
{
    if (!rcl_flag_state("aimbot"))
    {
        return;
    }
    if (!rcl_addr_getinstance || !rcl_addr_getownchar || !rcl_addr_battlescreen)
    {
        return;
    }
    void *battleMode = ((fn_get_inst_t)rcl_addr_getinstance)();
    if (!rcl_object_plausible(battleMode))
    {
        return;
    }
    void *ownChar = ((fn_get_own_char_t)rcl_addr_getownchar)(battleMode);
    if (!rcl_object_plausible(ownChar))
    {
        return;
    }
    if (rcl_aim_own_char != (uintptr_t)ownChar)
    {
        rcl_aim_own_char = (uintptr_t)ownChar;
        rcl_aim_own_reset();
    }
    int ownX = rcl_addr_getx ? ((fn_get_coord_t)rcl_addr_getx)(ownChar) : 0;
    int ownY = rcl_addr_gety ? ((fn_get_coord_t)rcl_addr_gety)(ownChar) : 0;
    int ownTeam = rcl_addr_getteam ? ((fn_get_team_t)rcl_addr_getteam)(battleMode) : 0;
    void *objMgr = nullptr;
    if (!rcl_read_ptr((uintptr_t)battleMode + RCL_MODE_MANAGER_OFF, &objMgr))
    {
        return;
    }
    if (!rcl_object_plausible(objMgr))
    {
        return;
    }
    void *rawObjects = nullptr;
    int32_t count = 0;
    if (!rcl_read_ptr((uintptr_t)objMgr + RCL_MGR_ARRAY_OFF, &rawObjects))
    {
        return;
    }
    if (!rcl_read_int((uintptr_t)objMgr + RCL_MGR_COUNT_OFF, &count))
    {
        return;
    }
    void **objects = (void **)rawObjects;
    if (!objects || count <= 0)
    {
        return;
    }
    if (count > SCAN_MAX)
    {
        count = SCAN_MAX;
    }
    if (!rcl_addr_readable((uintptr_t)objects, (size_t)count * sizeof(void *)))
    {
        rcl_aim_lock = 0;
        return;
    }
    void *probe = nullptr;
    if (!rcl_read_ptr((uintptr_t)objects, &probe))
    {
        return;
    }
    if (count > 1 &&
        !rcl_read_ptr((uintptr_t)objects + (uintptr_t)(count - 1) * sizeof(void *), &probe))
    {
        return;
    }
    float closestDistSq = 1.0e18f;
    float closestDistSqBlind = 1.0e18f;
    float lockDistSq = 0.0f;
    int targetX = 0;
    int targetY = 0;
    int blindX = 0;
    int blindY = 0;
    int lockX = 0;
    int lockY = 0;
    int lockSeen = 0;
    void *bestObj = nullptr;
    void *blindObj = nullptr;
    BOOL found = NO;
    for (int i = 0; i < count; i++)
    {
        void *obj = objects[i];
        if (!obj || obj == ownChar)
        {
            continue;
        }
        if (!rcl_object_plausible(obj))
        {
            continue;
        }
        uint8_t objDead = 0;
        if (!rcl_read_byte((uintptr_t)obj + RCL_OBJ_DEADFLAG_OFF, &objDead))
        {
            continue;
        }
        if (objDead)
        {
            continue;
        }
        int32_t team = 0;
        if (!rcl_read_int((uintptr_t)obj + RCL_OBJ_TEAM_OFF, &team))
        {
            continue;
        }
        if (team == ownTeam)
        {
            continue;
        }
        int ex = rcl_addr_getx ? ((fn_get_coord_t)rcl_addr_getx)(obj) : 0;
        int ey = rcl_addr_gety ? ((fn_get_coord_t)rcl_addr_gety)(obj) : 0;
        float dx = (float)(ex - ownX);
        float dy = (float)(ey - ownY);
        float distSq = dx * dx + dy * dy;
        if (obj == (void *)rcl_aim_lock && distSq > 1.0f)
        {
            lockDistSq = distSq;
            lockX = ex;
            lockY = ey;
            lockSeen = 1;
        }
        if (distSq > 1.0f && distSq < closestDistSqBlind)
        {
            closestDistSqBlind = distSq;
            blindX = ex;
            blindY = ey;
            blindObj = obj;
        }
        if (distSq <= 1.0f || distSq >= closestDistSq)
        {
            continue;
        }
        if (!rcl_wall_los((float)ownX, (float)ownY, (float)ex, (float)ey,
                          RCL_WALL_BLOCKS_PROJECTILES))
        {
            continue;
        }
        closestDistSq = distSq;
        targetX = ex;
        targetY = ey;
        bestObj = obj;
        found = YES;
    }
    if (lockSeen && (!found || lockDistSq <= closestDistSq * 1.25f))
    {
        targetX = lockX;
        targetY = lockY;
        bestObj = (void *)rcl_aim_lock;
        found = YES;
    }
    if (!found && closestDistSqBlind < 1.0e18f)
    {
        targetX = blindX;
        targetY = blindY;
        bestObj = blindObj;
        found = YES;
    }
    if (!found)
    {
        rcl_aim_lock = 0;
        return;
    }
    rcl_aim_lock = (uintptr_t)bestObj;
    {
        float px = (float)(targetX - ownX);
        float py = (float)(targetY - ownY);
        float lx = 0.0f;
        float ly = 0.0f;
        if ((uintptr_t)bestObj != rcl_aim_hist_id)
        {
            rcl_aim_hist_reset((uintptr_t)bestObj);
        }
        rcl_aim_hist_push((float)targetX, (float)targetY);
        if (rcl_aim_lead(px, py, &lx, &ly))
        {
            targetX += (int)lx;
            targetY += (int)ly;
        }
    }
    if (!rcl_ok((float)targetX, -RCL_AIM_COORD_MAX, RCL_AIM_COORD_MAX) ||
        !rcl_ok((float)targetY, -RCL_AIM_COORD_MAX, RCL_AIM_COORD_MAX))
    {
        return;
    }
    void *screen = nullptr;
    if (!rcl_read_ptr(rcl_addr_battlescreen, &screen))
    {
        return;
    }
    if (!rcl_object_plausible(screen))
    {
        if (!rcl_aim_rejected)
        {
            rcl_aim_rejected = YES;
        }
        return;
    }
    uintptr_t fireX = (uintptr_t)screen + OFF_BATTLESCREEN_AUTOFIREX;
    uintptr_t fireY = (uintptr_t)screen + OFF_BATTLESCREEN_AUTOFIREY;
    if (!rcl_addr_writable(fireX, 4) || !rcl_addr_writable(fireY, 4))
    {
        if (!rcl_aim_rejected)
        {
            rcl_aim_rejected = YES;
        }
        return;
    }
    *(int32_t *)fireX = targetX;
    *(int32_t *)fireY = targetY;
}
