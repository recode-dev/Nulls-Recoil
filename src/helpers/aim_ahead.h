#ifndef RECOIL_HELPERS_AIM_AHEAD_H
#define RECOIL_HELPERS_AIM_AHEAD_H

#include "../core/offsets.h"
#include "../utils/brawlers.h"
#include <stdint.h>

#define RCL_AIM_AHEAD_TILE 300
#define RCL_AIM_AHEAD_ENEMY_SPEED 750
#define RCL_AIM_AHEAD_LOBBED 0x01
#define RCL_AIM_AHEAD_BEAM 0x02
#define RCL_AIM_AHEAD_MELEE 0x04
#define RCL_AIM_AHEAD_DEFAULT 507

typedef struct
{
    const char *code;
    int16_t shotSpeed;
    int16_t range;
    float ahead;
    uint8_t flags;
} rcl_aim_ahead_t;

const rcl_aim_ahead_t *rcl_aim_ahead_of(const char *name);
int rcl_aim_ahead_lead(const char *name);
int rcl_aim_ahead_speed(const char *name);
const rcl_aim_ahead_t *rcl_aim_ahead_by_projectile(const char *projName);

#endif
