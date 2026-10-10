#include "../recoil.h"

typedef struct
{
    const char *from;
    const char *to;
} rcl_brawler_alias_t;

static const rcl_brawler_alias_t rcl_brawler_aliases[] = {
    {"8-BIT", "8BIT"},
    {"8_BIT", "8BIT"},
    {"ALTERNATOR", "JAE"},
    {"AMBUSHER", "LILY"},
    {"ARCADE", "8BIT"},
    {"ARTILLERY DUDE", "PENNY"},
    {"ARTILLERYDUDE", "PENNY"},
    {"ARTILLERY_DUDE", "PENNY"},
    {"ASSAULT SHOTGUN", "GRIFF"},
    {"ASSAULTSHOTGUN", "GRIFF"},
    {"ASSAULT_SHOTGUN", "GRIFF"},
    {"ATTACHER", "KIT"},
    {"ATTRACTOR", "COSMO"},
    {"AXE JUGGLER", "MELODY"},
    {"AXEJUGGLER", "MELODY"},
    {"AXE_JUGGLER", "MELODY"},
    {"BARKEEP", "BARLEY"},
    {"BARREL BOT", "BARRELBOT"},
    {"BARREL_BOT", "BARRELBOT"},
    {"BASEBALL", "BIBI"},
    {"BEAMER", "MANDY"},
    {"BEE SNIPER", "BEA"},
    {"BEESNIPER", "BEA"},
    {"BEE_SNIPER", "BEA"},
    {"BLACK HOLE", "TARO"},
    {"BLACKHOLE", "TARO"},
    {"BLACK_HOLE", "TARO"},
    {"BLOWER", "GALE"},
    {"BOLT", "BOLDER"},
    {"BOW DUDE", "BO"},
    {"BOWDUDE", "BO"},
    {"BOW_DUDE", "BO"},
    {"BULL DUDE", "BULL"},
    {"BULLDUDE", "BULL"},
    {"BULLETSTORM", "PIERCE"},
    {"BULL_DUDE", "BULL"},
    {"CACTUS", "SPIKE"},
    {"CANNON GIRL", "BONNIE"},
    {"CANNON GIRL SMALL", "BONNIE"},
    {"CANNONGIRL", "BONNIE"},
    {"CANNONGIRLSMALL", "BONNIE"},
    {"CANNON_GIRL", "BONNIE"},
    {"CANNON_GIRL_SMALL", "BONNIE"},
    {"CHRONOMANCER", "FINX"},
    {"CLUSTER BOMB DUDE", "TICK"},
    {"CLUSTERBOMBDUDE", "TICK"},
    {"CLUSTER_BOMB_DUDE", "TICK"},
    {"COCOONER", "CHARLIE"},
    {"CONDUCTOR", "CHUCK"},
    {"CONTROLLER", "NANI"},
    {"COOKER", "PEARL"},
    {"CRAB", "CLANCY"},
    {"CROSS BOMBER", "GROM"},
    {"CROSSBOMBER", "GROM"},
    {"CROSS_BOMBER", "GROM"},
    {"DANCER", "MINA"},
    {"DAREDEVIL", "GIGI"},
    {"DARRYL", "BARRELBOT"},
    {"DEAD MARIACHI", "POCO"},
    {"DEADMARIACHI", "POCO"},
    {"DEAD_MARIACHI", "POCO"},
    {"DIGGER DRILL", "DIGGER"},
    {"DIGGERDRILL", "DIGGER"},
    {"DIGGER_DRILL", "DIGGER"},
    {"DOMAIN", "TRUNK"},
    {"DOOR MAN", "GRAY"},
    {"DOORMAN", "GRAY"},
    {"DOOR_MAN", "GRAY"},
    {"DRAGON RIDER", "DRACO"},
    {"DRAGONRIDER", "DRACO"},
    {"DRAGON_RIDER", "DRACO"},
    {"DRILLER", "JACKY"},
    {"DUELIST", "CORDELIUS"},
    {"DUPLICATOR", "LOLLA"},
    {"DYNAMIKE", "MIKE"},
    {"EL PRIMO", "PRIMO"},
    {"ELECTRO SNIPER", "BELLE"},
    {"ELECTROSNIPER", "BELLE"},
    {"ELECTRO_SNIPER", "BELLE"},
    {"ELPRIMO", "PRIMO"},
    {"EL_PRIMO", "PRIMO"},
    {"ENRAGER", "EDGAR"},
    {"FIRE DUDE", "AMBER"},
    {"FIREDUDE", "AMBER"},
    {"FIRE_DUDE", "AMBER"},
    {"FISH TANK", "FISHTANK"},
    {"FISH_TANK", "FISHTANK"},
    {"FLEA", "EVE"},
    {"FURY", "ZIGGY"},
    {"FUTURE GIRL", "WENDY"},
    {"FUTUREGIRL", "WENDY"},
    {"FUTURE_GIRL", "WENDY"},
    {"GEISHA", "KAZE"},
    {"GEISHA TRANSFORMED", "KAZE"},
    {"GEISHATRANSFORMED", "KAZE"},
    {"GEISHA_TRANSFORMED", "KAZE"},
    {"GHOST", "SHADE"},
    {"GLADIATOR", "DAMIAN"},
    {"GLOWY", "GLOWBERT"},
    {"GUNSLINGER", "COLT"},
    {"HAMMER DUDE", "FRANK"},
    {"HAMMERDUDE", "FRANK"},
    {"HAMMER_DUDE", "FRANK"},
    {"HANK", "FISHTANK"},
    {"HOOK DUDE", "GENE"},
    {"HOOKDUDE", "GENE"},
    {"HOOK_DUDE", "GENE"},
    {"ICE DUDE", "LOU"},
    {"ICEDUDE", "LOU"},
    {"ICE_DUDE", "LOU"},
    {"INSECT MAN", "ANGELO"},
    {"INSECTMAN", "ANGELO"},
    {"INSECT_MAN", "ANGELO"},
    {"JAE-YONG", "JAE"},
    {"JAEYONG", "JAE"},
    {"JAE_YONG", "JAE"},
    {"JESSIE", "JESS"},
    {"JESTER", "CHESTER"},
    {"JETPACK GIRL", "JANET"},
    {"JETPACKGIRL", "JANET"},
    {"JETPACK_GIRL", "JANET"},
    {"KATANA KID", "NORI"},
    {"KATANAKID", "NORI"},
    {"KATANA_KID", "NORI"},
    {"KENJI", "SAMURAI"},
    {"KICKER DUDE", "FANG"},
    {"KICKERDUDE", "FANG"},
    {"KICKER_DUDE", "FANG"},
    {"KNIGHT", "ASH"},
    {"LARRY & LAWRIE", "TWINS"},
    {"LARRY&LAWRIE", "TWINS"},
    {"LARRYLAWRIE", "TWINS"},
    {"LARRY_&_LAWRIE", "TWINS"},
    {"LARRY_AND_LAWRIE", "TWINS"},
    {"LARRY_LAWRIE", "TWINS"},
    {"LEAPER", "MICO"},
    {"LOLA", "LOLLA"},
    {"LUCHADOR", "PRIMO"},
    {"MAGICAL GIRL", "STELLA"},
    {"MAGICALGIRL", "STELLA"},
    {"MAGICAL_GIRL", "STELLA"},
    {"MECHA DUDE", "MEG"},
    {"MECHA DUDE BIG", "MEG"},
    {"MECHADUDE", "MEG"},
    {"MECHADUDEBIG", "MEG"},
    {"MECHANIC", "JESS"},
    {"MECHA_DUDE", "MEG"},
    {"MECHA_DUDE_BIG", "MEG"},
    {"MELODIE", "MELODY"},
    {"MENDER", "GLOWBERT"},
    {"MINIGUN DUDE", "MJ"},
    {"MINIGUNDUDE", "MJ"},
    {"MINIGUN_DUDE", "MJ"},
    {"MOE", "DIGGER"},
    {"MORNINGSTAR", "LUMI"},
    {"MR. P", "MRP"},
    {"MR.P", "MRP"},
    {"MR._P", "MRP"},
    {"MR_P", "MRP"},
    {"MUMMY", "EMZ"},
    {"NINJA", "LEON"},
    {"PAINTER", "BERRY"},
    {"PAM", "MJ"},
    {"PERCENTER", "COLETTE"},
    {"POWER LEVELER", "SURGE"},
    {"POWERLEVELER", "SURGE"},
    {"POWER_LEVELER", "SURGE"},
    {"PUPPETEER", "WILLOW"},
    {"R-T", "ARTIE"},
    {"REDIRECTER", "NAJIA"},
    {"REVIVER", "DOUG"},
    {"RICO", "RICK"},
    {"ROCK", "BOLDER"},
    {"ROCKET GIRL", "BROCK"},
    {"ROCKETGIRL", "BROCK"},
    {"ROCKET_GIRL", "BROCK"},
    {"ROLLER", "STU"},
    {"ROPE DUDE", "BUZZ"},
    {"ROPEDUDE", "BUZZ"},
    {"ROPE_DUDE", "BUZZ"},
    {"RT", "ARTIE"},
    {"R_T", "ARTIE"},
    {"SAM", "BRONSON"},
    {"SANDSTORM", "SANDY"},
    {"SHADOWDEMON", "SIRIUS"},
    {"SHAMAN", "NITA"},
    {"SHIELD TANK", "BUSTER"},
    {"SHIELDTANK", "BUSTER"},
    {"SHIELD_TANK", "BUSTER"},
    {"SHOTGUN GIRL", "SHELLY"},
    {"SHOTGUNGIRL", "SHELLY"},
    {"SHOTGUN_GIRL", "SHELLY"},
    {"SILENCER", "OTIS"},
    {"SKATER", "OLLIE"},
    {"SNAKE OIL", "BYRON"},
    {"SNAKEOIL", "BYRON"},
    {"SNAKE_OIL", "BYRON"},
    {"SNIPER", "PIPER"},
    {"SOUL COLLECTOR", "GUS"},
    {"SOULCOLLECTOR", "GUS"},
    {"SOUL_COLLECTOR", "GUS"},
    {"SPAWNER DUDE", "MRP"},
    {"SPAWNERDUDE", "MRP"},
    {"SPAWNER_DUDE", "MRP"},
    {"SPEEDY", "MAX"},
    {"SPLITTER", "ARTIE"},
    {"STACKER", "VINCE"},
    {"STALKER", "ALLI"},
    {"STARR NOVA", "STELLA"},
    {"STARRNOVA", "STELLA"},
    {"STARR_NOVA", "STELLA"},
    {"STICKY BOMB", "SQUEAK"},
    {"STICKYBOMB", "SQUEAK"},
    {"STICKY_BOMB", "SQUEAK"},
    {"SUPER NOVA BEE SNIPER", "SUPERNOVABEESNIPER"},
    {"SUPER NOVA CACTUS", "SUPERNOVACACTUS"},
    {"SUPER NOVA FIRE DUDE", "SUPERNOVAFIREDUDE"},
    {"SUPER NOVA MAGICAL GIRL", "SUPERNOVAMAGICALGIRL"},
    {"SUPER NOVA VOODOO", "SUPERNOVAVOODOO"},
    {"SUPER_NOVA_BEE_SNIPER", "SUPERNOVABEESNIPER"},
    {"SUPER_NOVA_CACTUS", "SUPERNOVACACTUS"},
    {"SUPER_NOVA_FIRE_DUDE", "SUPERNOVAFIREDUDE"},
    {"SUPER_NOVA_MAGICAL_GIRL", "SUPERNOVAMAGICALGIRL"},
    {"SUPER_NOVA_VOODOO", "SUPERNOVAVOODOO"},
    {"TARA", "TARO"},
    {"TNT DUDE", "MIKE"},
    {"TNTDUDE", "MIKE"},
    {"TNT_DUDE", "MIKE"},
    {"TRICKSHOT DUDE", "RICK"},
    {"TRICKSHOTDUDE", "RICK"},
    {"TRICKSHOT_DUDE", "RICK"},
    {"UNDERTAKER", "MORTIS"},
    {"VOODOO", "JUJU"},
    {"WALLY", "SPROUT"},
    {"WEAPON THROWER", "BRONSON"},
    {"WEAPONTHROWER", "BRONSON"},
    {"WEAPON_THROWER", "BRONSON"},
    {"WHIRLWIND", "CARL"},
};

