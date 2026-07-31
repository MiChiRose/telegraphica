#include <cerrno>
#include <cstdint>
#include <mach/mach_time.h>
#include <pthread.h>
#include <sys/time.h>
#include <time.h>

namespace {

mach_timebase_info_data_t gTimebase = {0, 0};
pthread_once_t gTimebaseOnce = PTHREAD_ONCE_INIT;

void InitializeTimebase() {
    mach_timebase_info(&gTimebase);
}

} // namespace

// clock_gettime was added to macOS in 10.12. The modern SDK used to build
// the optional call transport lets libvpx reference it weakly, which leaves a
// null symbol on Mavericks and crashes as soon as VP8 encodes its first frame.
// Supplying the small POSIX subset used by libvpx keeps one transport binary
// compatible with the complete 10.9-10.13 call lane.
extern "C" int clock_gettime(clockid_t clockID, struct timespec *value) {
    if (!value) {
        errno = EINVAL;
        return -1;
    }

    if (clockID == CLOCK_REALTIME) {
        struct timeval currentTime;
        if (gettimeofday(&currentTime, NULL) != 0) {
            return -1;
        }
        value->tv_sec = currentTime.tv_sec;
        value->tv_nsec = currentTime.tv_usec * 1000L;
        return 0;
    }

    pthread_once(&gTimebaseOnce, InitializeTimebase);
    if (gTimebase.denom == 0) {
        errno = EINVAL;
        return -1;
    }

    const uint64_t ticks = mach_absolute_time();
    const uint64_t whole = ticks / gTimebase.denom;
    const uint64_t remainder = ticks % gTimebase.denom;
    const uint64_t nanoseconds =
        whole * gTimebase.numer +
        (remainder * gTimebase.numer) / gTimebase.denom;
    value->tv_sec = static_cast<time_t>(nanoseconds / 1000000000ULL);
    value->tv_nsec = static_cast<long>(nanoseconds % 1000000000ULL);
    return 0;
}
