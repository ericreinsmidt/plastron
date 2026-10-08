/* SPDX-License-Identifier: MIT */
/*
 * gauge: the four lights on the side show the battery.
 *
 * Bottom to top they are battery0 and battery1, the bottom light's red and
 * green, then battery2 to battery4, three green ones (the device tree says
 * which pin is which). What they show:
 *
 *   - Plugged in: a bar filling from the bottom, over the lights held for
 *     each full quarter of charge: 25% holds the bottom one, 50 two, 75
 *     three, and a full battery holds all four, still.
 *   - On the battery, under 10%: the bottom light flashes red, once every
 *     five seconds.
 *   - Otherwise nothing, so they cost nothing.
 *   - Asked (SIGUSR1, which TortOS sends on L2+R2 outside a game): the level
 *     flashes twice in a second, over whatever else is showing. 75 to 100%
 *     is all four, 50 to 74 the bottom three, 25 to 49 two, 10 to 24 one,
 *     and under 10 the bottom light red.
 *
 * It sleeps on the kernel's uevents (a charger plugged in or out, the battery
 * reporting) and wakes on a timer only while something moves: every step of
 * the bar while charging, each flash, and every half minute otherwise to look
 * at the level. Started by init, with respawn.
 *
 * For trying each state without waiting on the battery, /tmp/gauge-test
 * holding "PERCENT PLUGGED" ("60 1", "5 0") stands in for the battery while
 * it is there; /tmp is empty again at every boot. SIGHUP looks at once.
 */
#include <fcntl.h>
#include <linux/netlink.h>
#include <poll.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/signalfd.h>
#include <sys/socket.h>
#include <time.h>
#include <unistd.h>

#define BATTERY "/sys/class/power_supply/battery/capacity"
#define CHARGER "/sys/class/power_supply/rk817-charger/online"
#define TEST    "/tmp/gauge-test"

/* The lights as bits, bit 0 being battery0 */
#define RED     (1 << 0)
#define GREEN1  (1 << 1)

#define STEP_MS      400    /* the charging bar's pace */
#define LOW_EVERY_MS 5000   /* the low-battery flash, once this often */
#define LOW_ON_MS    200
#define ASK_MS       1000   /* asked: two flashes in this long */
#define IDLE_MS      30000  /* nothing showing: look at the level this often */
#define LOW          10

static int led_fd[5] = { -1, -1, -1, -1, -1 };
static int shown = -1;   /* what the lights show now, as bits */

static long now_ms(void)
{
	struct timespec t;

	clock_gettime(CLOCK_MONOTONIC, &t);
	return t.tv_sec * 1000L + t.tv_nsec / 1000000;
}

static void log_to_kernel(const char *text)
{
	int fd = open("/dev/kmsg", O_WRONLY | O_CLOEXEC);

	if (fd >= 0) {
		if (write(fd, text, strlen(text)) < 0) { /* nowhere to say so */ }
		close(fd);
	}
}

static int read_int(const char *path, int fallback)
{
	char buf[16];
	int fd = open(path, O_RDONLY | O_CLOEXEC);
	ssize_t got;

	if (fd < 0)
		return fallback;
	got = read(fd, buf, sizeof buf - 1);
	close(fd);
	if (got <= 0)
		return fallback;
	buf[got] = '\0';
	return atoi(buf);
}

/* The battery as the test file has it, if there is one */
static int read_test(int *pct, int *plugged)
{
	char buf[32];
	int fd = open(TEST, O_RDONLY | O_CLOEXEC);
	ssize_t got;

	if (fd < 0)
		return 0;
	got = read(fd, buf, sizeof buf - 1);
	close(fd);
	if (got <= 0)
		return 0;
	buf[got] = '\0';
	return sscanf(buf, "%d %d", pct, plugged) == 2;
}

/* Written only when it changes: a write is a GPIO toggle, and most wakes
 * change nothing */
static void show(int bits)
{
	if (bits == shown)
		return;
	for (int i = 0; i < 5; i++)
		if (led_fd[i] >= 0) {
			const char *v = bits & (1 << i) ? "1" : "0";

			if (pwrite(led_fd[i], v, 1, 0) < 0) { /* the light stays as it was */ }
		}
	shown = bits;
}

