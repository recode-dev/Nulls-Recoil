#include "../recoil.h"

const char *rcl_image_names[4] = {"Nulls Brawl", "Laser", "NB.app", nullptr};

BOOL rcl_setup_done = NO;

BOOL rcl_aim_rejected = NO;

__thread BOOL rcl_inside_hook = NO;

int rcl_dump_np = 0;

BOOL rcl_mode_strong = NO;

uintptr_t rcl_objvote_best_owner = 0;

int rcl_objvote_best_teamcount = 0;

rcl_objhit_t rcl_objhits[64];

int rcl_objhit_count = 0;

int rcl_objvote_max_votes = 0;

int rcl_trail_best = 0;

int rcl_votescan_attempts = 0;

double rcl_votescan_last = 0.0;

BOOL rcl_snapshot_first = NO;

BOOL rcl_snapshot_second = NO;

double rcl_snapshot_start = 0.0;

uintptr_t rcl_addr_getinstance = 0;

uintptr_t rcl_addr_getownchar = 0;

uintptr_t rcl_addr_getteam = 0;

uintptr_t rcl_addr_getx = 0;

uintptr_t rcl_addr_gety = 0;

uintptr_t rcl_addr_battlescreen = 0;

volatile int rcl_at = 0;

uintptr_t rcl_slot_object[34] = {0};

uintptr_t rcl_slot_arg[34] = {0};

uintptr_t rcl_slot_adopted = 0;

int rcl_sig_ticks = 0;

uintptr_t rcl_sig_last = 0;

uint64_t rcl_walk_tick = 0;

int rcl_walk_count = -1;

BOOL rcl_query_region(uintptr_t address, vm_prot_t *protection, vm_prot_t *maxProtection,
                      mach_vm_size_t *regionSize, uintptr_t *regionStart)
{
    vm_address_t regionAddress = (vm_address_t)address;
    vm_size_t size = 0;
    vm_region_basic_info_data_64_t info;
    mach_msg_type_number_t infoCount = VM_REGION_BASIC_INFO_COUNT_64;
    mach_port_t objectName = MACH_PORT_NULL;
    kern_return_t result =
        vm_region_64(mach_task_self(), &regionAddress, &size, VM_REGION_BASIC_INFO_64,
                     (vm_region_info_t)&info, &infoCount, &objectName);
    if (objectName != MACH_PORT_NULL)
    {
        mach_port_deallocate(mach_task_self(), objectName);
    }
    if (result != KERN_SUCCESS || size == 0)
    {
        return NO;
    }
    if ((uintptr_t)regionAddress > address)
    {
        return NO;
    }
    if ((uintptr_t)regionAddress + (uintptr_t)size <= address)
    {
        return NO;
    }
    if (protection)
    {
        *protection = info.protection;
    }
    if (maxProtection)
    {
        *maxProtection = info.max_protection;
    }
    if (regionSize)
    {
        *regionSize = (mach_vm_size_t)size;
    }
    if (regionStart)
    {
        *regionStart = (uintptr_t)regionAddress;
    }
    return YES;
}

BOOL rcl_addr_writable(uintptr_t address, size_t length)
{
    if (!address || !length)
    {
        return NO;
    }
    uintptr_t end = address + length;
    if (end < address)
    {
        return NO;
    }
    uintptr_t cursor = address;
    for (int guard = 0; cursor < end && guard < 64; guard++)
    {
        vm_prot_t protection = 0;
        mach_vm_size_t size = 0;
        uintptr_t start = 0;
        if (!rcl_query_region(cursor, &protection, nullptr, &size, &start))
        {
            return NO;
        }
        if (size == 0)
        {
            return NO;
        }
        if ((protection & VM_PROT_WRITE) == 0)
        {
            return NO;
        }
        uintptr_t next = start + (uintptr_t)size;
        if (next <= cursor)
        {
            return NO;
        }
        cursor = next;
    }
    return cursor >= end;
}

BOOL rcl_read_bytes(uintptr_t address, void *out, size_t length)
{
    if (!out || !length)
    {
        return NO;
    }
    if (!address)
    {
        return NO;
    }
    vm_size_t got = 0;
    kern_return_t result =
        vm_read_overwrite(mach_task_self(), (mach_vm_address_t)address, (mach_vm_size_t)length,
                          (mach_vm_address_t)(uintptr_t)out, &got);
    return result == KERN_SUCCESS && got == (vm_size_t)length;
}

BOOL rcl_pointer_plausible(uintptr_t value)
{
    if (value < 0x10000)
    {
        return NO;
    }
    if (value & 7)
    {
        return NO;
    }
    return YES;
}

BOOL rcl_read_byte(uintptr_t address, uint8_t *out)
{
    return rcl_read_bytes(address, out, 1);
}

BOOL rcl_read_int(uintptr_t address, int32_t *out)
{
    if (!out)
    {
        return NO;
    }
    if (address & 3)
    {
        return NO;
    }
    return rcl_read_bytes(address, out, 4);
}

BOOL rcl_read_float(uintptr_t address, float *out)
{
    if (address & 3)
    {
        return NO;
    }
    return rcl_read_bytes(address, out, 4);
}

BOOL rcl_writable(uintptr_t address, size_t length)
{
    uintptr_t end = address + length;
    uintptr_t cursor = address;
    if (!address || !length)
    {
        return NO;
    }
    if (end < address)
    {
        return NO;
    }
    for (int guard = 0; cursor < end && guard < 64; guard++)
    {
        vm_prot_t protection = 0;
        mach_vm_size_t size = 0;
        uintptr_t start = 0;
        uintptr_t next = 0;
        if (!rcl_query_region(cursor, &protection, nullptr, &size, &start))
        {
            return NO;
        }
        if ((protection & VM_PROT_WRITE) == 0)
        {
            return NO;
        }
        if (size == 0)
        {
            return NO;
        }
        next = start + (uintptr_t)size;
        if (next <= cursor)
        {
            return NO;
        }
        cursor = next;
    }
    return cursor >= end;
}

void rcl_note(uintptr_t, const void *src, size_t length, int)
{
    int n = rcl_at;
    uint32_t value = 0;
    if (n < 0)
    {
        n = 0;
    }
    if (n >= 24)
    {
        n = 0;
    }
    if (src && length)
    {
        size_t take = length < sizeof(value) ? length : sizeof(value);
        memcpy(&value, src, take);
    }
    rcl_at = (n + 1) % 24;
}

BOOL rcl_write_bytes(uintptr_t address, const void *src, size_t length)
{
    if (!src || !length)
    {
        return NO;
    }
    if (!address)
    {
        return NO;
    }
    if (1 && !rcl_writable(address, length))
    {
        rcl_note(address, src, length, 1);
        return NO;
    }
    rcl_note(address, src, length, 0);
    memcpy((void *)address, src, length);
    return YES;
}
BOOL rcl_read_ptr(uintptr_t address, void **out)
{
    if (!out)
    {
        return NO;
    }
    if (address & 7)
    {
        return NO;
    }
    return rcl_read_bytes(address, out, sizeof(void *));
}

void *rcl_read_global_ptr(uintptr_t rva)
{
    if (!rcl_base || !rva)
    {
        return nullptr;
    }
    void *value = nullptr;
    if (!rcl_read_ptr(rcl_base + rva, &value))
    {
        return nullptr;
    }
    return value;
}

uintptr_t rcl_callable(uintptr_t rva)
{
    if (!rcl_base || !rva)
    {
        return 0;
    }
    uintptr_t address = rcl_base + rva;
    if (!rcl_addr_executable(address))
    {
        return 0;
    }
    if (!rcl_image_text_contains(rcl_base, address))
    {
        return 0;
    }
    BOOL exact = NO;
    rcl_start_index(address, &exact);
    if (exact)
    {
        return address;
    }
    if (rcl_looks_like_start(address))
    {
        return address;
    }
    return 0;
}
BOOL rcl_copy(uintptr_t source, void *destination, size_t length)
{
    if (!source || !destination || !length)
    {
        return NO;
    }
    if (!rcl_addr_readable(source, length))
    {
        return NO;
    }
    vm_size_t copied = 0;
    kern_return_t result =
        vm_read_overwrite(mach_task_self(), (mach_vm_address_t)source, (mach_vm_size_t)length,
                          (mach_vm_address_t)(uintptr_t)destination, &copied);
    return result == KERN_SUCCESS && copied == (vm_size_t)length;
}

BOOL rcl_text_section(uintptr_t *address, uint64_t *size)
{
    if (!rcl_base)
    {
        return NO;
    }
    if (!rcl_addr_readable(rcl_base, sizeof(struct mach_header_64)))
    {
        return NO;
    }
    const struct mach_header_64 *header = (const struct mach_header_64 *)rcl_base;
    if (header->magic != MH_MAGIC_64)
    {
        return NO;
    }
    const uint8_t *cursor = (const uint8_t *)(header + 1);
    const uint8_t *limit = cursor + header->sizeofcmds;
    uintptr_t slide = rcl_image_slide(rcl_base);
    for (uint32_t i = 0; i < header->ncmds; i++)
    {
        if (cursor + sizeof(struct load_command) > limit)
        {
            return NO;
        }
        const struct load_command *command = (const struct load_command *)cursor;
        if (command->cmdsize < sizeof(struct load_command))
        {
            return NO;
        }
        if (cursor + command->cmdsize > limit)
        {
            return NO;
        }
        if (command->cmd == LC_SEGMENT_64 && command->cmdsize >= sizeof(struct segment_command_64))
        {
            const struct segment_command_64 *segment = (const struct segment_command_64 *)command;
            if (strcmp(segment->segname, "__TEXT") == 0)
            {
                uint64_t room = (uint64_t)command->cmdsize - sizeof(struct segment_command_64);
                uint64_t count = room / sizeof(struct section_64);
                if (count > segment->nsects)
                {
                    count = segment->nsects;
                }
                const struct section_64 *sections = (const struct section_64 *)(segment + 1);
                for (uint64_t s = 0; s < count; s++)
                {
                    if (strcmp(sections[s].sectname, "__text") != 0)
                    {
                        continue;
                    }
                    if (!sections[s].size)
                    {
                        continue;
                    }
                    if (address)
                    {
                        *address = slide + (uintptr_t)sections[s].addr;
                    }
                    if (size)
                    {
                        *size = sections[s].size;
                    }
                    return YES;
                }
            }
        }
        cursor += command->cmdsize;
    }
    return NO;
}

BOOL rcl_valid_header(uintptr_t base)
{
    if (!base)
    {
        return NO;
    }
    struct mach_header_64 header;
    if (!rcl_pointer_plausible(base))
    {
        return NO;
    }
    if (!rcl_read_bytes(base, &header, sizeof(header)))
    {
        return NO;
    }
    if (header.magic != MH_MAGIC_64)
    {
        return NO;
    }
    if (header.ncmds == 0 || header.ncmds > 4096)
    {
        return NO;
    }
    if (header.sizeofcmds == 0)
    {
        return NO;
    }
    if (header.sizeofcmds > (4u * 1024u * 1024u))
    {
        return NO;
    }
    if (!rcl_image_text_contains(base, base + RCL_IMAGE_TEXT_WINDOW))
    {
        return NO;
    }
    return YES;
}

BOOL find_game_image(uintptr_t *out_base)
{
    if (!out_base)
    {
        return NO;
    }
    uint32_t count = _dyld_image_count();
    if (count > 8192)
    {
        count = 8192;
    }
    uintptr_t fallback = 0;
    for (uint32_t i = 0; i < count; i++)
    {
        const char *path = _dyld_get_image_name(i);
        uintptr_t base = (uintptr_t)_dyld_get_image_header(i);
        if (!path || !base)
        {
            continue;
        }
        if (!strstr(path, ".app/"))
        {
            continue;
        }
        if (strstr(path, "/System/"))
        {
            continue;
        }
        if (strstr(path, "/usr/lib/"))
        {
            continue;
        }
        if (strstr(path, ".framework/"))
        {
            continue;
        }
        if (strstr(path, ".dylib"))
        {
            continue;
        }
        if (!rcl_valid_header(base))
        {
            continue;
        }
        BOOL matched = NO;
        for (int n = 0; rcl_image_names[n]; n++)
        {
            if (strstr(path, rcl_image_names[n]))
            {
                matched = YES;
                break;
            }
        }
        if (matched)
        {
            *out_base = base;
            return YES;
        }
        if (!fallback)
        {
            fallback = base;
        }
    }
    if (fallback)
    {
        *out_base = fallback;
        return YES;
    }
    return NO;
}

uintptr_t rcl_owner = 0;

int rcl_wired = 0;

dispatch_source_t rcl_scan_timer = nullptr;

BOOL rcl_segment_range(const char *name, uintptr_t *lo, uintptr_t *hi)
{
    if (!rcl_base || !name)
    {
        return NO;
    }
    if (!rcl_addr_readable(rcl_base, sizeof(struct mach_header_64)))
    {
        return NO;
    }
    const struct mach_header_64 *header = (const struct mach_header_64 *)rcl_base;
    if (header->magic != MH_MAGIC_64)
    {
        return NO;
    }
    const uint8_t *cursor = (const uint8_t *)(header + 1);
    const uint8_t *limit = cursor + header->sizeofcmds;
    uintptr_t slide = rcl_image_slide(rcl_base);
    for (uint32_t i = 0; i < header->ncmds; i++)
    {
        if (cursor + sizeof(struct load_command) > limit)
        {
            return NO;
        }
        const struct load_command *command = (const struct load_command *)cursor;
        if (command->cmdsize < sizeof(struct load_command))
        {
            return NO;
        }
        if (cursor + command->cmdsize > limit)
        {
            return NO;
        }
        if (command->cmd == LC_SEGMENT_64 && command->cmdsize >= sizeof(struct segment_command_64))
        {
            const struct segment_command_64 *segment = (const struct segment_command_64 *)command;
            if (strcmp(segment->segname, name) == 0)
            {
                if (lo)
                {
                    *lo = slide + (uintptr_t)segment->vmaddr;
                }
                if (hi)
                {
                    *hi = slide + (uintptr_t)segment->vmaddr + (uintptr_t)segment->vmsize;
                }
                return YES;
            }
        }
        cursor += command->cmdsize;
    }
    return NO;
}
void rcl_image_span_refresh(void)
{
    if (!rcl_base || !rcl_addr_readable(rcl_base, sizeof(struct mach_header_64)))
    {
        return;
    }
    const struct mach_header_64 *header = (const struct mach_header_64 *)rcl_base;
    if (header->magic != MH_MAGIC_64)
    {
        return;
    }
    const uint8_t *cursor = (const uint8_t *)(header + 1);
    const uint8_t *limit = cursor + header->sizeofcmds;
    for (uint32_t i = 0; i < header->ncmds; i++)
    {
        if (cursor + sizeof(struct load_command) > limit)
        {
            break;
        }
        const struct load_command *command = (const struct load_command *)cursor;
        if (command->cmdsize < sizeof(struct load_command))
        {
            break;
        }
        if (cursor + command->cmdsize > limit)
        {
            break;
        }
        cursor += command->cmdsize;
    }
}
const char *rcl_image_segment_name(uintptr_t value)
{
    if (!rcl_base || !value)
    {
        return nullptr;
    }
    if (!rcl_addr_readable(rcl_base, sizeof(struct mach_header_64)))
    {
        return nullptr;
    }
    const struct mach_header_64 *header = (const struct mach_header_64 *)rcl_base;
    if (header->magic != MH_MAGIC_64)
    {
        return nullptr;
    }
    const uint8_t *cursor = (const uint8_t *)(header + 1);
    const uint8_t *limit = cursor + header->sizeofcmds;
    uintptr_t slide = rcl_image_slide(rcl_base);
    for (uint32_t i = 0; i < header->ncmds; i++)
    {
        if (cursor + sizeof(struct load_command) > limit)
        {
            return nullptr;
        }
        const struct load_command *command = (const struct load_command *)cursor;
        if (command->cmdsize < sizeof(struct load_command))
        {
            return nullptr;
        }
        if (cursor + command->cmdsize > limit)
        {
            return nullptr;
        }
        if (command->cmd == LC_SEGMENT_64 && command->cmdsize >= sizeof(struct segment_command_64))
        {
            const struct segment_command_64 *segment = (const struct segment_command_64 *)command;
            if (segment->vmsize)
            {
                uintptr_t start = slide + (uintptr_t)segment->vmaddr;
                if (value >= start && value < (start + (uintptr_t)segment->vmsize))
                {
                    return segment->segname;
                }
            }
        }
        cursor += command->cmdsize;
    }
    return nullptr;
}

BOOL rcl_vtable_shaped(uintptr_t value)
{
    const char *segment = rcl_image_segment_name(value);
    if (!segment)
    {
        return NO;
    }
    if (value % 8)
    {
        return NO;
    }
    if (strcmp(segment, "__DATA_CONST") == 0)
    {
        return YES;
    }
    if (strcmp(segment, "__DATA") == 0)
    {
        return YES;
    }
    return NO;
}

BOOL rcl_heap_resident(uintptr_t value)
{
    if (!value)
    {
        return NO;
    }
    return rcl_image_segment_name(value) ? NO : YES;
}
BOOL rcl_instance_shaped(uintptr_t object)
{
    void *vtable = nullptr;
    if (!rcl_pointer_plausible(object))
    {
        return NO;
    }
    if (!rcl_heap_resident(object))
    {
        return NO;
    }
    if (!rcl_read_ptr(object, &vtable))
    {
        return NO;
    }
    if (!vtable)
    {
        return NO;
    }
    if ((uintptr_t)vtable == object)
    {
        return NO;
    }
    if (!rcl_vtable_shaped((uintptr_t)vtable))
    {
        return NO;
    }
    return YES;
}

