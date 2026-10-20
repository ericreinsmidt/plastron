/* The Brick panel probe: which panel is in this Brick?
 *
 * A card that boots plastron's kernel with this as its whole initramfs
 * (/rdinit). The kernel's panel driver reads the panel's ID at boot and logs
 * it ("brick panel: ..."); this takes those lines from the kernel log, saves
 * them to panel.txt on the card's boot partition, where any computer can read
 * them, and shows them on the screen. Saved first, as a panel the driver
 * doesn't know may not show anything. The power button turns the Brick off.
 *
 * Nothing else runs: no root, no TortOS, no GPU libraries. The device tree
 * has no node for the eMMC, so the Brick's own storage is never seen.
 * Built static by scripts/build-brick-probe.sh, with the kernel's 8x16 font.
 */
#include <dirent.h>
#include <fcntl.h>
#include <linux/fb.h>
#include <linux/input.h>
#include <poll.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/klog.h>
#include <sys/mman.h>
#include <sys/mount.h>
#include <sys/reboot.h>
#include <sys/stat.h>
#include <unistd.h>

#include "font_8x16.h"

#define PROBE_VERSION "1"
#define BOOT_PARTNAME "boot"
#define DISP_LCD_BACKLIGHT_ENABLE 0x104
#define AUTO_OFF_MS (5 * 60 * 1000)
#define BIT_IS_SET(array, bit) ((array)[(bit) / (8 * sizeof(long))] & (1UL << ((bit) % (8 * sizeof(long)))))

static char found_lines[2048];	/* the driver's "brick panel:" lines */
static char panel_name[64] = "not found";

static void say(const char *message)
{
	int fd = open("/dev/kmsg", O_WRONLY);

	if (fd >= 0) {
		dprintf(fd, "probe: %s\n", message);
		close(fd);
	}
}

/* The driver's lines from the kernel log, and the panel it settled on */
static void read_panel_lines(void)
{
	static char log[1 << 17];
	int length = klogctl(3, log, sizeof log - 1);	/* SYSLOG_ACTION_READ_ALL */
	char *line, *save = NULL;

	if (length <= 0)
		return;
	log[length] = 0;
	for (line = strtok_r(log, "\n", &save); line; line = strtok_r(NULL, "\n", &save)) {
		char *text = strstr(line, "brick panel: ");

		if (!text)
			continue;
		text += strlen("brick panel: ");
		if (strlen(found_lines) + strlen(text) + 2 < sizeof found_lines) {
			strcat(found_lines, text);
			strcat(found_lines, "\n");
		}
		/* The ID reads start with "0x"; the last other line is the verdict */
		if (strncmp(text, "0x", 2) != 0)
			snprintf(panel_name, sizeof panel_name, "%s", text);
	}
}

/* The card's partition with this GPT name, from its uevent */
static int find_partition(const char *name, char *device, size_t size)
{
	DIR *dir = opendir("/sys/class/block");
	struct dirent *entry;
	char want[80];
	int found = 0;

	if (!dir)
		return 0;
	snprintf(want, sizeof want, "PARTNAME=%s\n", name);
	while (!found && (entry = readdir(dir))) {
		char path[300], line[128];
		FILE *uevent;

		snprintf(path, sizeof path, "/sys/class/block/%s/uevent", entry->d_name);
		uevent = fopen(path, "r");
		if (!uevent)
			continue;
		while (fgets(line, sizeof line, uevent)) {
			if (strcmp(line, want) == 0) {
				snprintf(device, size, "/dev/%s", entry->d_name);
				found = 1;
				break;
			}
		}
		fclose(uevent);
	}
	closedir(dir);
	return found;
}

static int save_report(void)
{
	char device[300];
	FILE *report;
	int i;

	for (i = 0; i < 600 && !find_partition(BOOT_PARTNAME, device, sizeof device); i++)
		usleep(5000);
	if (i == 600)
		return 0;
	mkdir("/boot", 0755);
	if (mount(device, "/boot", "vfat", 0, NULL) != 0)
		return 0;
	report = fopen("/boot/panel.txt", "w");
	if (report) {
		fprintf(report, "TrimUI Brick panel probe %s\r\n\r\n", PROBE_VERSION);
		fprintf(report, "Panel: %s\r\n\r\n", panel_name);
		fprintf(report, "What the kernel's panel driver read:\r\n");
		for (char *p = found_lines; *p; p++) {
			if (*p == '\n')
				fputc('\r', report);
			fputc(*p, report);
		}
		fclose(report);
	}
	sync();
	umount("/boot");
	return report != NULL;
}

/* ---- the screen ---- */

static uint32_t *screen;
static struct fb_var_screeninfo var;
static unsigned pitch;	/* in pixels */

static void fill(unsigned x, unsigned y, unsigned w, unsigned h, uint32_t color)
{
	for (unsigned row = y; row < y + h && row < var.yres; row++)
		for (unsigned col = x; col < x + w && col < var.xres; col++)
			screen[row * pitch + col] = color;
}

