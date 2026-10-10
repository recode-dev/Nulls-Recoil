#include "../recoil.h"

static uintptr_t rcl_assist_lock = 0;
static uintptr_t rcl_assist_vel_id = 0;
static int32_t rcl_assist_vel_x = 0;
static int32_t rcl_assist_vel_y = 0;
static uint64_t rcl_assist_vel_ms = 0;
static float rcl_assist_seen_vx = 0.0f;
static float rcl_assist_seen_vy = 0.0f;
static uint64_t rcl_assist_shot_ms = 0;

void rcl_assist_reset(void)
{
    rcl_assist_lock = 0;
    rcl_assist_vel_id = 0;
    rcl_assist_vel_ms = 0;
    rcl_assist_seen_vx = 0.0f;
    rcl_assist_seen_vy = 0.0f;
    rcl_assist_shot_ms = 0;
}

static uint64_t rcl_assist_now(void)
{
    return (uint64_t)(CFAbsoluteTimeGetCurrent() * 1000.0);
}

uintptr_t rcl_assist_own(void)
{
    if (rcl_own_elem && rcl_object_plausible((void *)rcl_own_elem))
    {
        return rcl_own_elem;
    }
    return 0;
}

void *rcl_assist_skill(uintptr_t elem)
{
    void *data = nullptr;
    void *skill = nullptr;
    if (!elem)
    {
        return nullptr;
    }
    if (!rcl_read_ptr(elem + (uintptr_t)RCL_ELEM_DEF_OFF, &data) || !data)
    {
        return nullptr;
    }
    if (!rcl_pointer_plausible((uintptr_t)data))
    {
        return nullptr;
    }
    if (!rcl_read_ptr((uintptr_t)data + (uintptr_t)OFF_CHARDATA_WEAPONSKILL, &skill) || !skill)
    {
        return nullptr;
    }
    if (!rcl_pointer_plausible((uintptr_t)skill))
    {
        return nullptr;
    }
    return skill;
}

static int rcl_assist_linked(void *skill)
{
    int32_t kind = 0;
    if (!skill)
    {
        return 0;
    }
    if (!rcl_read_int((uintptr_t)skill + (uintptr_t)OFF_SKILLDATA_BEHAVIORTYPE, &kind))
    {
        return 0;
    }
    return kind == RCL_ASSIST_LINKED_BEHAVIOR ? 1 : 0;
}

int rcl_assist_range(uintptr_t elem, const char *code)
{
    void *skill = rcl_assist_skill(elem);
    const rcl_aim_ahead_t *row = nullptr;
    int32_t tiles = 0;
    if (skill && !rcl_assist_linked(skill) &&
        rcl_read_int((uintptr_t)skill + (uintptr_t)OFF_SKILLDATA_CASTINGRANGE, &tiles) &&
        tiles >= RCL_ASSIST_TILE_MIN && tiles <= RCL_ASSIST_TILE_MAX)
    {
        return tiles * RCL_ASSIST_TILE;
    }
    row = code ? rcl_aim_ahead_of(code) : nullptr;
    return row ? row->range : 0;
}

int rcl_assist_interval(uintptr_t elem)
{
    void *skill = rcl_assist_skill(elem);
    int32_t ms = 0;
    if (skill && rcl_read_int((uintptr_t)skill + (uintptr_t)OFF_SKILLDATA_MSBETWEENATTACKS, &ms))
    {
        if (ms >= RCL_ASSIST_INTERVAL_MIN && ms <= RCL_ASSIST_INTERVAL_MAX)
        {
            return ms;
        }
    }
    return RCL_ASSIST_INTERVAL;
}

int rcl_assist_speed(uintptr_t elem, const char *code)
{
    void *skill = rcl_assist_skill(elem);
    void *list = nullptr;
    void *projectile = nullptr;
    const rcl_aim_ahead_t *row = nullptr;
    int32_t speed = 0;
    if (skill && rcl_read_ptr((uintptr_t)skill + (uintptr_t)OFF_SKILLDATA_PROJECTILES, &list) &&
        list && rcl_pointer_plausible((uintptr_t)list) &&
        rcl_read_ptr((uintptr_t)list, &projectile) && projectile &&
        rcl_pointer_plausible((uintptr_t)projectile) &&
        rcl_read_int((uintptr_t)projectile + (uintptr_t)OFF_PROJECTILEDATA_SPEED, &speed))
    {
        if (speed >= RCL_ASSIST_SPEED_MIN && speed <= RCL_ASSIST_SPEED_MAX)
        {
            return speed;
        }
    }
    row = code ? rcl_aim_ahead_of(code) : nullptr;
    return row ? row->shotSpeed : 0;
}

static int rcl_assist_chain_ok(uintptr_t elem)
{
    void *skill = rcl_assist_skill(elem);
    if (!skill)
    {
        return 0;
    }
    if (rcl_assist_linked(skill))
    {
        return 0;
    }
    return rcl_assist_range(elem, nullptr) > 0;
}