BOOL rcl_manager_shape(uintptr_t manager)
{
    void *array = nullptr;
    void *probe = nullptr;
    int32_t count = 0;
    int32_t capacity = 0;
    if (!rcl_heap_resident(manager))
    {
        return NO;
    }
    if (!rcl_read_ptr(manager + RCL_MGR_ARRAY_OFF, &array))
    {
        return NO;
    }
    if (!rcl_read_int(manager + RCL_MGR_COUNT_OFF, &count))
    {
        return NO;
    }
    if (!rcl_read_int(manager + RCL_MGR_CAP_OFF, &capacity))
    {
        return NO;
    }
    if (count < 0 || count > 96)
    {
        return NO;
    }
    if (capacity < count || capacity > 4096)
    {
        return NO;
    }
    if (array && !rcl_heap_resident((uintptr_t)array))
    {
        return NO;
    }
    if (count > 0)
    {
        if (!array)
        {
            return NO;
        }
        if (!rcl_read_ptr((uintptr_t)array, &probe))
        {
            return NO;
        }
        if (!rcl_heap_resident((uintptr_t)probe))
        {
            return NO;
        }
        if (count > 1)
        {
            if (!rcl_read_ptr((uintptr_t)array + (uintptr_t)(count - 1) * sizeof(void *), &probe))
            {
                return NO;
            }
            if (!rcl_heap_resident((uintptr_t)probe))
            {
                return NO;
            }
        }
    }
    return YES;
}
int rcl_trail_count = 0;

BOOL rcl_vtable_in_image(uintptr_t vtable)
{
    uintptr_t lo = 0;
    uintptr_t hi = 0;
    if (!vtable)
    {
        return NO;
    }
    if (vtable >= rcl_base + RCL_DC_RVA_LO && vtable < rcl_base + RCL_DC_RVA_LO + RCL_DC_RVA_SIZE)
    {
        return YES;
    }
    if (rcl_segment_range("__DATA", &lo, &hi) && vtable >= lo && vtable < hi)
    {
        return YES;
    }
    return NO;
}

uintptr_t rcl_strip_ptr(uintptr_t value)
{
    uintptr_t stripped = value;
#if __has_feature(ptrauth_calls)
    stripped = (uintptr_t)ptrauth_strip((void *)value, ptrauth_key_function_pointer);
#endif
    if (stripped >= rcl_base && stripped < rcl_base + RCL_IMAGE_SPAN)
    {
        return stripped;
    }
    if ((stripped & 0xffffffffULL) < RCL_IMAGE_SPAN)
    {
        uintptr_t viaLow = rcl_base + (stripped & 0xffffffffULL);
        if (viaLow >= rcl_base && viaLow < rcl_base + RCL_IMAGE_SPAN)
        {
            return viaLow;
        }
    }
    return stripped;
}

void poll_for_game(int tick)
{
    if (rcl_setup_done)
    {
        return;
    }
    if (tick > 1200)
    {
        return;
    }
    uintptr_t base = 0;
    if (find_game_image(&base))
    {
        rcl_base = base;
        setup();
        return;
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
                     poll_for_game(tick + 1);
                   });
}

uintptr_t rcl_base = 0;

uint64_t rcl_ticks_a = 0;

uintptr_t rcl_manager_ptr = 0;

int rcl_collect(uintptr_t manager, rcl_obj_t *out, int capacity)
{
    void *data = nullptr;
    int32_t count = 0;
    int usable = 0;
    uintptr_t gidOff = RCL_OBJ_GLOBALID_OFF;
    uint32_t walkSeq = 0;
    rcl_gidless_scan(manager);
    if (!manager)
    {
        return 0;
    }
    if (!rcl_read_ptr(manager + RCL_MGR_ARRAY_OFF, &data) || !data)
    {
        return 0;
    }
    if (!rcl_read_int((uintptr_t)manager + RCL_MGR_COUNT_OFF, &count))
    {
        return 0;
    }
    if (count <= 0)
    {
        return 0;
    }
    if (count > capacity)
    {
        count = capacity;
    }
    gidOff = rcl_list_gid_off((uintptr_t)data, count);
    walkSeq = rcl_seq;
    for (int32_t i = 0; i < count && usable < capacity; i++)
    {
        void *element = nullptr;
        void *vtable = nullptr;
        rcl_obj_t entry;
        uintptr_t vtRva = 0;
        memset(&entry, 0, sizeof(entry));
        if (rcl_seq != walkSeq)
        {
            break;
        }
        if (!rcl_read_ptr((uintptr_t)data + (uintptr_t)i * sizeof(void *), &element))
        {
            continue;
        }
        if (!element)
        {
            continue;
        }
        entry.object = (uintptr_t)element;
        if (rcl_element_ascii(entry.object))
        {
            continue;
        }
        if (!rcl_read_ptr(entry.object, &vtable) || !vtable)
        {
            continue;
        }
        vtRva = (uintptr_t)vtable - rcl_base;
        if (vtRva < RCL_DC_RVA_LO || vtRva >= RCL_DC_RVA_LO + RCL_DC_RVA_SIZE)
        {
            continue;
        }
        entry.gid = rcl_gid_at(entry.object, gidOff);
        {
            uintptr_t tw = 0;
            rcl_element_type((uintptr_t)vtable, &tw);
            entry.typeWord = (int32_t)tw;
        }
        if (!rcl_read_int(entry.object + rcl_coord_x_off(), &entry.x) ||
            !rcl_read_int(entry.object + rcl_coord_y_off(), &entry.y) ||
            !rcl_read_int(entry.object + RCL_OBJ_OWNERINDEX_OFF, &entry.ownerIndex) ||
            !rcl_read_int(entry.object + RCL_OBJ_TEAM_OFF, &entry.teamOld) ||
            !rcl_read_int(entry.object + RCL_TEAM_OFF, &entry.teamNew) ||
            !rcl_read_byte(entry.object + RCL_OBJ_DEADFLAG_OFF, &entry.dead) ||
            !rcl_read_byte(entry.object + RCL_OBJ_ACTIVEFLAG_OFF, &entry.activeFlag))
        {
            continue;
        }
        if (entry.gid >= 2000000)
        {
            rcl_proj_track(entry.object, vtRva, entry.gid, entry.teamOld);
            if (rcl_dump_np < RCL_NP_DUMPS)
            {
                int32_t npX = 0;
                int32_t npY = 0;
                int32_t np70 = 0;
                int32_t np74 = 0;
                float npFx = 0.0f;
                float npFy = 0.0f;
                float npF70 = 0.0f;
                float npF74 = 0.0f;
                void *np38 = nullptr;
                rcl_dump_np++;
                rcl_read_int(entry.object + RCL_OBJ_X_OFF, &npX);
                rcl_read_int(entry.object + RCL_OBJ_Y_OFF, &npY);
                rcl_read_int(entry.object + RCL_OFF, &np70);
                rcl_read_int(entry.object + RCL_OFF + 4ULL, &np74);
                rcl_read_ptr(entry.object + RCL_NP_PTR_OFF, &np38);
                if (!rcl_read_float(entry.object + RCL_OBJ_X_OFF, &npFx))
                {
                    npFx = 0.0f;
                }
                if (!rcl_read_float(entry.object + RCL_OBJ_Y_OFF, &npFy))
                {
                    npFy = 0.0f;
                }
                if (!rcl_read_float(entry.object + RCL_OFF, &npF70))
                {
                    npF70 = 0.0f;
                }
                if (!rcl_read_float(entry.object + RCL_OFF + 4ULL, &npF74))
                {
                    npF74 = 0.0f;
                }
            }
            continue;
        }
        if (entry.gid == 0 && !rcl_gidless)
        {
            continue;
        }
        if (entry.x <= -1000000 || entry.x >= 1000000 || entry.y <= -1000000 || entry.y >= 1000000)
        {
            if (!RCL_COORD_SOFT)
            {
                continue;
            }
        }
        if ((entry.teamOld < 0 || entry.teamOld > 7) && (entry.teamNew < 0 || entry.teamNew > 7))
        {
            continue;
        }
        out[usable++] = entry;
    }
    return usable;
}

int rcl_small(long value)
{
    return (value > -RCL_VALUE_MAX && value < RCL_VALUE_MAX) ? 1 : 0;
}

float rcl_as_float(uint32_t bits)
{
    union
    {
        uint32_t u;
        float f;
    } view;
    view.u = bits;
    return view.f;
}

void rcl_discriminate(uintptr_t manager)
{
    rcl_obj_t objects[64];
    uint32_t words[RCL_ELEMS][RCL_ELEM_WORDS];
    int usable = 0;
    int n = 0;
    int teamOff = -1;
    int coordOff = -1;
    int intPairOff = -1;
    int floatPairOff = -1;
    memset(objects, 0, sizeof(objects));
    memset(words, 0, sizeof(words));
    usable = rcl_collect(manager, objects, 64);
    if (usable == 0)
    {
        return;
    }
    if (usable == 1)
    {
        return;
    }
    n = (usable < RCL_ELEMS) ? usable : RCL_ELEMS;
    for (int i = 0; i < n; i++)
    {
        if (!rcl_read_bytes(objects[i].object, words[i], sizeof(words[i])))
        {
            return;
        }
    }
    for (int w = 0; w < RCL_ELEM_WORDS; w++)
    {
        int distinct = 0;
        int allSmall = 1;
        int allTiny = 1;
        int64_t minV = 0;
        int64_t maxV = 0;
        for (int i = 0; i < n; i++)
        {
            int32_t value = (int32_t)words[i][w];
            int seen = 0;
            for (int j = 0; j < i; j++)
            {
                if (words[j][w] == words[i][w])
                {
                    seen = 1;
                    break;
                }
            }
            if (!seen)
            {
                distinct++;
            }
            if (i == 0)
            {
                minV = value;
                maxV = value;
            }
            if (value < minV)
            {
                minV = value;
            }
            if (value > maxV)
            {
                maxV = value;
            }
            if (!rcl_small(value))
            {
                allSmall = 0;
            }
            if (value < 0 || value > 15)
            {
                allTiny = 0;
            }
        }
        if (distinct <= 1)
        {
            continue;
        }
        if (teamOff < 0 && allTiny && distinct >= 2 && distinct <= RCL_TEAM_MAX)
        {
            teamOff = w * 4;
        }
        if (coordOff < 0 && allSmall && distinct == n)
        {
            coordOff = w * 4;
        }
    }
    if (teamOff == (int)RCL_OBJ_X_OFF || teamOff == (int)RCL_OBJ_Y_OFF)
    {
        teamOff = -1;
    }
    {
        int order[RCL_ELEM_WORDS];
        int orderCount = 0;
        int defaultWord = (int)(RCL_OBJ_X_OFF / 4);
        if (defaultWord >= 0 && defaultWord + 1 < RCL_ELEM_WORDS)
        {
            order[orderCount++] = defaultWord;
        }
        for (int w = 0; w + 1 < RCL_ELEM_WORDS; w++)
        {
            if (w != defaultWord)
            {
                order[orderCount++] = w;
            }
        }
        for (int k = 0; k < orderCount && intPairOff < 0; k++)
        {
            int w = order[k];
            int ok = 1;
            int dx = 0;
            int dy = 0;
            if (teamOff >= 0 && (w * 4 == teamOff || (w + 1) * 4 == teamOff))
            {
                continue;
            }
            for (int i = 0; i < n && ok; i++)
            {
                if (!rcl_small((int32_t)words[i][w]))
                {
                    ok = 0;
                }
                if (!rcl_small((int32_t)words[i][w + 1]))
                {
                    ok = 0;
                }
            }
            if (!ok)
            {
                continue;
            }
            for (int i = 0; i < n; i++)
            {
                int seenX = 0;
                int seenY = 0;
                for (int j = 0; j < i; j++)
                {
                    if (words[j][w] == words[i][w])
                    {
                        seenX = 1;
                    }
                    if (words[j][w + 1] == words[i][w + 1])
                    {
                        seenY = 1;
                    }
                }
                if (!seenX)
                {
                    dx++;
                }
                if (!seenY)
                {
                    dy++;
                }
            }
            if (dx == n && dy == n)
            {
                intPairOff = w * 4;
            }
        }
    }
    for (int w = 0; w + 1 < RCL_ELEM_WORDS && floatPairOff < 0; w++)
    {
        int ok = 1;
        int anyNonZero = 0;
        int distinctPairs = 0;
        int seenAny = 0;
        float fx = 0.0f;
        float fy = 0.0f;
        if (teamOff >= 0 && (w * 4 == teamOff || (w + 1) * 4 == teamOff))
        {
            continue;
        }
        for (int i = 0; i < n; i++)
        {
            float ax = rcl_as_float(words[i][w]);
            float ay = rcl_as_float(words[i][w + 1]);
            int seen = 0;
            if (ax <= -RCL_FLOAT_MAX || ax >= RCL_FLOAT_MAX)
            {
                ok = 0;
            }
            if (ay <= -RCL_FLOAT_MAX || ay >= RCL_FLOAT_MAX)
            {
                ok = 0;
            }
            if (words[i][w] != 0 || words[i][w + 1] != 0)
            {
                anyNonZero = 1;
            }
            if (i == 0)
            {
                fx = ax;
                fy = ay;
            }
            for (int j = 0; j < i; j++)
            {
                if (words[j][w] == words[i][w] && words[j][w + 1] == words[i][w + 1])
                {
                    seen = 1;
                    break;
                }
            }
            if (!seen)
            {
                distinctPairs++;
                if (i > 0)
                {
                    seenAny = 1;
                }
            }
        }
        if (!ok || !anyNonZero || !seenAny)
        {
            continue;
        }
        floatPairOff = w * 4;
    }
}

uint64_t rcl_us(void)
{
    static mach_timebase_info_data_t tb;
    static int ready = 0;
    uint64_t t = 0;
    if (!ready)
    {
        ready = 1;
        mach_timebase_info(&tb);
    }
    t = mach_absolute_time();
    if (tb.denom == 0)
    {
        return t / 1000ULL;
    }
    return (t / (uint64_t)tb.denom) * (uint64_t)tb.numer / 1000ULL;
}

int rcl_logs_a = 0;

int rcl_seeded = 0;

int32_t rcl_last_x_a = 0;

int32_t rcl_last_y_a = 0;

uintptr_t rcl_pair_base(void)
{
    void *battleRaw = nullptr;
    uintptr_t battle = 0;
    uintptr_t alt = rcl_controller();
    if (rcl_base && rcl_read_ptr(rcl_base + RCL_BATTLE_RVA, &battleRaw))
    {
        battle = (uintptr_t)battleRaw;
    }
    if (battle)
    {
        if (rcl_hop(battle, nullptr))
        {
            return battle;
        }
    }
    return alt;
}

const char *rcl_prologue_rule(uintptr_t address)
{
    uint32_t first = 0;
    if (!rcl_read_word(address, &first))
    {
        return "unreadable";
    }
    if (first == 0xD503233F)
    {
        return "paciasp";
    }
    if (first == 0xD503237F)
    {
        return "pacibsp";
    }
    if ((first & 0xFFFFFF1F) == 0xD503241F)
    {
        return "bti";
    }
    if ((first & 0xFF800000u) == 0xA9800000u && ((first >> 5) & 31u) == 31u)
    {
        return "stppre";
    }
    if ((first & 0xFF8003FFu) == 0xD10003FFu)
    {
        return "subsp";
    }
    if (address >= 4)
    {
        uint32_t previous = 0;
        if (rcl_read_word(address - 4, &previous) && previous == 0xD65F03C0)
        {
            return "afterret";
        }
    }
    return "none";
}

BOOL rcl_looks_like_start(uintptr_t address)
{
    const char *rule = rcl_prologue_rule(address);
    if (!rule)
    {
        return NO;
    }
    return strcmp(rule, "none") != 0 && strcmp(rule, "unreadable") != 0;
}

size_t rcl_start_index(uintptr_t address, BOOL *exact)
{
    size_t index = (size_t)-1;
    if (exact)
    {
        *exact = NO;
    }
    if (!rcl_starts || !rcl_starts_count)
    {
        return index;
    }
    size_t low = 0;
    size_t high = rcl_starts_count;
    while (low < high)
    {
        size_t mid = low + (high - low) / 2;
        if (rcl_starts[mid] <= address)
        {
            low = mid + 1;
        }
        else
        {
            high = mid;
        }
    }
    if (low == 0)
    {
        return index;
    }
    index = low - 1;
    if (exact)
    {
        *exact = (rcl_starts[index] == address);
    }
    return index;
}

BOOL rcl_start_word(uint32_t word)
{
    if (word == 0xD503233F || word == 0xD503237F)
    {
        return YES;
    }
    if ((word & 0xFFFFFF1Fu) == 0xD503241Fu)
    {
        return YES;
    }
    if ((word & 0xFF800000u) == 0xA9800000u && ((word >> 5) & 31u) == 31u)
    {
        return YES;
    }
    if ((word & 0xFF8003FFu) == 0xD10003FFu)
    {
        return YES;
    }
    return NO;
}

