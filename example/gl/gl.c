#include <SDL/SDL.h>
#include <GL/gl.h>

int main(int argc, char ** argv) {
  if((SDL_Init(SDL_INIT_VIDEO)==-1))
    {
      fprintf(stderr, "Could not initialize SDL: %s\n", SDL_GetError());
      exit(-1);
    }

  SDL_Surface * screen = SDL_SetVideoMode(640, 480, 8, SDL_OPENGL);
  if (screen == NULL)
    {
      fprintf(stderr, "Could not initialize video mode: %s\n", SDL_GetError());
      exit(-1);
    }

  SDL_Event event;
  int running = 1;
  while(running)
    {
      while(SDL_PollEvent(&event))
        {
          switch(event.type)
            {
              case SDL_QUIT:
              running = 0;
	      break;
            }
        }

      glClear(GL_COLOR_BUFFER_BIT);

      SDL_Flip(screen);
    }
  SDL_Quit();

  return 0;
}
