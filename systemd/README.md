# Hermes Suite Systemd Services

This directory contains systemd service unit files for managing Hermes Suite services.

## Template Services

These are template services (indicated by the `@` in the filename). You instantiate them with your username.

## Installation

### User Services (Recommended)

To install services for your user account (no root required):

```bash
# Create user services directory
mkdir -p ~/.config/systemd/user

# Copy service files
cp hermes-gateway@.service ~/.config/systemd/user/
cp hermes-dashboard@.service ~/.config/systemd/user/
cp hermes-webui@.service ~/.config/systemd/user/

# Reload systemd daemon
systemctl --user daemon-reload
```

### System Services (Requires Root)

To install services system-wide:

```bash
# Copy service files to system directory
sudo cp hermes-gateway@.service /etc/systemd/system/
sudo cp hermes-dashboard@.service /etc/systemd/system/
sudo cp hermes-webui@.service /etc/systemd/system/

# Reload systemd daemon
sudo systemctl daemon-reload
```

## Usage

Replace `USERNAME` with your actual username.

### Start All Services

```bash
# User services
systemctl --user start hermes-gateway@USERNAME
systemctl --user start hermes-dashboard@USERNAME
systemctl --user start hermes-webui@USERNAME

# System services
sudo systemctl start hermes-gateway@USERNAME
sudo systemctl start hermes-dashboard@USERNAME
sudo systemctl start hermes-webui@USERNAME
```

### Stop Services

```bash
# User services
systemctl --user stop hermes-gateway@USERNAME
systemctl --user stop hermes-dashboard@USERNAME
systemctl --user stop hermes-webui@USERNAME

# System services
sudo systemctl stop hermes-gateway@USERNAME
sudo systemctl stop hermes-dashboard@USERNAME
sudo systemctl stop hermes-webui@USERNAME
```

### Check Status

```bash
# User services
systemctl --user status hermes-gateway@USERNAME
systemctl --user status hermes-dashboard@USERNAME
systemctl --user status hermes-webui@USERNAME

# System services
sudo systemctl status hermes-gateway@USERNAME
sudo systemctl status hermes-dashboard@USERNAME
sudo systemctl status hermes-webui@USERNAME
```

### View Logs

```bash
# User services (last 50 lines)
journalctl --user -u hermes-gateway@USERNAME -n 50

# Follow logs in real-time
journalctl --user -u hermes-gateway@USERNAME -f

# System services
sudo journalctl -u hermes-gateway@USERNAME -f
```

### Enable Services (Auto-start on Login/Boot)

```bash
# User services (start on login)
systemctl --user enable hermes-gateway@USERNAME
systemctl --user enable hermes-dashboard@USERNAME
systemctl --user enable hermes-webui@USERNAME

# System services (start on boot)
sudo systemctl enable hermes-gateway@USERNAME
sudo systemctl enable hermes-dashboard@USERNAME
sudo systemctl enable hermes-webui@USERNAME
```

### Disable Services

```bash
# User services
systemctl --user disable hermes-gateway@USERNAME
systemctl --user disable hermes-dashboard@USERNAME
systemctl --user disable hermes-webui@USERNAME

# System services
sudo systemctl disable hermes-gateway@USERNAME
sudo systemctl disable hermes-dashboard@USERNAME
sudo systemctl disable hermes-webui@USERNAME
```

## Service Details

- **hermes-gateway@**: Main Hermes agent gateway (port 8642)
  - Uses: `hermes_upstream/.venv/bin/hermes gateway run`
- **hermes-dashboard@**: Hermes dashboard UI (port 9119)
  - Uses: `hermes_upstream/.venv/bin/hermes dashboard`
- **hermes-webui@**: Hermes web interface (port 8787)
  - Uses: `hermes_webui/venv/bin/python server.py`

## Notes

- These are template services using systemd's `%i` (username) and `%h` (home directory) specifiers
- All services use the venv-isolated versions of hermes and dependencies (no global installation required)
- Log files are sent to journalctl instead of disk files
- Services automatically restart on failure with a 10-second delay
- Services are configured with rate limiting (max 5 restarts in 5 minutes)
- For user services, replace `USERNAME` with your login username (e.g., `hermes-gateway@alice`)
- Path `%h/hermes-suite/` assumes you have cloned the repository in your home directory
- **Important**: The services require that `hermes_upstream` and `hermes_webui` have been installed with their respective virtual environments set up (typically via `make install-local`)