BOOL rcl_start_boundary(const uint8_t *bytes, size_t offset)
{
    if (offset < 4)
    {
        return NO;
    }
    for (size_t back = 4, seen = 0; back <= offset && seen < 8; back += 4, seen++)
    {
        uint32_t word = 0;
        memcpy(&word, bytes + offset - back, 4);
        if (word == 0xD65F03C0)
        {
            return YES;
        }
        if (word == 0xD503201F)
        {
            continue;
        }
        if ((word & 0xFFFFFF1Fu) == 0xD503241Fu)
        {
            continue;
        }
        return NO;
    }
    return NO;
}

void rcl_load_function_starts(void)
{
    if (rcl_starts || !rcl_base)
    {
        return;
    }
    uintptr_t textAddress = 0;
    uint64_t textSize = 0;
    if (!rcl_text_section(&textAddress, &textSize))
    {
        return;
    }
    if (textSize < 64 || textSize > (64ull * 1024ull * 1024ull))
    {
        return;
    }
    uint8_t *bytes = (uint8_t *)malloc((size_t)textSize);
    if (!bytes)
    {
        return;
    }
    if (!rcl_copy(textAddress, bytes, (size_t)textSize))
    {
        free(bytes);
        return;
    }
    size_t capacity = 32768;
    uintptr_t *starts = (uintptr_t *)malloc(capacity * sizeof(uintptr_t));
    if (!starts)
    {
        free(bytes);
        return;
    }
    size_t count = 0;
    for (size_t offset = 4; offset + 4 <= (size_t)textSize; offset += 4)
    {
        uint32_t word = 0;
        memcpy(&word, bytes + offset, 4);
        if (!rcl_start_word(word))
        {
            continue;
        }
        if (!rcl_start_boundary(bytes, offset))
        {
            continue;
        }
        if (count >= capacity)
        {
            size_t grown = capacity * 2;
            uintptr_t *larger = (uintptr_t *)realloc(starts, grown * sizeof(uintptr_t));
            if (!larger)
            {
                break;
            }
            starts = larger;
            capacity = grown;
        }
        starts[count++] = textAddress + offset;
    }
    free(bytes);
    if (!count)
    {
        free(starts);
        return;
    }
    rcl_starts = starts;
    rcl_starts_count = count;
}
int rcl_word(uintptr_t address, uint32_t *out)
{
    if (!out)
    {
        return 0;
    }
    if (address & 3ULL)
    {
        return 0;
    }
    return rcl_read_bytes(address, out, sizeof(*out)) ? 1 : 0;
}

int rcl_is_term(uint32_t w)
{
    if ((w & 0xFFFFFC1Fu) == 0xD65F0000u)
    {
        return 1;
    }
    if ((w & 0xFFFFFC1Fu) == 0xD61F0000u)
    {
        return 1;
    }
    if (w == 0xD69F03E0u)
    {
        return 1;
    }
    if ((w & 0xFC000000u) == 0x14000000u)
    {
        return 1;
    }
    return 0;
}

int rcl_is_prologue(uint32_t w)
{
    if (w == 0xD503237Fu || w == 0xD503233Fu)
    {
        return 1;
    }
    if ((w & 0xFFFFFF1Fu) == 0xD503241Fu)
    {
        return 1;
    }
    if ((w & 0xFF800000u) == 0xA9800000u && ((w >> 5) & 31u) == 31u)
    {
        return 1;
    }
    if ((w & 0xFF8003FFu) == 0xD10003FFu)
    {
        return 1;
    }
    return 0;
}

uintptr_t rcl_entry(uintptr_t rva)
{
    uint32_t self = 0;
    uint32_t prev = 0;
    if (!rcl_base || !rva)
    {
        return 0;
    }
    if (!rcl_word(rcl_base + rva, &self))
    {
        return 0;
    }
    if (self == 0)
    {
        return 0;
    }
    if (rcl_is_prologue(self))
    {
        return rcl_base + rva;
    }
    if (!rcl_word(rcl_base + rva - 4, &prev))
    {
        return 0;
    }
    if (rcl_is_term(prev))
    {
        return rcl_base + rva;
    }
    return 0;
}

uintptr_t *rcl_starts = nullptr;

size_t rcl_starts_count = 0;

uintptr_t rcl_setpred = 0;

int rcl_live_objs = 0;

int rcl_live_teams = 0;

int rcl_fb_on = 0;

unsigned long long rcl_obj_prev = 0;

uintptr_t rcl_site = 0;

int rcl_site_state = -1;

int rcl_scan_armed = -1;

volatile uint32_t rcl_seq = 0;

uintptr_t rcl_pub_object = 0;

uintptr_t rcl_pub_array = 0;

int32_t rcl_pub_count = 0;

uintptr_t rcl_tick_object = 0;

uintptr_t rcl_tick_array = 0;

int32_t rcl_tick_count = 0;

void rcl_publish(uintptr_t object, uintptr_t array, int32_t count, int32_t, const char *)
{
    __sync_synchronize();
    rcl_seq++;
    __sync_synchronize();
    rcl_pub_object = object;
    rcl_pub_array = array;
    rcl_pub_count = count;
    rcl_players_object = object;
    rcl_players_array = array;
    rcl_players_count = count;
    __sync_synchronize();
    rcl_seq++;
    __sync_synchronize();
}

int rcl_snapshot(uintptr_t *objectOut, uintptr_t *arrayOut, int32_t *countOut)
{
    int tries;
    for (tries = 0; tries < 8; tries++)
    {
        uint32_t s1 = rcl_seq;
        uintptr_t o;
        uintptr_t a;
        int32_t c;
        if (s1 & 1u)
        {
            continue;
        }
        o = rcl_pub_object;
        a = rcl_pub_array;
        c = rcl_pub_count;
        __sync_synchronize();
        if (rcl_seq != s1)
        {
            continue;
        }
        if (objectOut)
        {
            *objectOut = o;
        }
        if (arrayOut)
        {
            *arrayOut = a;
        }
        if (countOut)
        {
            *countOut = c;
        }
        return 1;
    }
    return 0;
}

void rcl_tick_begin(void)
{
    uintptr_t o = 0;
    uintptr_t a = 0;
    int32_t c = 0;
    if (!rcl_snapshot(&o, &a, &c))
    {
        return;
    }
    rcl_tick_object = o;
    rcl_tick_array = a;
    rcl_tick_count = c;
}

uint64_t rcl_idle_start = 0;

static const uint32_t rcl_slot_site_hash[34] = {
    0x7744a9f0u, 0xd8ef9922u, 0x00000000u, 0x00000000u,
    0x00000000u, 0x3888a7e0u, 0x00000000u, 0x00000000u,
    0x00000000u, 0x00000000u, 0x00000000u, 0xe5674c94u,
    0x00000000u, 0x6e078ab4u, 0x6e078ab4u, 0x00000000u,
    0x4d5cf2adu, 0x04be5d31u, 0xa7ee96fau, 0xcfef7319u,
    0x140cf28cu, 0x00000000u, 0x00000000u, 0x75481000u,
    0x1a66e6cfu, 0x00000000u, 0x00000000u, 0x00000000u,
    0xdba51345u, 0x1f08716fu, 0xd537a3b5u, 0x41120014u,
    0x00000000u, 0x1d5fea33u,
};

static uint32_t rcl_site_hash(uintptr_t address)
{
    uint8_t bytes[16];
    uint32_t hash = 0x811c9dc5u;
    int i = 0;

    if (!rcl_read_bytes(address, bytes, sizeof(bytes)))
    {
        return 0;
    }

    for (i = 0; i < (int)sizeof(bytes); i++)
    {
        hash ^= (uint32_t)bytes[i];
        hash *= 0x01000193u;
    }

    return hash;
}

void rcl_slot_hooks_install(void)
{
    rcl_hook_t specs[34];
    int i = 0;

    if (!rcl_base)
    {
        return;
    }

    memcpy(specs, rcl_slot_specs, sizeof(specs));

    for (i = 0; i < 34; i++)
    {
        if (!specs[i].rva || !rcl_slot_site_hash[i])
        {
            continue;
        }

        if (rcl_site_hash(rcl_base + specs[i].rva) != rcl_slot_site_hash[i])
        {
            specs[i].rva = 0;
        }
    }

    rcl_hooks_install(rcl_base, specs, 34, (void **)rcl_slot_orig);
}

const int rcl_object_slots[3] = {2, 3, 4};

uint64_t rcl_slot_hits[34] = {0};

int rcl_pub_logs = 0;

void rcl_slot_pump(void)
{
    int first = -1;
    for (int i = 0; i < 34; i++)
    {
        if (!rcl_slot_object[i])
        {
            continue;
        }
        if (!rcl_slot_specs[i].control && first < 0)
        {
            first = i;
        }
    }
    if (first < 0)
    {
        return;
    }
    uintptr_t object = rcl_slot_object[first];
    if (rcl_slot_adopted == object)
    {
        return;
    }
    rcl_slot_adopted = object;
    {
        void *vtable = nullptr;
        if (!(rcl_read_ptr(object, &vtable) && vtable && rcl_vtable_in_image((uintptr_t)vtable)) &&
            !rcl_pointer_plausible((uintptr_t)vtable))
        {
            return;
        }
    }
}

rcl_slot_fn_t rcl_slot_orig[34] = {nullptr};

uint64_t rcl_slot_repl_0(void *a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5,
                         uint64_t a6, uint64_t a7)
{
    rcl_slot_note(0, a0, a1);
    if (rcl_slot_orig[0])
    {
        return rcl_slot_orig[0](a0, a1, a2, a3, a4, a5, a6, a7);
    }
    return 0;
}

uint64_t rcl_slot_repl_1(void *a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5,
                         uint64_t a6, uint64_t a7)
{
    rcl_slot_note(1, a0, a1);
    if (rcl_slot_orig[1])
    {
        return rcl_slot_orig[1](a0, a1, a2, a3, a4, a5, a6, a7);
    }
    return 0;
}

uint64_t rcl_slot_repl_2(void *a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5,
                         uint64_t a6, uint64_t a7)
{
    rcl_slot_note(2, a0, a1);
    if (rcl_slot_orig[2])
    {
        return rcl_slot_orig[2](a0, a1, a2, a3, a4, a5, a6, a7);
    }
    return 0;
}

uint64_t rcl_slot_repl_3(void *a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5,
                         uint64_t a6, uint64_t a7)
{
    rcl_slot_note(3, a0, a1);
    if (rcl_slot_orig[3])
    {
        return rcl_slot_orig[3](a0, a1, a2, a3, a4, a5, a6, a7);
    }
    return 0;
}

uint64_t rcl_slot_repl_4(void *a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5,
                         uint64_t a6, uint64_t a7)
{
    rcl_slot_note(4, a0, a1);
    if (rcl_slot_orig[4])
    {
        return rcl_slot_orig[4](a0, a1, a2, a3, a4, a5, a6, a7);
    }
    return 0;
}

uint64_t rcl_slot_repl_5(void *a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5,
                         uint64_t a6, uint64_t a7)
{
    rcl_slot_note(5, a0, a1);
    if (rcl_slot_orig[5])
    {
        return rcl_slot_orig[5](a0, a1, a2, a3, a4, a5, a6, a7);
    }
    return 0;
}

uint64_t rcl_slot_repl_6(void *a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5,
                         uint64_t a6, uint64_t a7)
{
    rcl_slot_note(6, a0, a1);
    if (rcl_slot_orig[6])
    {
        return rcl_slot_orig[6](a0, a1, a2, a3, a4, a5, a6, a7);
    }
    return 0;
}

uint64_t rcl_slot_repl_7(void *a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5,
                         uint64_t a6, uint64_t a7)
{
    rcl_slot_note(7, a0, a1);
    if (rcl_slot_orig[7])
    {
        return rcl_slot_orig[7](a0, a1, a2, a3, a4, a5, a6, a7);
    }
    return 0;
}

uint64_t rcl_slot_repl_8(void *a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5,
                         uint64_t a6, uint64_t a7)
{
    rcl_slot_note(8, a0, a1);
    if (rcl_slot_orig[8])
    {
        return rcl_slot_orig[8](a0, a1, a2, a3, a4, a5, a6, a7);
    }
    return 0;
}

uint64_t rcl_slot_repl_9(void *a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5,
                         uint64_t a6, uint64_t a7)
{
    rcl_slot_note(9, a0, a1);
    if (rcl_slot_orig[9])
    {
        return rcl_slot_orig[9](a0, a1, a2, a3, a4, a5, a6, a7);
    }
    return 0;
}

uint64_t rcl_slot_repl_10(void *a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5,
                          uint64_t a6, uint64_t a7)
{
    rcl_slot_note(10, a0, a1);
    if (rcl_slot_orig[10])
    {
        return rcl_slot_orig[10](a0, a1, a2, a3, a4, a5, a6, a7);
    }
    return 0;
}

uint64_t rcl_slot_repl_11(void *a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5,
                          uint64_t a6, uint64_t a7)
{
    rcl_slot_note(11, a0, a1);
    if (rcl_slot_orig[11])
    {
        return rcl_slot_orig[11](a0, a1, a2, a3, a4, a5, a6, a7);
    }
    return 0;
}

uint64_t rcl_slot_repl_12(void *a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5,
                          uint64_t a6, uint64_t a7)
{
    rcl_slot_note(12, a0, a1);
    if (rcl_slot_orig[12])
    {
        return rcl_slot_orig[12](a0, a1, a2, a3, a4, a5, a6, a7);
    }
    return 0;
}

uint64_t rcl_slot_repl_13(void *a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5,
                          uint64_t a6, uint64_t a7)
{
    rcl_slot_note(13, a0, a1);
    if (rcl_slot_orig[13])
    {
        return rcl_slot_orig[13](a0, a1, a2, a3, a4, a5, a6, a7);
    }
    return 0;
}

uint64_t rcl_slot_repl_14(void *a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5,
                          uint64_t a6, uint64_t a7)
{
    rcl_slot_note(14, a0, a1);
    if (rcl_slot_orig[14])
    {
        return rcl_slot_orig[14](a0, a1, a2, a3, a4, a5, a6, a7);
    }
    return 0;
}

uint64_t rcl_slot_repl_15(void *a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5,
                          uint64_t a6, uint64_t a7)
{
    rcl_slot_note(15, a0, a1);
    if (rcl_slot_orig[15])
    {
        return rcl_slot_orig[15](a0, a1, a2, a3, a4, a5, a6, a7);
    }
    return 0;
}

uint64_t rcl_slot_repl_16(void *a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5,
                          uint64_t a6, uint64_t a7)
{
    rcl_slot_note(16, a0, a1);
    if (rcl_slot_orig[16])
    {
        return rcl_slot_orig[16](a0, a1, a2, a3, a4, a5, a6, a7);
    }
    return 0;
}

uint64_t rcl_slot_repl_17(void *a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5,
                          uint64_t a6, uint64_t a7)
{
    rcl_slot_note(17, a0, a1);
    if (rcl_slot_orig[17])
    {
        return rcl_slot_orig[17](a0, a1, a2, a3, a4, a5, a6, a7);
    }
    return 0;
}

uint64_t rcl_slot_repl_18(void *a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5,
                          uint64_t a6, uint64_t a7)
{
    rcl_slot_note(18, a0, a1);
    if (rcl_slot_orig[18])
    {
        return rcl_slot_orig[18](a0, a1, a2, a3, a4, a5, a6, a7);
    }
    return 0;
}

uint64_t rcl_slot_repl_19(void *a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5,
                          uint64_t a6, uint64_t a7)
{
    rcl_slot_note(19, a0, a1);
    if (rcl_slot_orig[19])
    {
        return rcl_slot_orig[19](a0, a1, a2, a3, a4, a5, a6, a7);
    }
    return 0;
}

uint64_t rcl_slot_repl_20(void *a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5,
                          uint64_t a6, uint64_t a7)
{
    rcl_slot_note(20, a0, a1);
    if (rcl_slot_orig[20])
    {
        return rcl_slot_orig[20](a0, a1, a2, a3, a4, a5, a6, a7);
    }
    return 0;
}

uint64_t rcl_slot_repl_21(void *a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5,
                          uint64_t a6, uint64_t a7)
{
    rcl_slot_note(21, a0, a1);
    if (rcl_slot_orig[21])
    {
        return rcl_slot_orig[21](a0, a1, a2, a3, a4, a5, a6, a7);
    }
    return 0;
}

uint64_t rcl_slot_repl_22(void *a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5,
                          uint64_t a6, uint64_t a7)
{
    rcl_slot_note(22, a0, a1);
    if (rcl_slot_orig[22])
    {
        return rcl_slot_orig[22](a0, a1, a2, a3, a4, a5, a6, a7);
    }
    return 0;
}

uint64_t rcl_slot_repl_23(void *a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5,
                          uint64_t a6, uint64_t a7)
{
    rcl_slot_note(23, a0, a1);
    if (rcl_slot_orig[23])
    {
        return rcl_slot_orig[23](a0, a1, a2, a3, a4, a5, a6, a7);
    }
    return 0;
}

uint64_t rcl_slot_repl_24(void *a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5,
                          uint64_t a6, uint64_t a7)
{
    rcl_slot_note(24, a0, a1);
    if (rcl_slot_orig[24])
    {
        return rcl_slot_orig[24](a0, a1, a2, a3, a4, a5, a6, a7);
    }
    return 0;
}

