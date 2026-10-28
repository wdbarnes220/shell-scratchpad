# Shell Scratchpad

A bar widget for running a shell command and reading its output in a popup, without switching to a terminal.

## Requirements

- Omarchy Quattro shell with plugin support
- Bash and the `timeout` utility

## Install

Install this repository as an Omarchy plugin:

```sh
omarchy plugin add https://github.com/wdbarnes220/shell-scratchpad --enable
```

If you already have the local plugin folder, place `wdb.shell-scratchpad` in the right bar section in `~/.config/omarchy/shell.json`, then run `omarchy-shell shell rescanPlugins` (or restart the shell).

## Use

Click the `>_` button in the bar, enter a command, and press Enter or click **Run**. Output and errors appear in the panel. Use Up/Down to cycle through the current session's command history; press Escape to close the panel. Each command is run via `bash -c` with a 10-second timeout.

Commands run with the same permissions as the Omarchy shell process. Review commands before running them. History is kept in memory only and is cleared when the shell restarts.

## License

MIT. See [LICENSE](LICENSE).
