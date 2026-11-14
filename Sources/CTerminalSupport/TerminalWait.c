#include "CTerminalSupport.h"
#include <errno.h>
#include <stddef.h>
#include <sys/select.h>

static int valid_descriptor(int descriptor) {
    if (descriptor < 0 || descriptor >= FD_SETSIZE) {
        errno = EINVAL;
        return 0;
    }
    return 1;
}

int tui_wait_readable(int terminal, int signals, int timeout_ms) {
    if (!valid_descriptor(terminal) || !valid_descriptor(signals) || timeout_ms < 0) {
        errno = EINVAL;
        return -1;
    }
    fd_set readable;
    FD_ZERO(&readable);
    FD_SET(terminal, &readable);
    FD_SET(signals, &readable);
    struct timeval timeout = {timeout_ms / 1000, (timeout_ms % 1000) * 1000};
    int maximum = terminal > signals ? terminal : signals;
    int result = select(maximum + 1, &readable, NULL, NULL, &timeout);
    if (result <= 0) return result;
    return (FD_ISSET(terminal, &readable) ? 1 : 0) | (FD_ISSET(signals, &readable) ? 2 : 0);
}

int tui_wait_writable(int terminal, int timeout_ms) {
    if (!valid_descriptor(terminal) || timeout_ms < 0) {
        errno = EINVAL;
        return -1;
    }
    fd_set writable;
    FD_ZERO(&writable);
    FD_SET(terminal, &writable);
    struct timeval timeout = {timeout_ms / 1000, (timeout_ms % 1000) * 1000};
    return select(terminal + 1, NULL, &writable, NULL, &timeout);
}
