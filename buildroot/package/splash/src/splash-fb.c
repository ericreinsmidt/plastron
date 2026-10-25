/* SPDX-License-Identifier: GPL-3.0-or-later */
/*
 * splash-fb: TortOS's boot animation on the TrimUI Brick, from the moment its
 * framebuffer exists until TortOS draws its first frame.
 *
 * The Pixel 2's splash.c does the same through DRM; the Brick's display is
 * Allwinner's framebuffer driver, so this draws into /dev/fb0 instead. Its
 * frames (scripts/make-splash-frames.py --brick) are at the panel's own
 * 1024x768, and only the band of rows that changed from the frame before is
 * stored, zlib-compressed, so a frame is unpacked into the last one and only
 * that band copied to the screen. On the Brick that is TortOS's flyby (its
 * tools/genboot.py): the wordmark from the first frame, and the turtle
 * shooting across above it with his speed bars, cut wherever TortOS is ready.
 *
 * It draws into the framebuffer's last page and shows it with a pan. TortOS,
 * drawing through the GPU, takes the screen in two steps: when it sets up EGL
 * the pan moves to the first of EGL's own pages, still empty, and about 0.6 s
 * later its first present moves it again. The first move, before TortOS has
 * said it is presenting, is undone: the pan goes straight back to this page
 * and the animation goes on. EGL's pages are never written to: followed into
 * one instead, the turtle stayed under TortOS's first frames as they faded in,
 * as TortOS draws them over what its buffer held (tried 2026-10-13). A move
 * after that is TortOS's first frame, and this stops at once. TortOS says so
 * with a SIGUSR1 just before its first present, as on the Pixel 2; it used to
 * be its renderer's line in /tmp/tortos.log, and the log is on the card now.
 *
 * EGL's setup clears the framebuffer's pages, this one too, so after each
 * frame the page is spot-checked against the frame and written again whole if
 * anything is gone (copying only each frame's band, the wordmark was wiped
 * and never came back). When the animation is over it holds the last frame
 * the same way, putting back EGL's pan if that comes later, until TortOS
 * draws, or 15 s.
 *
 * Started first thing, by inittab's first line; the framebuffer is there long
 * before the panel lights, so the first frame is waiting when it does.
 */
#include <fcntl.h>
#include <linux/fb.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <time.h>
#include <unistd.h>
#include <zlib.h>

#define FRAMES     "/usr/share/splash/frames.bin"
#define BACKGROUND 0xff111310   /* the Brick's boot screen, if there are no frames */

/* Seconds since the kernel started, as the kernel log counts them */
static double since_boot(void)
{
	struct timespec now;

	clock_gettime(CLOCK_BOOTTIME, &now);
	return now.tv_sec + now.tv_nsec / 1e9;
}

static void log_to_kernel(const char *text)
{
	int fd = open("/dev/kmsg", O_WRONLY | O_CLOEXEC);

	if (fd >= 0) {
		if (write(fd, text, strlen(text)) < 0) { /* a missing line is not fatal */ }
		close(fd);
	}
}

/* The frames file, mapped: header, offset table, then each frame's band */
static const uint8_t *frames;
static size_t frames_size;
static unsigned frame_count, fps, frame_w, frame_h;

static int frames_open(void)
{
	struct stat st;
	int fd = open(FRAMES, O_RDONLY | O_CLOEXEC);

	if (fd < 0 || fstat(fd, &st) < 0 || st.st_size < 12) return -1;
	frames = mmap(NULL, st.st_size, PROT_READ, MAP_PRIVATE, fd, 0);
	close(fd);
	if (frames == MAP_FAILED || memcmp(frames, "TSPZ", 4)) return -1;
	frames_size = st.st_size;
	frame_w = frames[4] | frames[5] << 8;
	frame_h = frames[6] | frames[7] << 8;
	frame_count = frames[8] | frames[9] << 8;
	fps = frames[10] | frames[11] << 8;
	return frame_count && fps ? 0 : -1;
}

