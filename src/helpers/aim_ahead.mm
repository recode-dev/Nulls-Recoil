#include "../recoil.h"

static const rcl_aim_ahead_t rcl_aim_ahead_table[] = {
    {"8BIT", 4500, 667, 1.67f, 0},
    {"ALLI", 0, 0, 0.00f, 4},
    {"AMBER", 3500, 714, 1.79f, 0},
    {"ANGELO", 4000, 750, 1.88f, 0},
    {"ARTIE", 4500, 667, 1.67f, 0},
    {"ASH", 5000, 280, 0.70f, 0},
    {"BARLEY", 0, 0, 0.00f, 1},
    {"BARRELBOT", 4000, 450, 1.12f, 0},
    {"BEA", 3255, 922, 2.30f, 0},
    {"BELLE", 4000, 750, 1.88f, 0},
    {"BERRY", 0, 0, 0.00f, 1},
    {"BIBI", 0, 0, 0.00f, 4},
    {"BO", 2800, 929, 2.32f, 0},
    {"BOLDER", 0, 0, 0.00f, 4},
    {"BONNIE", 3800, 711, 1.78f, 0},
    {"BROCK", 2700, 1000, 2.50f, 0},
    {"BRONSON", 5000, 180, 0.45f, 0},
    {"BULL", 2853, 561, 1.40f, 0},
    {"BUSTER", 4200, 381, 0.95f, 0},
    {"BUZZ", 4000, 200, 0.50f, 0},
    {"BYRON", 4000, 750, 1.88f, 0},
    {"CARL", 3000, 833, 2.08f, 0},
    {"CHARLIE", 4200, 643, 1.61f, 0},
    {"CHESTER", 3300, 758, 1.89f, 0},
    {"CHUCK", 2700, 667, 1.67f, 0},
    {"CLANCY", 3500, 657, 1.64f, 0},
    {"COLETTE", 4000, 650, 1.62f, 0},
    {"COLT", 4000, 675, 1.69f, 0},
    {"CORDELIUS", 3800, 421, 1.05f, 0},
    {"COSMO", 1600, 1688, 4.22f, 0},
    {"CROW", 3261, 797, 1.99f, 0},
    {"DAMIAN", 5000, 160, 0.40f, 0},
    {"DIGGER", 2800, 536, 1.34f, 0},
    {"DOUG", 0, 0, 0.00f, 4},
    {"DRACO", 3800, 316, 0.79f, 0},
    {"EDGAR", 3500, 171, 0.43f, 0},
    {"EMZ", 1500, 1333, 3.33f, 0},
    {"EVE", 3500, 800, 2.00f, 0},
    {"FANG", 3200, 250, 0.62f, 0},
    {"FINX", 3000, 833, 2.08f, 0},
    {"FISHTANK", 0, 0, 0.00f, 4},
    {"FRANK", 5000, 360, 0.90f, 0},
    {"GALE", 3000, 833, 2.08f, 0},
    {"GENE", 3200, 531, 1.33f, 0},
    {"GIGI", 0, 0, 0.00f, 4},
    {"GLOWBERT", 5000, 440, 1.10f, 0},
    {"GODZILLA", 0, 0, 0.00f, 4},
    {"GRAY", 3804, 710, 1.77f, 0},
    {"GRIFF", 3100, 806, 2.02f, 0},
    {"GROM", 0, 0, 0.00f, 1},
    {"GUS", 4000, 700, 1.75f, 0},
    {"JACKY", 0, 0, 0.00f, 4},
    {"JAE", 3700, 676, 1.69f, 0},
    {"JANET", 3650, 329, 0.82f, 0},
    {"JESS", 3050, 885, 2.21f, 0},
    {"JUJU", 0, 0, 0.00f, 1},
    {"KAZE", 0, 0, 0.00f, 4},
    {"KIT", 0, 0, 0.00f, 1},
    {"LEON", 3500, 829, 2.07f, 0},
    {"LILY", 3500, 171, 0.43f, 0},
    {"LOLLA", 4500, 600, 1.50f, 0},
    {"LOU", 4000, 700, 1.75f, 0},
    {"LUMI", 3500, 686, 1.71f, 0},
    {"MAISIE", 3200, 812, 2.03f, 0},
    {"MANDY", 3800, 711, 1.78f, 0},
    {"MAX", 4000, 625, 1.56f, 0},
    {"MEEPLE", 3000, 767, 1.92f, 0},
    {"MEG", 4000, 675, 1.69f, 0},
    {"MELODY", 4500, 533, 1.33f, 0},
    {"MICO", 0, 0, 0.00f, 4},
    {"MIKE", 0, 0, 0.00f, 1},
    {"MINA", 3000, 800, 2.00f, 0},
    {"MJ", 4130, 654, 1.63f, 0},
    {"MORTIS", 0, 0, 0.00f, 4},
    {"MRP", 3000, 700, 1.75f, 0},
    {"NAJIA", 1700, 1059, 2.65f, 0},
    {"NANI", 4000, 650, 1.62f, 0},
    {"NITA", 2718, 662, 1.66f, 0},
    {"NORI", 4000, 275, 0.69f, 0},
    {"OLLIE", 3000, 633, 1.58f, 0},
    {"OTIS", 3600, 750, 1.88f, 0},
    {"PEARL", 4000, 675, 1.69f, 0},
    {"PENNY", 3400, 765, 1.91f, 0},
    {"PIERCE", 4000, 750, 1.88f, 0},
    {"PIPER", 4000, 750, 1.88f, 0},
    {"POCO", 2500, 840, 2.10f, 0},
    {"PRIMO", 3261, 276, 0.69f, 0},
    {"RICK", 3478, 834, 2.08f, 0},
    {"ROSA", 5000, 220, 0.55f, 0},
    {"RUFFS", 3800, 711, 1.78f, 0},
    {"SAMURAI", 0, 0, 0.00f, 4},
    {"SANDY", 3500, 514, 1.29f, 0},
    {"SHADE", 0, 0, 0.00f, 4},
    {"SHELLY", 3100, 742, 1.85f, 0},
    {"SIRIUS", 0, 0, 0.00f, 1},
    {"SPIKE", 2174, 1058, 2.64f, 0},
    {"SPROUT", 0, 0, 0.00f, 1},
    {"SQUEAK", 4000, 575, 1.44f, 0},
    {"STELLA", 0, 0, 0.00f, 2},
    {"STU", 3300, 697, 1.74f, 0},
    {"SUPERNOVABEESNIPER", 2800, 1000, 2.50f, 0},
    {"SUPERNOVACACTUS", 2174, 506, 1.26f, 0},
    {"SUPERNOVAFIREDUDE", 2800, 607, 1.52f, 0},
    {"SUPERNOVAMAGICALGIRL", 0, 0, 0.00f, 4},
    {"SUPERNOVAVOODOO", 0, 0, 0.00f, 1},
    {"SURGE", 3500, 571, 1.43f, 0},
    {"TARO", 3152, 761, 1.90f, 0},
    {"TICK", 0, 0, 0.00f, 1},
    {"TRUNK", 0, 0, 0.00f, 4},
    {"TWINS", 0, 0, 0.00f, 1},
    {"VINCE", 4000, 625, 1.56f, 0},
    {"WENDY", 3500, 686, 1.71f, 0},
    {"WILLOW", 0, 0, 0.00f, 1},
    {"ZIGGY", 0, 0, 0.00f, 1},
};