static const char *rcl_assist_code(void)
{
    int i = 0;
    for (i = 0; i < 16; i++)
    {
        const rcl_proj_t *proj = &rcl_projs[i];
        const rcl_aim_ahead_t *row = nullptr;
        if (!proj->elem || !proj->name)
        {
            continue;
        }
        if (!rcl_own_team_seen || proj->team != rcl_own_team_a)
        {
            continue;
        }
        row = rcl_aim_ahead_by_projectile(proj->name);
        if (row)
        {
            return row->code;
        }
    }
    return nullptr;
}

static int rcl_assist_team(const rcl_obj_t *object)
{
    return (rcl_team_off == (int)RCL_OBJ_TEAM_OFF) ? object->teamOld : object->teamNew;
}

static int rcl_assist_reachable(const rcl_obj_t *object, int32_t myX, int32_t myY)
{
    if (object->dead)
    {
        return 0;
    }
    if (rcl_assist_team(object) == rcl_own_team_a)
    {
        return 0;
    }
    return rcl_wall_los((float)myX, (float)myY, (float)object->x, (float)object->y,
                        RCL_WALL_BLOCKS_PROJECTILES);
}

int rcl_assist_pick(uintptr_t elem, int32_t myX, int32_t myY, int range, rcl_assist_target_t *out)
{
    rcl_obj_t objects[RCL_ASSIST_TARGET_MAX];
    uintptr_t manager = rcl_manager_ptr ? rcl_manager_ptr : rcl_players_object;
    int usable = 0;
    int i = 0;
    int stickyRange = range + RCL_ASSIST_STICKY;
    float limit = (float)range * (float)range;
    float best = 0.0f;
    int found = 0;
    if (!out || range <= 0 || !manager)
    {
        return 0;
    }
    if (!rcl_own_team_seen)
    {
        return 0;
    }
    usable = rcl_collect(manager, objects, RCL_ASSIST_TARGET_MAX);
    if (usable <= 0)
    {
        return 0;
    }
    if (usable > RCL_ASSIST_TARGET_MAX)
    {
        usable = RCL_ASSIST_TARGET_MAX;
    }
    if (rcl_assist_lock)
    {
        for (i = 0; i < usable; i++)
        {
            const rcl_obj_t *object = &objects[i];
            float dx = 0.0f;
            float dy = 0.0f;
            float distance = 0.0f;
            if (object->object != rcl_assist_lock)
            {
                continue;
            }
            dx = (float)(object->x - myX);
            dy = (float)(object->y - myY);
            distance = dx * dx + dy * dy;
            if (distance < (float)stickyRange * (float)stickyRange && object->object != elem &&
                rcl_assist_reachable(object, myX, myY))
            {
                out->object = object->object;
                out->gid = object->gid;
                out->x = object->x;
                out->y = object->y;
                out->distanceSq = distance;
                return 1;
            }
            break;
        }
        rcl_assist_lock = 0;
    }
    best = limit;
    for (i = 0; i < usable; i++)
    {
        const rcl_obj_t *object = &objects[i];
        float dx = 0.0f;
        float dy = 0.0f;
        float distance = 0.0f;
        if (!object->object || object->object == elem)
        {
            continue;
        }
        dx = (float)(object->x - myX);
        dy = (float)(object->y - myY);
        distance = dx * dx + dy * dy;
        if (distance <= 1.0f || distance >= best)
        {
            continue;
        }
        if (!rcl_assist_reachable(object, myX, myY))
        {
            continue;
        }
        best = distance;
        out->object = object->object;
        out->gid = object->gid;
        out->x = object->x;
        out->y = object->y;
        out->distanceSq = distance;
        found = 1;
    }
    if (!found)
    {
        return 0;
    }
    rcl_assist_lock = out->object;
    return 1;
}

int rcl_assist_aim(uintptr_t screen, int32_t aimX, int32_t aimY)
{
    uintptr_t fireX = 0;
    uintptr_t fireY = 0;
    if (!screen)
    {
        return 0;
    }
    fireX = screen + (uintptr_t)OFF_BATTLESCREEN_AUTOFIREX;
    fireY = screen + (uintptr_t)OFF_BATTLESCREEN_AUTOFIREY;
    if (!rcl_addr_writable(fireX, 4) || !rcl_addr_writable(fireY, 4))
    {
        return 0;
    }
    if (!rcl_write_bytes(fireX, &aimX, sizeof(aimX)))
    {
        return 0;
    }
    if (!rcl_write_bytes(fireY, &aimY, sizeof(aimY)))
    {
        return 0;
    }
    return 1;
}

