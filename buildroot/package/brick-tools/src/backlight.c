/* The Brick's backlight through sunxi disp2: backlight on|off, or a level. */
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>

#define DISP_LCD_SET_BRIGHTNESS		0x102
#define DISP_LCD_BACKLIGHT_ENABLE	0x104
#define DISP_LCD_BACKLIGHT_DISABLE	0x105

int main(int argc, char **argv)
{
	unsigned long args[4] = { 0 };	/* screen 0 */
	int fd = open("/dev/disp", O_RDWR), request;

	if (fd < 0 || argc < 2) { fprintf(stderr, "usage: backlight on|off|LEVEL\n"); return 1; }
	if (!strcmp(argv[1], "on")) request = DISP_LCD_BACKLIGHT_ENABLE;
	else if (!strcmp(argv[1], "off")) request = DISP_LCD_BACKLIGHT_DISABLE;
	else { request = DISP_LCD_SET_BRIGHTNESS; args[1] = strtoul(argv[1], NULL, 0); }
	return ioctl(fd, request, args) < 0;
}