#define RCL_AIM_AHEAD_COUNT ((int)(sizeof(rcl_aim_ahead_table) / sizeof(rcl_aim_ahead_table[0])))

typedef struct
{
    const char *proj;
    int16_t row;
} rcl_aim_ahead_proj_t;

static const rcl_aim_ahead_proj_t rcl_aim_ahead_projs[] = {
    {"AlternatorSpeedProjectile", 52},
    {"AmbusherProjectile", 59},
    {"ArcadeProjectile", 0},
    {"ArtilleryDudeProjectile", 82},
    {"AssaultShotgunProjectile", 48},
    {"AttacherProjectile", 57},
    {"AttractorCarrierProjectile", 29},
    {"AxeJugglerProjectile", 68},
    {"BarkeepProjectile", 6},
    {"BarrelBotProjectile", 7},
    {"BeamerProjectile", 64},
    {"BeeSniperProjectile", 8},
    {"BlackHoleProjectile", 106},
    {"BlowerProjectile", 42},
    {"BowDudeProjectile", 12},
    {"BullDudeProjectile", 17},
    {"BulletstormProjectile", 83},
    {"CactusProjectile", 95},
    {"CannonGirlProjectile", 14},
    {"ChronomancerProjectile", 39},
    {"ClusterBombProjectile", 107},
    {"CocoonerProjectile", 22},
    {"ConductorProjectile", 24},
    {"ControllerProjectile", 76},
    {"CookerProjectile", 81},
    {"CrabProjectile", 25},
    {"CrossBomberProjectile", 49},
    {"CrowProjectile", 30},
    {"DancerProjectileSingle", 71},
    {"DeadMariachiProjectile", 85},
    {"DiggerProjectile", 32},
    {"DoorManProjectile", 47},
    {"DragonRiderProjectile", 34},
    {"DuelistProjectile", 28},
    {"DuplicatorProjectile", 60},
    {"ElectroSniperProjectile", 9},
    {"EnragerProjectile", 35},
    {"FireDudeProjectile", 2},
    {"FleaProjectile1", 37},
    {"FuryProjectile", 113},
    {"FutureGirlProjectile", 111},
    {"GladiatorProjectile", 31},
    {"GunslingerProjectile", 27},
    {"HammerDudeProjectile", 41},
    {"HookProjectile", 43},
    {"IceDudeProjectile", 61},
    {"JesterProjectile", 23},
    {"JetpackGirlProjectile", 53},
    {"KatanaKidProjectile", 78},
    {"KickerDudeProjectile", 38},
    {"KnightProjectile1", 5},
    {"LeonDefProjectile", 58},
    {"MagicalGirlProjectile", 98},
    {"MaisieProjectile", 63},
    {"MechaDudeProjectile", 67},
    {"MechanicProjectile1", 54},
    {"MeepleProjectile", 66},
    {"MenderProjectile", 45},
    {"MinigunDudeProjectile", 72},
    {"MorningstarProjectile", 62},
    {"MosquitoProjectile", 3},
    {"MummyProjectile", 36},
    {"PainterProjectile", 10},
    {"PercenterProjectile", 26},
    {"PowerLevelerProjectile", 105},
    {"PrimoDefProjectile", 86},
    {"PuppeteerProjectile", 112},
    {"RedirecterProjectile", 75},
    {"RocketGirlProjectile", 15},
    {"RollerProjectile", 99},
    {"RopeDudeProjectile", 19},
    {"RosaProjectile", 88},
    {"RuffsProjectile", 89},
    {"SandstormProjectile", 91},
    {"ShadowdemonProjectileIndirect", 94},
    {"ShamanProjectile", 77},
    {"ShieldTankProjectile", 18},
    {"ShotgunGirlProjectile", 93},
    {"SilencerProjectile", 80},
    {"SkaterProjectile", 79},
    {"SnakeOilProjectile", 20},
    {"SniperProjectile", 84},
    {"SoulCollectorProjectile", 50},
    {"SpawnerDudeProjectile", 74},
    {"SpeedyProjectile", 65},
    {"SplitterProjectile", 4},
    {"StackerProjectile", 110},
    {"StickyBombProjectile", 97},
    {"SuperNovaBeeSniperProjectile", 100},
    {"SuperNovaCactusProjectile", 101},
    {"SuperNovaFireDudeProjectile", 102},
    {"SuperNovaVoodooProjectileEarth", 104},
    {"TntDudeProjectile", 70},
    {"TrickshotDudeProjectile", 87},
    {"TwinsThrowerProjectile", 109},
    {"VoodooProjectileEarth", 55},
    {"WallyProjectile", 96},
    {"WeaponThrowerProjectile", 16},
    {"WhirlwindProjectile", 21},
};

