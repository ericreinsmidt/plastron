/* SPDX-License-Identifier: MIT */
/*
 * usbrole: the USB port is a host while something that wants power is
 * plugged into it, and a device otherwise.
 *
 * The Pixel 2's one USB-C port is both: a device to a computer (charging, and
 * the networking development runs over) and a host to a USB-C DAC. The USB
 * PHY tells them apart by the ID pin and reports it as its extcon's USB-HOST
 * cable, but nothing in the kernel acts on it: the dwc2 controller takes its
 * role from the role switch. This sets the role from the pin, once at startup
 * and then on every change, as ROCKNIX does on this device. It sleeps on the
 * kernel's uevents in between.
 *
 * It asks for host only while USB-HOST reads 1, so the port never supplies
 * power while a computer or a charger is powering it, which ROCKNIX warns can
 * damage the board.
 *
 * And when a DAC's sound card appears, it turns the DAC's own playback volume
 * to full: the volume the player moves is a software one in front of it
 * (asound.conf's pcm.usb), the same for every DAC.
 */
#include <dirent.h>
#include <fcntl.h>
#include <linux/netlink.h>
#include <sound/asound.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/socket.h>
#include <unistd.h>

/* Room for a directory name of the most a name can be, 255 */
static char host_state[320];   /* the USB-HOST cable's state file */
static char role_file[320];    /* the role switch */

static void log_to_kernel(const char *text)
{
	int fd = open("/dev/kmsg", O_WRONLY | O_CLOEXEC);

	if (fd >= 0) {
		if (write(fd, text, strlen(text)) < 0) { /* nowhere to say so */ }
		close(fd);
	}
}

static int read_line(const char *path, char *out, size_t n)
{
	int fd = open(path, O_RDONLY | O_CLOEXEC);
	ssize_t got;

	if (fd < 0)
		return -1;
	got = read(fd, out, n - 1);
	close(fd);
	if (got < 0)
		return -1;
	out[got] = '\0';
	out[strcspn(out, "\n")] = '\0';
	return 0;
}

/* The USB-HOST cable, among every extcon's cables, and the role switch */
static int find_files(void)
{
	DIR *d;
	struct dirent *e;

	if ((d = opendir("/sys/class/extcon"))) {
		while ((e = readdir(d)) && !host_state[0]) {
			for (int i = 0; i < 16; i++) {
				char path[320], name[32];

				snprintf(path, sizeof path, "/sys/class/extcon/%s/cable.%d/name",
				         e->d_name, i);
				if (read_line(path, name, sizeof name) < 0)
					break;
				if (strcmp(name, "USB-HOST"))
					continue;
				snprintf(host_state, sizeof host_state,
				         "/sys/class/extcon/%s/cable.%d/state", e->d_name, i);
				break;
			}
		}
		closedir(d);
	}
	if ((d = opendir("/sys/class/usb_role"))) {
		while ((e = readdir(d)) && !role_file[0]) {
			if (e->d_name[0] == '.')
				continue;
			snprintf(role_file, sizeof role_file, "/sys/class/usb_role/%s/role",
			         e->d_name);
		}
		closedir(d);
	}
	return host_state[0] && role_file[0] ? 0 : -1;
}

static void follow_pin(void)
{
	char state[8], role[16];
	const char *want;
	int fd;

	if (read_line(host_state, state, sizeof state) < 0 ||
	    read_line(role_file, role, sizeof role) < 0)
		return;
	want = strcmp(state, "1") ? "device" : "host";
	if (!strcmp(role, want))
		return;
	fd = open(role_file, O_WRONLY | O_CLOEXEC);
	if (fd < 0)
		return;
	if (write(fd, want, strlen(want)) > 0)
		log_to_kernel(strcmp(want, "host") ?
		              "usbrole: device, nothing plugged in wants power\n" :
		              "usbrole: host, something plugged in wants power\n");
	close(fd);
}

/* The output's controls, "... Playback Volume" and "... Playback Switch", at
 * full and on. Not a headset's microphone monitor or sidetone, which are
 * playback controls too: full there is the room in your ears, or feedback. */
static void dac_full(int card)
{
	struct snd_ctl_elem_id ids[64];
	struct snd_ctl_elem_list list = { .space = 64, .pids = ids };
	char path[32];
	int fd, set = 0;

	snprintf(path, sizeof path, "/dev/snd/controlC%d", card);
	if ((fd = open(path, O_RDWR | O_CLOEXEC)) < 0)
		return;
	if (ioctl(fd, SNDRV_CTL_IOCTL_ELEM_LIST, &list) < 0)
		list.used = 0;
	for (unsigned int i = 0; i < list.used; i++) {
		struct snd_ctl_elem_info info = { .id = ids[i] };
		struct snd_ctl_elem_value v = { .id = ids[i] };
		const char *name = (const char *)ids[i].name;
		int volume = strstr(name, "Playback Volume") != NULL;
		int on = strstr(name, "Playback Switch") != NULL;

		if ((!volume && !on) || strstr(name, "Mic") || strstr(name, "Sidetone") ||
		    strstr(name, "Monitor"))
			continue;
		if (ioctl(fd, SNDRV_CTL_IOCTL_ELEM_INFO, &info) < 0 ||
		    !(info.access & SNDRV_CTL_ELEM_ACCESS_WRITE) ||
		    info.type != (volume ? SNDRV_CTL_ELEM_TYPE_INTEGER
		                         : SNDRV_CTL_ELEM_TYPE_BOOLEAN))
			continue;
		for (unsigned int c = 0; c < info.count && c < 128; c++)
			v.value.integer.value[c] = volume ? info.value.integer.max : 1;
		if (ioctl(fd, SNDRV_CTL_IOCTL_ELEM_WRITE, &v) >= 0)
			set++;
	}
	close(fd);
	if (set) {
		char text[64];

		snprintf(text, sizeof text, "usbrole: card %d's playback at full\n", card);
		log_to_kernel(text);
	}
}

int main(void)
{
	struct sockaddr_nl addr = { .nl_family = AF_NETLINK, .nl_groups = 1 };
	char msg[4096];
	int sock;

	if (find_files() < 0) {
		log_to_kernel("usbrole: no USB-HOST cable or no role switch\n");
		/* init respawns us; don't spin */
		sleep(10);
		return 1;
	}
	sock = socket(AF_NETLINK, SOCK_DGRAM | SOCK_CLOEXEC, NETLINK_KOBJECT_UEVENT);
	if (sock < 0 || bind(sock, (struct sockaddr *)&addr, sizeof addr) < 0) {
		log_to_kernel("usbrole: can't listen for the kernel's events\n");
		sleep(10);
		return 1;
	}

	follow_pin();
	/* A DAC already in, if init restarted us. Card 0 is the RK817. */
	for (int card = 1; card < 8; card++)
		dac_full(card);
	/* The PHY's extcon announces each change of its cables as a uevent:
	 * "change@/devices/.../extcon/extcon0". A sound card's controls arrive
	 * as "add@/devices/.../sound/card1/controlC1", the node already made. */
	for (;;) {
		ssize_t got = recv(sock, msg, sizeof msg - 1, 0);
		const char *last;

		if (got <= 0)
			continue;
		msg[got] = '\0';
		last = strrchr(msg, '/');
		if (strstr(msg, "/extcon/"))
			follow_pin();
		else if (!strncmp(msg, "add@", 4) && last && !strncmp(last, "/controlC", 9) &&
		         atoi(last + 9) > 0)
			dac_full(atoi(last + 9));
	}
}
