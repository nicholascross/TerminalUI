#ifndef C_TERMINAL_SUPPORT_H
#define C_TERMINAL_SUPPORT_H

// Installs process-wide terminal signal handlers and returns a nonblocking wakeup descriptor.
// Only one caller may own the handlers at a time.
int tui_signals_open(void);
void tui_signals_close(void);
int tui_signals_termination_requested(void);

// select-based terminal readiness for macOS, where poll does not support /dev/tty.
// Read returns a mask: 1 for terminal input, 2 for the signal pipe; -1 on error.
int tui_wait_readable(int terminal, int signals, int timeout_ms);
// Write returns 1 when writable, 0 on timeout, or -1 on error.
int tui_wait_writable(int terminal, int timeout_ms);

#endif
