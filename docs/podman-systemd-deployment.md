## Deploying with Podman and systemd

This setup runs Fizzy from this repository on a multi-app server, with Caddy terminating HTTPS and forwarding traffic to a local Podman container.

The container listens only on `127.0.0.1:3006`, so public traffic should go through Caddy.

### Server layout

Clone your Fizzy fork to `/opt/fizzy`:

```sh
sudo git clone git@github.com:whatznew-ai/fizzy.git /opt/fizzy
```

Create the persistent storage directory:

```sh
sudo mkdir -p /srv/fizzy/storage
```

### Environment

Copy the example environment file and edit it with real values:

```sh
sudo cp /opt/fizzy/deploy/podman/env.example /opt/fizzy/.env
sudo chmod 600 /opt/fizzy/.env
sudo editor /opt/fizzy/.env
```

The systemd unit passes this file to Podman with:

```sh
--env-file /opt/fizzy/.env
```

Do not commit `.env`. The repository root already ignores `.env*` files.
Podman reads `KEY=value` lines from this file directly, so do not wrap values in shell quotes.

For a Caddy/Cloudflare deployment, keep these settings:

```env
BASE_URL=https://fizzy.example.com
ASSUME_SSL=true
FORCE_SSL=true
```

Do not set `TLS_DOMAIN`; Caddy owns TLS in this deployment.

### Build the image

Build the image locally from this fork:

```sh
cd /opt/fizzy
sudo podman build --pull=always --tag localhost/fizzy:local .
```

### Install the systemd service

```sh
sudo cp /opt/fizzy/deploy/podman/fizzy.service /etc/systemd/system/fizzy.service
sudo systemctl daemon-reload
sudo systemctl enable --now fizzy
```

Check status and logs:

```sh
sudo systemctl status fizzy
sudo journalctl -u fizzy -f
```

### Health check

The systemd unit configures a Podman health check against Fizzy's unauthenticated Rails health endpoint:

```sh
curl --fail --silent --show-error --output /dev/null http://127.0.0.1/up
```

Podman runs this inside the container every 30 seconds, after a 60 second startup grace period. If the container becomes unhealthy, Podman restarts it.

Check health status with:

```sh
sudo podman inspect --format '{{.State.Health.Status}}' fizzy
sudo podman healthcheck run fizzy
```

### Caddy

Point Caddy at the local port:

```caddyfile
fizzy.example.com {
  reverse_proxy 127.0.0.1:3006
}
```

Reload Caddy after editing its config:

```sh
sudo systemctl reload caddy
```

In Cloudflare, use **Full (strict)** SSL mode so the browser, Cloudflare, and Caddy all agree that the public request is HTTPS.

### Updates

To deploy new code:

```sh
cd /opt/fizzy
sudo git pull --ff-only
sudo podman build --pull=always --tag localhost/fizzy:local .
sudo systemctl restart fizzy
```

### Console

Run the Rails console inside the container:

```sh
sudo podman exec -it fizzy bin/rails c
```
