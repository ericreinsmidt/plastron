/* rootswitch: the TrimUI Brick's whole initramfs.
 *
 * The boot script (board/brick/boot.cmd) loads brick/boot/initramfs.cpio.gz
 * and runs /rdinit; this is that /rdinit. It finds the card's GPT partition
 * named plastron-root, mounts it (squashfs, read-only, or ext4) and hands
 * over to its /sbin/init, which runs plastron's Brick system from there. No
 * shell and no BusyBox: built static (package/brick-rootswitch), packed by
 * board/brick/post-image.sh.
 */
#include <dirent.h>
#include <fcntl.h>
#include <stdio.h>
#include <string.h>
#include <sys/mount.h>
#include <sys/stat.h>
#include <unistd.h>

#define ROOT_LABEL "plastron-root"

static void say(const char *message)
{
	int fd = open("/dev/kmsg", O_WRONLY);

	if (fd >= 0) {
		dprintf(fd, "rootswitch: %s\n", message);
		close(fd);
	}
}

/* The partition's device name, from its uevent's PARTNAME (GPT names) */
static int find_root(char *device, size_t size)
{
	DIR *dir = opendir("/sys/class/block");
	struct dirent *entry;
	int found = 0;

	if (!dir)
		return 0;
	while (!found && (entry = readdir(dir))) {
		char path[300], line[128];
		FILE *uevent;

		snprintf(path, sizeof path, "/sys/class/block/%s/uevent", entry->d_name);
		uevent = fopen(path, "r");
		if (!uevent)
			continue;
		while (fgets(line, sizeof line, uevent)) {
			if (strcmp(line, "PARTNAME=" ROOT_LABEL "\n") == 0) {
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

int main(void)
{
	char device[300];
	int i, fd;

	mkdir("/dev", 0755);
	mkdir("/sys", 0755);
	mkdir("/root", 0755);
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

	/* The card is probed alongside the rest of the boot: up to 3 s */
	for (i = 0; i < 600 && !find_root(device, sizeof device); i++)
		usleep(5000);
	if (i == 600) {
		say("no partition named " ROOT_LABEL);
		for (;;)
			pause();
	}
	umount("/sys");
	/* squashfs, read-only: half the bytes to read, the boot's files packed
	 * together at its front (board/brick/squashfs-sort.txt). ext4, writable,
	 * where the root is that instead */
	if (mount(device, "/root", "squashfs", MS_RDONLY, NULL) != 0 &&
	    mount(device, "/root", "ext4", MS_NOATIME, NULL) != 0) {
		say("can't mount the root partition");
		for (;;)
			pause();
	}

	/* /dev comes along; then the new root takes the place of this one */
	mount("/dev", "/root/dev", NULL, MS_MOVE, NULL);
	if (chdir("/root") != 0 || mount(".", "/", NULL, MS_MOVE, NULL) != 0 ||
	    chroot(".") != 0 || chdir("/") != 0) {
		say("can't switch to the root partition");
		for (;;)
			pause();
	}
	execl("/sbin/init", "init", (char *)NULL);
	say("no /sbin/init on the root partition");
	for (;;)
		pause();
}
