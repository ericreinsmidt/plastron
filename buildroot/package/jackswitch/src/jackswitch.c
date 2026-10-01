/*
 * jackswitch: sound follows the headphone jack.
 *
 * The kernel sees headphones go in and out (the RK817's "Headphones" input
 * device reports SW_HEADPHONE_INSERT), but nothing in it moves the sound:
 * the codec's "Playback Mux" stays on whatever it was set to. This sets it
 * to HP while headphones are in and SPK otherwise, once at startup and then
 * on every change. It sleeps in read() in between.
 */
#include <alsa/asoundlib.h>
#include <fcntl.h>
#include <linux/input.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

#define BIT_IS_SET(array, bit) ((array)[(bit) / 8] & (1 << ((bit) % 8)))

static int open_headphone_jack(void)
{
	for (int i = 0; i < 32; i++) {
		char path[32];
		unsigned char switches[SW_MAX / 8 + 1] = { 0 };

		snprintf(path, sizeof(path), "/dev/input/event%d", i);
		int fd = open(path, O_RDONLY | O_CLOEXEC);
		if (fd < 0)
			continue;
		if (ioctl(fd, EVIOCGBIT(EV_SW, sizeof(switches)), switches) >= 0 &&
		    BIT_IS_SET(switches, SW_HEADPHONE_INSERT))
			return fd;
		close(fd);
	}
	return -1;
}

static int headphones_in(int fd)
{
	unsigned char switches[SW_MAX / 8 + 1] = { 0 };

	if (ioctl(fd, EVIOCGSW(sizeof(switches)), switches) < 0)
		return 0;
	return BIT_IS_SET(switches, SW_HEADPHONE_INSERT) != 0;
}

static void log_to_kernel(const char *text)
{
	int fd = open("/dev/kmsg", O_WRONLY | O_CLOEXEC);

	if (fd >= 0) {
		write(fd, text, strlen(text));
		close(fd);
	}
}

/* Picks the mux item by name, so it doesn't depend on the order */
static int set_output(snd_ctl_t *ctl, const char *output)
{
	snd_ctl_elem_id_t *id;
	snd_ctl_elem_info_t *info;
	snd_ctl_elem_value_t *value;

	snd_ctl_elem_id_alloca(&id);
	snd_ctl_elem_info_alloca(&info);
	snd_ctl_elem_value_alloca(&value);

	snd_ctl_elem_id_set_interface(id, SND_CTL_ELEM_IFACE_MIXER);
	snd_ctl_elem_id_set_name(id, "Playback Mux");
	snd_ctl_elem_info_set_id(info, id);
	if (snd_ctl_elem_info(ctl, info) < 0)
		return -1;

	unsigned int items = snd_ctl_elem_info_get_items(info);
	for (unsigned int item = 0; item < items; item++) {
		snd_ctl_elem_info_set_item(info, item);
		if (snd_ctl_elem_info(ctl, info) < 0)
			return -1;
		if (strcmp(snd_ctl_elem_info_get_item_name(info), output))
			continue;
		snd_ctl_elem_value_set_id(value, id);
		snd_ctl_elem_value_set_enumerated(value, 0, item);
		return snd_ctl_elem_write(ctl, value) < 0 ? -1 : 0;
	}
	return -1;
}

int main(void)
{
	int fd = open_headphone_jack();
	snd_ctl_t *ctl = NULL;

	if (fd < 0 || snd_ctl_open(&ctl, "hw:0", 0) < 0) {
		log_to_kernel("jackswitch: no headphone jack or no sound card\n");
		/* init respawns us; don't spin */
		sleep(10);
		return 1;
	}

	if (set_output(ctl, headphones_in(fd) ? "HP" : "SPK") < 0) {
		log_to_kernel("jackswitch: can't set Playback Mux\n");
		sleep(10);
		return 1;
	}

	struct input_event event;
	while (read(fd, &event, sizeof(event)) == sizeof(event)) {
		if (event.type == EV_SW && event.code == SW_HEADPHONE_INSERT)
			set_output(ctl, event.value ? "HP" : "SPK");
	}
	return 1;
}
