/*
 * splash: TortOS's boot animation on the Pixel 2, from the moment the panel
 * lights until TortOS is ready.
 *
 * The frames are TortOS's own boot video (res/boot/tortos-boot.mp4: the
 * turtle walks across, dashes off, and leaves the logo), turned onto the
 * portrait panel and run-length encoded ahead of time by
 * scripts/make-splash-frames.py, so nothing is decoded here but the runs.
 *
 * It plays at the video's own rate and never holds anything up: TortOS starts
 * alongside it, and when TortOS has its first frame ready it sends SIGUSR1.
 * The splash stops on the frame it is showing, lets go of the display, and
 * keeps that frame up until TortOS's replaces it. If the animation finishes
 * first, the logo simply stays.
 *
 * Logs "splash: panel lit at ... s", which is how the boot's first picture is
 * timed (docs/boot-time.md), and where it stopped.
 */
#include <errno.h>
#include <fcntl.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <time.h>
#include <unistd.h>
#include <xf86drm.h>
#include <xf86drmMode.h>

#define FRAMES     "/usr/share/splash/frames.bin"
#define BACKGROUND 0xff111310   /* the Brick's boot screen, if there are no frames */

static volatile sig_atomic_t stop;

static void on_stop(int sig) { (void)sig; stop = 1; }

/* Seconds since the kernel started, as the kernel log counts them */
static double since_boot(void)
{
	struct timespec now;

	clock_gettime(CLOCK_BOOTTIME, &now);
	return now.tv_sec + now.tv_nsec / 1e9;
}

/* A line in the kernel log, where boot timing is read from */
static void log_to_kernel(const char *text)
{
	int fd = open("/dev/kmsg", O_WRONLY | O_CLOEXEC);

	if (fd >= 0) {
		if (write(fd, text, strlen(text)) < 0) { /* a missing line is not fatal */ }
		close(fd);
	}
}

/* The frames file, mapped: header, offset table, then the runs */
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
	if (frames == MAP_FAILED || memcmp(frames, "TSPL", 4)) return -1;
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

/* One frame's runs into ordinary memory, row by row against the dumb
 * buffer's pitch. Ordinary memory and one copy after, because the buffer the
 * display reads is uncached and writing it piecemeal is slow. */
static void frame_decode(unsigned n, uint32_t *out, uint32_t pitch_px)
{
	uint32_t start = get32(frames + 12 + 4 * n);
	uint32_t end = n + 1 < frame_count ? get32(frames + 12 + 4 * (n + 1)) : frames_size;
	uint32_t x = 0, y = 0;

	for (const uint8_t *p = frames + start; p + 8 <= frames + end && y < frame_h; p += 8) {
		uint32_t count = get32(p), color = get32(p + 4);

		while (count--) {
			out[y * pitch_px + x] = color;
			if (++x == frame_w) { x = 0; y++; }
		}
	}
}

struct buffer {
	uint32_t fb;
	uint32_t *map;
};

static int buffer_create(int fd, const drmModeModeInfo *mode, struct buffer *b,
			 uint32_t *pitch, uint64_t *size)
{
	struct drm_mode_create_dumb create = {
		.width = mode->hdisplay, .height = mode->vdisplay, .bpp = 32
	};

	if (drmIoctl(fd, DRM_IOCTL_MODE_CREATE_DUMB, &create)) return -1;
	if (drmModeAddFB(fd, mode->hdisplay, mode->vdisplay, 24, 32, create.pitch,
			 create.handle, &b->fb)) return -1;
	struct drm_mode_map_dumb map = { .handle = create.handle };
	if (drmIoctl(fd, DRM_IOCTL_MODE_MAP_DUMB, &map)) return -1;
	b->map = mmap(NULL, create.size, PROT_READ | PROT_WRITE, MAP_SHARED, fd, map.offset);
	if (b->map == MAP_FAILED) return -1;
	*pitch = create.pitch;
	*size = create.size;
	return 0;
}

