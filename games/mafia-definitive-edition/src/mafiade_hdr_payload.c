/*
 * Copyright (C) 2026 macOs-crossover-game-patch contributors
 * SPDX-License-Identifier: MIT
 */

typedef unsigned char u8;
typedef unsigned int u32;
typedef int i32;
typedef unsigned long long u64;
typedef u64 usize;

#define MSABI __attribute__((ms_abi))
#define PAYLOAD_DATA __attribute__((section("__TEXT,__hdrdata"), used))

typedef i32 HRESULT;

typedef struct {
  u32 width;
  u32 height;
  u32 mip_levels;
  u32 array_size;
  u32 format;
  u32 sample_count;
  u32 sample_quality;
  u32 usage;
  u32 bind_flags;
  u32 cpu_access_flags;
  u32 misc_flags;
} Texture2DDesc;

typedef struct {
  u32 filter;
  u32 address_u;
  u32 address_v;
  u32 address_w;
  float mip_lod_bias;
  u32 max_anisotropy;
  u32 comparison_func;
  float border_color[4];
  float min_lod;
  float max_lod;
} SamplerDesc;

typedef struct {
  float top_left_x;
  float top_left_y;
  float width;
  float height;
  float min_depth;
  float max_depth;
} Viewport;

extern const u8 proxy_vs_start[];
extern const u8 proxy_vs_end[];
extern const u8 proxy_ps_start[];
extern const u8 proxy_ps_end[];

PAYLOAD_DATA static void *g_real_rtv;
PAYLOAD_DATA static void *g_vertex_shader;
PAYLOAD_DATA static void *g_pixel_shader;
PAYLOAD_DATA static void *g_sampler;
PAYLOAD_DATA static u32 g_proxy_ready;

PAYLOAD_DATA static u8 IID_ID3D11Texture2D[16] = {
  0xf2, 0xaa, 0x15, 0x6f, 0x08, 0xd2, 0x89, 0x4e,
  0x9a, 0xb4, 0x48, 0x95, 0x35, 0xd3, 0x4f, 0x9c
};

PAYLOAD_DATA static u8 IID_IDXGISwapChain3[16] = {
  0xdb, 0x9b, 0xd9, 0x94, 0xf8, 0xf1, 0xb0, 0x4a,
  0xb2, 0x36, 0x7d, 0xa0, 0x17, 0x0e, 0xda, 0xb1
};

static void *method(void *object, u32 index) {
  return (*(void ***)object)[index];
}

static MSABI u32 release_object(void *object) {
  typedef u32 (MSABI *Fn)(void *);
  return ((Fn)method(object, 2))(object);
}

static MSABI HRESULT get_buffer(void *swapchain, u32 index, const void *iid, void **output) {
  typedef HRESULT (MSABI *Fn)(void *, u32, const void *, void **);
  return ((Fn)method(swapchain, 9))(swapchain, index, iid, output);
}

static MSABI HRESULT query_interface(void *object, const void *iid, void **output) {
  typedef HRESULT (MSABI *Fn)(void *, const void *, void **);
  return ((Fn)method(object, 0))(object, iid, output);
}

static MSABI HRESULT create_texture_2d(void *device, const Texture2DDesc *desc, void **output) {
  typedef HRESULT (MSABI *Fn)(void *, const Texture2DDesc *, const void *, void **);
  return ((Fn)method(device, 5))(device, desc, (const void *)0, output);
}

static MSABI HRESULT create_rtv(void *device, void *resource, void **output) {
  typedef HRESULT (MSABI *Fn)(void *, void *, const void *, void **);
  return ((Fn)method(device, 9))(device, resource, (const void *)0, output);
}

static MSABI HRESULT create_vertex_shader(void *device, const void *data, usize size, void **output) {
  typedef HRESULT (MSABI *Fn)(void *, const void *, usize, void *, void **);
  return ((Fn)method(device, 12))(device, data, size, (void *)0, output);
}

static MSABI HRESULT create_pixel_shader(void *device, const void *data, usize size, void **output) {
  typedef HRESULT (MSABI *Fn)(void *, const void *, usize, void *, void **);
  return ((Fn)method(device, 15))(device, data, size, (void *)0, output);
}

static MSABI HRESULT create_sampler(void *device, const SamplerDesc *desc, void **output) {
  typedef HRESULT (MSABI *Fn)(void *, const SamplerDesc *, void **);
  return ((Fn)method(device, 23))(device, desc, output);
}

static MSABI void release_real_rtv(void) {
  if (g_real_rtv != (void *)0) {
    release_object(g_real_rtv);
    g_real_rtv = (void *)0;
  }
  g_proxy_ready = 0;
}

static MSABI i32 initialize_present_pipeline(void *device) {
  SamplerDesc sampler;
  if (g_vertex_shader == (void *)0) {
    if (create_vertex_shader(device, proxy_vs_start,
          (usize)(proxy_vs_end - proxy_vs_start), &g_vertex_shader) < 0) return 0;
  }
  if (g_pixel_shader == (void *)0) {
    if (create_pixel_shader(device, proxy_ps_start,
          (usize)(proxy_ps_end - proxy_ps_start), &g_pixel_shader) < 0) return 0;
  }
  if (g_sampler == (void *)0) {
    sampler.filter = 0;
    sampler.address_u = 3;
    sampler.address_v = 3;
    sampler.address_w = 3;
    sampler.mip_lod_bias = 0.0f;
    sampler.max_anisotropy = 1;
    sampler.comparison_func = 8;
    sampler.border_color[0] = 0.0f;
    sampler.border_color[1] = 0.0f;
    sampler.border_color[2] = 0.0f;
    sampler.border_color[3] = 0.0f;
    sampler.min_lod = 0.0f;
    sampler.max_lod = 3.402823466e+38f;
    if (create_sampler(device, &sampler, &g_sampler) < 0) return 0;
  }
  return 1;
}

