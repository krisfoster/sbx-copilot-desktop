# syntax=docker/dockerfile:1
# Debian, not Docker's Ubuntu-based shell image: Ubuntu ships Chromium only as a snap stub, which cannot run in a
# container, while Debian has a real arm64 deb. A bare distro image must still carry the runtime's platform floor
# (bash, sh, curl, git, a CA store, and a non-root `agent` user with uid 1000 and home /home/agent), so it is
# rebuilt below to match what docker.io/sbx/shell-image provides.
ARG BASE_IMAGE=docker.io/library/debian:trixie-slim
FROM ${BASE_IMAGE}

ENV DEBIAN_FRONTEND=noninteractive \
    BASH_ENV=/etc/sandbox-persistent.sh

# Platform floor: bash, curl, git, CA store, tini (PID 1), sudo and ssh as in the shell image.
# chromium: the browser, run in --app mode. dbus + gnome-keyring + libsecret: a Secret Service so Chromium keeps the
# sign-in across restarts. fonts: without them most of the page renders as boxes.
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      bash ca-certificates curl git jq openssh-client sudo tini \
      chromium dbus dbus-user-session gnome-keyring libsecret-1-0 \
      fonts-liberation fonts-noto-core fonts-noto-color-emoji \
 && rm -rf /var/lib/apt/lists/* \
 && chromium --version \
 && command -v dbus-run-session \
 && command -v gnome-keyring-daemon \
 && groupadd --gid 1000 agent \
 && useradd --uid 1000 --gid 1000 --create-home --home-dir /home/agent --shell /bin/bash agent \
 && usermod -aG sudo agent \
 && echo 'agent ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/agent \
 && chmod 0440 /etc/sudoers.d/agent \
 && install -d -o agent -g agent /home/agent/workspace \
 && : > /etc/sandbox-persistent.sh

# No --chmod on the COPY: it would also reset the mode of the parent directories. chmod the two scripts instead.
COPY --chown=0:0 overlay/opt/copilot-desktop/bin/ /opt/copilot-desktop/bin/
RUN chmod 0755 /opt/copilot-desktop/bin/copilot-session /opt/copilot-desktop/bin/copilot-bus

USER agent
WORKDIR /home/agent/workspace

# The host runs this as the agent. The session script waits for the Wayland socket, then starts Chromium under a
# private D-Bus session. tini -s reaps Chromium's orphaned helper processes.
ENTRYPOINT ["tini", "-s", "--", "/opt/copilot-desktop/bin/copilot-session"]
