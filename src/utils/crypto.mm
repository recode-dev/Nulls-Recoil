#include "../recoil.h"

static const uint32_t RCL_SHA_K[64] = {
    0x428a2f98UL, 0x71374491UL, 0xb5c0fbcfUL, 0xe9b5dba5UL, 0x3956c25bUL, 0x59f111f1UL,
    0x923f82a4UL, 0xab1c5ed5UL, 0xd807aa98UL, 0x12835b01UL, 0x243185beUL, 0x550c7dc3UL,
    0x72be5d74UL, 0x80deb1feUL, 0x9bdc06a7UL, 0xc19bf174UL, 0xe49b69c1UL, 0xefbe4786UL,
    0x0fc19dc6UL, 0x240ca1ccUL, 0x2de92c6fUL, 0x4a7484aaUL, 0x5cb0a9dcUL, 0x76f988daUL,
    0x983e5152UL, 0xa831c66dUL, 0xb00327c8UL, 0xbf597fc7UL, 0xc6e00bf3UL, 0xd5a79147UL,
    0x06ca6351UL, 0x14292967UL, 0x27b70a85UL, 0x2e1b2138UL, 0x4d2c6dfcUL, 0x53380d13UL,
    0x650a7354UL, 0x766a0abbUL, 0x81c2c92eUL, 0x92722c85UL, 0xa2bfe8a1UL, 0xa81a664bUL,
    0xc24b8b70UL, 0xc76c51a3UL, 0xd192e819UL, 0xd6990624UL, 0xf40e3585UL, 0x106aa070UL,
    0x19a4c116UL, 0x1e376c08UL, 0x2748774cUL, 0x34b0bcb5UL, 0x391c0cb3UL, 0x4ed8aa4aUL,
    0x5b9cca4fUL, 0x682e6ff3UL, 0x748f82eeUL, 0x78a5636fUL, 0x84c87814UL, 0x8cc70208UL,
    0x90befffaUL, 0xa4506cebUL, 0xbef9a3f7UL, 0xc67178f2UL};

static const uint32_t RCL_SHA_IV[8] = {0x6a09e667UL, 0xbb67ae85UL, 0x3c6ef372UL, 0xa54ff53aUL,
                                       0x510e527fUL, 0x9b05688cUL, 0x1f83d9abUL, 0x5be0cd19UL};

typedef struct
{
    uint32_t h[8];
    uint8_t buf[64];
    uint64_t bits;
    size_t n;
} rcl_sha_ctx_t;

static uint32_t rcl_ror(uint32_t v, int s)
{
    return (v >> s) | (v << (32 - s));
}

static void rcl_sha_block(rcl_sha_ctx_t *c, const uint8_t *p)
{
    uint32_t w[64];
    uint32_t a = 0;
    uint32_t b = 0;
    uint32_t cc = 0;
    uint32_t d = 0;
    uint32_t e = 0;
    uint32_t f = 0;
    uint32_t g = 0;
    uint32_t hh = 0;
    int i = 0;
    for (i = 0; i < 16; i++)
    {
        w[i] = ((uint32_t)p[i * 4] << 24) | ((uint32_t)p[i * 4 + 1] << 16) |
               ((uint32_t)p[i * 4 + 2] << 8) | (uint32_t)p[i * 4 + 3];
    }
    for (i = 16; i < 64; i++)
    {
        uint32_t s0 = rcl_ror(w[i - 15], 7) ^ rcl_ror(w[i - 15], 18) ^ (w[i - 15] >> 3);
        uint32_t s1 = rcl_ror(w[i - 2], 17) ^ rcl_ror(w[i - 2], 19) ^ (w[i - 2] >> 10);
        w[i] = w[i - 16] + s0 + w[i - 7] + s1;
    }
    a = c->h[0];
    b = c->h[1];
    cc = c->h[2];
    d = c->h[3];
    e = c->h[4];
    f = c->h[5];
    g = c->h[6];
    hh = c->h[7];
    for (i = 0; i < 64; i++)
    {
        uint32_t S1 = rcl_ror(e, 6) ^ rcl_ror(e, 11) ^ rcl_ror(e, 25);
        uint32_t ch = (e & f) ^ ((~e) & g);
        uint32_t t1 = hh + S1 + ch + RCL_SHA_K[i] + w[i];
        uint32_t S0 = rcl_ror(a, 2) ^ rcl_ror(a, 13) ^ rcl_ror(a, 22);
        uint32_t maj = (a & b) ^ (a & cc) ^ (b & cc);
        uint32_t t2 = S0 + maj;
        hh = g;
        g = f;
        f = e;
        e = d + t1;
        d = cc;
        cc = b;
        b = a;
        a = t1 + t2;
    }
    c->h[0] += a;
    c->h[1] += b;
    c->h[2] += cc;
    c->h[3] += d;
    c->h[4] += e;
    c->h[5] += f;
    c->h[6] += g;
    c->h[7] += hh;
}

