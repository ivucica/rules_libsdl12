/* Minimal SDL 1.2 example used by the submodule integration test.
 * See MODULE.bazel / WORKSPACE for how rules_libsdl12 is brought in
 * as a git submodule instead of from the Bazel Central Registry.
 */
#include "SDL/SDL.h"

int main(int argc, char *argv[]) {
    if (SDL_Init(SDL_INIT_VIDEO) < 0) {
        return 1;
    }
    SDL_Quit();
    return 0;
}