static uint32_t get32(const uint8_t *p)
{
	return p[0] | p[1] << 8 | p[2] << 16 | (uint32_t)p[3] << 24;
}

/*
 * Frame n over frame n - 1 in pixels (frame_w * 4 bytes a row): its band
 * unpacked, then each byte given back the same byte of the pixel to its left
 * (the encoder took it away, as PNG's Sub filter does). The band's rows are
 * returned in *first and *rows, the only ones to copy to the screen; 0 rows
 * is a frame like the last, and -1 a frame that wouldn't unpack.
 */
static int frame_decode(unsigned n, uint8_t *pixels, unsigned *first, unsigned *rows)
{
	size_t stride = (size_t)frame_w * 4;
	uint32_t at = get32(frames + 12 + 4 * n);

	if (at + 8 > frames_size) return -1;
	*first = frames[at] | frames[at + 1] << 8;
	*rows = frames[at + 2] | frames[at + 3] << 8;
	uint32_t length = get32(frames + at + 4);
	if (!*rows) return 0;
	if (*first + *rows > frame_h || at + 8 + length > frames_size) return -1;

	uint8_t *band = pixels + *first * stride;
	uLongf size = *rows * stride;
	if (uncompress(band, &size, frames + at + 8, length) != Z_OK || size != *rows * stride)
		return -1;
	for (unsigned y = 0; y < *rows; y++) {
		uint8_t *row = band + y * stride;

		for (size_t i = 4; i < stride; i++)
			row[i] += row[i - 4];
	}
	return 0;
}

/* The page still shows the frame: 64 pixels spread over it compared */
static int page_intact(const uint32_t *page, const uint32_t *pixels, size_t words)
{
	for (size_t i = 0; i < 64; i++) {
		size_t at = i * (words / 64) + (i * 7919) % (words / 64);

		if (page[at] != pixels[at]) return 0;
	}
	return 1;
}

/* Where the screen is panned to now */
static uint32_t pan_now(int fd)
{
	struct fb_var_screeninfo var;

	return ioctl(fd, FBIOGET_VSCREENINFO, &var) == 0 ? var.yoffset : (uint32_t)-1;
}

/* TortOS is about to present (its SIGUSR1): from here a pan is its first frame */
static volatile sig_atomic_t tortos_presenting;

static void on_tortos(int sig)
{
	(void)sig;
	tortos_presenting = 1;
}

/*
 * Still this one's screen: 1 to draw on, 0 when TortOS has presented. EGL's
 * first pan, when TortOS sets it up, is put back.
 */
static int still_ours(int fd, uint32_t yoffset, int *took_back)
{
	struct fb_var_screeninfo var;
	uint32_t now = pan_now(fd);

	if (now == yoffset) return 1;
	if (now == (uint32_t)-1 || *took_back || tortos_presenting) return 0;
	*took_back = 1;
	if (ioctl(fd, FBIOGET_VSCREENINFO, &var)) return 0;
	var.xoffset = 0;
	var.yoffset = yoffset;
	return ioctl(fd, FBIOPAN_DISPLAY, &var) == 0;
}

