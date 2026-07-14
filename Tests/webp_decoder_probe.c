#include "webp/decode.h"
#include <stdio.h>
#include <stdlib.h>

static unsigned char *ReadFile(const char *path, size_t *size) {
    FILE *file = fopen(path, "rb");
    long length = 0;
    unsigned char *bytes = NULL;
    if (file == NULL) return NULL;
    if (fseek(file, 0, SEEK_END) != 0) {
        fclose(file);
        return NULL;
    }
    length = ftell(file);
    if (length <= 0 || fseek(file, 0, SEEK_SET) != 0) {
        fclose(file);
        return NULL;
    }
    bytes = (unsigned char *)malloc((size_t)length);
    if (bytes == NULL || fread(bytes, 1, (size_t)length, file) != (size_t)length) {
        free(bytes);
        fclose(file);
        return NULL;
    }
    fclose(file);
    *size = (size_t)length;
    return bytes;
}

int main(int argc, char **argv) {
    size_t size = 0;
    unsigned char *bytes = NULL;
    unsigned char *rgba = NULL;
    int width = 0;
    int height = 0;
    if (argc != 2) {
        fprintf(stderr, "usage: webp_decoder_probe fixture.webp\n");
        return 2;
    }
    bytes = ReadFile(argv[1], &size);
    if (bytes == NULL || !WebPGetInfo(bytes, size, &width, &height)) {
        fprintf(stderr, "WebP metadata decode failed\n");
        free(bytes);
        return 3;
    }
    if (size > 8 && WebPGetInfo(bytes, 8, &width, &height)) {
        fprintf(stderr, "Truncated WebP was incorrectly accepted\n");
        free(bytes);
        return 5;
    }
    rgba = WebPDecodeRGBA(bytes, size, &width, &height);
    free(bytes);
    if (rgba == NULL || width <= 0 || height <= 0) {
        fprintf(stderr, "WebP pixel decode failed\n");
        WebPFree(rgba);
        return 4;
    }
    printf("WebP decode passed: %dx%d\n", width, height);
    WebPFree(rgba);
    return 0;
}