uint64_t rcl_slot_repl_25(void *a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5,
                          uint64_t a6, uint64_t a7)
{
    rcl_slot_note(25, a0, a1);
    if (rcl_slot_orig[25])
    {
        return rcl_slot_orig[25](a0, a1, a2, a3, a4, a5, a6, a7);
    }
    return 0;
}

uint64_t rcl_slot_repl_26(void *a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5,
                          uint64_t a6, uint64_t a7)
{
    rcl_slot_note(26, a0, a1);
    if (rcl_slot_orig[26])
    {
        return rcl_slot_orig[26](a0, a1, a2, a3, a4, a5, a6, a7);
    }
    return 0;
}

uint64_t rcl_slot_repl_27(void *a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5,
                          uint64_t a6, uint64_t a7)
{
    rcl_slot_note(27, a0, a1);
    if (rcl_slot_orig[27])
    {
        return rcl_slot_orig[27](a0, a1, a2, a3, a4, a5, a6, a7);
    }
    return 0;
}

uint64_t rcl_slot_repl_28(void *a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5,
                          uint64_t a6, uint64_t a7)
{
    rcl_slot_note(28, a0, a1);
    if (rcl_slot_orig[28])
    {
        return rcl_slot_orig[28](a0, a1, a2, a3, a4, a5, a6, a7);
    }
    return 0;
}

uint64_t rcl_slot_repl_29(void *a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5,
                          uint64_t a6, uint64_t a7)
{
    rcl_slot_note(29, a0, a1);
    if (rcl_slot_orig[29])
    {
        return rcl_slot_orig[29](a0, a1, a2, a3, a4, a5, a6, a7);
    }
    return 0;
}

uint64_t rcl_slot_repl_30(void *a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5,
                          uint64_t a6, uint64_t a7)
{
    rcl_slot_note(30, a0, a1);
    if (rcl_slot_orig[30])
    {
        return rcl_slot_orig[30](a0, a1, a2, a3, a4, a5, a6, a7);
    }
    return 0;
}

uint64_t rcl_slot_repl_31(void *a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5,
                          uint64_t a6, uint64_t a7)
{
    rcl_slot_note(31, a0, a1);
    if (rcl_slot_orig[31])
    {
        return rcl_slot_orig[31](a0, a1, a2, a3, a4, a5, a6, a7);
    }
    return 0;
}

uint64_t rcl_slot_repl_32(void *a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5,
                          uint64_t a6, uint64_t a7)
{
    uint64_t r = 0;
    if (rcl_slot_orig[32])
    {
        r = rcl_slot_orig[32](a0, a1, a2, a3, a4, a5, a6, a7);
    }
    return r;
}

uint64_t rcl_slot_repl_33(void *a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5,
                          uint64_t a6, uint64_t a7)
{
    uint64_t r = 0;
    if (rcl_slot_orig[33])
    {
        r = rcl_slot_orig[33](a0, a1, a2, a3, a4, a5, a6, a7);
    }
    return r;
}

const rcl_hook_t rcl_slot_specs[34] = {
    {RCL_SLOT_RVA_0, (void *)rcl_slot_repl_0, 0},
    {RCL_SLOT_RVA_1, (void *)rcl_slot_repl_1, 0},
    {RCL_SLOT_NONE, (void *)rcl_slot_repl_2, 0},
    {RCL_SLOT_NONE, (void *)rcl_slot_repl_3, 0},
    {RCL_SLOT_NONE, (void *)rcl_slot_repl_4, 0},
    {RCL_SLOT_RVA_5, (void *)rcl_slot_repl_5, 1},
    {0, (void *)rcl_slot_repl_6, 1},
    {RCL_SLOT_NONE, (void *)rcl_slot_repl_7, 0},
    {RCL_SLOT_NONE, (void *)rcl_slot_repl_8, 0},
    {RCL_SLOT_NONE, (void *)rcl_slot_repl_9, 0},
    {RCL_SLOT_NONE, (void *)rcl_slot_repl_10, 0},
    {RCL_SLOT_RVA_11, (void *)rcl_slot_repl_11, 0},
    {RCL_SLOT_NONE, (void *)rcl_slot_repl_12, 1},
    {RCL_SLOT_RVA_13, (void *)rcl_slot_repl_13, 0},
    {RCL_SLOT_RVA_14, (void *)rcl_slot_repl_14, 0},
    {RCL_SLOT_NONE, (void *)rcl_slot_repl_15, 0},
    {RCL_SLOT_RVA_16, (void *)rcl_slot_repl_16, 0},
    {RCL_SLOT_RVA_17, (void *)rcl_slot_repl_17, 1},
    {RCL_SLOT_RVA_18, (void *)rcl_slot_repl_18, 1},
    {RCL_SLOT_RVA_19, (void *)rcl_slot_repl_19, 0},
    {RCL_SLOT_RVA_20, (void *)rcl_slot_repl_20, 0},
    {RCL_SLOT_NONE, (void *)rcl_slot_repl_21, 0},
    {RCL_SLOT_NONE, (void *)rcl_slot_repl_22, 0},
    {RCL_SLOT_RVA_23, (void *)rcl_slot_repl_23, 0},
    {RCL_SLOT_RVA_24, (void *)rcl_slot_repl_24, 0},
    {0, (void *)rcl_slot_repl_25, 0},
    {0, (void *)rcl_slot_repl_26, 0},
    {RCL_SLOT_NONE, (void *)rcl_slot_repl_27, 0},
    {RCL_SLOT_RVA_28, (void *)rcl_slot_repl_28, 0},
    {RCL_SLOT_RVA_29, (void *)rcl_slot_repl_29, 0},
    {RCL_SLOT_RVA_30, (void *)rcl_slot_repl_30, 0},
    {RCL_SLOT_RVA_31, (void *)rcl_slot_repl_31, 0},
    {RVA_LOGICBATTLEMODECLIENT_UPDATE, (void *)rcl_slot_repl_32, 0},
    {RVA_BATTLESCREEN__UPDATEMOVEMENT, (void *)rcl_slot_repl_33, 0},
};

void rcl_slot_note(int index, void *self, uint64_t arg1)
{
    if (index < 0 || index >= 34)
    {
        return;
    }
    rcl_slot_hits[index]++;
    if (!rcl_slot_object[index] && self)
    {
        rcl_slot_object[index] = (uintptr_t)self;
    }
    if (!rcl_slot_arg[index] && arg1)
    {
        rcl_slot_arg[index] = (uintptr_t)arg1;
    }
}

uint64_t rcl_hook_dispatches(void)
{
    uint64_t total = 0;
    for (int i = 0; i < 34; i++)
    {
        total += rcl_slot_hits[i];
    }
    return total;
}

uint64_t rcl_object_dispatches(void)
{
    uint64_t total = 0;
    for (int i = 0; i < 3; i++)
    {
        total += rcl_slot_hits[rcl_object_slots[i]];
    }
    return total;
}
int rcl_vtable_is_data(uintptr_t vtable)
{
    const char *segment = rcl_image_segment_name(vtable);
    if (!segment)
    {
        return 0;
    }
    if (strcmp(segment, "__DATA_CONST") == 0)
    {
        return 1;
    }
    if (strcmp(segment, "__DATA") == 0)
    {
        return 1;
    }
    return 0;
}

int rcl_state_tick(void)
{
    uintptr_t slot = (uintptr_t)rcl_read_global_ptr(RCL_STATE_RVA);
    int32_t state = -1;
    void *value = nullptr;
    uintptr_t scene = 0;
    uintptr_t client = 0;
    uintptr_t inner = 0;
    uintptr_t players = 0;
    void *array = nullptr;
    int32_t count = 0;
    int32_t capacity = 0;
    uintptr_t hopArray[2] = {0};
    int32_t hopCount[2] = {0};
    int32_t hopCap[2] = {0};
    int hopOk[2] = {0};
    int score[2];
    int chosen = -1;
    if (slot)
    {
        rcl_read_int(slot + RCL_STATE_ENUM_OFF, &state);
    }
    if (slot != rcl_site || state != rcl_site_state)
    {
        rcl_state_note(state);
        rcl_site = slot;
        rcl_site_state = state;
    }
    if (!slot)
    {
        return 0;
    }
    if (state != 5)
    {
        return 0;
    }
    if (!rcl_read_ptr(slot + RCL_SCENE_OFF, &value) || !value)
    {
        return 0;
    }
    scene = (uintptr_t)value;
    if (scene != rcl_scene_object)
    {
        rcl_scene_object = scene;
    }
    if (!rcl_read_ptr(scene + RCL_MODE_MANAGER_OFF, &value) || !value)
    {
        return 1;
    }
    client = (uintptr_t)value;
    if (!rcl_read_ptr(client + RCL_CLIENT_HOP_OFF, &value) || !value)
    {
        return 1;
    }
    inner = (uintptr_t)value;
    hopOk[0] = rcl_container_header(client, &hopArray[0], &hopCount[0], &hopCap[0]);
    hopOk[1] = rcl_container_header(inner, &hopArray[1], &hopCount[1], &hopCap[1]);
    score[0] = hopOk[0] ? rcl_container_score(client) : -1;
    score[1] = hopOk[1] ? rcl_container_score(inner) : -1;
    if (score[1] > score[0])
    {
        chosen = 1;
        rcl_hop_sticky = 1;
    }
    else if (score[0] > score[1])
    {
        chosen = 0;
        rcl_hop_sticky = 0;
    }
    else
    {
        chosen = hopOk[1] ? 1 : (hopOk[0] && !rcl_hop_sticky ? 0 : -1);
    }
    if (chosen != rcl_last_choice)
    {
        rcl_last_choice = chosen;
    }
    else if (rcl_hop_logs < 6)
    {
        rcl_hop_logs++;
    }
    if (scene != rcl_hop_scene)
    {
        rcl_hop_scene = scene;
    }
    if (RCL_WIRE_OWNER && rcl_owner)
    {
        void *directArray = nullptr;
        int32_t directCount = 0;
        if (rcl_read_ptr(rcl_owner + RCL_MGR_ARRAY_OFF, &directArray) && directArray &&
            rcl_read_int(rcl_owner + RCL_MGR_COUNT_OFF, &directCount) && directCount > 0)
        {
            rcl_players_object = rcl_owner;
            rcl_players_array = (uintptr_t)directArray;
            rcl_players_count = directCount;
            rcl_hop_chosen = RCL_HOPCHOSEN_DIRECT;
            if (!rcl_wired)
            {
                rcl_wired = 1;
            }
            return 0;
        }
    }
    if (chosen < 0)
    {
        return 1;
    }
    players = (chosen == 1) ? inner : client;
    array = (void *)hopArray[chosen];
    count = hopCount[chosen];
    capacity = hopCap[chosen];
    rcl_hop_chosen = chosen;
    {
        static int v141_array_vote_logs = 0;
        if ((uintptr_t)array != rcl_pub_array && players == rcl_pub_object &&
            v141_array_vote_logs < RCL_ARRAY_VOTE_LOGS)
        {
            v141_array_vote_logs++;
        }
    }
    if (players != rcl_pub_object || (uintptr_t)array != rcl_pub_array || count != rcl_pub_count)
    {
        rcl_publish(players, (uintptr_t)array, count, capacity, "hop-adopt");
    }
    return 1;
}

int rcl_scan_allowed(uint64_t fired, uint64_t)
{
    if (fired > 0)
    {
        rcl_idle_start = 0;
        return 1;
    }
    if (rcl_idle_start == 0)
    {
        rcl_idle_start = rcl_ticks_b;
    }
    if ((rcl_ticks_b - rcl_idle_start) < RCL_IDLE_RETRY_TICKS)
    {
        return 0;
    }
    rcl_idle_start = rcl_ticks_b;
    return 1;
}

int rcl_battle_gate_fallback(int v63)
{
    int liveEnough = (rcl_live_objs >= RCL_LIVE_OBJ_MIN && rcl_live_teams >= RCL_LIVE_TEAM_MIN);
    rcl_fb_on = (v63 || liveEnough) ? 1 : 0;
    if (!rcl_fb_on)
    {
        return 0;
    }
    if (v63)
    {
        return 1;
    }
    return 1;
}

void rcl_start_timer(void)
{
    if (rcl_scan_timer)
    {
        return;
    }
    dispatch_queue_t queue = dispatch_get_global_queue(QOS_CLASS_UTILITY, 0);
    dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
    if (!timer)
    {
        return;
    }
    uint64_t interval = (uint64_t)(1.0 * NSEC_PER_SEC);
    dispatch_source_set_timer(timer, dispatch_time(DISPATCH_TIME_NOW, (int64_t)interval), interval,
                              (uint64_t)(0.25 * NSEC_PER_SEC));
    dispatch_source_set_event_handler(timer, ^{
      rcl_slot_pump();
      int scene = rcl_state_tick();
      int gate = rcl_battle_gate(scene);
      int battle = gate || scene;
      int fallback = rcl_battle_gate_fallback(battle);
      int ready = rcl_scan_ready(battle || fallback);
      int needScan = !scene && !rcl_players_object;
      if (needScan != rcl_scan_armed)
      {
          rcl_scan_armed = needScan;
      }
      if (needScan && ready &&
          rcl_scan_allowed((unsigned long long)rcl_object_dispatches(), rcl_hook_dispatches()))
      {
          rcl_locate_battle_mode();
      }
      rcl_modesig_tick();
      rcl_ticks_b++;
      if ((rcl_ticks_b % RCL_HB_TICKS) == 0)
      {
          rcl_hb_sig_prev = rcl_modesig_hits;
      }
    });
    dispatch_resume(timer);
    rcl_scan_timer = timer;
}

uint64_t rcl_ticks_b = 0;

int rcl_hb_sig_prev = 0;

int rcl_battle_active = 0;

int rcl_battle_last_tick = 0;

int rcl_battle_gate(int scene)
{
    unsigned long long objFired = rcl_object_dispatches();
    int objGrew = objFired > rcl_obj_prev;
    int sigGrew = rcl_modesig_hits > rcl_hb_sig_prev;
    int sceneGrew = scene ? 1 : 0;
    rcl_obj_prev = objFired;
    if (sigGrew || objGrew || sceneGrew)
    {
        rcl_battle_last_tick = (int)rcl_ticks_b;
        if (!rcl_battle_active)
        {
            rcl_battle_active = 1;
        }
    }
    else if (rcl_battle_active && ((int)rcl_ticks_b - rcl_battle_last_tick) >= RCL_QUIET_SECS)
    {
        rcl_battle_active = 0;
    }
    return rcl_battle_active;
}

void rcl_run_workload(void)
{
    rcl_tick_begin();
    rcl_wall_maybe_refresh((uint64_t)(CFAbsoluteTimeGetCurrent() * 1000.0));
    rcl_locate_battle_mode();
    if (rcl_scene_object)
    {
        if (!rcl_snapshot_first)
        {
            rcl_snapshot_first = YES;
            rcl_snapshot_start = CFAbsoluteTimeGetCurrent();
        }
        else if (!rcl_snapshot_second)
        {
            if (CFAbsoluteTimeGetCurrent() > (rcl_snapshot_start + RCL_SNAPSHOT_DELAY))
            {
                rcl_snapshot_second = YES;
            }
        }
    }
    rcl_run_autododge();
    rcl_run_autoaim();
    rcl_run_assist();
}

void rcl_run_autododge(void)
{
    if (!rcl_flag_state("autododge"))
    {
        return;
    }
    if (rcl_in_move)
    {
        return;
    }
    rcl_in_move = 1;
    rcl_autododge();
    rcl_in_move = 0;
}

static uint64_t rcl_work_us = 0;

static void rcl_objc_body(void)
{
    uint64_t now = 0;
    if (rcl_inside_hook)
    {
        return;
    }
    now = rcl_us();
    if (now && rcl_work_us && (now - rcl_work_us) < 500)
    {
        return;
    }
    rcl_work_us = now;
    rcl_inside_hook = YES;
    rcl_run_workload();
    rcl_inside_hook = NO;
}

void setup(void)
{
    if (rcl_setup_done)
    {
        return;
    }
    rcl_setup_done = YES;
    rcl_log_set_enabled(0);
    rcl_flag_set("logs", RCL_LOGS_ON);
    rcl_load_function_starts();
    rcl_resolve_addresses();
    rcl_objc_arm(rcl_base, "MetalView", "render", rcl_objc_body);
    rcl_objc_arm(rcl_base, "NullView", "render", rcl_objc_body);
    rcl_feature_setup("slot hooks", rcl_slot_hooks_install);
    rcl_start_timer();
}

__attribute__((constructor)) void start(void)
{
    dispatch_async(dispatch_get_main_queue(), ^{
      poll_for_game(0);
    });
}

int rcl_prev_state = -1;

int rcl_hop_chosen = -1;

int rcl_hop_sticky = 0;

int rcl_modesig_hits = 0;

uintptr_t rcl_scan_container = 0;

int rcl_modesig_hit(uintptr_t at)
{
    void *vt = nullptr;
    void *mgr = nullptr;
    int32_t ec = 0;
    int32_t m124 = 0;
    int32_t count = 0;
    if (!at)
    {
        return 0;
    }
    if (!rcl_read_ptr(at, &vt) || !vt)
    {
        return 0;
    }
    if (!rcl_vtable_in_image((uintptr_t)vt))
    {
        return 0;
    }
    if (!rcl_vtable_is_data((uintptr_t)vt))
    {
        return 0;
    }
    if (!rcl_read_int(at + RCL_MODE_MODEVAR_OFF, &m124) || m124 < 0x01 || m124 > 0x80)
    {
        return 0;
    }
    if (!rcl_read_int(at + RCL_MODE_EC_OFF, &ec) || ec < -1024 || ec > 1024)
    {
        return 0;
    }
    if (!rcl_read_ptr(at + RCL_MODE_MANAGER_OFF, &mgr) || !mgr)
    {
        return 0;
    }
    if (!rcl_pointer_plausible((uintptr_t)mgr))
    {
        return 0;
    }
    if (!rcl_read_int((uintptr_t)mgr + RCL_MGR_COUNT_OFF, &count))
    {
        return 0;
    }
    if (count < 2 || count > 96)
    {
        return 0;
    }
    return 1;
}

