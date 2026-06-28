# 🤖 Bakbot

Bakbot is a lightweight CLI tool that automatically backs up files by sending them as compressed ZIP archives to a Telegram chat on a configurable schedule.

## How It Works

On startup, Bakbot immediately sends a backup of the specified file to the configured Telegram chat. It then continues to run in the background, sending fresh backups according to the cron schedule you define. Each backup is zipped, timestamped, and delivered as a Telegram document with the filename and date in the caption.

## Prerequisites

- A Telegram bot token (create one via [@BotFather](https://t.me/BotFather))
- The chat ID of the Telegram user or group that should receive backups

## Installation

### Quick install (Linux, recommended)

The installer script automatically downloads the latest release for your architecture, walks you through configuration interactively, and sets up a systemd service so bakbot runs in the background and restarts on boot.

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/mehdikhody/bakbot/master/install.sh)
```

The script will prompt you for:

- **Telegram bot token** — from [@BotFather](https://t.me/BotFather)
- **Chat ID** — the user or group that receives the backups
- **File path** — the file or directory to back up
- **Schedule** — choose from presets (hourly / daily / weekly / monthly) or enter a custom cron expression
- **Proxy URL** — optional, leave blank to skip

Once done, bakbot starts immediately and is registered as a systemd service. Your settings are saved to `/etc/bakbot/config` (readable only by root).

#### Managing the service

```bash
systemctl status  bakbot      # check if it's running
systemctl restart bakbot      # apply config changes
systemctl stop    bakbot      # stop the bot
systemctl disable bakbot      # remove from startup
journalctl -u     bakbot -f   # follow live logs
```

To change settings after installation, edit the config file and restart:

```bash
nano /etc/bakbot/config
systemctl restart bakbot
```

### From source

```bash
git clone https://github.com/mehdikhody/bakbot.git
cd bakbot
go build -o bakbot .
```

## Usage

```
bakbot [flags]
```

### Flags

| Flag         | Short | Required | Description                 |
|--------------|-------| -------- |-----------------------------|
| `--token`    | `-t`  | ✅       | Telegram bot token          |
| `--file`     | `-f`  | ✅       | Path to the file to back up |
| `--chatId`   | `-c`  | ✅       | Telegram target chat ID     |
| `--schedule` | `-s`  |          | Cron schedule               |
| `--send`     |       |          | Send backup immediately     |
| `--proxy`    | `-p`  |          | HTTP proxy URL              |
| `--version`  | `-v`  |          | Print version information   |

### Example

```bash
bakbot \
  --token "123456:ABC-DEF..." \
  --file /var/lib/myapp/database.db \
  --chatId 987654321 \
  --schedule "@daily" \
  --send
```

This will immediately send a backup and then repeat every day at midnight.

## Cron Schedules

You can use standard cron expressions or one of the built-in shortcuts:

| Entry                   | Description                       | Equivalent    |
| ----------------------- | --------------------------------- | ------------- |
| `@yearly` / `@annually` | Once a year, Jan 1st at midnight  | `0 0 0 1 1 *` |
| `@monthly`              | Once a month, midnight on the 1st | `0 0 0 1 * *` |
| `@weekly`               | Once a week, midnight Sat/Sun     | `0 0 0 * * 0` |
| `@daily` / `@midnight`  | Once a day at midnight            | `0 0 0 * * *` |
| `@hourly`               | Once an hour                      | `0 0 * * * *` |

Custom cron expressions with seconds precision are also supported, e.g. `0 30 9 * * *` for every day at 09:30.

## Using a Proxy

If Telegram is not directly accessible from your server, pass an HTTP/HTTPS proxy URL:

```bash
bakbot \
  --token "123456:ABC-DEF..." \
  --file /path/to/file \
  --chatId 987654321 \
  --proxy "http://user:pass@proxy.example.com:8080"
```

## Stopping the Bot

Press `CTRL-C` or send a `SIGTERM` signal. Bakbot will gracefully shut down and clean up any temporary ZIP files.

## License

MIT
