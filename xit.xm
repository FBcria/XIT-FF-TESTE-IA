#import <UIKit/UIKit.h>
#import <substrate.h>
#include "offsets.hpp"
#include <cmath>
#include <vector>
#include <atomic>

uintptr_t g_base = 0;
size_t    g_size = 0;
FFOffsets g_off  = {};

// ---------- Config ----------
static std::atomic<bool> cfg_aim{false};
static std::atomic<bool> cfg_esp{false};
static std::atomic<bool> cfg_aimline{true};
static std::atomic<float> cfg_fov{180.f};
static std::atomic<float> cfg_smooth{4.f};

// ---------- Pattern scan ----------
uintptr_t find_pattern(const char* pat, const char* mask) {
    size_t mlen = strlen(mask);
    if (!g_base || g_size < mlen) return 0;
    for (size_t i = 0; i + mlen < g_size; ++i) {
        bool ok = true;
        for (size_t j = 0; j < mlen; ++j) {
            if (mask[j] == 'x' && pat[j] != *(char*)(g_base + i + j)) { ok = false; break; }
        }
        if (ok) return g_base + i;
    }
    return 0;
}

uintptr_t find_module_base(const char* name) {
    uint32_t cnt = _dyld_image_count();
    for (uint32_t i = 0; i < cnt; ++i) {
        const char* n = _dyld_get_image_name(i);
        if (n && strstr(n, name)) {
            g_size = 0;
            const struct mach_header_64* h = (const struct mach_header_64*)_dyld_get_image_header(i);
            // tamanho aproximado pelo segmento __TEXT
            uintptr_t c = (uintptr_t)h;
            struct load_command* lc = (struct load_command*)(c + sizeof(mach_header_64));
            for (uint32_t k = 0; k < h->ncmds; ++k) {
                if (lc->cmd == LC_SEGMENT_64) {
                    struct segment_command_64* s = (struct segment_command_64*)lc;
                    if (!strcmp(s->segname, "__TEXT")) { g_size = s->vmsize; break; }
                }
                lc = (struct load_command*)((uintptr_t)lc + lc->cmdsize);
            }
            return c;
        }
    }
    return 0;
}

// ---------- Resolve offsets ----------
bool resolve_offsets() {
    g_base = find_module_base("FreeFire");
    if (!g_base) return false;

    // Patterns genéricos — AJUSTE os bytes conforme dump do OB55.
    // Exemplo: padrão de função de camera update
    uintptr_t cam = find_pattern(
        "\xF0\x48\x8D\x05????\xF0\x48", "xxxxxx????xx");
    if (cam) g_off.cam_pos = cam + 8;

    // Exemplo de pattern de player loop
    uintptr_t lp = find_pattern(
        "\x48\x8B\x05????\x48\x8B\x88", "xxx????xxx");
    if (lp) g_off.local_player = lp + 3;

    return g_off.local_player && g_off.cam_pos;
}

// ---------- Math ----------
struct Vec3 { float x, y, z; };
struct Vec2 { float x, y; };

static Vec3 cam_pos;
static float vmatrix[16];

static bool w2s(const Vec3& w, Vec2& out, CGSize sz) {
    float cx = vmatrix[0]*w.x + vmatrix[4]*w.y + vmatrix[8]*w.z  + vmatrix[12];
    float cy = vmatrix[1]*w.x + vmatrix[5]*w.y + vmatrix[9]*w.z  + vmatrix[13];
    float cw = vmatrix[3]*w.x + vmatrix[7]*w.y + vmatrix[11]*w.z + vmatrix[15];
    if (cw < 0.01f) return false;
    float nx = cx / cw, ny = cy / cw;
    out.x = (sz.width  * 0.5f) * (1.f + nx);
    out.y = (sz.height * 0.5f) * (1.f - ny);
    return true;
}

// ---------- ESP overlay ----------
@interface ESPView : UIView
@end

@implementation ESPView

- (instancetype)initWithFrame:(CGRect)f {
    if ((self = [super initWithFrame:f])) {
        self.backgroundColor = UIColor.clearColor;
        self.userInteractionEnabled = NO;
    }
    return self;
}

- (void)drawRect:(CGRect)rect {
    if (!cfg_esp) return;
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    if (!ctx) return;

    // Atualiza matrix e câmera a partir da memória
    if (g_off.matrix)   memcpy(vmatrix, (void*)g_off.matrix, 64);
    if (g_off.cam_pos)  cam_pos = rd<Vec3>(g_off.cam_pos);

    CGSize sz = self.bounds.size;
    CGContextSetStrokeColorWithColor(ctx, UIColor.greenColor.CGColor);
    CGContextSetLineWidth(ctx, 1.5f);

    // Exemplo: 10 entidades, offsets relativos — ajuste conforme o dump
    uintptr_t list = rd<uintptr_t>(g_off.entity_list);
    for (int i = 0; i < 10 && list; ++i) {
        uintptr_t ent = list + i * 0x8; // stride genérico
        Vec3 pos = rd<Vec3>(rd<uintptr_t>(ent) + 0x50);
        if (!pos.x) continue;

        Vec2 head, foot;
        Vec3 footW = pos, headW = {pos.x, pos.y + 1.8f, pos.z};
        if (w2s(headW, head, sz) && w2s(footW, foot, sz)) {
            float h = foot.y - head.y;
            float w = h * 0.45f;
            CGRect r = CGRectMake(foot.x - w/2, head.y, w, h);
            CGContextStrokeRect(ctx, r);
            CGContextMoveToPoint(ctx, r.origin.x, r.origin.y + r.size.height);
            CGContextAddLineToPoint(ctx,