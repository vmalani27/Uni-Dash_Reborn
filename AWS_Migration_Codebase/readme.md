plan: to move the codebase setup to a code server on nas pi. exposing it via only tailscale so that i have finegrained access to the development

installation of required extensions and cli setup on the pi itself

central management of secrets as well as code 

Setup (on Raspberry Pi)
curl -fsSL https://code-server.dev/install.sh | sh
code-server

By default it will:

Start on http://localhost:8080
Generate a password in ~/.config/code-server/config.yaml
Edit config:

bind-addr: 0.0.0.0:8080
auth: password
password: your_secure_password