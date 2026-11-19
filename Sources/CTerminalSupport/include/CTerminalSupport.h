#ifndef C_TERMINAL_SUPPORT_H
#define C_TERMINAL_SUPPORT_H

#include <sys/types.h>

// Installs process-wide terminal signal handlers and returns a nonblocking wakeup descriptor.
// Only one caller may own the handlers at a time.
int tui_signals_open(void);
void tui_signals_close(void);
int tui_signals_termination_requested(void);
void tui_signals_ignore_interrupt(int ignored);

// Starts a command in the host's foreground process group with blocking TTY stdio.
// Returns zero on success or a POSIX error number.
int tui_command_spawn(pid_t *child, char *const argv[]);
// Returns 1 on exit, 0 while running, or -1 with errno set.
int tui_command_poll(pid_t child, int *exit_code, int *signal_number);

// select-based terminal readiness for macOS, where poll does not support /dev/tty.
// Read returns a mask: 1 for terminal input, 2 for the signal pipe; -1 on error.
int tui_wait_readable(int terminal, int signals, int timeout_ms);
// Adds a dedicated application-update descriptor (-1 disables it); bit 4 reports updates.
int tui_wait_readable_updates(int terminal, int signals, int updates, int timeout_ms);
// Write returns 1 when writable, 0 on timeout, or -1 on error.
int tui_wait_writable(int terminal, int timeout_ms);

#endif
