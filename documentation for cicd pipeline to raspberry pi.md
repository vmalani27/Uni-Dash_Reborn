# GitHub Self-Hosted Runner on Raspberry Pi

This guide covers the setup, maintenance, and troubleshooting of a self-hosted GitHub runner on a Raspberry Pi.

## 1. Environment & Prerequisites
- **Device:** Raspberry Pi (32-bit or 64-bit ARM).
- **OS:** Linux ARM.
- **Directory:** `~/actions-runner`.
- **Identity:** Managed via `.runner` and `.credentials` files.

## 2. Resetting the Runner
If the runner identity is invalidated (e.g., "registration has been deleted"), follow these steps to reset:

1. **Navigate to the runner directory:**
   ```bash
   cd ~/actions-runner
   ```
2. **Stop and uninstall the service:**
   ```bash
   sudo ./svc.sh stop
   sudo ./svc.sh uninstall
   ```
3. **Remove existing configuration:**
   ```bash
   ./config.sh remove
   # If above fails, manually clean up:
   rm -f .runner .credentials
   ```
4. **Re-register on GitHub:**
   Go to `Repo Settings -> Actions -> Runners -> New self-hosted runner` and copy the provided config command. Run it once.
5. **Reinstall as a service:**
   ```bash
   sudo ./svc.sh install
   sudo ./svc.sh start
   ```

## 3. Monitoring
- **Service Status:** Check if the runner is active locally:
  ```bash
  sudo ./svc.sh status
  ```
- **GitHub UI:** Verify the runner appears as **Online** in the GitHub repository settings.
- **Persistence:** The runner is configured as a systemd service; it will auto-start after reboots. To verify:
  ```bash
  systemctl is-enabled actions.runner.*.service
  ```

## 4. Debugging & Troubleshooting
Runners typically fail for two reasons: **Network failure** (retries automatically) or **Identity failure** (exits/service stops).

### Troubleshooting Connection/Invalidation
1. **Restart the service (First Step):**
   If the connection seems bad or the runner is offline, try restarting:
   ```bash
   sudo ./svc.sh start
   ```
2. **Check for Identity Invalidation:**
   If `sudo ./svc.sh status` shows the service is "inactive (dead)" despite a restart, check logs for:
   `“Failed to create a session. The runner registration has been deleted.”`
3. **If Identity is Invalidated:**
   Perform a **Full Reset** as described in Section 2.

> [!IMPORTANT]
> Avoid re-running `config.sh` without properly uninstalling the service first. Identity invalidation is usually triggered by GitHub's side and requires a clean re-registration.