#define RCL_BRAWLER_ALIAS_COUNT                                                                    \
    ((int)(sizeof(rcl_brawler_aliases) / sizeof(rcl_brawler_aliases[0])))

static char rcl_brawler_buf[RCL_BRAWLER_SLOTS][RCL_BRAWLER_NAME_MAX];
static int rcl_brawler_slot = 0;

static char rcl_brawler_upper(int c)
{
    if (c >= 'a' && c <= 'z')
    {
        return (char)(c - 'a' + 'A');
    }
    return (char)c;
}

static int rcl_brawler_space(int c)
{
    return c == ' ' || c == '\t' || c == '\n' || c == '\r' || c == '\f' || c == '\v';
}

const char *rcl_brawler_canon(const char *name)
{
    char *out = nullptr;
    int i = 0;
    int n = 0;
    int gap = 0;
    if (!name || !name[0])
    {
        return nullptr;
    }
    out = rcl_brawler_buf[rcl_brawler_slot];
    rcl_brawler_slot = (rcl_brawler_slot + 1) % RCL_BRAWLER_SLOTS;
    while (name[i] && n < RCL_BRAWLER_NAME_MAX - 1)
    {
        int c = (unsigned char)name[i];
        i++;
        if (rcl_brawler_space(c))
        {
            if (n == 0 || gap)
            {
                continue;
            }
            out[n] = '_';
            n++;
            gap = 1;
            continue;
        }
        out[n] = rcl_brawler_upper(c);
        n++;
        gap = 0;
    }
    if (gap && n > 0)
    {
        n--;
    }
    out[n] = 0;
    for (i = 0; i < RCL_BRAWLER_ALIAS_COUNT; i++)
    {
        if (strcmp(rcl_brawler_aliases[i].from, out) == 0)
        {
            return rcl_brawler_aliases[i].to;
        }
    }
    return out;
}
