/*
 * brrr: says "TortOS go brrr" on the Pixel 2's screen at boot, for fun.
 *
 * Sets a mode on the first connected connector through KMS, draws into a
 * dumb buffer, and then sleeps, since the picture goes when the buffer does.
 * The panel is portrait (480x640) mounted on its side, so the drawing is
 * done in landscape (640x480) and turned 90 degrees counter-clockwise, the
 * same way the kernel console rotated it (fbcon rotate=3).
 */
#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <unistd.h>
#include <xf86drm.h>
#include <xf86drmMode.h>

/* 5x7 glyphs, one row per byte, high bit on the left */
static const struct {
	char c;
	uint8_t rows[7];
} font[] = {
	{ 'B', { 0x1e, 0x11, 0x11, 0x1e, 0x11, 0x11, 0x1e } },
	{ 'H', { 0x11, 0x11, 0x11, 0x1f, 0x11, 0x11, 0x11 } },
	{ 'O', { 0x0e, 0x11, 0x11, 0x11, 0x11, 0x11, 0x0e } },
	{ 'S', { 0x0f, 0x10, 0x10, 0x0e, 0x01, 0x01, 0x1e } },
	{ 'T', { 0x1f, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04 } },
	{ 'a', { 0x00, 0x00, 0x0e, 0x01, 0x0f, 0x11, 0x0f } },
	{ 'b', { 0x10, 0x10, 0x16, 0x19, 0x11, 0x11, 0x1e } },
	{ 'e', { 0x00, 0x00, 0x0e, 0x11, 0x1f, 0x10, 0x0e } },
	{ 'g', { 0x00, 0x0f, 0x11, 0x11, 0x0f, 0x01, 0x0e } },
	{ 'i', { 0x04, 0x00, 0x0c, 0x04, 0x04, 0x04, 0x0e } },
	{ 'l', { 0x0c, 0x04, 0x04, 0x04, 0x04, 0x04, 0x0e } },
	{ 'o', { 0x00, 0x00, 0x0e, 0x11, 0x11, 0x11, 0x0e } },
	{ 'r', { 0x00, 0x00, 0x16, 0x19, 0x10, 0x10, 0x10 } },
	{ 's', { 0x00, 0x00, 0x0f, 0x10, 0x0e, 0x01, 0x1e } },
	{ 't', { 0x08, 0x08, 0x1c, 0x08, 0x08, 0x09, 0x06 } },
};

static uint32_t *pixels;
static uint32_t pitch_pixels, panel_w, panel_h;

/* Landscape point (x, y) to the portrait panel, turned counter-clockwise */
static void put(int x, int y, uint32_t color)
{
	int px = y, py = (int)panel_h - 1 - x;

	if (px < 0 || py < 0 || px >= (int)panel_w || py >= (int)panel_h)
		return;
	pixels[py * pitch_pixels + px] = color;
}

static void draw_glyph(const uint8_t *glyph, int left, int top, int scale, uint32_t color)
{
	for (int row = 0; row < 7; row++)
		for (int col = 0; col < 5; col++)
			if (glyph[row] & (0x10 >> col))
				for (int dy = 0; dy < scale; dy++)
					for (int dx = 0; dx < scale; dx++)
						put(left + col * scale + dx, top + row * scale + dy, color);
}

/* One line, centered across the screen, with a drop shadow */
static void draw_line(const char *text, int top, int scale)
{
	int advance = 6 * scale, width = (int)strlen(text) * advance - scale;
	int left = (640 - width) / 2, shadow = scale * 3 / 8;

	for (int pass = 0; pass < 2; pass++)
		for (int i = 0; text[i]; i++)
			for (size_t f = 0; f < sizeof(font) / sizeof(font[0]); f++)
				if (font[f].c == text[i])
					draw_glyph(font[f].rows,
						   left + i * advance + (pass ? 0 : shadow),
						   top + (pass ? 0 : shadow), scale,
						   pass ? 0xffffff : 0x1a3a5a);
}

int main(void)
{
	int fd = open("/dev/dri/card0", O_RDWR | O_CLOEXEC);
	if (fd < 0) {
		perror("brrr: /dev/dri/card0");
		return 1;
	}

	drmModeRes *res = drmModeGetResources(fd);
	drmModeConnector *conn = NULL;
	for (int i = 0; res && i < res->count_connectors; i++) {
		conn = drmModeGetConnector(fd, res->connectors[i]);
		if (conn && conn->connection == DRM_MODE_CONNECTED && conn->count_modes)
			break;
		drmModeFreeConnector(conn);
		conn = NULL;
	}
	if (!conn || !res->count_crtcs) {
		fprintf(stderr, "brrr: no connected display\n");
		return 1;
	}
	drmModeModeInfo mode = conn->modes[0];
	panel_w = mode.hdisplay;
	panel_h = mode.vdisplay;

	struct drm_mode_create_dumb create = { .width = panel_w, .height = panel_h, .bpp = 32 };
	if (drmIoctl(fd, DRM_IOCTL_MODE_CREATE_DUMB, &create)) {
		perror("brrr: create buffer");
		return 1;
	}
	uint32_t fb;
	if (drmModeAddFB(fd, panel_w, panel_h, 24, 32, create.pitch, create.handle, &fb)) {
		perror("brrr: add framebuffer");
		return 1;
	}
	struct drm_mode_map_dumb map = { .handle = create.handle };
	drmIoctl(fd, DRM_IOCTL_MODE_MAP_DUMB, &map);
	pixels = mmap(NULL, create.size, PROT_READ | PROT_WRITE, MAP_SHARED, fd, map.offset);
	if (pixels == MAP_FAILED) {
		perror("brrr: map buffer");
		return 1;
	}
	pitch_pixels = create.pitch / 4;

	/* Icy blue, darker toward the bottom */
	for (int y = 0; y < 480; y++)
		for (int x = 0; x < 640; x++) {
			int shade = 255 - y / 4;
			put(x, y, (uint32_t)(shade / 3) << 16 | (uint32_t)(shade * 2 / 3) << 8 | (uint32_t)shade);
		}

	/* TortOS go, then a big brrr */
	draw_line("TortOS go", 132, 9);
	draw_line("brrr", 235, 16);

	if (drmModeSetCrtc(fd, res->crtcs[0], fb, 0, 0, &conn->connector_id, 1, &mode)) {
		perror("brrr: set mode");
		return 1;
	}

	/* The picture lasts as long as the buffer, so stay */
	for (;;)
		pause();
}
