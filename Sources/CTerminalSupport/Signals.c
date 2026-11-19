#include "CTerminalSupport.h"
#include <errno.h>
#include <fcntl.h>
#include <signal.h>
#include <stddef.h>
#include <unistd.h>

static int signal_pipe[2] = {-1, -1};
static volatile sig_atomic_t signal_write_descriptor = -1;
static volatile sig_atomic_t termination_requested;
static volatile sig_atomic_t interrupt_ignored;
static const int watched[] = {SIGWINCH, SIGTERM, SIGHUP, SIGINT, SIGPIPE};
static struct sigaction previous[sizeof(watched) / sizeof(watched[0])];
static size_t installed;

static void wake_loop(int number) {
    int saved_errno = errno;
    if (number == SIGINT && interrupt_ignored) return;
    unsigned char byte = (unsigned char)number;
    if (number == SIGTERM || number == SIGHUP || number == SIGINT) termination_requested = 1;
    if (signal_write_descriptor >= 0) {
        (void)write((int)signal_write_descriptor, &byte, 1);
    }
    errno = saved_errno;
}

void tui_signals_close(void) {
    while (installed > 0) {
        --installed;
        (void)sigaction(watched[installed], &previous[installed], NULL);
    }
    signal_write_descriptor = -1;
    if (signal_pipe[0] >= 0) close(signal_pipe[0]);
    if (signal_pipe[1] >= 0) close(signal_pipe[1]);
    signal_pipe[0] = signal_pipe[1] = -1;
}

int tui_signals_termination_requested(void) { return termination_requested != 0; }

void tui_signals_ignore_interrupt(int ignored) { interrupt_ignored = ignored != 0; }

int tui_signals_open(void) {
    if (signal_pipe[0] >= 0) { errno = EBUSY; return -1; }
    if (pipe(signal_pipe) < 0) return -1;
    termination_requested = 0;
    interrupt_ignored = 0;
    for (int index = 0; index < 2; ++index) {
        int flags = fcntl(signal_pipe[index], F_GETFL);
        int descriptor_flags = fcntl(signal_pipe[index], F_GETFD);
        if (flags < 0 || descriptor_flags < 0 ||
            fcntl(signal_pipe[index], F_SETFL, flags | O_NONBLOCK) < 0 ||
            fcntl(signal_pipe[index], F_SETFD, descriptor_flags | FD_CLOEXEC) < 0) {
            int error = errno;
            tui_signals_close();
            errno = error;
            return -1;
        }
    }
    signal_write_descriptor = signal_pipe[1];
    for (size_t index = 0; index < sizeof(watched) / sizeof(watched[0]); ++index) {
        struct sigaction action = {0};
        sigemptyset(&action.sa_mask);
        action.sa_handler = watched[index] == SIGPIPE ? SIG_IGN : wake_loop;
        if (sigaction(watched[index], &action, &previous[index]) < 0) {
            int error = errno;
            tui_signals_close();
            errno = error;
            return -1;
        }
        ++installed;
    }
    return signal_pipe[0];
}
