#include <SDL/SDL.h>
#include <gtest/gtest.h>

TEST(SimpleTimer, BasicSDLInit) {
  EXPECT_NE((SDL_Init(SDL_INIT_TIMER)), -1);

  SDL_Quit();
}
