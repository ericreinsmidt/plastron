/* rootswitch: the TrimUI Brick's whole initramfs.
 *
 * The boot script (board/brick/boot.cmd) loads brick/boot/initramfs.cpio.gz
 * and runs /rdinit; this is that /rdinit. It finds the card's GPT partition
 * named plastron-root, mounts it (squashfs, read-only, or ext4) and hands
 * over to its /sbin/init, which runs plastron's Brick system from there. No
 * shell and no BusyBox: built static (package/brick-rootswitch), packed by
 * board/brick/post-image.sh.
 *
 * A new root comes the same way: put on the games partition as
 * .dev/root-update.squashfs, with a file named root-update on the boot
 * partition for the boot script to see, which then adds rootupdate=1 to the
 * kernel's command line. This writes it over the root partition first, checks
 * it, and removes both. A write cut short leaves both, to start over at the
 * next boot.
 */
#include <dirent.h>
#include <fcntl.h>
#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include <stdlib.h>
#include <linux/fs.h>
#include <sys/ioctl.h>
#include <sys/mount.h>
#include <sys/stat.h>
#include <unistd.h>

#define ROOT_LABEL "plastron-root"
#define GAMES_LABEL "tortos"
#define BOOT_LABEL "boot"
#define UPDATE "/games/.dev/root-update.squashfs"
#define MARKER "/boot/root-update"
#define CHUNK (1024 * 1024)

static void say(const char *message)
{
	int fd = open("/dev/kmsg", O_WRONLY);

	if (fd >= 0) {
		dprintf(fd, "rootswitch: %s\n", message);
		close(fd);
	}
}

/* The partition's device name, from its uevent's PARTNAME (GPT names) */
static int find_partition(const char *label, char *device, size_t size)
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
			if (strncmp(line, "PARTNAME=", 9) == 0 &&
			    strncmp(line + 9, label, strlen(label)) == 0 &&
			    strcmp(line + 9 + strlen(label), "\n") == 0) {
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

static unsigned char file_chunk[CHUNK], card_chunk[CHUNK];

/* Writes the update over the root partition and reads it back from the card.
 * 0 when the root partition now holds it */
static int write_root(int update, off_t length, const char *device)
{
	off_t done;
	int root = open(device, O_RDWR);

	if (root < 0)
		return -1;
	for (done = 0; done < length; done += CHUNK) {
		size_t n = length - done < CHUNK ? length - done : CHUNK;

		if (pread(update, file_chunk, n, done) != (ssize_t)n ||
		    pwrite(root, file_chunk, n, done) != (ssize_t)n)
			goto fail;
	}
	/* What's read back has to come from the card, not the page cache */
	if (fsync(root) != 0 || ioctl(root, BLKFLSBUF, 0) != 0)
		goto fail;
	for (done = 0; done < length; done += CHUNK) {
		size_t n = length - done < CHUNK ? length - done : CHUNK;

		if (pread(update, file_chunk, n, done) != (ssize_t)n ||
		    pread(root, card_chunk, n, done) != (ssize_t)n ||
		    memcmp(file_chunk, card_chunk, n) != 0)
			goto fail;
	}
	close(root);
	return 0;
fail:
	close(root);
	return -1;
}

/* The new root, if one is waiting: checked as a squashfs that fits the root
 * partition, written, read back, then removed with the boot partition's
 * marker */
static void root_update(const char *device)
{
	char games[300], boot[300], path[300], line[64], message[200];
	unsigned char super[48];
	unsigned long long sectors = 0, used = 0;
	struct stat info;
	FILE *size;
	int update, i, ok = 0;

	if (!find_partition(GAMES_LABEL, games, sizeof games) ||
	    !find_partition(BOOT_LABEL, boot, sizeof boot)) {
		say("root update: no games or boot partition");
		return;
	}
	mkdir("/games", 0755);
	mkdir("/boot", 0755);
	if (mount(games, "/games", "exfat", 0, NULL) != 0) {
		say("root update: can't mount the games partition");
		return;
	}
	snprintf(path, sizeof path, "/sys/class/block/%s/size", strrchr(device, '/') + 1);
	size = fopen(path, "r");
	if (size) {
		if (fgets(line, sizeof line, size))
			sectors = strtoull(line, NULL, 10);
		fclose(size);
	}

	update = open(UPDATE, O_RDONLY);
	if (update < 0) {
		say("root update: no " UPDATE);
	} else if (fstat(update, &info) != 0 ||
		   pread(update, super, sizeof super, 0) != sizeof super ||
		   memcmp(super, "hsqs", 4) != 0) {
		say("root update: not a squashfs, left as it is");
	} else {
		/* bytes_used, little-endian at 40 in the superblock */
		for (i = 7; i >= 0; i--)
			used = used << 8 | super[40 + i];
		if (used > (unsigned long long)info.st_size ||
		    (unsigned long long)info.st_size > sectors * 512) {
			say("root update: doesn't fit the root partition, left as it is");
		} else if (write_root(update, info.st_size, device) != 0) {
			say("root update: write failed, trying again next boot");
			close(update);
			umount("/games");
			return;
		} else {
			snprintf(message, sizeof message, "root update: %lld bytes written and checked",
				 (long long)info.st_size);
			say(message);
			ok = 1;
		}
		close(update);
	}
	if (ok)
		unlink(UPDATE);
	umount("/games");

	/* The marker goes either way, done or nothing to do, so the boot script
	 * stops asking */
	if (mount(boot, "/boot", "vfat", 0, NULL) == 0) {
		unlink(MARKER);
		umount("/boot");
	}
	sync();
}

/* rootupdate=1 on the kernel's command line, from the boot script */
static int update_asked(void)
{
	char cmdline[1024];
	ssize_t n = -1;
	int fd;

	mkdir("/proc", 0755);
	if (mount("proc", "/proc", "proc", 0, NULL) != 0)
		return 0;
	fd = open("/proc/cmdline", O_RDONLY);
	if (fd >= 0) {
		n = read(fd, cmdline, sizeof cmdline - 1);
		close(fd);
	}
	umount("/proc");
	if (n <= 0)
		return 0;
	cmdline[n] = 0;
	return strstr(cmdline, " rootupdate=1") != NULL;
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
	for (i = 0; i < 600 && !find_partition(ROOT_LABEL, device, sizeof device); i++)
		usleep(5000);
	if (i == 600) {
		say("no partition named " ROOT_LABEL);
		for (;;)
			pause();
	}
	if (update_asked())
		root_update(device);
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