void rcl_modesig_tick(void)
{
    uintptr_t found = 0;
    if (rcl_scene_object)
    {
        return;
    }
    if (!rcl_battle_active && (rcl_ticks_b % RCL_QUIET_BUCKET_TICKS) != 0)
    {
        return;
    }
    for (int i = 0; i < rcl_objhit_count && !found; i++)
    {
        if (rcl_modesig_hit(rcl_objhits[i].at))
        {
            found = rcl_objhits[i].at;
        }
    }
    if (!found)
    {
        return;
    }
    if (rcl_sig_last == found)
    {
        rcl_sig_ticks++;
    }
    else
    {
        rcl_sig_last = found;
        rcl_sig_ticks = 1;
    }
    if (rcl_sig_ticks < RCL_MODESIG_TICKS)
    {
        return;
    }
    {
        void *vt = nullptr;
        void *mgr = nullptr;
        int32_t ec = 0;
        int32_t m124 = 0;
        int32_t count = 0;
        int32_t cap = 0;
        rcl_modesig_hits++;
        rcl_scene_object = found;
        rcl_battle_last_tick = (int)rcl_ticks_b;
        rcl_read_ptr(found, &vt);
        rcl_read_ptr(found + RCL_MODE_MANAGER_OFF, &mgr);
        rcl_read_int(found + RCL_MODE_EC_OFF, &ec);
        rcl_read_int(found + RCL_MODE_MODEVAR_OFF, &m124);
        rcl_read_int((uintptr_t)mgr + RCL_MGR_COUNT_OFF, &count);
        rcl_read_int((uintptr_t)mgr + RCL_MGR_CAP_OFF, &cap);
        if (count >= 2 && cap >= count && cap <= 4096)
        {
            void *mgrArray = nullptr;
            if (rcl_read_ptr((uintptr_t)mgr + RCL_MGR_ARRAY_OFF, &mgrArray) && mgrArray)
            {
                rcl_publish((uintptr_t)mgr, (uintptr_t)mgrArray, count, cap, "modesig");
            }
        }
    }
}

int rcl_element_type(uintptr_t vt, uintptr_t *wordOut)
{
    void *slotPtr = nullptr;
    uintptr_t slot = 0;
    if (wordOut)
    {
        *wordOut = 0;
    }
    if (!vt)
    {
        return -1;
    }
    if (!rcl_read_ptr(vt + RCL_TYPE_SLOT_OFF, &slotPtr) || !slotPtr)
    {
        return -1;
    }
    slot = rcl_strip_ptr((uintptr_t)slotPtr) - rcl_base;
    if (wordOut)
    {
        *wordOut = slot;
    }
    switch (slot)
    {
    case RCL_TYPE_SLOT_RVA_0:
        return 0;
    case RCL_TYPE_SLOT_RVA_1:
        return 1;
    case RCL_TYPE_SLOT_RVA_2:
        return 2;
    case RCL_TYPE_SLOT_RVA_3:
        return 3;
    case RCL_TYPE_SLOT_RVA_4:
        return 4;
    case RCL_TYPE_SLOT_RVA_5:
        return 5;
    case RCL_TYPE_SLOT_RVA_6:
        return 6;
    case RCL_TYPE_SLOT_RVA_8:
        return 8;
    default:
        return -1;
    }
}

uintptr_t rcl_hop_scene = 0;

int rcl_container_header(uintptr_t object, uintptr_t *arrayOut, int32_t *countOut, int32_t *capOut)
{
    void *array = nullptr;
    if (arrayOut)
    {
        *arrayOut = 0;
    }
    if (countOut)
    {
        *countOut = 0;
    }
    if (capOut)
    {
        *capOut = 0;
    }
    if (!object)
    {
        return 0;
    }
    if (rcl_header_reason(object, countOut, capOut))
    {
        return 0;
    }
    if (!rcl_read_ptr(object + RCL_MGR_ARRAY_OFF, &array) || !array)
    {
        return 0;
    }
    if (!rcl_heap_resident((uintptr_t)array))
    {
        return 0;
    }
    if (arrayOut)
    {
        *arrayOut = (uintptr_t)array;
    }
    return 1;
}

int32_t rcl_gid_at(uintptr_t element, uintptr_t off)
{
    int32_t gid = 0;
    if (off && rcl_read_int(element + off, &gid))
    {
        return gid;
    }
    return 0;
}

int32_t rcl_gid(uintptr_t element, int32_t *offOut)
{
    int32_t gid = 0;
    int32_t alt = 0;
    if (offOut)
    {
        *offOut = 0;
    }
    if (!element)
    {
        return 0;
    }
    if (rcl_read_int(element + RCL_OBJ_GLOBALID_OFF, &gid) && gid)
    {
        if (offOut)
        {
            *offOut = (int32_t)RCL_OBJ_GLOBALID_OFF;
        }
        return gid;
    }
    if (rcl_read_int(element + RCL_GID_FALLBACK_OFF, &alt) && alt)
    {
        if (offOut)
        {
            *offOut = (int32_t)RCL_GID_FALLBACK_OFF;
        }
        return alt;
    }
    return 0;
}

int rcl_last_choice = -2;

int rcl_hop_logs = 0;

int rcl_container_score(uintptr_t container)
{
    void *array = nullptr;
    int32_t count = 0;
    int32_t own = -1;
    int32_t ownTeam = -1;
    int32_t gid = 0;
    int32_t team = 0;
    int samples = 0;
    int gidOk = 0;
    int teamOk = 0;
    int posOk = 0;
    int posDistinct = 0;
    int asciiCount = 0;
    int soft = 0;
    int32_t px = 0;
    int32_t py = 0;
    int32_t qx = 0;
    int32_t qy = 0;
    int score = 0;
    int i;
    int j;
    if (!container)
    {
        return -1;
    }
    if (!rcl_read_ptr(container + RCL_MGR_ARRAY_OFF, &array) || !array)
    {
        return -1;
    }
    if (!rcl_read_int(container + RCL_MGR_COUNT_OFF, &count))
    {
        return -1;
    }
    if (count <= 0 || count > RCL_COUNT_MAX)
    {
        return -1;
    }
    if (own < 0 || own >= count)
    {
        soft = 1;
    }
    for (i = 0; i < count && samples < 4; i++)
    {
        void *element = nullptr;
        if (!rcl_read_ptr((uintptr_t)array + (uintptr_t)i * 8ULL, &element) || !element)
        {
            continue;
        }
        samples++;
        team = 0;
        px = 0;
        py = 0;
        if (rcl_element_ascii((uintptr_t)element))
        {
            asciiCount++;
        }
        gid = rcl_gid((uintptr_t)element, nullptr);
        rcl_read_int((uintptr_t)element + RCL_TEAM_OFF, &team);
        if (rcl_read_int((uintptr_t)element + RCL_OBJ_X_OFF, &px) &&
            rcl_read_int((uintptr_t)element + RCL_OBJ_Y_OFF, &py) && px > -RCL_COORD_MAX &&
            px < RCL_COORD_MAX && py > -RCL_COORD_MAX && py < RCL_COORD_MAX && (px != 0 || py != 0))
        {
            int dup = 0;
            posOk++;
            for (j = 0; j < i; j++)
            {
                void *other = nullptr;
                if (!rcl_read_ptr((uintptr_t)array + (uintptr_t)j * 8ULL, &other) || !other)
                {
                    continue;
                }
                if (!rcl_read_int((uintptr_t)other + RCL_OBJ_X_OFF, &qx))
                {
                    continue;
                }
                if (!rcl_read_int((uintptr_t)other + RCL_OBJ_Y_OFF, &qy))
                {
                    continue;
                }
                if (qx == px && qy == py)
                {
                    dup = 1;
                    break;
                }
            }
            if (!dup)
            {
                posDistinct++;
            }
        }
        if (gid)
        {
            gidOk++;
        }
        if (team >= 0 && team <= 7)
        {
            teamOk++;
        }
    }
    if (samples > 0 && (asciiCount * 100) / samples > RCL_ASCII_RATIO)
    {
        return -1;
    }
    if (soft)
    {
        if (posOk < RCL_SOFT_MIN_POS || posDistinct < RCL_SOFT_MIN_DIST)
        {
            return -1;
        }
        score = RCL_SOFT_BASE;
    }
    else
    {
        score = 6;
        if (ownTeam >= 0 && ownTeam <= 15)
        {
            score += 2;
        }
    }
    if (gidOk)
    {
        score += 1;
    }
    if (teamOk)
    {
        score += 1;
    }
    if (count >= 3)
    {
        score += 2;
    }
    if (count >= 6)
    {
        score += 1;
    }
    score += posOk * RCL_POS_BONUS + posDistinct * RCL_DIST_BONUS;
    return score;
}
int rcl_scan_ready(int battle)
{
    if (rcl_ticks_b < RCL_SCAN_FLOOR_TICKS)
    {
        return 0;
    }
    if (battle || rcl_scene_object)
    {
        return 1;
    }
    if (rcl_ticks_b < RCL_SCAN_FALLBACK_TICKS)
    {
        return 0;
    }
    return (rcl_ticks_b % RCL_QUIET_BUCKET_TICKS) == 0;
}

void rcl_resolve_addresses(void)
{
    if (!rcl_base)
    {
        return;
    }
    rcl_addr_getinstance = rcl_callable(RVA_BATTLEMODE_GETINSTANCE);
    rcl_addr_getownchar = rcl_callable(RVA_LOGICBATTLEMODECLIENT_GETOWNCHARACTER);
    rcl_addr_getteam = rcl_callable(RVA_LOGICBATTLEMODECLIENT_GETOWNPLAYERTEAM);
    rcl_addr_getx = rcl_callable(RVA_LOGICGAMEOBJECTCLIENT_GETX);
    rcl_addr_gety = rcl_callable(RVA_LOGICGAMEOBJECTCLIENT_GETY);
    rcl_addr_battlescreen = rcl_base;
    if (!rcl_addr_readable(rcl_addr_battlescreen, sizeof(void *)))
    {
        rcl_addr_battlescreen = 0;
    }
}
void rcl_locate_battle_mode(void)
{
    if (rcl_mode_strong)
    {
        return;
    }
    if (rcl_votescan_attempts >= RCL_VOTESCAN_ATTEMPTS)
    {
        return;
    }
    double now = CFAbsoluteTimeGetCurrent();
    if (rcl_votescan_last > 0.0 && (now - rcl_votescan_last) < RCL_VOTESCAN_INTERVAL)
    {
        return;
    }
    rcl_votescan_last = now;
    rcl_votescan_attempts++;
    if (rcl_votescan_attempts == 1)
    {
        rcl_image_span_refresh();
    }
    if ((rcl_votescan_attempts % RCL_VOTESCAN_GLOBAL_EVERY) == 1)
    {
        rcl_image_span_refresh();
    }
}

int rcl_probe_done = 0;

uintptr_t rcl_probe_object = 0;

uint64_t rcl_probe_last_ms = 0;

int rcl_coord_ok = 0;

int rcl_coord_usable = 0;

int rcl_team_off = (int)RCL_OBJ_TEAM_OFF;

void rcl_read_map(uintptr_t mode)
{
    void *tileMap = nullptr;
    void *tiles = nullptr;
    int32_t width = 0;
    int32_t height = 0;
    if (!mode)
    {
        return;
    }
    tileMap = (void *)rcl_map_object();
    if (!tileMap)
    {
        return;
    }
    if (!rcl_read_int((uintptr_t)tileMap + RCL_MAP_WIDTH_OFF, &width))
    {
        return;
    }
    if (!rcl_read_int((uintptr_t)tileMap + RCL_MAP_HEIGHT_OFF, &height))
    {
        return;
    }
    if (width <= 0 || height <= 0)
    {
        return;
    }
    if (width > RCL_WALL_MAX_MAP_TILES || height > RCL_WALL_MAX_MAP_TILES)
    {
        return;
    }
    if (!rcl_read_ptr((uintptr_t)tileMap + RCL_MAP_TILES_OFF, &tiles) || !tiles)
    {
        return;
    }
    if ((uintptr_t)tiles == rcl_tiles && width == rcl_w && height == rcl_h)
    {
        return;
    }
    rcl_tiles = (uintptr_t)tiles;
    rcl_w = width;
    rcl_h = height;
    rcl_wall_notify_battle_mode_changed((uint64_t)(CFAbsoluteTimeGetCurrent() * 1000.0));
}

int rcl_gidless = 0;

void rcl_gidless_scan(uintptr_t manager)
{
    void *data = nullptr;
    int32_t count = 0;
    int32_t i = 0;
    int seen = 0;
    int withGid = 0;
    rcl_gidless = 0;
    if (!RCL_GIDLESS)
    {
        return;
    }
    if (!manager)
    {
        return;
    }
    if (!rcl_read_ptr(manager + RCL_MGR_ARRAY_OFF, &data) || !data)
    {
        return;
    }
    if (!rcl_read_int(manager + RCL_MGR_COUNT_OFF, &count))
    {
        return;
    }
    for (i = 0; i < count && i < 8; i++)
    {
        void *element = nullptr;
        if (!rcl_read_ptr((uintptr_t)data + (uintptr_t)i * 8ULL, &element) || !element)
        {
            continue;
        }
        seen++;
        if (rcl_gid((uintptr_t)element, nullptr) != 0)
        {
            withGid++;
        }
    }
    if (seen > 0 && withGid == 0)
    {
        rcl_gidless = 1;
        return;
    }
}

uintptr_t rcl_list_gid_off(uintptr_t array, int32_t count)
{
    uintptr_t off = RCL_OBJ_GLOBALID_OFF;
    int sawAt8 = 0;
    int sawAt50 = 0;
    int i = 0;
    int32_t v = 0;
    if (!array || count <= 0)
    {
        return off;
    }
    for (i = 0; i < count && i < 4; i++)
    {
        void *element = nullptr;
        if (!rcl_read_ptr(array + (uintptr_t)i * sizeof(void *), &element) || !element)
        {
            continue;
        }
        if (rcl_read_int((uintptr_t)element + RCL_OBJ_GLOBALID_OFF, &v) && v != 0)
        {
            sawAt8++;
        }
        if (rcl_read_int((uintptr_t)element + RCL_GID_FALLBACK_OFF, &v) && v != 0)
        {
            sawAt50++;
        }
    }
    if (sawAt8 > 0)
    {
        off = RCL_OBJ_GLOBALID_OFF;
    }
    else if (sawAt50 > 0)
    {
        off = RCL_GID_FALLBACK_OFF;
    }
    return off;
}

int rcl_dead = 0;

int rcl_own_team_a = -1;

int rcl_own_team_seen = 0;

uintptr_t rcl_proj_addr = 0;

uint8_t rcl_proj_bytes[0x100];

int rcl_proj_have = 0;

int rcl_proj_dumps = 0;

uint64_t rcl_proj_diff_logs = 0;

void rcl_proj_track(uintptr_t elem, uintptr_t, int32_t, int32_t)
{
    uint8_t now[0x100];
    int i;
    if (!elem)
    {
        return;
    }
    if (!rcl_read_bytes(elem, now, sizeof(now)))
    {
        return;
    }
    if (elem != rcl_proj_addr)
    {
        rcl_proj_addr = elem;
        memcpy(rcl_proj_bytes, now, sizeof(now));
        rcl_proj_have = 1;
        if (rcl_proj_dumps < RCL_DUMPS)
        {
            rcl_proj_dumps++;
            for (i = 0; i < 0x100; i += 8)
            {
                uint64_t q = 0;
                int32_t lo = 0;
                int32_t hi = 0;
                float loF = 0.0f;
                float hiF = 0.0f;
                memcpy(&q, now + i, 8);
                memcpy(&lo, now + i, 4);
                memcpy(&hi, now + i + 4, 4);
                memcpy(&loF, now + i, 4);
                memcpy(&hiF, now + i + 4, 4);
            }
        }
        return;
    }
    if (!rcl_proj_have)
    {
        memcpy(rcl_proj_bytes, now, sizeof(now));
        rcl_proj_have = 1;
        return;
    }
    for (i = 0; i < 0x100; i++)
    {
        if (rcl_proj_bytes[i] == now[i])
        {
            continue;
        }
        rcl_proj_diff_logs++;
        if (rcl_proj_diff_logs <= RCL_DIFF_LOGS)
        {
            uint64_t oldQ = 0;
            uint64_t newQ = 0;
            int base = i & ~7;
            memcpy(&oldQ, rcl_proj_bytes + base, 8);
            memcpy(&newQ, now + base, 8);
        }
    }
    memcpy(rcl_proj_bytes, now, sizeof(now));
}

