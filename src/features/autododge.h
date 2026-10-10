#ifndef RECOIL_FEATURES_AUTODODGE_AUTODODGE_H
#define RECOIL_FEATURES_AUTODODGE_AUTODODGE_H

#include "../core/offsets.h"
#include "../helpers/dodge_kinds.h"

extern __thread int rcl_in_move;
extern int32_t rcl_pl_mine[12];

extern int rcl_cand_now[3];
extern int rcl_cand_seen;
extern int32_t rcl_prev_x;
extern int32_t rcl_prev_y;

int rcl_proj_vel(const rcl_proj_t *p, float *vxOut, float *vyOut);
void rcl_candidates(uintptr_t ownElem, int *out);
void rcl_autododge(void);

extern float rcl_own_r;

int rcl_ok(float v, float lo, float hi);

extern float rcl_rad_est;
extern int rcl_cal_off_seen;
extern int rcl_rad_off;

extern int rcl_cal_n;
extern float rcl_cal_rad_seen;

#endif