int main(void)
{
	/* First: SIGUSR1 left at its default would end this */
	struct sigaction on = { .sa_handler = on_tortos };
	sigemptyset(&on.sa_mask);
	sigaction(SIGUSR1, &on, NULL);

	int fd = open("/dev/fb0", O_RDWR | O_CLOEXEC);
	struct fb_var_screeninfo var;
	struct fb_fix_screeninfo fix;

	if (fd < 0 || ioctl(fd, FBIOGET_VSCREENINFO, &var) || ioctl(fd, FBIOGET_FSCREENINFO, &fix) ||
	    var.bits_per_pixel != 32) {
		perror("splash: /dev/fb0");
		return 1;
	}
	uint32_t pages = var.yres_virtual / var.yres;
	if (pages < 2) {
		fprintf(stderr, "splash: the framebuffer has no spare page\n");
		return 1;
	}
	uint8_t *fbmem = mmap(NULL, fix.smem_len, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
	if (fbmem == MAP_FAILED) {
		perror("splash: mapping the framebuffer");
		return 1;
	}
	/* The last page, which TortOS's first presents don't use */
	uint32_t yoffset = (pages - 1) * var.yres;
	uint8_t *page = fbmem + (size_t)yoffset * fix.line_length;
	size_t size = (size_t)var.yres * fix.line_length;
	uint32_t *pixels = malloc(size);
	if (!pixels) {
		perror("splash: memory");
		return 1;
	}

	unsigned first_row, rows;
	int animated = frames_open() == 0 && frame_w == var.xres && frame_h == var.yres &&
		       fix.line_length == frame_w * 4 &&
		       frame_decode(0, (uint8_t *)pixels, &first_row, &rows) == 0;
	if (!animated) {
		for (size_t i = 0; i < size / 4; i++) pixels[i] = BACKGROUND;
		frame_count = 1;
	}
	memcpy(page, pixels, size);
	var.xoffset = 0;
	var.yoffset = yoffset;
	if (ioctl(fd, FBIOPAN_DISPLAY, &var)) {
		perror("splash: pan");
		return 1;
	}
	double first = since_boot();
	char line[256];
	snprintf(line, sizeof(line), "splash: first frame at %.3f s\n", first);
	log_to_kernel(line);

	/*
	 * The rest at the video's rate, each on its own deadline from the first.
	 * While waiting, the pan is looked at every 4 ms, so TortOS taking the
	 * screen is seen well before its presents come round to this page.
	 * Each frame goes in just after a vertical blank, and the copy (about
	 * 3 ms) stays ahead of the scan down the panel (16 ms), so it doesn't
	 * tear.
	 */
	unsigned shown = 0, repaired = 0;
	int stopped = 0, took_back = 0;
	for (unsigned n = 1; n < frame_count && !stopped; n++) {
		double due = first + (double)n / fps;

		if (frame_decode(n, (uint8_t *)pixels, &first_row, &rows))
			break;
		for (;;) {
			if (!still_ours(fd, yoffset, &took_back)) {
				stopped = 1;
				break;
			}
			double wait = due - since_boot();
			if (wait <= 0) break;
			struct timespec t = { 0, (long)((wait < 0.004 ? wait : 0.004) * 1e9) };
			nanosleep(&t, NULL);
		}
		if (stopped) break;
		uint32_t zero = 0;
		ioctl(fd, FBIO_WAITFORVSYNC, &zero);
		if (!still_ours(fd, yoffset, &took_back)) {
			stopped = 1;
			break;
		}
		memcpy(page + (size_t)first_row * fix.line_length,
		       (uint8_t *)pixels + (size_t)first_row * fix.line_length,
		       (size_t)rows * fix.line_length);
		if (!page_intact((uint32_t *)page, pixels, size / 4)) {
			memcpy(page, pixels, size);
			repaired++;
		}
		shown = n;
	}

	/* The last frame held until TortOS draws */
	double give_up = since_boot() + 15;
	while (!stopped && since_boot() < give_up) {
		struct timespec t = { 0, 8000000 };

		if (!still_ours(fd, yoffset, &took_back)) {
			stopped = 1;
			break;
		}
		if (!page_intact((uint32_t *)page, pixels, size / 4)) {
			memcpy(page, pixels, size);
			repaired++;
		}
		nanosleep(&t, NULL);
	}
	snprintf(line, sizeof(line), "splash: %s at frame %u of %u, %.3f s%s, page rewritten %u times\n",
		 stopped ? "TortOS took over" : "gave up waiting for TortOS", shown, frame_count, since_boot(),
		 took_back ? " (after putting EGL's first pan back)" : "", repaired);
	log_to_kernel(line);
	/* The picture stays in the framebuffer's memory without this process */
	return 0;
}
