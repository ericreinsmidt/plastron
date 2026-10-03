/* SPDX-License-Identifier: MIT */
/*
 * powerkey: a press of the power button shuts the device down cleanly.
 *
 * Watches whichever input device reports KEY_POWER (on the Pixel 2, the
 * RK817's "rk805 pwrkey") and runs poweroff when the button is let go
 * after a press. Holding it about 10 s is still the power chip's own hard
 * cut-off, for when nothing answers. TortOS will take this over, since a
 * press should save the game first.
 */
#include <fcntl.h>
#include <linux/input.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

#define BIT_IS_SET(array, bit) ((array)[(bit) / 8] & (1 << ((bit) % 8)))

static int open_power_key(void)
{
	for (int i = 0; i < 32; i++) {
		char path[32];
		unsigned char keys[KEY_MAX / 8 + 1] = { 0 };

		snprintf(path, sizeof(path), "/dev/input/event%d", i);
		int fd = open(path, O_RDONLY | O_CLOEXEC);
		if (fd < 0)
			continue;
		if (ioctl(fd, EVIOCGBIT(EV_KEY, sizeof(keys)), keys) >= 0 &&
		    BIT_IS_SET(keys, KEY_POWER))
			return fd;
		close(fd);
	}
	return -1;
}

static void log_to_kernel(const char *text)
{
	int fd = open("/dev/kmsg", O_WRONLY | O_CLOEXEC);

	if (fd >= 0) {
		write(fd, text, strlen(text));
		close(fd);
	}
}

int main(void)
{
	int fd = open_power_key();

	if (fd < 0) {
		log_to_kernel("powerkey: no input device has a power key\n");
		/* init respawns us; don't spin */
		sleep(10);
		return 1;
	}

	int pressed = 0;
	struct input_event event;
	while (read(fd, &event, sizeof(event)) == sizeof(event)) {
		if (event.type != EV_KEY || event.code != KEY_POWER)
			continue;
		if (event.value == 1) {
			pressed = 1;
		} else if (event.value == 0 && pressed) {
			log_to_kernel("powerkey: power button pressed, shutting down\n");
			execl("/sbin/poweroff", "poweroff", (char *)NULL);
			return 1;
		}
	}
	return 1;
}