int rcl_vt_ok(uintptr_t obj, uintptr_t *vtOut)
{
    void *vt = nullptr;
    uintptr_t vtRva = 0;
    if (vtOut)
    {
        *vtOut = 0;
    }
    if (!obj)
    {
        return 0;
    }
    if (obj & 7)
    {
        return 0;
    }
    if (!rcl_read_ptr(obj, &vt) || !vt)
    {
        return 0;
    }
    if ((uintptr_t)vt < rcl_base)
    {
        return 0;
    }
    vtRva = (uintptr_t)vt - rcl_base;
    if (vtRva < RCL_DC_RVA_LO || vtRva >= RCL_DC_RVA_LO + RCL_DC_RVA_SIZE)
    {
        return 0;
    }
    if (vtOut)
    {
        *vtOut = (uintptr_t)vt;
    }
    return 1;
}

int rcl_cand_ok(uintptr_t cand, const char **why, uintptr_t *vtOut)
{
    uintptr_t vt = 0;
    int32_t gate = 0;
    if (vtOut)
    {
        *vtOut = 0;
    }
    if (!cand)
    {
        if (why)
        {
            *why = "null";
        }
        return 0;
    }
    if (cand & 7)
    {
        if (why)
        {
            *why = "unaligned";
        }
        return 0;
    }
    if (!rcl_addr_readable(cand, RCL_MIN_OBJ_BYTES))
    {
        if (why)
        {
            *why = "not-readable";
        }
        return 0;
    }
    if (!rcl_vt_ok(cand, &vt))
    {
        if (why)
        {
            *why = "vtable-not-in-data-const";
        }
        return 0;
    }
    if (!rcl_read_int(cand + RCL_GATE_FLAG_OFF, &gate))
    {
        if (why)
        {
            *why = "gate-unreadable";
        }
        return 0;
    }
    if (why)
    {
        *why = "ok";
    }
    if (vtOut)
    {
        *vtOut = vt;
    }
    return 1;
}

uintptr_t rcl_hop(uintptr_t base, int *whyOut)
{
    void *p = nullptr;
    void *q = nullptr;
    if (whyOut)
    {
        *whyOut = 0;
    }
    if (!base)
    {
        if (whyOut)
        {
            *whyOut = 1;
        }
        return 0;
    }
    if (!rcl_read_ptr(base + RCL_CTRL_MODE_OFF, &p) || !p)
    {
        if (whyOut)
        {
            *whyOut = 2;
        }
        return 0;
    }
    if (!rcl_read_ptr((uintptr_t)p + RCL_OWN_INNER_OFF, &q) || !q)
    {
        if (whyOut)
        {
            *whyOut = 3;
        }
        return 0;
    }
    return (uintptr_t)q;
}
uintptr_t rcl_client(void)
{
    void *client = nullptr;
    if (!rcl_scene_object)
    {
        return 0;
    }
    if (!rcl_read_ptr((uintptr_t)rcl_scene_object + RCL_CLIENT_OFF, &client))
    {
        return 0;
    }
    return (uintptr_t)client;
}

void rcl_state_note(int state)
{
    if (rcl_prev_state == 5 && state != 5)
    {
        rcl_own_index = -1;
        rcl_own_ptr = 0;
        rcl_own_ptr_a = 0;
    }
    if (state == 5 && rcl_prev_state != 5)
    {
        rcl_owner = 0;
        rcl_wired = 0;
    }
    rcl_prev_state = state;
}

rcl_proj_t rcl_projs[16];

rcl_proj_death_t rcl_proj_deaths[16];

int rcl_proj_death_n = 0;

static char rcl_proj_name_buf[16][64];

static int rcl_proj_read_name(uintptr_t data, char *dst, int cap)
{
    void *strp = nullptr;
    void *farp = nullptr;
    uintptr_t str = 0;
    uintptr_t src = 0;
    int32_t len = 0;
    if (!data || !dst || cap <= 1)
    {
        return 0;
    }
    if (!rcl_read_ptr(data + (uintptr_t)RCL_PROJ_DATA_NAME_OFF, &strp) || !strp)
    {
        return 0;
    }
    str = (uintptr_t)strp;
    if (!rcl_read_int(str + (uintptr_t)RCL_SC_LEN_OFF, &len))
    {
        return 0;
    }
    if (len <= 0 || len >= cap)
    {
        return 0;
    }
    if (len <= 7)
    {
        src = str + (uintptr_t)RCL_SC_DATA_OFF;
    }
    else
    {
        if (!rcl_read_ptr(str + (uintptr_t)RCL_SC_DATA_OFF, &farp) || !farp)
        {
            return 0;
        }
        src = (uintptr_t)farp;
    }
    if (!rcl_read_bytes(src, dst, (size_t)len))
    {
        return 0;
    }
    dst[len] = 0;
    return 1;
}

int rcl_proj_scan(uintptr_t manager, int32_t count)
{
    void *array = nullptr;
    int found = 0;
    int k;
    int32_t i;
    uint64_t nowMs = 0;
    if (!manager || count <= 0)
    {
        return 0;
    }
    if (count > RCL_COUNT_MAX)
    {
        count = RCL_COUNT_MAX;
    }
    if (!rcl_read_ptr(manager + RCL_MGR_ARRAY_OFF, &array) || !array)
    {
        return 0;
    }
    for (k = 0; k < 16; k++)
    {
        rcl_projs[k].classRva = (uintptr_t)-1;
    }
    rcl_proj_death_n = 0;
    nowMs = (uint64_t)(CFAbsoluteTimeGetCurrent() * 1000.0);
    for (i = 0; i < count && found < 16; i++)
    {
        void *element = nullptr;
        void *vtable = nullptr;
        uintptr_t vtRva = 0;
        int32_t gid = 0;
        int32_t px = 0;
        int32_t py = 0;
        int slot = -1;
        if (!rcl_read_ptr((uintptr_t)array + (uintptr_t)i * 8ULL, &element) || !element)
        {
            continue;
        }
        if (!rcl_read_ptr((uintptr_t)element, &vtable) || !vtable)
        {
            continue;
        }
        vtRva = (uintptr_t)vtable - rcl_base;
        gid = rcl_gid((uintptr_t)element, nullptr);
        if (gid < 2000000)
        {
            continue;
        }
        {
            static uintptr_t seenCls[4] = {0, 0, 0, 0};
            static int seenClsN = 0;
            int si;
            int known = 0;
            for (si = 0; si < seenClsN; si++)
            {
                if (seenCls[si] == vtRva)
                {
                    known = 1;
                    break;
                }
            }
            if (!known && seenClsN < 4)
            {
                seenCls[seenClsN++] = vtRva;
            }
        }
        if (1 && vtRva != (uintptr_t)RCL_CLASS_PROJ_RVA)
        {
            continue;
        }
        if (!rcl_read_int((uintptr_t)element + RCL_OBJ_X_OFF, &px))
        {
            continue;
        }
        if (!rcl_read_int((uintptr_t)element + RCL_OBJ_Y_OFF, &py))
        {
            continue;
        }
        for (k = 0; k < 16; k++)
        {
            if (rcl_projs[k].elem != (uintptr_t)element)
            {
                continue;
            }
            slot = k;
            break;
        }
        if (slot < 0)
        {
            for (k = 0; k < 16; k++)
            {
                if (rcl_projs[k].classRva != (uintptr_t)-1)
                {
                    continue;
                }
                slot = k;
                break;
            }
        }
        if (slot < 0)
        {
            continue;
        }
        if (rcl_projs[slot].elem == (uintptr_t)element)
        {
            if (px != rcl_projs[slot].x || py != rcl_projs[slot].y)
            {
                rcl_projs[slot].px = rcl_projs[slot].x;
                rcl_projs[slot].py = rcl_projs[slot].y;
                rcl_projs[slot].pms = rcl_projs[slot].qms;
                rcl_projs[slot].hasPrev = 1;
            }
        }
        else
        {
            rcl_projs[slot].elem = (uintptr_t)element;
            rcl_projs[slot].px = px;
            rcl_projs[slot].py = py;
            rcl_projs[slot].spawnX = px;
            rcl_projs[slot].spawnY = py;
            rcl_projs[slot].pms = nowMs;
            rcl_projs[slot].hasPrev = 0;
            rcl_projs[slot].spawnedAt = nowMs;
        }
        {
            uintptr_t teamOff =
                (rcl_team_off == (int)RCL_OBJ_TEAM_OFF) ? RCL_OBJ_TEAM_OFF : RCL_TEAM_OFF;
            int32_t pteam = -1;
            if (rcl_read_int((uintptr_t)element + teamOff, &pteam) && pteam >= 0 && pteam <= 7)
            {
                rcl_projs[slot].team = pteam;
            }
            else
            {
                int side = rcl_own_side_spawn(px, py);
                if (side == 1 && rcl_own_team_b >= 0)
                {
                    rcl_projs[slot].team = rcl_own_team_b;
                }
                else
                {
                    rcl_projs[slot].team = -1;
                }
            }
        }
        {
            void *def = nullptr;
            uint8_t indirect = 0;
            rcl_projs[slot].name = nullptr;
            rcl_projs[slot].angle = 0.0f;
            rcl_projs[slot].radius = 0.0f;
            rcl_projs[slot].vx = 0.0f;
            rcl_projs[slot].vy = 0.0f;
            rcl_projs[slot].isThrower = 0;
            rcl_projs[slot].isBeam = 0;
            rcl_projs[slot].targetX = 0;
            rcl_projs[slot].targetY = 0;
            rcl_projs[slot].spawnAreaRadius = 0;
            rcl_projs[slot].spawnAreaActiveTime = 0;
            rcl_projs[slot].castRange = 0;
            if (rcl_read_ptr((uintptr_t)element + (uintptr_t)RCL_ELEM_DEF_OFF, &def) && def)
            {
                if (rcl_proj_read_name((uintptr_t)def, rcl_proj_name_buf[slot], 64))
                {
                    rcl_projs[slot].name = rcl_proj_name_buf[slot];
                }
                if (rcl_read_bytes((uintptr_t)def + (uintptr_t)RCL_PROJ_ISTHROWER_OFF, &indirect,
                                   sizeof(indirect)))
                {
                    rcl_projs[slot].isThrower = indirect ? 1 : 0;
                }
            }
            {
                int32_t raw = 0;
                if (rcl_read_int((uintptr_t)element + (uintptr_t)RCL_PROJ_ANGLE_OFF, &raw) &&
                    raw > 0 && raw <= 360)
                {
                    rcl_projs[slot].angle = (float)raw;
                }
            }
        }
        rcl_projs[slot].classRva = vtRva;
        rcl_projs[slot].x = px;
        rcl_projs[slot].y = py;
        rcl_projs[slot].gid = gid;
        rcl_projs[slot].qms = nowMs;
        found++;
    }
    for (k = 0; k < 16; k++)
    {
        if (rcl_projs[k].classRva != (uintptr_t)-1)
        {
            continue;
        }
        if (rcl_projs[k].elem && rcl_projs[k].name && rcl_proj_death_n < 16)
        {
            rcl_proj_death_t *rec = &rcl_proj_deaths[rcl_proj_death_n];
            rec->name = rcl_projs[k].name;
            rec->angle = rcl_projs[k].angle;
            rec->spawnX = rcl_projs[k].spawnX;
            rec->spawnY = rcl_projs[k].spawnY;
            rec->x = rcl_projs[k].x;
            rec->y = rcl_projs[k].y;
            rcl_proj_death_n++;
        }
        rcl_projs[k].elem = 0;
        rcl_projs[k].hasPrev = 0;
        rcl_projs[k].name = nullptr;
    }
    return found;
}

static int rcl_ctrl_logs = 0;

static int rcl_bounds_try(uintptr_t receiver, int32_t *wOut, int32_t *hOut)
{
    uintptr_t bounds = 0;
    int32_t w = 0;
    int32_t h = 0;
    if (!receiver)
    {
        return 0;
    }
    if (!rcl_pointer_plausible(receiver))
    {
        return 0;
    }
    {
        void *box = nullptr;
        if (!rcl_read_ptr(receiver + (uintptr_t)RCL_BOX_PTR_OFF, &box))
        {
            return 0;
        }
        bounds = (uintptr_t)box;
    }
    if (!bounds || (bounds & 7))
    {
        return 0;
    }
    if (!rcl_addr_readable(bounds, 0x100))
    {
        return 0;
    }
    if (!rcl_read_int(bounds + RCL_BOUNDS_X_OFF, &w))
    {
        return 0;
    }
    if (!rcl_read_int(bounds + RCL_BOUNDS_Y_OFF, &h))
    {
        return 0;
    }
    if (w <= 3 || h <= 3 || w > 200000 || h > 200000)
    {
        return 0;
    }
    if (wOut)
    {
        *wOut = w;
    }
    if (hOut)
    {
        *hOut = h;
    }
    return 1;
}

int rcl_ctrl_bounds(uintptr_t base, int32_t *wOut, int32_t *hOut)
{
    if (!base)
    {
        return 0;
    }
    if (!rcl_pointer_plausible(base))
    {
        return 0;
    }
    return rcl_bounds_try(base, wOut, hOut);
}

uintptr_t rcl_controller(void)
{
    uintptr_t client = rcl_client();
    int32_t cw = 0;
    int32_t ch = 0;
    if (client && rcl_ctrl_bounds(client, &cw, &ch))
    {
        return client;
    }
    if (!rcl_ctrl_logs)
    {
        rcl_ctrl_logs = 1;
    }
    return client;
}
int rcl_signal_logs = 0;

void rcl_death_signals(uintptr_t ownElem, int32_t, int32_t)
{
    static int lastDead = -999;
    static int lastOwnAlive = -999;
    static int lastCtrlAlive = -999;
    uintptr_t ctrl = 0;
    uint8_t deadByte = 0;
    int dead = -1;
    int ownAlive = -1;
    int ctrlAlive = -1;
    if (!ownElem)
    {
        return;
    }
    if (rcl_read_bytes(ownElem + RCL_DEAD_OFF, &deadByte, sizeof(deadByte)))
    {
        dead = (int)deadByte;
    }
    if (!rcl_read_int(ownElem + RCL_OWN_ALIVE_OFF, &ownAlive))
    {
        ownAlive = -1;
    }
    ctrl = rcl_controller();
    if (ctrl && !rcl_read_int(ctrl + RCL_CTRL_ALIVE_OFF, &ctrlAlive))
    {
        ctrlAlive = -1;
    }
    if (dead > 0 || ownAlive == 0)
    {
        rcl_dead = 1;
    }
    else if (dead == 0 && ownAlive == 1)
    {
        rcl_dead = 0;
    }
    if (dead == lastDead && ownAlive == lastOwnAlive && ctrlAlive == lastCtrlAlive)
    {
        return;
    }
    lastDead = dead;
    lastOwnAlive = ownAlive;
    lastCtrlAlive = ctrlAlive;
    if (rcl_signal_logs >= 12)
    {
        return;
    }
    rcl_signal_logs++;
}

void rcl_alive(int32_t, int32_t)
{
    if (!rcl_dead)
    {
        return;
    }
    rcl_dead = 0;
}

uint64_t rcl_read_u64(uintptr_t address)
{
    uint64_t value = 0;
    if (!rcl_read_bytes(address, &value, sizeof(value)))
    {
        return 0;
    }
    return value;
}

const char *rcl_header_reason(uintptr_t manager, int32_t *countOut, int32_t *capOut)
{
    void *array = nullptr;
    int32_t count = 0;
    int32_t capacity = 0;
    if (countOut)
    {
        *countOut = 0;
    }
    if (capOut)
    {
        *capOut = 0;
    }
    if (!manager)
    {
        return "no-manager";
    }
    if (manager & 7ULL)
    {
        return "manager-unaligned";
    }
    if (!rcl_read_ptr(manager + RCL_MGR_ARRAY_OFF, &array))
    {
        return "array-unreadable";
    }
    if (!array)
    {
        return "array-null";
    }
    if (!rcl_read_int(manager + RCL_MGR_COUNT_OFF, &count))
    {
        return "count-unreadable";
    }
    if (count <= 0)
    {
        return "count-zero";
    }
    if (!rcl_read_int(manager + RCL_MGR_CAP_OFF, &capacity))
    {
        return "cap-unreadable";
    }
    if (count > capacity)
    {
        return "count-above-cap";
    }
    if (capacity > 4096)
    {
        return "cap-above-ceiling";
    }
    if (count > 96)
    {
        return "count-above-ceiling";
    }
    if (countOut)
    {
        *countOut = count;
    }
    if (capOut)
    {
        *capOut = capacity;
    }
    return nullptr;
}

uintptr_t rcl_coord_x_off(void)
{
    return RCL_OBJ_X_OFF;
}

uintptr_t rcl_coord_y_off(void)
{
    return RCL_OBJ_Y_OFF;
}

rcl_trail_t rcl_trail[8];

