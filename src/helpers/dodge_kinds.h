#ifndef RECOIL_HELPERS_DODGE_KINDS_H
#define RECOIL_HELPERS_DODGE_KINDS_H

#include "../core/offsets.h"
#include <stdint.h>

typedef struct
{
    uintptr_t elem;
    uintptr_t classRva;
    int32_t x;
    int32_t y;
    int32_t px;
    int32_t py;
    int32_t team;
    int32_t spawnX;
    int32_t spawnY;
    int32_t gid;
    uint64_t pms;
    uint64_t qms;
    int hasPrev;
    const char *name;
    int32_t targetX;
    int32_t targetY;
    float radius;
    float angle;
    uint64_t spawnedAt;
    float vx;
    float vy;
    int isThrower;
    int isBeam;
    int32_t spawnAreaRadius;
    int32_t spawnAreaActiveTime;
    int32_t castRange;
} rcl_proj_t;

#define RCL_FIT_COUNT 9
#define RCL_KIND_COUNT 755

#define RCL_FIT_FALLBACK 8

#define RCL_K_BLOB 0x01
#define RCL_K_LOCKPATH 0x02
#define RCL_K_DROP 0x04
#define RCL_K_FADE 0x08

typedef struct
{
    float grow;
    float pad;
} rcl_fit_t;

typedef struct
{
    const char *name;
    int8_t fit;
    uint8_t flags;
    int16_t reachAdj;
    int32_t maxRange;
    int32_t chargedRange;
    int32_t growR;
    float speedMul;
    float fadeBase;
    float fadeK;
} rcl_kind_t;

float rcl_proj_radius(const rcl_proj_t *p, float speed);
int rcl_kind_index(const char *name);
const rcl_kind_t *rcl_kind_of(const char *name);
const rcl_fit_t *rcl_fit_of(const char *name);

#endif
