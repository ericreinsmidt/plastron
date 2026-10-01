/*
 * sdltest: how long SDL2 takes to come up the way TortOS uses it on the
 * Pixel 2 (KMS/DRM, OpenGL ES renderer), and whether presenting a rotated
 * landscape frame keeps full speed.
 *
 * The scene is 640x480 landscape, drawn into a texture and copied to the
 * 480x640 portrait panel turned 90 degrees counter-clockwise. A red square
 * marks the top-left corner and a green bar the top edge.
 */
#include <SDL2/SDL.h>
#include <stdio.h>
#include <time.h>

static double now(void)
{
	struct timespec t;

	clock_gettime(CLOCK_MONOTONIC, &t);
	return t.tv_sec + t.tv_nsec / 1e9;
}

int main(int argc, char **argv)
{
	int frames = argc > 1 ? atoi(argv[1]) : 300;
	double t0 = now();

	SDL_SetHint(SDL_HINT_RENDER_DRIVER, "opengles2");
	if (SDL_Init(SDL_INIT_VIDEO)) {
		fprintf(stderr, "SDL_Init: %s\n", SDL_GetError());
		return 1;
	}
	double t_init = now();

	SDL_Window *window = SDL_CreateWindow("sdltest", 0, 0, 480, 640, SDL_WINDOW_FULLSCREEN);
	if (!window) {
		fprintf(stderr, "window: %s\n", SDL_GetError());
		return 1;
	}
	double t_window = now();

	SDL_Renderer *renderer = SDL_CreateRenderer(window, -1,
		SDL_RENDERER_ACCELERATED | SDL_RENDERER_PRESENTVSYNC);
	if (!renderer) {
		fprintf(stderr, "renderer: %s\n", SDL_GetError());
		return 1;
	}
	double t_renderer = now();

	SDL_RendererInfo info;
	SDL_GetRendererInfo(renderer, &info);
	int out_w, out_h;
	SDL_GetRendererOutputSize(renderer, &out_w, &out_h);

	SDL_Texture *scene = SDL_CreateTexture(renderer, SDL_PIXELFORMAT_ARGB8888,
		SDL_TEXTUREACCESS_TARGET, 640, 480);

	/* The landscape scene's centre goes to the portrait screen's centre */
	SDL_Rect dest = { (out_w - 640) / 2, (out_h - 480) / 2, 640, 480 };
	double t_first = 0;

	double loop_start = now();
	for (int i = 0; i < frames; i++) {
		SDL_SetRenderTarget(renderer, scene);
		SDL_SetRenderDrawColor(renderer, 20, 40, 80, 255);
		SDL_RenderClear(renderer);
		/* Something that moves, so frames differ */
		SDL_Rect box = { (i * 4) % 600, 200, 40, 40 };
		SDL_SetRenderDrawColor(renderer, 255, 255, 255, 255);
		SDL_RenderFillRect(renderer, &box);
		SDL_Rect corner = { 0, 0, 80, 80 };
		SDL_SetRenderDrawColor(renderer, 255, 0, 0, 255);
		SDL_RenderFillRect(renderer, &corner);
		SDL_Rect top = { 80, 0, 560, 20 };
		SDL_SetRenderDrawColor(renderer, 0, 255, 0, 255);
		SDL_RenderFillRect(renderer, &top);

		SDL_SetRenderTarget(renderer, NULL);
		SDL_SetRenderDrawColor(renderer, 0, 0, 0, 255);
		SDL_RenderClear(renderer);
		SDL_RenderCopyEx(renderer, scene, NULL, &dest, -90, NULL, SDL_FLIP_NONE);
		SDL_RenderPresent(renderer);
		if (i == 0) {
			t_first = now();
			loop_start = t_first;
		}
	}
	double loop_end = now();

	printf("renderer %s, output %dx%d\n", info.name, out_w, out_h);
	printf("SDL_Init(VIDEO)   %6.1f ms\n", (t_init - t0) * 1000);
	printf("window            %6.1f ms\n", (t_window - t_init) * 1000);
	printf("renderer          %6.1f ms\n", (t_renderer - t_window) * 1000);
	printf("first frame       %6.1f ms\n", (t_first - t_renderer) * 1000);
	printf("total to picture  %6.1f ms\n", (t_first - t0) * 1000);
	if (frames > 1)
		printf("%d rotated frames at %.2f fps\n", frames - 1,
		       (frames - 1) / (loop_end - loop_start));

	SDL_Quit();
	return 0;
}