static void rcl_sha_init(rcl_sha_ctx_t *c)
{
    memcpy(c->h, RCL_SHA_IV, sizeof(RCL_SHA_IV));
    c->bits = 0;
    c->n = 0;
}

static void rcl_sha_update(rcl_sha_ctx_t *c, const uint8_t *p, size_t length)
{
    size_t i = 0;
    c->bits += (uint64_t)length * 8ULL;
    while (i < length)
    {
        size_t k = (size_t)64 - c->n;
        if (k > length - i)
        {
            k = length - i;
        }
        memcpy(c->buf + c->n, p + i, k);
        c->n += k;
        i += k;
        if (c->n == 64)
        {
            rcl_sha_block(c, c->buf);
            c->n = 0;
        }
    }
}

static void rcl_sha_final(rcl_sha_ctx_t *c, uint8_t out[32])
{
    uint8_t pad[72];
    uint64_t bits = c->bits;
    size_t padlen = (c->n < 56) ? ((size_t)56 - c->n) : ((size_t)120 - c->n);
    int i = 0;
    pad[0] = 0x80;
    memset(pad + 1, 0, padlen - 1);
    for (i = 0; i < 8; i++)
    {
        pad[padlen + (size_t)i] = (uint8_t)(bits >> (56 - 8 * i));
    }
    rcl_sha_update(c, pad, padlen + 8);
    for (i = 0; i < 8; i++)
    {
        out[i * 4] = (uint8_t)(c->h[i] >> 24);
        out[i * 4 + 1] = (uint8_t)(c->h[i] >> 16);
        out[i * 4 + 2] = (uint8_t)(c->h[i] >> 8);
        out[i * 4 + 3] = (uint8_t)(c->h[i]);
    }
}

void rcl_sha(const uint8_t *data, size_t length, uint8_t out[32])
{
    rcl_sha_ctx_t c;
    rcl_sha_init(&c);
    rcl_sha_update(&c, data, length);
    rcl_sha_final(&c, out);
}

void rcl_ci_make_block(const uint8_t key16[16], const uint8_t mask16[16], uint8_t pad,
                       uint8_t out[64])
{
    int i = 0;
    for (i = 0; i < 16; i++)
    {
        out[i] = (uint8_t)(key16[i] ^ mask16[i]);
    }
    memset(out + 16, pad, 64 - 16);
}

uint32_t rcl_ci_compute_token(const uint8_t key16[16], const uint8_t cmd16[16],
                              const uint32_t *table, const uint8_t innerMask[16],
                              const uint8_t outerMask[16])
{
    uint8_t msg[0x14];
    uint8_t innerBuf[64 + 0x14];
    uint8_t outerBuf[64 + 32];
    uint8_t block[64];
    uint8_t inner[32];
    uint8_t digest[32];
    uint32_t typeRaw = 0;
    uint32_t typeC = 0;
    uint32_t token = 0;
    int i = 0;
    typeRaw = (uint32_t)cmd16[4] | ((uint32_t)cmd16[5] << 8) | ((uint32_t)cmd16[6] << 16) |
              ((uint32_t)cmd16[7] << 24);
    typeC = (typeRaw <= 0x16) ? table[typeRaw] : (uint32_t)0xdeadbeef;
    for (i = 0; i < 12; i++)
    {
        msg[i] = cmd16[4 + i];
    }
    for (i = 0; i < 4; i++)
    {
        msg[12 + i] = cmd16[i];
    }
    msg[16] = (uint8_t)(typeC);
    msg[17] = (uint8_t)(typeC >> 8);
    msg[18] = (uint8_t)(typeC >> 16);
    msg[19] = (uint8_t)(typeC >> 24);
    rcl_ci_make_block(key16, innerMask, (uint8_t)0x36, block);
    memcpy(innerBuf, block, 64);
    memcpy(innerBuf + 64, msg, 0x14);
    rcl_sha(innerBuf, sizeof(innerBuf), inner);
    rcl_ci_make_block(key16, outerMask, (uint8_t)0x5c, block);
    memcpy(outerBuf, block, 64);
    memcpy(outerBuf + 64, inner, 32);
    rcl_sha(outerBuf, sizeof(outerBuf), digest);
    token = (uint32_t)digest[0] | (((uint32_t)digest[1] & (uint32_t)0x7f) << 8);
    if (token <= (uint32_t)1)
    {
        token = (uint32_t)1;
    }
    return token;
}
