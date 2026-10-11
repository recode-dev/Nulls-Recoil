#ifndef RECOIL_HELPERS_DODGE_PROFILES_H
#define RECOIL_HELPERS_DODGE_PROFILES_H

#include "../core/offsets.h"
#include <stdint.h>
#include "./dodge_kinds.h"

typedef struct
{
    const char *name;
    float angle;
    int32_t spawnX;
    int32_t spawnY;
    int32_t x;
    int32_t y;
} rcl_proj_death_t;

#define RCL_OWNER_VOTE_MIN 3
#define RCL_OWNER_VOTE_TEAMS_MIN 2
#define RCL_MIN_USABLE_2 1
#define RCL_MIN_USABLE 1
#define RCL_REPROBE_MS 5000
#define RCL_PROJ_RADIUS_DEFAULT 150.0f
#define RCL_OWN_RADIUS_MIN 40.0f
#define RCL_OWN_RADIUS_MAX 200.0f

typedef struct
{
    int has_segment;
    float x;
    float y;
    float radius;
    float t0;
    float t1;
    float ax;
    float ay;
    float bx;
    float by;
    const char *name;
} rcl_hazard_t;

int rcl_shape_hazards(const rcl_proj_t *p, uint64_t now_ms, rcl_hazard_t *out, int max_out);
int rcl_blocks_linear(const char *name);
void rcl_note_burst_death(const rcl_proj_death_t *rec);

#endif
