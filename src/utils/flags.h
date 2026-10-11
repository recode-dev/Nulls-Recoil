#ifndef RECOIL_UTILS_FLAGS_H
#define RECOIL_UTILS_FLAGS_H

#include "../core/offsets.h"

#define RCL_FEATURE_MAX 16

#define RCL_FLAG_AIMBOT (1u << 0)
#define RCL_FLAG_AUTODODGE (1u << 1)

void rcl_flag_set(const char *name, int value);
int rcl_flag_state(const char *name);
int rcl_feature_setup(const char *label, void (*setup)(void));

#endif