__attribute__((used)) MSABI HRESULT hdr_create_backbuffer_proxy(void *manager, void *swapchain_object) {
  Texture2DDesc desc;
  void *real_texture = (void *)0;
  void *swapchain3 = (void *)0;
  void *proxy_texture = (void *)0;
  void *backend = *(void **)((u8 *)manager + 0x20);
  void *device = *(void **)((u8 *)backend + 0xd0);
  void *swapchain = *(void **)((u8 *)swapchain_object + 0x20);
  void **game_texture = (void **)((u8 *)swapchain_object + 0x30);
  HRESULT result;

  release_real_rtv();
  result = get_buffer(swapchain, 0, IID_ID3D11Texture2D, &real_texture);
  if (result < 0 || real_texture == (void *)0) return result;

  result = create_rtv(device, real_texture, &g_real_rtv);
  if (result < 0 || g_real_rtv == (void *)0) {
    *game_texture = real_texture;
    return result;
  }

  desc.width = *(u32 *)((u8 *)swapchain_object + 8);
  desc.height = *(u32 *)((u8 *)swapchain_object + 12);
  desc.mip_levels = 1;
  desc.array_size = 1;
  desc.format = 10;
  desc.sample_count = 1;
  desc.sample_quality = 0;
  desc.usage = 0;
  desc.bind_flags = 0x28;
  desc.cpu_access_flags = 0;
  desc.misc_flags = 0;
  result = create_texture_2d(device, &desc, &proxy_texture);
  if (result < 0 || proxy_texture == (void *)0 || !initialize_present_pipeline(device)) {
    if (proxy_texture != (void *)0) release_object(proxy_texture);
    release_real_rtv();
    *game_texture = real_texture;
    return result;
  }

  *game_texture = proxy_texture;
  release_object(real_texture);
  g_proxy_ready = 1;

  if (query_interface(swapchain, IID_IDXGISwapChain3, &swapchain3) >= 0 &&
      swapchain3 != (void *)0) {
    typedef HRESULT (MSABI *SetColorSpaceFn)(void *, u32);
    ((SetColorSpaceFn)method(swapchain3, 38))(swapchain3, 12);
    release_object(swapchain3);
  }
  return 0;
}

__attribute__((used)) MSABI void hdr_release_backbuffer_proxy(void) {
  release_real_rtv();
}

__attribute__((used)) MSABI HRESULT hdr_present(void *renderer, u32 sync_interval) {
  typedef void (MSABI *SetTwoFn)(void *, u32, void *);
  typedef void (MSABI *SetThreeFn)(void *, u32, u32, void *);
  typedef void (MSABI *SetRenderTargetsFn)(void *, u32, void *, void *);
  typedef void (MSABI *SetShaderFn)(void *, void *, void *, u32);
  typedef void (MSABI *DrawFn)(void *, u32, u32);
  typedef HRESULT (MSABI *PresentFn)(void *, u32, u32);
  void *swapchain_object = *(void **)((u8 *)renderer + 0x382f0);
  void *swapchain = *(void **)((u8 *)swapchain_object + 0x20);
  void *context = *(void **)((u8 *)renderer + 0x382e8);
  void *source_view = *(void **)((u8 *)swapchain_object + 0x48);
  void *null_view = (void *)0;
  float blend_factor[4] = {0.0f, 0.0f, 0.0f, 0.0f};
  Viewport viewport;

  if (g_proxy_ready && g_real_rtv != (void *)0 && source_view != (void *)0) {
    viewport.top_left_x = 0.0f;
    viewport.top_left_y = 0.0f;
    viewport.width = (float)*(u32 *)((u8 *)swapchain_object + 8);
    viewport.height = (float)*(u32 *)((u8 *)swapchain_object + 12);
    viewport.min_depth = 0.0f;
    viewport.max_depth = 1.0f;

    ((SetRenderTargetsFn)method(context, 33))(context, 1, &g_real_rtv, (void *)0);
    ((void (MSABI *)(void *, void *, const float *, u32))method(context, 35))
      (context, (void *)0, blend_factor, 0xffffffffu);
    ((void (MSABI *)(void *, void *, u32))method(context, 36))(context, (void *)0, 0);
    ((SetTwoFn)method(context, 44))(context, 1, &viewport);
    ((void (MSABI *)(void *, void *))method(context, 17))(context, (void *)0);
    ((void (MSABI *)(void *, u32))method(context, 24))(context, 4);
    ((SetShaderFn)method(context, 11))(context, g_vertex_shader, (void *)0, 0);
    ((SetShaderFn)method(context, 9))(context, g_pixel_shader, (void *)0, 0);
    ((SetThreeFn)method(context, 8))(context, 0, 1, &source_view);
    ((SetThreeFn)method(context, 10))(context, 0, 1, &g_sampler);
    ((DrawFn)method(context, 13))(context, 3, 0);
    ((SetThreeFn)method(context, 8))(context, 0, 1, &null_view);
  }

  return ((PresentFn)method(swapchain, 8))(swapchain, sync_interval, 0);
}
