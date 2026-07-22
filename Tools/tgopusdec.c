#include <errno.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <opus/opusfile.h>

#define TG_MAX_DECODED_WAV_BYTES (512ULL * 1024ULL * 1024ULL)

static void write_u16_le(FILE *file, uint16_t value) {
    unsigned char bytes[2];
    bytes[0] = (unsigned char)(value & 0xff);
    bytes[1] = (unsigned char)((value >> 8) & 0xff);
    fwrite(bytes, 1, 2, file);
}

static void write_u32_le(FILE *file, uint32_t value) {
    unsigned char bytes[4];
    bytes[0] = (unsigned char)(value & 0xff);
    bytes[1] = (unsigned char)((value >> 8) & 0xff);
    bytes[2] = (unsigned char)((value >> 16) & 0xff);
    bytes[3] = (unsigned char)((value >> 24) & 0xff);
    fwrite(bytes, 1, 4, file);
}

static int write_wav_header(FILE *file, uint32_t sample_rate, uint16_t channels, uint16_t bits_per_sample, uint32_t data_bytes) {
    uint16_t block_align = (uint16_t)(channels * (bits_per_sample / 8));
    uint32_t byte_rate = sample_rate * block_align;
    uint32_t riff_size = 36 + data_bytes;

    if (fseek(file, 0, SEEK_SET) != 0) {
        return -1;
    }
    fwrite("RIFF", 1, 4, file);
    write_u32_le(file, riff_size);
    fwrite("WAVE", 1, 4, file);
    fwrite("fmt ", 1, 4, file);
    write_u32_le(file, 16);
    write_u16_le(file, 1);
    write_u16_le(file, channels);
    write_u32_le(file, sample_rate);
    write_u32_le(file, byte_rate);
    write_u16_le(file, block_align);
    write_u16_le(file, bits_per_sample);
    fwrite("data", 1, 4, file);
    write_u32_le(file, data_bytes);
    return ferror(file) ? -1 : 0;
}

int main(int argc, char **argv) {
    if (argc != 3) {
        fprintf(stderr, "usage: tgopusdec input.ogg output.wav\n");
        return 64;
    }

    const char *input_path = argv[1];
    const char *output_path = argv[2];
    int opus_error = 0;
    OggOpusFile *opus_file = op_open_file(input_path, &opus_error);
    if (!opus_file) {
        fprintf(stderr, "op_open_file failed: %d\n", opus_error);
        return 65;
    }

    FILE *output = fopen(output_path, "wb+");
    if (!output) {
        fprintf(stderr, "could not open output: %s\n", strerror(errno));
        op_free(opus_file);
        return 66;
    }

    const uint32_t sample_rate = 48000;
    const uint16_t channels = 2;
    const uint16_t bits_per_sample = 16;
    if (write_wav_header(output, sample_rate, channels, bits_per_sample, 0) != 0) {
        fprintf(stderr, "could not write wav header\n");
        fclose(output);
        op_free(opus_file);
        return 67;
    }

    opus_int16 pcm[120 * 48 * 2];
    uint64_t total_frames = 0;
    for (;;) {
        int frames = op_read_stereo(opus_file, pcm, (int)(sizeof(pcm) / sizeof(pcm[0])));
        if (frames == 0) {
            break;
        }
        if (frames < 0) {
            fprintf(stderr, "op_read_stereo failed: %d\n", frames);
            fclose(output);
            op_free(opus_file);
            remove(output_path);
            return 68;
        }
        const uint64_t bytes_per_frame = (uint64_t)channels * (bits_per_sample / 8);
        const uint64_t maximum_pcm_bytes = TG_MAX_DECODED_WAV_BYTES - 44;
        const uint64_t maximum_frames = maximum_pcm_bytes / bytes_per_frame;
        if (total_frames > maximum_frames ||
            (uint64_t)frames > maximum_frames - total_frames) {
            fprintf(stderr, "decoded file exceeds the safe wav size limit\n");
            fclose(output);
            op_free(opus_file);
            remove(output_path);
            return 70;
        }
        size_t sample_count = (size_t)frames * channels;
        if (fwrite(pcm, sizeof(opus_int16), sample_count, output) != sample_count) {
            fprintf(stderr, "could not write pcm data\n");
            fclose(output);
            op_free(opus_file);
            remove(output_path);
            return 69;
        }
        total_frames += (uint64_t)frames;
    }

    uint32_t data_bytes = (uint32_t)(total_frames * channels * (bits_per_sample / 8));
    if (write_wav_header(output, sample_rate, channels, bits_per_sample, data_bytes) != 0) {
        fprintf(stderr, "could not finalize wav header\n");
        fclose(output);
        op_free(opus_file);
        remove(output_path);
        return 71;
    }

    fclose(output);
    op_free(opus_file);
    return 0;
}
