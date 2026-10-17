## Sandbox

Herdr is the session. Split panes and run `pi` in each one. Fresh is `$EDITOR`.

Node.js 24 or newer is installed. `pi` and `factory` are on PATH. Docker is available inside the sandbox.

In bash, `npm` is an alias for `sfw npm` ([Socket Firewall Free](https://github.com/SocketDev/sfw-free/)). Running the `npm` binary directly does not go through the firewall.

## Factory server

`factory-up`, run from the repository root, starts `factory serve` in a Herdr workspace named `factory` and writes the dashboard's API URL and token to `.factory/dashboard.env`. Running it again leaves a healthy server alone. Pi needs nothing from it: it reads `.factory/local.token` and the SQLite state directly.
