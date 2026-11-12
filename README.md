# Squat Break

A small [Omarchy](https://omarchy.org/) shell plugin that reminds you to stand up, do a few squats, and keep track of your progress.

Your bar shows the exercise icon, today's count, and the countdown to your next break:

```text
󰒡 40 - 59:59
```

Click it to record completed squats, see your daily and all-time totals, or adjust your reminders. The countdown updates every second and freezes while paused.

## Features

- Recurring desktop reminders: **every 60 minutes, suggesting 20 squats** by default.
- Manual recording of the number you actually completed.
- Today's count and an all-time total, saved between sessions.
- Undo the last entry, even if the date has changed.
- Snooze for five minutes, pause, or resume.
- Adjustable interval from 1 to 1,440 minutes and suggested set size from 1 to 1,000 squats.
- One shared ledger across monitors, with atomic writes and file locking.
- English and European Portuguese, following your Omarchy language.
- Local storage only: no accounts, telemetry, network requests, or extra packages.

## Requirements

- **Omarchy Quattro**, tested on **4.5.0-3**, with the native shell and its `qs.Commons` / `qs.Ui` components.
- Python 3, already provided by Omarchy. The helper uses only Python's standard library.

The plugin uses Omarchy's normal desktop notifications and respects Do Not Disturb. Notification sounds follow your desktop setup; this plugin does not replace or modify the notification daemon.

## Install

```sh
omarchy plugin add https://github.com/braga1k/omarchy-squat-break.git --enable
```

Omarchy places the widget beside your clock in `centerEnd`. To move it:

```sh
omarchy bar move b1k.squats --section right
```

The plugin ID is **`b1k.squats`**. If you already have a manually installed copy with that ID, back up that plugin folder and remove the existing copy before adding this repository. Your ledger is stored separately; keep it to preserve your counts.

## Use

| Control | Action |
| --- | --- |
| Left-click the bar widget | Open or close the panel |
| Right-click the bar widget | Pause or resume reminders |
| **Record … squats** | Add the confirmed number to today's count and all-time total |
| **Undo last entry** | Remove the last confirmed entry |
| **Snooze 5 min** | Move the next reminder five minutes ahead |
| **Save settings** | Apply the interval and suggested set size |
| **Pause / Resume** | Freeze the remaining time or continue from it |
| Click a reminder | Open the panel |
| Escape | Close the panel |

Only squats you explicitly record count. A reminder never records a completed set for you.

Recording a set starts a new full interval. Changing the interval also restarts the timer; changing only the suggested count does not delay your next break. Snoozing while paused changes the time you will have left when you resume.

The service checks reminder deadlines every 15 seconds, so an alert may arrive up to 15 seconds after the countdown reaches zero. After a long suspension or restart, it sends at most one overdue reminder instead of replaying a backlog. While the plugin or shell is disabled, it does not run a background reminder service.

## Your data

The ledger is stored at:

```text
~/.local/share/omarchy-squats/ledger.json
```

If `XDG_DATA_HOME` is set, the plugin uses `$XDG_DATA_HOME/omarchy-squats/ledger.json` instead.

It contains totals by local calendar date, the last entry available to undo, your settings, and the timer state. The all-time total is the sum of the saved daily totals. A new local date starts today's count at zero without changing previous days.

Back up this file to keep or move your history. Writes use an atomic replacement, `0600` file permissions, and a lock to protect simultaneous actions. If the ledger is invalid or cannot be saved, the panel reports the error and does not silently overwrite it.

## Update, disable, or remove

```sh
omarchy plugin update b1k.squats
omarchy plugin disable b1k.squats
omarchy plugin enable b1k.squats
omarchy plugin remove b1k.squats
```

Disabling or removing the plugin preserves your ledger. To erase your history too, remove the data directory yourself after backing it up.

## Troubleshooting

Reload plugin discovery if the widget has not appeared:

```sh
omarchy-shell shell rescanPlugins
```

If a code update remains cached, restart just the shell:

```sh
omarchy restart shell
```

Your saved counts and timer deadline survive a shell restart.

Inspect the current state:

```sh
omarchy-shell b1k.squats status
```

For a data error, check the ledger's permissions and restore a known-good backup if necessary. Keep a copy of the existing file first.

## Development

```sh
python3 -m unittest discover -s tests -v
omarchy plugin validate .
./tests/run-qml.sh
```

The unit tests cover persistence, date changes, undo, recurring reminders, suspend/resume timing, snoozing, settings, corrupted data, and concurrent operations. The QML smoke check runs in a separate test instance with temporary data; it requires an active desktop session. It also checks that markup-shaped strings cannot pass into shared notification and tooltip components as markup.

Plugin code runs inside Omarchy's shell with your user permissions. This plugin starts a short-lived local Python helper and calls Omarchy's notification command; it does not install a system service or request elevated privileges.

## License

[MIT](LICENSE).
