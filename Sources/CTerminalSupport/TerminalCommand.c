#include "CTerminalSupport.h"
#include <errno.h>
#include <fcntl.h>
#include <signal.h>
#include <spawn.h>
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
    if (!error) error = posix_spawn_file_actions_addopen(&actions, STDIN_FILENO, "/dev/tty", O_RDWR | O_NOCTTY, 0);
    if (!error) error = posix_spawn_file_actions_adddup2(&actions, STDIN_FILENO, STDOUT_FILENO);
    if (!error) error = posix_spawn_file_actions_adddup2(&actions, STDIN_FILENO, STDERR_FILENO);
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
