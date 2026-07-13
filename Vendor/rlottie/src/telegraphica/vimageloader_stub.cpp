/* Telegraphica TGS stickers are vector-only. External and embedded images are disabled. */
#include <stddef.h>

extern "C" {

unsigned char *lottie_image_load(char const *filename, int *x, int *y, int *comp, int req_comp)
{
    (void)filename;
    (void)x;
    (void)y;
    (void)comp;
    (void)req_comp;
    return NULL;
}

unsigned char *lottie_image_load_from_data(const char *imageData, int len, int *x, int *y, int *comp, int req_comp)
{
    (void)imageData;
    (void)len;
    (void)x;
    (void)y;
    (void)comp;
    (void)req_comp;
    return NULL;
}

void lottie_image_free(unsigned char *data)
{
    (void)data;
}

}