/* Text at a scale of the 8x16 font; returns the height used */
static unsigned text(unsigned x, unsigned y, unsigned scale, uint32_t color, const char *s)
{
	for (unsigned cx = x; *s; s++, cx += 8 * scale) {
		const unsigned char *glyph = &fontdata_8x16[(unsigned char)*s * 16];

		for (unsigned gy = 0; gy < 16; gy++)
			for (unsigned gx = 0; gx < 8; gx++)
				if (glyph[gy] & (0x80 >> gx))
					fill(cx + gx * scale, y + gy * scale, scale, scale, color);
	}
	return 16 * scale;
}

static void draw(int saved)
{
	const uint32_t background = 0xff101820, white = 0xffffffff, grey = 0xffa0a8b0,
		       green = 0xff60e080, amber = 0xffffc040;
	char line[160], copy[sizeof found_lines], *id, *save = NULL;
	unsigned y = 40;
	struct fb_fix_screeninfo fix;
	int fd = open("/dev/fb0", O_RDWR);

	if (fd < 0 || ioctl(fd, FBIOGET_VSCREENINFO, &var) || ioctl(fd, FBIOGET_FSCREENINFO, &fix) ||
	    var.bits_per_pixel != 32)
		return;
	screen = mmap(NULL, fix.smem_len, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
	if (screen == MAP_FAILED)
		return;
	pitch = fix.line_length / 4;
	var.yoffset = 0;
	ioctl(fd, FBIOPAN_DISPLAY, &var);

	fill(0, 0, var.xres, var.yres, background);
	y += text(40, y, 3, grey, "TrimUI Brick panel probe") + 30;
	snprintf(line, sizeof line, "Panel: %s", panel_name);
	y += text(40, y, 4, green, line) + 40;
	y += text(40, y, 2, grey, "What the panel answered:") + 10;
	snprintf(copy, sizeof copy, "%s", found_lines);
	for (id = strtok_r(copy, "\n", &save); id; id = strtok_r(NULL, "\n", &save))
		if (strncmp(id, "0x", 2) == 0)
			y += text(60, y, 2, white, id) + 6;
	y += 34;
	y += text(40, y, 2, saved ? white : amber,
		  saved ? "Saved as panel.txt on the card." : "Could not save panel.txt.") + 10;
	y += text(40, y, 2, white, "Please send a photo of this screen,") + 6;
	y += text(40, y, 2, white, "or that file, to whoever gave you this card.") + 34;
	text(40, y, 2, grey, "Press the power button to turn the Brick off.");

	fd = open("/dev/disp", O_RDWR);
	if (fd >= 0) {
		unsigned long args[4] = { 0 };

		ioctl(fd, DISP_LCD_BACKLIGHT_ENABLE, args);
	}
}

/* ---- the power button ---- */

static int open_power_key(void)
{
	for (int i = 0; i < 16; i++) {
		unsigned long keys[KEY_MAX / (8 * sizeof(long)) + 1] = { 0 };
		char path[32];
		int fd;

		snprintf(path, sizeof path, "/dev/input/event%d", i);
		fd = open(path, O_RDONLY);
		if (fd < 0)
			continue;
		if (ioctl(fd, EVIOCGBIT(EV_KEY, sizeof keys), keys) >= 0 && BIT_IS_SET(keys, KEY_POWER))
			return fd;
		close(fd);
	}
	return -1;
}

static void wait_for_power_key(void)
{
	struct input_event event;
	struct pollfd p;
	int i, waited = 0;

	for (i = 0; i < 300 && (p.fd = open_power_key()) < 0; i++)
		usleep(10000);
	if (p.fd < 0) {
		usleep(AUTO_OFF_MS * 1000);
		return;
	}
	p.events = POLLIN;
	while (waited < AUTO_OFF_MS) {
		if (poll(&p, 1, 1000) <= 0) {
			waited += 1000;
			continue;
		}
		if (read(p.fd, &event, sizeof event) == sizeof event &&
		    event.type == EV_KEY && event.code == KEY_POWER && event.value == 0)
			return;
	}
}

int main(void)
{
	int fd, saved, i;

	mkdir("/dev", 0755);
	mkdir("/sys", 0755);
	mount("devtmpfs", "/dev", "devtmpfs", 0, NULL);
	mount("sysfs", "/sys", "sysfs", 0, NULL);
	fd = open("/dev/console", O_RDWR);
	if (fd >= 0) {
		dup2(fd, 0);
		dup2(fd, 1);
		dup2(fd, 2);
		if (fd > 2)
			close(fd);
	}

	/* The panel driver runs before the initramfs, but the screen's device
	 * can appear a moment later */
	for (i = 0; i < 300 && access("/dev/fb0", F_OK) != 0; i++)
		usleep(10000);
	read_panel_lines();
	saved = save_report();
	say(saved ? "panel.txt saved" : "panel.txt not saved");
	draw(saved);

	wait_for_power_key();
	say("powering off");
	sync();
	reboot(RB_POWER_OFF);
	return 0;
}
