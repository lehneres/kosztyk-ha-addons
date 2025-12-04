# ClamAV Daemon - Home Assistant Add-on

This add-on runs the **ClamAV daemon (`clamd`)** so other services
(e.g. your `clamav-rest-api` add-on or external apps) can scan files
via the standard ClamAV TCP protocol on port **3310**.

## Features

- Runs `clamd` as a TCP service
- Uses the official ClamAV database (`freshclam`)
- Configurable:
  - Listen IP (default: `0.0.0.0`)
  - Listen port (default: `3310`)
  - Max file size and stream length limits

## Configuration

Options in the add-on config:

```yaml
listen_ip: "0.0.0.0"
listen_port: 3310
max_file_size_mb: 250
stream_max_length_mb: 250