void rcl_probe(uintptr_t manager, uintptr_t mode, int)
{
    rcl_obj_t objects[64];
    int usable = 0;
    int inRange = 0;
    int distinct = 0;
    int teamsOld[8] = {0, 0, 0, 0, 0, 0, 0, 0};
    int teamsNew[8] = {0, 0, 0, 0, 0, 0, 0, 0};
    int distinctOld = 0;
    int distinctNew = 0;
    memset(objects, 0, sizeof(objects));
    rcl_probe_done = 1;
    if (mode)
    {
        rcl_read_map(mode);
    }
    usable = rcl_collect(manager, objects, 64);
    for (int i = 0; i < usable; i++)
    {
        if (objects[i].x > -1000000 && objects[i].x < 1000000 && objects[i].y > -1000000 &&
            objects[i].y < 1000000)
        {
            inRange++;
        }
        if (objects[i].teamOld >= 0 && objects[i].teamOld < 8)
        {
            teamsOld[objects[i].teamOld] = 1;
        }
        if (objects[i].teamNew >= 0 && objects[i].teamNew < 8)
        {
            teamsNew[objects[i].teamNew] = 1;
        }
        {
            int seen = 0;
            for (int j = 0; j < i; j++)
            {
                if (objects[j].x == objects[i].x && objects[j].y == objects[i].y)
                {
                    seen = 1;
                    break;
                }
            }
            if (!seen)
            {
                distinct++;
            }
        }
    }
    for (int i = 0; i < 8; i++)
    {
        if (teamsOld[i])
        {
            distinctOld++;
        }
        if (teamsNew[i])
        {
            distinctNew++;
        }
    }
    rcl_team_off = (int)RCL_OBJ_TEAM_OFF;
    rcl_coord_usable = usable;
    {
        int unique = 0;
        for (int i = 0; i < usable; i++)
        {
            int seen = 0;
            for (int j = 0; j < i; j++)
            {
                if (objects[j].gid == objects[i].gid)
                {
                    seen = 1;
                    break;
                }
            }
            if (!seen)
            {
                unique++;
            }
        }
    }
    rcl_coord_ok = (usable >= 2 && inRange == usable && distinct >= 2 &&
                    (distinctOld >= 2 || distinctNew >= 2))
                       ? 1
                       : 0;
    {
        int back = 0;
        int backRead = 0;
        for (int i = 0; i < usable; i++)
        {
            void *backPtr = nullptr;
            if (!rcl_read_ptr(objects[i].object + RCL_ELEM_BACK_OFF, &backPtr))
            {
                continue;
            }
            backRead++;
            if ((uintptr_t)backPtr == manager)
            {
                back++;
            }
        }
    }
}

void rcl_paircal(void)
{
    uintptr_t ctrl = rcl_pair_base();
    int32_t ownX = 0;
    int32_t ownY = 0;
    int32_t px = 0;
    int32_t py = 0;
    int dx = 0;
    int dy = 0;
    float pLen = 0.0f;
    float mLen = 0.0f;
    if ((rcl_ticks_a % 60) != 0)
    {
        return;
    }
    if (rcl_logs_a >= RCL_LOGS_a)
    {
        return;
    }
    if (!ctrl)
    {
        return;
    }
    if (!rcl_own(&ownX, &ownY))
    {
        return;
    }
    if (!rcl_read_int(ctrl + RCL_CTRL_RAW_X_OFF, &px))
    {
        return;
    }
    if (!rcl_read_int(ctrl + RCL_CTRL_RAW_Y_OFF, &py))
    {
        return;
    }
    if (rcl_seeded)
    {
        dx = (int)(ownX - rcl_last_x_a);
        dy = (int)(ownY - rcl_last_y_a);
    }
    rcl_seeded = 1;
    rcl_last_x_a = ownX;
    rcl_last_y_a = ownY;
    pLen = sqrtf((float)(px * px + py * py));
    mLen = sqrtf((float)(dx * dx + dy * dy));
    if (pLen < 1.0f || mLen < 1.0f)
    {
        return;
    }
    rcl_logs_a++;
}

uintptr_t rcl_scene_object = 0;

int rcl_team_at(const rcl_obj_t *objects, int index)
{
    if (!objects || index < 0)
    {
        return -1;
    }
    return (rcl_team_off == (int)RCL_OBJ_TEAM_OFF) ? objects[index].teamOld
                                                   : objects[index].teamNew;
}

int rcl_own_ok(int32_t x, int32_t y)
{
    if (x == 0 && y == 0)
    {
        return 0;
    }
    if (x < -100000 || x > 100000)
    {
        return 0;
    }
    if (y < -100000 || y > 100000)
    {
        return 0;
    }
    return 1;
}

int rcl_own_side_spawn(int32_t sx, int32_t sy)
{
    int i = 0;
    int best = -1;
    float bestD = 0.0f;
    float secondD = -1.0f;
    if (rcl_own_team_b < 0)
    {
        return -1;
    }
    if (rcl_pl_n <= 0)
    {
        return -1;
    }
    for (i = 0; i < rcl_pl_n; i++)
    {
        float dx = (float)sx - (float)rcl_pl_x[i];
        float dy = (float)sy - (float)rcl_pl_y[i];
        float d2 = dx * dx + dy * dy;
        if (best < 0 || d2 < bestD)
        {
            secondD = (best < 0) ? -1.0f : bestD;
            bestD = d2;
            best = i;
        }
        else if (secondD < 0.0f || d2 < secondD)
        {
            secondD = d2;
        }
    }
    if (best < 0)
    {
        return -1;
    }
    if (bestD > RCL_ATTRIB_R)
    {
        return -1;
    }
    if (secondD >= 0.0f && bestD * RCL_ATTRIB_MARGIN > secondD)
    {
        return -1;
    }
    return (rcl_pl_team[best] == rcl_own_team_b) ? 1 : 0;
}
void rcl_respawn_event(int32_t, int32_t, int32_t, int32_t)
{
    int i = 0;
    rcl_state_code = RCL_STATE_RESPAWN;
    rcl_respawn_tick = (int)rcl_ticks_a;
    rcl_clear_life();
    rcl_pending = 1;
    rcl_pending_tick = (int)rcl_ticks_a;
    for (i = 0; i < 3; i++)
    {
        rcl_pre[i] = rcl_cand_frame[i];
        rcl_cand_changes[i] = 0;
    }
}

uintptr_t rcl_own_ptr = 0;

int rcl_own_index = -1;

const char *rcl_own_from = "none";

void rcl_own_index_probe(void)
{
    uintptr_t cand[2];
    uintptr_t array = rcl_players_array;
    int32_t count = rcl_players_count;
    int taken = 0;
    int b;
    if (!array || count <= 0)
    {
        return;
    }
    cand[0] = rcl_players_object;
    cand[1] = rcl_scene_object;
    for (b = 0; b < 2; b++)
    {
        int32_t idx = -1;
        int32_t team = -1;
        void *elem = nullptr;
        int hit = 0;
        if (!cand[b])
        {
            continue;
        }
        if (!rcl_read_int(cand[b] + RCL_OWNIDX_OFF, &idx))
        {
            continue;
        }
        rcl_read_int(cand[b] + RCL_OWNTEAM_OFF, &team);
        if (idx >= 0 && idx < count)
        {
            if (rcl_read_ptr(array + (uintptr_t)idx * 8ULL, &elem) && elem)
            {
                hit = 1;
            }
        }
        if (hit && !taken)
        {
            taken = 1;
            rcl_own_index = idx;
            rcl_own_ptr = (uintptr_t)elem;
            rcl_own_from = (b == 0) ? "container+e0" : "scene+e0";
        }
    }
    if (!taken)
    {
        rcl_own_index = -1;
        rcl_own_ptr = 0;
        rcl_own_from = "index-miss";
    }
}

void rcl_publish_own(uintptr_t elem, const char *)
{
    uintptr_t vt = 0;
    const char *why = "?";
    if (!rcl_cand_ok(elem, &why, &vt))
    {
        return;
    }
    rcl_own_elem = elem;
    if (rcl_pub_logs < RCL_PUB_LOGS)
    {
        rcl_pub_logs++;
    }
}
int rcl_own_from_slot(uintptr_t *objectOut, int32_t *gidOut)
{
    uintptr_t scene = rcl_scene_object;
    uintptr_t hop[2] = {0};
    void *outer = nullptr;
    int k;
    if (objectOut)
    {
        *objectOut = 0;
    }
    if (gidOut)
    {
        *gidOut = 0;
    }
    if (!scene)
    {
        return 0;
    }
    if (rcl_read_ptr(scene + RCL_CLIENT_OFF, &outer) && outer)
    {
        hop[0] = (uintptr_t)outer;
        if (rcl_read_ptr((uintptr_t)outer + RCL_CLIENT_OFF, &outer) && outer)
        {
            hop[1] = (uintptr_t)outer;
        }
    }
    for (k = 0; k < 2; k++)
    {
        void *array = nullptr;
        void *element = nullptr;
        int32_t count = 0;
        int32_t idx = -1;
        int32_t gid = 0;
        if (!hop[k])
        {
            continue;
        }
        if (!rcl_read_int(hop[k] + RCL_OWNIDX_OFF, &idx))
        {
            continue;
        }
        if (!rcl_read_ptr(hop[k] + RCL_MGR_ARRAY_OFF, &array) || !array)
        {
            continue;
        }
        if (!rcl_read_int(hop[k] + RCL_MGR_COUNT_OFF, &count))
        {
            continue;
        }
        if (idx < 0 || idx >= count || count <= 0)
        {
            continue;
        }
        if (!rcl_read_ptr((uintptr_t)array + (uintptr_t)idx * 8ULL, &element) || !element)
        {
            continue;
        }
        gid = rcl_gid((uintptr_t)element, nullptr);
        if (gid < RCL_GID_FLOOR || gid >= 2000000)
        {
            continue;
        }
        if (objectOut)
        {
            *objectOut = (uintptr_t)element;
        }
        if (gidOut)
        {
            *gidOut = gid;
        }
        return 1;
    }
    return 0;
}

uintptr_t rcl_players_object = 0;

uintptr_t rcl_players_array = 0;

int rcl_players_count = 0;

uintptr_t rcl_own_elem_scan = 0;

int rcl_state_code = RCL_STATE_INIT;

int rcl_pl_n = 0;

int32_t rcl_pl_x[12];

int32_t rcl_pl_y[12];

int32_t rcl_pl_team[12];

int rcl_mate_n = 0;

int32_t rcl_mate_x[8];

int32_t rcl_mate_y[8];

int rcl_own_team_b = -1;

int rcl_team_trust = 1;

int32_t rcl_enemy_x[12];

int32_t rcl_enemy_y[12];

int rcl_enemy_n = 0;

void rcl_roster(uintptr_t ownElem, int ownIndex, int ownTeam, const rcl_obj_t *objects, int usable)
{
    int i = 0;
    int ownSide = 0;
    int hist[12];
    int hn = 0;
    rcl_pl_n = 0;
    rcl_mate_n = 0;
    rcl_enemy_n = 0;
    rcl_own_team_b = ownTeam;
    rcl_team_trust = 1;
    for (i = 0; i < usable && rcl_pl_n < 12; i++)
    {
        int32_t team = 0;
        int isOwn = 0;
        int h = 0;
        if (objects[i].gid < 1000000)
        {
            continue;
        }
        if (objects[i].gid >= 2000000)
        {
            continue;
        }
        team = rcl_team_at(objects, i);
        isOwn =
            (ownElem && objects[i].object == ownElem) ? 1 : ((!ownElem && i == ownIndex) ? 1 : 0);
        rcl_pl_x[rcl_pl_n] = objects[i].x;
        rcl_pl_y[rcl_pl_n] = objects[i].y;
        rcl_pl_team[rcl_pl_n] = team;
        rcl_pl_mine[rcl_pl_n] = isOwn;
        rcl_pl_n++;
        if (isOwn)
        {
            continue;
        }
        for (h = 0; h < hn; h++)
        {
            if (hist[h] == team)
            {
                break;
            }
        }
        if (h == hn && hn < 12)
        {
            hist[hn++] = team;
        }
        if (team != ownTeam)
        {
            continue;
        }
        ownSide++;
        if (rcl_mate_n >= 8)
        {
            continue;
        }
        rcl_mate_x[rcl_mate_n] = objects[i].x;
        rcl_mate_y[rcl_mate_n] = objects[i].y;
        rcl_mate_n++;
    }
    ownSide++;
    if (rcl_pl_n >= 4 && (ownSide > (rcl_pl_n / 2) || hn < 2))
    {
        rcl_team_trust = 0;
        rcl_mate_n = 0;
    }
    {
        int ownSpawn = -1;
        int k = 0;
        for (k = 0; k < rcl_pl_n; k++)
        {
            if (rcl_pl_mine[k])
            {
                ownSpawn = k;
                break;
            }
        }
        {
            int same = 1;
            for (k = 1; k < rcl_pl_n; k++)
            {
                if (rcl_pl_team[k] != rcl_pl_team[0])
                {
                    same = 0;
                }
            }
            if (rcl_pl_n > 1 && same && rcl_team_trust)
            {
                rcl_team_trust = 0;
            }
        }
        if (!rcl_team_trust)
        {
            int m = 0;
            int e = 0;
            rcl_mate_n = 0;
            rcl_enemy_n = 0;
            for (k = 0; k < rcl_pl_n; k++)
            {
                float dx = 0.0f;
                float dy = 0.0f;
                if (rcl_pl_mine[k])
                {
                    continue;
                }
                dx = (float)(rcl_pl_x[k] - rcl_pl_x[ownSpawn]);
                dy = (float)(rcl_pl_y[k] - rcl_pl_y[ownSpawn]);
                if (sqrtf(dx * dx + dy * dy) <= RCL_CLUSTER)
                {
                    if (m < 8)
                    {
                        rcl_mate_x[m] = rcl_pl_x[k];
                        rcl_mate_y[m] = rcl_pl_y[k];
                        m++;
                    }
                }
                else if (e < 12)
                {
                    rcl_enemy_x[e] = rcl_pl_x[k];
                    rcl_enemy_y[e] = rcl_pl_y[k];
                    e++;
                }
            }
            rcl_mate_n = m;
            rcl_enemy_n = e;
        }
    }
    if (rcl_team_trust)
    {
        for (i = 0; i < rcl_pl_n && rcl_enemy_n < 12; i++)
        {
            if (rcl_pl_mine[i])
            {
                continue;
            }
            if (rcl_pl_team[i] == ownTeam)
            {
                continue;
            }
            rcl_enemy_x[rcl_enemy_n] = rcl_pl_x[i];
            rcl_enemy_y[rcl_enemy_n] = rcl_pl_y[i];
            rcl_enemy_n++;
        }
    }
}

int rcl_cand_frame[3];

int rcl_cand_changes[3];

int rcl_dead_slot = -1;

int rcl_dead_value = 0;

int rcl_pending = 0;

int rcl_pending_tick = 0;

int rcl_pre[3];

int rcl_prev_valid = 0;

int rcl_respawn_tick = 0;

void rcl_clear_life(void)
{
    rcl_prev_valid = 0;
}

int rcl_life(uintptr_t ownElem, int32_t ownX, int32_t ownY)
{
    int i = 0;
    int deadNow = 0;
    rcl_candidates(ownElem, rcl_cand_now);
    if (rcl_cand_seen)
    {
        for (i = 0; i < 3; i++)
        {
            if (rcl_cand_now[i] != rcl_cand_frame[i])
            {
                if (rcl_cand_changes[i] < 1000000)
                {
                    rcl_cand_changes[i]++;
                }
            }
        }
    }
    for (i = 0; i < 3; i++)
    {
        rcl_cand_frame[i] = rcl_cand_now[i];
    }
    rcl_cand_seen = 1;
    if (rcl_pending && ((int)rcl_ticks_a - rcl_pending_tick) >= RCL_HOLD_FRAMES)
    {
        int bestSlot = -1;
        int bestChanges = 0;
        rcl_pending = 0;
        for (i = 0; i < 3; i++)
        {
            if (rcl_pre[i] < 0 || rcl_cand_now[i] < 0)
            {
                continue;
            }
            if (rcl_cand_now[i] == rcl_pre[i])
            {
                continue;
            }
            if (bestSlot < 0 || rcl_cand_changes[i] < bestChanges)
            {
                bestSlot = i;
                bestChanges = rcl_cand_changes[i];
            }
        }
        if (bestSlot >= 0)
        {
            rcl_dead_slot = bestSlot;
            rcl_dead_value = rcl_pre[bestSlot];
        }
    }
    if (rcl_prev_valid && rcl_own_ok(ownX, ownY) && rcl_own_ok(rcl_prev_x, rcl_prev_y))
    {
        int64_t jx = (int64_t)ownX - (int64_t)rcl_prev_x;
        int64_t jy = (int64_t)ownY - (int64_t)rcl_prev_y;
        if (jx * jx + jy * jy >= (int64_t)RCL_RESPAWN_JUMP * RCL_RESPAWN_JUMP)
        {
            rcl_respawn_event(ownX, ownY, rcl_prev_x, rcl_prev_y);
        }
    }
    rcl_prev_x = ownX;
    rcl_prev_y = ownY;
    rcl_prev_valid = 1;
    if (rcl_state_code == RCL_STATE_INIT)
    {
        rcl_state_code = RCL_STATE_ALIVE;
    }
    if (rcl_dead_slot >= 0 && rcl_cand_now[rcl_dead_slot] == rcl_dead_value)
    {
        deadNow = 1;
    }
    if (deadNow)
    {
        if (rcl_state_code != RCL_STATE_DEAD)
        {
            rcl_state_code = RCL_STATE_DEAD;
        }
        return 1;
    }
    if (rcl_state_code == RCL_STATE_DEAD)
    {
        rcl_clear_life();
        rcl_state_code = RCL_STATE_ALIVE;
        return 0;
    }
    if (rcl_state_code == RCL_STATE_RESPAWN &&
        ((int)rcl_ticks_a - rcl_respawn_tick) < RCL_RESPAWN_VISIBLE)
    {
        return 0;
    }
    rcl_state_code = RCL_STATE_ALIVE;
    return 0;
}

