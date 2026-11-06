#pragma once
#include <cstdint>

// Base do módulo (preenchido em runtime)
extern uintptr_t g_base;
extern size_t    g_size;

// Wrappers de leitura/escrita
template <typename T>
inline T rd(uintptr_t a) { return *(T*)a; }

template <typename T>
inline void wr(uintptr_t a, T v) { *(T*)a = v; }

// Pattern scan genérico (mascara '?' = wildcard)
uintptr_t find_pattern(const char* pat, const char* mask);
uintptr_t find_module_base(const char* name);
size_t    get_module_size(uintptr_t base);

// Offsets resolvidos em runtime
struct FFOffsets {
    uintptr_t local_player;      // ponteiro para player local
    uintptr_t entity_list;       // início da lista de entidades
    uintptr_t matrix;            // view matrix (world->screen)
    uintptr_t cam_pos;           // posição da câmera
};

extern FFOffsets g_off;
bool resolve_offsets();