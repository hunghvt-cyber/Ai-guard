# Gemini Docker Relay POC

This branch does **not** replace the current Gemini launcher.

Goal:

    Gemini container
      |
      | network_mode: none
      |
      +-- Unix socket --> host fixed relay --> github.com:22

The container receives no Docker socket and no host network.

The host relay accepts only a Unix socket and has a fixed TCP destination. The client cannot select an arbitrary destination.

## Security properties

- Docker `network_mode: none`
- `cap_drop: ALL`
- `no-new-privileges`
- no Docker socket
- no host network
- GitHub access only through the fixed relay
- direct DNS/network access must fail
- relay socket is mode 0600 inside a mode 0700 temporary directory

## Before running

Back up the current runtime first:

    du -sh /vol1/Docker/gemini
    tar -C /vol1/Docker -czf /vol1/Docker/gemini-backup-$(date +%Y%m%d-%H%M%S).tar.gz gemini

Do not modify `compose.yml`, `gemini-auto`, or `gemini-supervisor.py` during this POC.

## Run

The script uses the existing Gemini image through a temporary Compose override. It does not replace the running launcher.

    cd /vol1/Docker/Ai-guard
    git fetch origin
    git checkout enforcement/gemini-docker-relay-poc-20260921
    git pull --ff-only
    AI_GUARD_GITHUB_KEY=/home/admin/.ssh/github_gemini_ngusidan       ./poc/gemini-docker-relay/run-poc.sh

Expected result:

    NETWORK_DENY=PASS
    GITHUB_RELAY=PASS
    POC_PASS

A failure means STOP and restore nothing yet; the existing Gemini runtime remains untouched.

## FnNAS host SSH relay POC

After the GitHub relay POC passes, test the same isolated container against the FnNAS host SSH service:

    cd /vol1/Docker/Ai-guard
    git pull --ff-only
    ./poc/gemini-docker-relay/run-host-ssh-poc.sh

The host relay is fixed to:

    127.0.0.1:22

The container still has network_mode: none; it receives only the Unix relay socket and the existing FnNAS SSH private key. The SSH host key is collected on the host side and pinned into a temporary known_hosts file.

Expected result:

    NETWORK_DENY=PASS
    HOST_SSH_RELAY=PASS
    POC_PASS

This POC does not modify the production Gemini launcher.