int rcl_resolve_own(const rcl_obj_t *objects, int usable, int *indexOut, const char **fromOut)
{
    int32_t wx = 0;
    int32_t wy = 0;
    int32_t wantGid = -1;
    uintptr_t slotOwn = 0;
    int32_t slotGid = 0;
    int hasWit = 0;
    int best = -1;
    int64_t bestD = 0;
    int i;
    if (indexOut)
    {
        *indexOut = -1;
    }
    if (fromOut)
    {
        *fromOut = "none";
    }
    if (!objects || usable <= 0)
    {
        return 0;
    }
    {
        uintptr_t minOwn = 0;
        int32_t minGid = 0;
        if (rcl_own_by_min_gid(rcl_tick_array, rcl_tick_count, &minOwn, &minGid) && minOwn)
        {
            for (i = 0; i < usable; i++)
            {
                if (objects[i].object != minOwn)
                {
                    continue;
                }
                if (indexOut)
                {
                    *indexOut = i;
                }
                if (fromOut)
                {
                    *fromOut = "v134-min";
                }
                return 1;
            }
        }
    }
    if (rcl_own_from_slot(&slotOwn, &slotGid) && slotOwn)
    {
        for (i = 0; i < usable; i++)
        {
            if (objects[i].object != slotOwn)
            {
                continue;
            }
            if (objects[i].gid < RCL_GID_FLOOR || objects[i].gid >= RCL_GID_MAX)
            {
                continue;
            }
            if (indexOut)
            {
                *indexOut = i;
            }
            if (fromOut)
            {
                *fromOut = "v129-slot";
            }
            return 1;
        }
    }
    if (rcl_own_gid > 0)
    {
        wantGid = rcl_own_gid;
    }
    else if (slotGid > 0)
    {
        wantGid = slotGid;
    }
    else if (rcl_own_ptr_a)
    {
        wantGid = rcl_gid(rcl_own_ptr_a, nullptr);
    }
    for (i = 0; i < usable; i++)
    {
        if (objects[i].x <= -RCL_COORD_MAX || objects[i].x >= RCL_COORD_MAX)
        {
            continue;
        }
        if (objects[i].y <= -RCL_COORD_MAX || objects[i].y >= RCL_COORD_MAX)
        {
            continue;
        }
        if (objects[i].x == 0 && objects[i].y == 0)
        {
            continue;
        }
        if (wantGid > 0 && objects[i].gid == wantGid)
        {
            if (indexOut)
            {
                *indexOut = i;
            }
            if (fromOut)
            {
                *fromOut = "v129-gid";
            }
            return 1;
        }
    }
    if (rcl_own_from_list(objects, usable, indexOut, fromOut))
    {
        return 1;
    }
    hasWit = rcl_witness(&wx, &wy) && (wx != 0 || wy != 0);
    if (!hasWit)
    {
        return 0;
    }
    for (i = 0; i < usable; i++)
    {
        int64_t dx = 0;
        int64_t dy = 0;
        int64_t d = 0;
        if (objects[i].x <= -RCL_COORD_MAX || objects[i].x >= RCL_COORD_MAX)
        {
            continue;
        }
        if (objects[i].y <= -RCL_COORD_MAX || objects[i].y >= RCL_COORD_MAX)
        {
            continue;
        }
        if (objects[i].x == 0 && objects[i].y == 0)
        {
            continue;
        }
        dx = (int64_t)objects[i].x - (int64_t)wx;
        dy = (int64_t)objects[i].y - (int64_t)wy;
        d = dx * dx + dy * dy;
        if (best < 0 || d < bestD)
        {
            best = i;
            bestD = d;
        }
    }
    if (best < 0)
    {
        return 0;
    }
    if (indexOut)
    {
        *indexOut = best;
    }
    if (fromOut)
    {
        *fromOut = "v129-near";
    }
    return 1;
}

uintptr_t rcl_own_ptr_a = 0;

uintptr_t rcl_own_ptr_b = 0;

int rcl_own_index_3 = -1;

int rcl_own_verdict(uintptr_t element)
{
    void *vtable = nullptr;
    uintptr_t vtRva = 0;
    int32_t x = 0;
    int32_t y = 0;
    int32_t teamOld = 0;
    int32_t teamNew = 0;
    uint8_t dead = 0;
    if (!element)
    {
        return 0;
    }
    if (rcl_element_ascii(element))
    {
        return 0;
    }
    if (!rcl_read_ptr(element, &vtable) || !vtable)
    {
        return 0;
    }
    vtRva = (uintptr_t)vtable - rcl_base;
    if (vtRva < RCL_DC_RVA_LO || vtRva >= RCL_DC_RVA_LO + RCL_DC_RVA_SIZE)
    {
        return 0;
    }
    if (!rcl_read_int(element + rcl_coord_x_off(), &x) ||
        !rcl_read_int(element + rcl_coord_y_off(), &y) ||
        !rcl_read_int(element + RCL_OBJ_TEAM_OFF, &teamOld) ||
        !rcl_read_int(element + RCL_TEAM_OFF, &teamNew) ||
        !rcl_read_byte(element + RCL_OBJ_DEADFLAG_OFF, &dead))
    {
        return 0;
    }
    if (x <= -1000000 || x >= 1000000 || y <= -1000000 || y >= 1000000)
    {
        return 0;
    }
    return 1;
}

void rcl_own_probe(void)
{
    uintptr_t cand[2];
    int taken = 0;
    int b;
    cand[0] = rcl_players_object;
    cand[1] = rcl_scene_object;
    for (b = 0; b < 2; b++)
    {
        void *array = nullptr;
        void *elem = nullptr;
        int32_t count = 0;
        int32_t idx = -1;
        int32_t team = -1;
        int32_t eid = 0;
        int32_t eteam = 0;
        int32_t elemGid = 0;
        int32_t gidOff = 0;
        int sig = 0;
        int valid = 0;
        if (!cand[b])
        {
            continue;
        }
        if (!rcl_read_ptr(cand[b] + RCL_ARRAY_OFF, &array) || !array)
        {
            continue;
        }
        if (!rcl_read_int(cand[b] + RCL_COUNT_OFF, &count))
        {
            count = 0;
        }
        if (!rcl_read_int(cand[b] + RCL_OWNIDX_OFF, &idx))
        {
            idx = -1;
        }
        if (!rcl_read_int(cand[b] + RCL_OWNTEAM_OFF, &team))
        {
            team = -1;
        }
        if (idx >= 0 && count > 0 && idx < count)
        {
            if (rcl_read_ptr((uintptr_t)array + (uintptr_t)idx * 8ULL, &elem) && elem)
            {
                if (rcl_read_int((uintptr_t)elem + RCL_ELEM_ID_OFF, &eid) &&
                    rcl_read_int((uintptr_t)elem + RCL_ELEM_TEAM_OFF, &eteam))
                {
                    elemGid = rcl_gid((uintptr_t)elem, &gidOff);
                    if (eid == idx && eid != 0)
                    {
                        sig = 1;
                    }
                    else if (team >= 0 && team <= 7 && eteam == team)
                    {
                        sig = 2;
                    }
                    else if (idx == 0 && elemGid != 0)
                    {
                        sig = 3;
                    }
                    else
                    {
                        sig = 0;
                    }
                }
            }
        }
        if (sig)
        {
            valid = rcl_own_verdict((uintptr_t)elem);
        }
        if (sig && valid && !taken)
        {
            taken = 1;
            rcl_own_ptr_a = (uintptr_t)elem;
        }
    }
    if (!taken)
    {
        rcl_own_ptr_a = 0;
    }
}
int rcl_own_latch(const rcl_obj_t *objects, int usable, int *indexOut, const char **fromOut)
{
    int i = 0;
    if (indexOut)
    {
        *indexOut = -1;
    }
    if (fromOut)
    {
        *fromOut = "none";
    }
    if (!objects || usable <= 0 || !rcl_own_elem_scan)
    {
        return 0;
    }
    for (i = 0; i < usable; i++)
    {
        if (objects[i].object != rcl_own_elem_scan)
        {
            continue;
        }
        if (objects[i].gid < RCL_GID_FLOOR || objects[i].gid >= 2000000)
        {
            return 0;
        }
        if (objects[i].teamOld < 0 || objects[i].teamOld > 15)
        {
            return 0;
        }
        if (indexOut)
        {
            *indexOut = i;
        }
        if (fromOut)
        {
            *fromOut = "latched";
        }
        return 1;
    }
    return 0;
}
uintptr_t rcl_own_elem = 0;
int32_t rcl_own_gid = 0;
int rcl_no_source_passes = 0;
int rcl_own_logged = 0;

int rcl_own_by_min_gid(uintptr_t array, int32_t count, uintptr_t *elemOut, int32_t *gidOut)
{
    uintptr_t best = 0;
    int32_t bestGid = 0;
    int32_t i = 0;
    if (elemOut)
    {
        *elemOut = 0;
    }
    if (gidOut)
    {
        *gidOut = 0;
    }
    if (!array || count <= 0)
    {
        return 0;
    }
    for (i = 0; i < count; i++)
    {
        void *element = nullptr;
        int32_t gid = 0;
        int32_t team = 0;
        if (!rcl_read_ptr(array + (uintptr_t)i * sizeof(void *), &element) || !element)
        {
            continue;
        }
        gid = rcl_gid((uintptr_t)element, nullptr);
        if (gid < RCL_GID_FLOOR || gid >= 2000000)
        {
            continue;
        }
        if (!rcl_read_int((uintptr_t)element + RCL_OBJ_TEAM_OFF, &team))
        {
            continue;
        }
        if (team < 0 || team > 15)
        {
            continue;
        }
        if (!best || gid < bestGid)
        {
            best = (uintptr_t)element;
            bestGid = gid;
        }
    }
    if (!best)
    {
        return 0;
    }
    rcl_own_gid = bestGid;
    if (elemOut)
    {
        *elemOut = best;
    }
    if (gidOut)
    {
        *gidOut = bestGid;
    }
    return 1;
}

int rcl_own_from_list(const rcl_obj_t *objects, int usable, int *indexOut, const char **fromOut)
{
    int best = -1;
    int32_t bestGid = 0;
    int accepted = 0;
    int i;
    if (indexOut)
    {
        *indexOut = -1;
    }
    if (!objects || usable <= 0)
    {
        return 0;
    }
    for (i = 0; i < usable; i++)
    {
        int32_t gid = objects[i].gid;
        if (gid < RCL_GID_FLOOR || gid >= 2000000)
        {
            continue;
        }
        if (objects[i].teamOld < 0 || objects[i].teamOld > 15)
        {
            continue;
        }
        accepted++;
        if (best < 0 || gid < bestGid)
        {
            best = i;
            bestGid = gid;
        }
    }
    if (best < 0)
    {
        return 0;
    }
    if (indexOut)
    {
        *indexOut = best;
    }
    if (fromOut)
    {
        *fromOut = "v135-list";
    }
    return 1;
}

int rcl_own_scan(void)
{
    uintptr_t bases[RCL_SCAN_BASES];
    uintptr_t array = rcl_players_array;
    int32_t count = rcl_players_count;
    uintptr_t client = 0;
    uintptr_t inputMgr = 0;
    void *chain = nullptr;
    void *input = nullptr;
    int found = 0;
    if (!rcl_scene_object)
    {
        return 0;
    }
    if (!array || count <= 0)
    {
        return 0;
    }
    bases[0] = rcl_scene_object;
    if (rcl_read_ptr(rcl_scene_object + RCL_MODE_MANAGER_OFF, &chain) && chain)
    {
        client = (uintptr_t)chain;
    }
    if (rcl_read_ptr(rcl_scene_object + RCL_MODE_INPUTMGR_OFF, &input) && input)
    {
        inputMgr = (uintptr_t)input;
    }
    bases[1] = client;
    bases[2] = inputMgr;
    rcl_own_index_probe();
    rcl_own_probe();
    if (!rcl_setpred)
    {
        rcl_setpred = rcl_entry(RCL_MODEPAIRSET_RVA);
    }
    for (int b = 0; b < RCL_SCAN_BASES; b++)
    {
        if (!bases[b])
        {
            continue;
        }
        for (int i = 0; i < RCL_SCAN_QWORDS; i++)
        {
            uintptr_t off = (uintptr_t)i * 8ULL;
            uintptr_t value = (uintptr_t)rcl_read_u64(bases[b] + off);
            uintptr_t index = 0;
            if (!value)
            {
                continue;
            }
            if (value <= array)
            {
                continue;
            }
            if (value >= array + (uintptr_t)count * 8ULL)
            {
                continue;
            }
            if ((value - array) % 8ULL)
            {
                continue;
            }
            index = (value - array) / 8ULL;
            if (!found)
            {
                rcl_own_ptr_b = value;
                rcl_own_index_3 = (int)index;
                found = 1;
            }
        }
    }
    if (!found && rcl_scan_container != array)
    {
        rcl_scan_container = array;
    }
    return found;
}

int rcl_resolve_own_fallback(const rcl_obj_t *objects, int usable, int *indexOut,
                             const char **fromOut)
{
    if (indexOut)
    {
        *indexOut = -1;
    }
    if (fromOut)
    {
        *fromOut = "none";
    }
    if (!objects || usable <= 0)
    {
        return 0;
    }
    if (rcl_own_index >= 0 && rcl_own_ptr)
    {
        int seen = 0;
        int i;
        for (i = 0; i < usable; i++)
        {
            if (objects[i].object == rcl_own_ptr)
            {
                seen = 1;
                break;
            }
        }
        if (seen)
        {
            if (indexOut)
            {
                *indexOut = i;
            }
            if (fromOut)
            {
                *fromOut = rcl_own_from;
            }
            return 1;
        }
    }
    if (rcl_own_index_3 >= 0 && rcl_own_index_3 < usable &&
        objects[rcl_own_index_3].object == rcl_own_ptr_b)
    {
        if (indexOut)
        {
            *indexOut = rcl_own_index_3;
        }
        if (fromOut)
        {
            *fromOut = "scan";
        }
        return 1;
    }
    return 0;
}

int rcl_own(int32_t *xOut, int32_t *yOut)
{
    uintptr_t own = rcl_own_elem_scan;
    if (!own)
    {
        own = rcl_own_elem;
    }
    if (!own)
    {
        return 0;
    }
    if (!rcl_read_int(own + RCL_OBJ_X_OFF, xOut))
    {
        return 0;
    }
    if (!rcl_read_int(own + RCL_OBJ_Y_OFF, yOut))
    {
        return 0;
    }
    return 1;
}
void rcl_candidates(uintptr_t ownElem, int *out)
{
    uint8_t deadByte = 0;
    int32_t ownAlive = -1;
    int32_t ctrlAlive = -1;
    uintptr_t ctrl = rcl_controller();
    out[0] = -1;
    out[1] = -1;
    out[2] = -1;
    if (ownElem && rcl_read_bytes(ownElem + RCL_DEAD_OFF, &deadByte, sizeof(deadByte)))
    {
        out[0] = (int)deadByte;
    }
    if (ownElem && rcl_read_int(ownElem + RCL_OWN_ALIVE_OFF, &ownAlive))
    {
        out[1] = (int)ownAlive;
    }
    if (ctrl && rcl_read_int(ctrl + RCL_CTRL_ALIVE_OFF, &ctrlAlive))
    {
        out[2] = (int)ctrlAlive;
    }
}

int rcl_ascii_word(uintptr_t address)
{
    uint8_t bytes[8];
    int printable = 0;
    if (!rcl_read_bytes(address, bytes, sizeof(bytes)))
    {
        return 0;
    }
    for (int i = 0; i < 8; i++)
    {
        if (bytes[i] >= 0x20 && bytes[i] <= 0x7e)
        {
            printable++;
        }
    }
    return printable == 8 ? 1 : 0;
}

int rcl_word_ascii(uint64_t value)
{
    uint8_t bytes[8];
    int printable = 0;
    memcpy(bytes, &value, sizeof(bytes));
    for (int i = 0; i < 8; i++)
    {
        if (bytes[i] >= 0x20 && bytes[i] <= 0x7e)
        {
            printable++;
        }
    }
    return printable;
}

int rcl_element_ascii(uintptr_t element)
{
    if (rcl_ascii_word(element))
    {
        return 1;
    }
    return rcl_word_ascii((uint64_t)element) == 8 ? 1 : 0;
}

static int rcl_interp(int32_t *x, int32_t *y)
{
    uintptr_t client = rcl_client();
    int32_t cx = 0;
    int32_t cy = 0;
    if (x)
    {
        *x = 0;
    }
    if (y)
    {
        *y = 0;
    }
    if (!client)
    {
        return 0;
    }
    if (!rcl_read_int(client + RCL_CLIENT_POS_X_OFF, &cx))
    {
        return 0;
    }
    if (!rcl_read_int(client + RCL_CLIENT_POS_Y_OFF, &cy))
    {
        return 0;
    }
    if (x)
    {
        *x = cx;
    }
    if (y)
    {
        *y = cy;
    }
    return 1;
}

int rcl_witness(int32_t *x, int32_t *y)
{
    int32_t wx = 0;
    int32_t wy = 0;
    if (x)
    {
        *x = 0;
    }
    if (y)
    {
        *y = 0;
    }
    if (!rcl_interp(&wx, &wy))
    {
        return 0;
    }
    if (x)
    {
        *x = wx;
    }
    if (y)
    {
        *y = wy;
    }
    return 1;
}