#define RCL_AIM_AHEAD_PROJ_COUNT ((int)(sizeof(rcl_aim_ahead_projs) / sizeof(rcl_aim_ahead_projs[0])))

const rcl_aim_ahead_t *rcl_aim_ahead_by_projectile(const char *projName)
{
    int lo = 0;
    int hi = RCL_AIM_AHEAD_PROJ_COUNT - 1;
    if (!projName || !projName[0])
    {
        return nullptr;
    }
    while (lo <= hi)
    {
        int mid = lo + (hi - lo) / 2;
        int cmp = strcmp(projName, rcl_aim_ahead_projs[mid].proj);
        if (cmp == 0)
        {
            return &rcl_aim_ahead_table[rcl_aim_ahead_projs[mid].row];
        }
        if (cmp < 0)
        {
            hi = mid - 1;
            continue;
        }
        lo = mid + 1;
    }
    return nullptr;
}

const rcl_aim_ahead_t *rcl_aim_ahead_of(const char *name)
{
    const char *code = nullptr;
    int lo = 0;
    int hi = RCL_AIM_AHEAD_COUNT - 1;
    if (!name || !name[0])
    {
        return nullptr;
    }
    code = rcl_brawler_canon(name);
    if (!code || !code[0])
    {
        return nullptr;
    }
    while (lo <= hi)
    {
        int mid = lo + (hi - lo) / 2;
        int cmp = strcmp(code, rcl_aim_ahead_table[mid].code);
        if (cmp == 0)
        {
            return &rcl_aim_ahead_table[mid];
        }
        if (cmp < 0)
        {
            hi = mid - 1;
            continue;
        }
        lo = mid + 1;
    }
    return nullptr;
}

int rcl_aim_ahead_lead(const char *name)
{
    const rcl_aim_ahead_t *row = rcl_aim_ahead_of(name);
    if (!row)
    {
        return RCL_AIM_AHEAD_DEFAULT;
    }
    return (int)(row->ahead * (float)RCL_AIM_AHEAD_TILE);
}

int rcl_aim_ahead_speed(const char *name)
{
    const rcl_aim_ahead_t *row = rcl_aim_ahead_of(name);
    if (!row)
    {
        return 0;
    }
    return row->shotSpeed;
}
