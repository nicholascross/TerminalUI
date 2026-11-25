#include "CTerminalSupport.h"
#include <errno.h>
#include <fcntl.h>
#include <signal.h>
#include <spawn.h>
#include <stdbool.h>
#include <sys/ioctl.h>
#include <sys/wait.h>
#include <unistd.h>

#if defined(__APPLE__)
#include <TargetConditionals.h>
#if TARGET_OS_OSX
#include <crt_externs.h>
#endif
#else
extern char **environ;
#endif

#if !defined(__APPLE__) || TARGET_OS_OSX
static bool is_controlling_terminal(int fd) {
    if (tcgetpgrp(fd) == -1) return false;

    // A PTY master can report a foreground group too, but I/O goes to the other end.
#if defined(__APPLE__)
    char name[128];
    return ioctl(fd, TIOCPTYGNAME, name) == -1;
#elif defined(TIOCGPTN)
    unsigned int number;
    return ioctl(fd, TIOCGPTN, &number) == -1;
#else
    return true;
#endif
}

static int add_terminal_stdio_actions(posix_spawn_file_actions_t *actions) {
    bool inherit[STDERR_FILENO + 1] = {false};
    int input_fd = -1;
    int output_fd = -1;

    // Keep the actual TTY device when possible. macOS kqueue cannot watch /dev/tty.
    for (int fd = STDIN_FILENO; fd <= STDERR_FILENO; fd++) {
        int flags = fcntl(fd, F_GETFL);
        if (flags == -1 || (flags & O_NONBLOCK)) continue;
        int access = flags & O_ACCMODE;
        int required = fd == STDIN_FILENO ? O_RDONLY : O_WRONLY;
        if (access != required && access != O_RDWR) continue;
        int descriptor_flags = fcntl(fd, F_GETFD);
        if (descriptor_flags == -1 || (descriptor_flags & FD_CLOEXEC)) continue;
        if (!is_controlling_terminal(fd)) continue;

        inherit[fd] = true;
        if (input_fd == -1 && access != O_WRONLY) input_fd = fd;
        if (output_fd == -1 && access != O_RDONLY) output_fd = fd;
    }

    // Give redirected streams the controlling terminal too, using a blocking open as a fallback.
    int fallback_fd = -1;
    for (int fd = STDIN_FILENO; fd <= STDERR_FILENO; fd++) {
        if (inherit[fd]) continue;
        int source = fd == STDIN_FILENO ? input_fd : output_fd;
        if (source == -1) source = fallback_fd;
        int error;
        if (source == -1) {
            error = posix_spawn_file_actions_addopen(actions, fd, "/dev/tty", O_RDWR | O_NOCTTY, 0);
            fallback_fd = fd;
        } else {
            error = posix_spawn_file_actions_adddup2(actions, source, fd);
        }
        if (error) return error;
    }
    return 0;
}
#endif

int tui_command_spawn(pid_t *child, char *const argv[]) {
#if defined(__APPLE__) && !TARGET_OS_OSX
    return ENOTSUP;
#else
    posix_spawn_file_actions_t actions;
    int error = posix_spawn_file_actions_init(&actions);
    if (error) return error;

    posix_spawnattr_t attributes;
    error = posix_spawnattr_init(&attributes);
    if (error) {
        posix_spawn_file_actions_destroy(&actions);
        return error;
    }

    sigset_t mask, defaults;
    sigemptyset(&mask);
    sigemptyset(&defaults);
    sigaddset(&defaults, SIGPIPE);
    sigaddset(&defaults, SIGINT);
    sigaddset(&defaults, SIGQUIT);
    sigaddset(&defaults, SIGTSTP);
    sigaddset(&defaults, SIGTTIN);
    sigaddset(&defaults, SIGTTOU);

    error = posix_spawnattr_setsigmask(&attributes, &mask);
    if (!error) error = posix_spawnattr_setsigdefault(&attributes, &defaults);
    if (!error) error = posix_spawnattr_setflags(&attributes, POSIX_SPAWN_SETSIGMASK | POSIX_SPAWN_SETSIGDEF);
    if (!error) error = add_terminal_stdio_actions(&actions);
    if (!error) {
#if defined(__APPLE__)
        char **environment = *_NSGetEnviron();
#else
        char **environment = environ;
#endif
        error = posix_spawnp(child, argv[0], &actions, &attributes, argv, environment);
    }
    posix_spawnattr_destroy(&attributes);
    posix_spawn_file_actions_destroy(&actions);
    return error;
#endif
}

int tui_command_poll(pid_t child, int *exit_code, int *signal_number) {
    int status;
    pid_t result;
    do {
        result = waitpid(child, &status, WNOHANG);
    } while (result < 0 && errno == EINTR);
    if (result <= 0) return (int)result;
    if (WIFEXITED(status)) {
        *exit_code = WEXITSTATUS(status);
        return 1;
    }
    if (WIFSIGNALED(status)) {
        *signal_number = WTERMSIG(status);
        return 1;
    }
    return 0;
}