static void flip_done(int fd, unsigned seq, unsigned sec, unsigned usec, void *data)
{
	(void)fd; (void)seq; (void)sec; (void)usec;
	*(int *)data = 1;
}

int main(void)
{
	struct sigaction sa = { .sa_handler = on_stop };

	/* No SA_RESTART: a wait in progress returns, and the loop sees the flag */
	sigaction(SIGUSR1, &sa, NULL);

	int fd = open("/dev/dri/card0", O_RDWR | O_CLOEXEC);
	if (fd < 0) {
		perror("splash: /dev/dri/card0");
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
		fprintf(stderr, "splash: no connected display\n");
		return 1;
	}
	drmModeModeInfo mode = conn->modes[0];
	uint32_t crtc = res->crtcs[0];

	struct buffer buf[2];
	uint32_t pitch;
	uint64_t size;
	if (buffer_create(fd, &mode, &buf[0], &pitch, &size) ||
	    buffer_create(fd, &mode, &buf[1], &pitch, &size)) {
		perror("splash: buffers");
		return 1;
	}
	uint32_t *pixels = malloc(size);
	if (!pixels) {
		perror("splash: memory");
		return 1;
	}

	/* The frames, or the plain boot color if they are missing or do not fit
	 * the panel: a picture either way. */
	int animated = frames_open() == 0 &&
		       frame_w == mode.hdisplay && frame_h == mode.vdisplay;
	if (animated) {
		frame_decode(0, pixels, pitch / 4);
	} else {
		for (uint64_t i = 0; i < size / 4; i++) pixels[i] = BACKGROUND;
		frame_count = 1;
	}
	memcpy(buf[0].map, pixels, size);

	double started = since_boot();
	if (drmModeSetCrtc(fd, crtc, buf[0].fb, 0, 0, &conn->connector_id, 1, &mode)) {
		perror("splash: set mode");
		return 1;
	}
	double lit = since_boot();
	char line[128];
	snprintf(line, sizeof(line), "splash: panel lit at %.3f s, the mode-set took %.0f ms\n",
		 lit, (lit - started) * 1000);
	log_to_kernel(line);

	/* The rest of the frames at the video's rate, each on its own deadline
	 * from the first, so a late frame does not push every later one back. */
	unsigned shown = 0;
	drmEventContext ev = { .version = 2, .page_flip_handler = flip_done };
	for (unsigned n = 1; n < frame_count && !stop; n++) {
		struct buffer *next = &buf[n & 1];
		double due = lit + (double)n / fps;

		frame_decode(n, pixels, pitch / 4);
		memcpy(next->map, pixels, size);
		while (!stop) {
			double wait = due - since_boot();
			if (wait <= 0) break;
			struct timespec t = { (time_t)wait, (long)((wait - (time_t)wait) * 1e9) };
			nanosleep(&t, NULL);
		}
		if (stop) break;
		int flipped = 0;
		if (drmModePageFlip(fd, crtc, next->fb, DRM_MODE_PAGE_FLIP_EVENT, &flipped))
			break;
		/* Until it is on glass: a flip still queued when TortOS takes the
		 * display would come back busy on its side. */
		while (!flipped) {
			if (drmHandleEvent(fd, &ev) && errno != EINTR) break;
		}
		shown = n;
	}

	/*
	 * Let go of the display but keep the picture: dropping DRM master leaves
	 * the mode and the frame on screen, so TortOS can take the display and
	 * replace the picture directly, with nothing in between. Exiting would
	 * free the framebuffers and blank the panel.
	 */
	drmDropMaster(fd);
	snprintf(line, sizeof(line), "splash: %s at frame %u of %u, %.3f s\n",
		 stop ? "stopped for TortOS" : "finished", shown, frame_count, since_boot());
	log_to_kernel(line);

	/* The picture lasts as long as the buffer, so stay */
	for (;;)
		pause();
}