int rcl_assist_cast(uintptr_t elem, int32_t dx, int32_t dy)
{
    void *skill = nullptr;
    if (!rcl_assist_chain_ok(elem))
    {
        return 0;
    }
    skill = rcl_assist_skill(elem);
    if (!skill)
    {
        return 0;
    }
    return rcl_enqueue_skill((int)dx, (int)dy, (int)RCL_ATTACK_COMMANDTYPE, skill);
}

static void rcl_assist_velocity(uintptr_t object, int32_t x, int32_t y, uint64_t now)
{
    float dt = 0.0f;
    if (rcl_assist_vel_id != object || !rcl_assist_vel_ms)
    {
        rcl_assist_vel_id = object;
        rcl_assist_vel_x = x;
        rcl_assist_vel_y = y;
        rcl_assist_vel_ms = now;
        rcl_assist_seen_vx = 0.0f;
        rcl_assist_seen_vy = 0.0f;
        return;
    }
    if (now <= rcl_assist_vel_ms)
    {
        return;
    }
    dt = (float)(now - rcl_assist_vel_ms) / 1000.0f;
    rcl_assist_seen_vx = (float)(x - rcl_assist_vel_x) / dt;
    rcl_assist_seen_vy = (float)(y - rcl_assist_vel_y) / dt;
    rcl_assist_vel_x = x;
    rcl_assist_vel_y = y;
    rcl_assist_vel_ms = now;
}

static float rcl_assist_intercept(float px, float py, float vx, float vy, float speed)
{
    float t = 0.0f;
    int i = 0;
    if (speed <= 1.0f)
    {
        return 0.0f;
    }
    t = sqrtf(px * px + py * py) / speed;
    for (i = 0; i < RCL_ASSIST_ITER; i++)
    {
        float ax = px + vx * t;
        float ay = py + vy * t;
        t = sqrtf(ax * ax + ay * ay) / speed;
    }
    if (!(t == t) || t < 0.0f)
    {
        return 0.0f;
    }
    if (t > RCL_ASSIST_LEAD_TMAX)
    {
        t = RCL_ASSIST_LEAD_TMAX;
    }
    return t;
}

void rcl_run_assist(void)
{
    uintptr_t screen = 0;
    uintptr_t elem = 0;
    const char *code = nullptr;
    rcl_assist_target_t target;
    uint64_t now = 0;
    int32_t myX = 0;
    int32_t myY = 0;
    int range = 0;
    int speed = 0;
    int interval = 0;
    float leadX = 0.0f;
    float leadY = 0.0f;
    int32_t fireX = 0;
    int32_t fireY = 0;
    if (!rcl_flag_state("assist"))
    {
        return;
    }
    screen = rcl_controller();
    elem = rcl_assist_own();
    if (!screen || !elem)
    {
        return;
    }
    if (!rcl_own(&myX, &myY))
    {
        return;
    }
    if (myX < (int32_t)-RCL_ASSIST_COORD_MAX || myX > (int32_t)RCL_ASSIST_COORD_MAX ||
        myY < (int32_t)-RCL_ASSIST_COORD_MAX || myY > (int32_t)RCL_ASSIST_COORD_MAX)
    {
        return;
    }
    code = rcl_assist_code();
    range = rcl_assist_range(elem, code);
    memset(&target, 0, sizeof(target));
    if (!rcl_assist_pick(elem, myX, myY, range, &target))
    {
        rcl_assist_reset();
        return;
    }
    speed = rcl_assist_speed(elem, code);
    interval = rcl_assist_interval(elem);
    now = rcl_assist_now();
    rcl_assist_velocity(target.object, target.x, target.y, now);
    leadX = (float)(target.x - myX);
    leadY = (float)(target.y - myY);
    if (speed > 0)
    {
        float t = rcl_assist_intercept(leadX, leadY, rcl_assist_seen_vx, rcl_assist_seen_vy,
                                       (float)speed) +
                  RCL_ASSIST_LATENCY;
        if (t > RCL_ASSIST_LEAD_TMAX)
        {
            t = RCL_ASSIST_LEAD_TMAX;
        }
        leadX += rcl_assist_seen_vx * t;
        leadY += rcl_assist_seen_vy * t;
    }
    fireX = myX + (int32_t)leadX;
    fireY = myY + (int32_t)leadY;
    if (fireX < (int32_t)-RCL_ASSIST_COORD_MAX || fireX > (int32_t)RCL_ASSIST_COORD_MAX ||
        fireY < (int32_t)-RCL_ASSIST_COORD_MAX || fireY > (int32_t)RCL_ASSIST_COORD_MAX)
    {
        return;
    }
    rcl_assist_aim(screen, fireX, fireY);
    if (rcl_assist_shot_ms && (now - rcl_assist_shot_ms) < (uint64_t)interval)
    {
        return;
    }
    rcl_assist_cast(elem, fireX - myX, fireY - myY);
    rcl_assist_shot_ms = now;
}
