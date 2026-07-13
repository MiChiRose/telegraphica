#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "rlottie_capi.h"

static uint64_t TGChecksum(const uint32_t *pixels, size_t count) {
    uint64_t value = 1469598103934665603ULL;
    size_t index = 0;
    for (index = 0; index < count; index++) {
        value ^= pixels[index];
        value *= 1099511628211ULL;
    }
    return value;
}

int main(int argc, char **argv) {
    FILE *file = NULL;
    long length = 0;
    char *json = NULL;
    Lottie_Animation *animation = NULL;
    uint32_t *pixels = NULL;
    size_t frameCount = 0;
    size_t sourceWidth = 0;
    size_t sourceHeight = 0;
    uint64_t first = 0;
    uint64_t middle = 0;
    int result = 0;

    if (argc != 2) return 2;
    file = fopen(argv[1], "rb");
    if (!file) return 3;
    fseek(file, 0, SEEK_END);
    length = ftell(file);
    rewind(file);
    json = (char *)calloc((size_t)length + 1, 1);
    if (!json || fread(json, 1, (size_t)length, file) != (size_t)length) return 4;
    fclose(file);

    animation = lottie_animation_from_data(json, "telegraphica-probe", "");
    free(json);
    if (!animation) return 5;
    frameCount = lottie_animation_get_totalframe(animation);
    lottie_animation_get_size(animation, &sourceWidth, &sourceHeight);
    if (frameCount < 2 || sourceWidth == 0 || sourceHeight == 0) return 6;

    pixels = (uint32_t *)calloc(128 * 128, sizeof(uint32_t));
    if (!pixels) return 7;
    lottie_animation_render(animation, 0, pixels, 128, 128, 128 * 4);
    first = TGChecksum(pixels, 128 * 128);
    memset(pixels, 0, 128 * 128 * sizeof(uint32_t));
    lottie_animation_render(animation, frameCount / 2, pixels, 128, 128, 128 * 4);
    middle = TGChecksum(pixels, 128 * 128);
    if (first == middle) {
        result = 8;
    } else {
        printf("TGS renderer passed: %lu frames, %lux%lu source\n",
               (unsigned long)frameCount,
               (unsigned long)sourceWidth,
               (unsigned long)sourceHeight);
    }
    free(pixels);
    lottie_animation_destroy(animation);
    return result;
}
