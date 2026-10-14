/* How long since the chip came out of reset: the generic timer counts from
 * reset (unless the firmware resets it), the kernel's uptime from its own
 * start, so the difference is the time spent before the kernel. */
#include <stdint.h>
#include <stdio.h>
#include <time.h>

int main(void)
{
	uint64_t count, freq;
	struct timespec up;

	asm volatile("mrs %0, cntfrq_el0" : "=r"(freq));
	asm volatile("isb; mrs %0, cntvct_el0" : "=r"(count));
	clock_gettime(CLOCK_BOOTTIME, &up);
	double since_reset = (double)count / freq, uptime = up.tv_sec + up.tv_nsec / 1e9;
	printf("timer %.3f s since reset (%llu Hz), kernel up %.3f s, before the kernel %.3f s\n",
	       since_reset, (unsigned long long)freq, uptime, since_reset - uptime);
	return 0;
}