/* n green lights from the bottom, n from 0 to 4 */
static int greens(int n)
{
	int bits = 0;

	for (int i = 0; i < n && i < 4; i++)
		bits |= GREEN1 << i;
	return bits;
}

/* The level as lights, for when it is asked for */
static int level_bits(int pct)
{
	if (pct >= 75) return greens(4);
	if (pct >= 50) return greens(3);
	if (pct >= 25) return greens(2);
	if (pct >= LOW) return greens(1);
	return RED;
}

int main(void)
{
	struct sockaddr_nl nl = { .nl_family = AF_NETLINK, .nl_groups = 1 };
	struct pollfd pf[2];
	sigset_t sigs;
	long asked_at = -1;      /* when the level was last asked for */
	long bar_start = 0;      /* when the charging bar began its cycle */
	int was_plugged = -1;

	for (int i = 0; i < 5; i++) {
		char path[64];

		snprintf(path, sizeof path, "/sys/class/leds/battery%d/brightness", i);
		led_fd[i] = open(path, O_WRONLY | O_CLOEXEC);
	}
	if (led_fd[0] < 0 && led_fd[4] < 0) {
		/* No lights to drive: wait here rather than let init respawn us
		 * over and over */
		log_to_kernel("gauge: no battery lights in this device tree\n");
		for (;;)
			pause();
	}

	sigemptyset(&sigs);
	sigaddset(&sigs, SIGUSR1);
	sigaddset(&sigs, SIGTERM);
	sigaddset(&sigs, SIGHUP);
	sigprocmask(SIG_BLOCK, &sigs, NULL);
	pf[0].fd = signalfd(-1, &sigs, SFD_CLOEXEC | SFD_NONBLOCK);
	pf[0].events = POLLIN;
	pf[1].fd = socket(AF_NETLINK, SOCK_DGRAM | SOCK_CLOEXEC | SOCK_NONBLOCK,
	                  NETLINK_KOBJECT_UEVENT);
	if (pf[1].fd >= 0 && bind(pf[1].fd, (struct sockaddr *)&nl, sizeof nl) < 0) {
		close(pf[1].fd);
		pf[1].fd = -1;
	}
	pf[1].events = POLLIN;
	log_to_kernel("gauge: showing the battery on the side lights\n");

	for (;;) {
		long now = now_ms();
		int pct = read_int(BATTERY, 100);
		int plugged = read_int(CHARGER, 0) == 1;
		int bits = 0, wait = IDLE_MS;

		read_test(&pct, &plugged);
		plugged = plugged != 0;

		if (plugged != was_plugged) {
			bar_start = now;
			was_plugged = plugged;
		}

		if (plugged) {
			int held = pct >= 100 ? 4 : pct / 25;

			if (held >= 4) {
				bits = greens(4);
			} else {
				/* held, then one more each step up to all four, and again */
				int steps = 4 - held + 1;
				long t = now - bar_start;

				bits = greens(held + (int)(t / STEP_MS % steps));
				wait = STEP_MS - (int)(t % STEP_MS);
			}
		} else if (pct < LOW) {
			long t = now % LOW_EVERY_MS;

			if (t < LOW_ON_MS) {
				bits = RED;
				wait = LOW_ON_MS - (int)t;
			} else {
				wait = LOW_EVERY_MS - (int)t;
			}
		}

		/* Asked: two flashes over the rest, on and off a quarter second each */
		if (asked_at >= 0) {
			long t = now - asked_at;

			if (t < ASK_MS) {
				bits = (t / 250) % 2 ? 0 : level_bits(pct);
				if (250 - (int)(t % 250) < wait)
					wait = 250 - (int)(t % 250);
			} else {
				asked_at = -1;
			}
		}

		show(bits);

		if (poll(pf, 2, wait) <= 0)
			continue;
		if (pf[0].revents & POLLIN) {
			struct signalfd_siginfo si;

			while (read(pf[0].fd, &si, sizeof si) == (ssize_t)sizeof si) {
				if (si.ssi_signo == SIGTERM) {
					show(0);
					return 0;
				}
				if (si.ssi_signo == SIGUSR1)
					asked_at = now_ms();
			}
		}
		if (pf[1].revents & POLLIN) {
			char buf[2048];

			/* Any uevent is a reason to look again; reading them is cheaper
			 * than sorting them */
			while (recv(pf[1].fd, buf, sizeof buf, 0) > 0) { }
		}
	}
}
