#include <SDL/SDL.h>
#include <stdio.h>

int main() {
  if((SDL_Init(SDL_INIT_VIDEO)==-1))
    {
      fprintf(stderr, "Could not initialize SDL: %s\n", SDL_GetError());
      exit(-1);
    }

  SDL_Quit();
  return 0;
}
