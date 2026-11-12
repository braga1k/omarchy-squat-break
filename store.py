#!/usr/bin/env python3
"""Local squat ledger; serialized operations and atomic, durable writes."""
import argparse
import datetime as dt
import fcntl
import json
import math
import os
from pathlib import Path
import tempfile
import time

MAX_TOTAL = 9_000_000_000_000


def integer(value, low, high):
    if type(value) is not int or not low <= value <= high:
        raise ValueError('Invalid integer')
    return value


def timestamp(value):
    if type(value) not in (int, float) or not math.isfinite(value) or not 0 <= value <= 1e13:
        raise ValueError('Invalid timestamp')
    return value


def validate(s):
    if not isinstance(s, dict) or s.get('version') != 1:
        raise ValueError('Unsupported ledger')
    integer(s['interval'], 1, 1440)
    integer(s['suggested'], 1, 1000)
    if type(s['paused']) is not bool or type(s['due']) is not bool:
        raise ValueError('Invalid timer state')
    timestamp(s['next_at'])
    timestamp(s['remaining'])
    days = s['days']
    if not isinstance(days, dict) or len(days) > 36600:
        raise ValueError('Invalid daily ledger')
    for day, count in days.items():
        if dt.date.fromisoformat(day).isoformat() != day:
            raise ValueError('Invalid day')
        integer(count, 0, MAX_TOTAL)
    if sum(days.values()) > MAX_TOTAL:
        raise ValueError('Counter limit exceeded')
    last = s['last']
    if last is not None:
        if not isinstance(last, dict) or last['day'] not in days:
            raise ValueError('Invalid last entry')
        integer(last['count'], 1, 1000)
        if last['count'] > days[last['day']]:
            raise ValueError('Invalid undo entry')
    return s


def initial(now):
    return dict(version=1, interval=60, suggested=20, paused=False,
                due=False, next_at=now + 3600, remaining=3600, days={}, last=None)


def operate(s, action, args, now, today):
    alert = False
    if action == 'tick' and not s['paused'] and now >= s['next_at']:
        # A resume/restart sends at most one reminder, never a backlog.
        s['due'] = True
        s['next_at'] = now + s['interval'] * 60
        alert = True
    elif action == 'add':
        count = integer(int(args[0]), 1, 1000)
        if sum(s['days'].values()) + count > MAX_TOTAL:
            raise ValueError('Counter limit exceeded')
        s['days'][today] = s['days'].get(today, 0) + count
        s['last'] = dict(day=today, count=count)
        s['due'] = False
        s['next_at'] = now + s['interval'] * 60
        s['remaining'] = s['interval'] * 60
    elif action == 'undo' and s['last']:
        last = s['last']
        s['days'][last['day']] -= last['count']
        s['last'] = None
    elif action == 'pause' and not s['paused']:
        s['remaining'] = max(0, s['next_at'] - now)
        s['paused'] = True
    elif action == 'resume' and s['paused']:
        s['next_at'] = now + s['remaining']
        s['paused'] = False
    elif action == 'snooze':
        s['next_at'] = now + 300
        s['remaining'] = 300
        s['due'] = False
    elif action == 'settings':
        interval = integer(int(args[0]), 1, 1440)
        suggested = integer(int(args[1]), 1, 1000)
        # Editing the suggested count alone must not delay the reminder.
        if interval != s['interval']:
            s['next_at'] = now + interval * 60
            s['remaining'] = interval * 60
            s['due'] = False
        s['interval'], s['suggested'] = interval, suggested
    validate(s)
    remaining = s['remaining'] if s['paused'] else max(0, s['next_at'] - now)
    return dict(today=s['days'].get(today, 0), total=sum(s['days'].values()),
                interval=s['interval'], suggested=s['suggested'], paused=s['paused'],
                due=s['due'], remaining=math.ceil(remaining), alert=alert,
                canUndo=s['last'] is not None,
                history=[dict(day=d, count=c) for d, c in sorted(s['days'].items(), reverse=True)[:7]])


def run(directory, action, args, now=None, today=None):
    now = time.time() if now is None else now
    today = dt.datetime.fromtimestamp(now).date().isoformat() if today is None else today
    directory = Path(directory)
    directory.mkdir(mode=0o700, parents=True, exist_ok=True)
    path = directory / 'ledger.json'
    with open(directory / 'ledger.lock', 'a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        if path.exists():
            if path.stat().st_size > 2_000_000:
                raise ValueError('Ledger too large')
            s = validate(json.loads(path.read_text()))
        else:
            s = initial(now)
        before = json.dumps(s, sort_keys=True)
        result = operate(s, action, args, now, today)
        if not path.exists() or json.dumps(s, sort_keys=True) != before:
            fd, temporary = tempfile.mkstemp(prefix='.ledger-', dir=directory)
            try:
                with os.fdopen(fd, 'w') as out:
                    json.dump(s, out, ensure_ascii=False, sort_keys=True)
                    out.write('\n')
                    out.flush()
                    os.fsync(out.fileno())
                os.replace(temporary, path)
                directory_fd = os.open(directory, os.O_DIRECTORY)
                try:
                    os.fsync(directory_fd)
                finally:
                    os.close(directory_fd)
            finally:
                if os.path.exists(temporary):
                    os.unlink(temporary)
        return result


def main():
    p = argparse.ArgumentParser()
    p.add_argument('action', choices=['tick', 'status', 'add', 'undo', 'pause', 'resume', 'snooze', 'settings'])
    p.add_argument('values', nargs='*')
    p.add_argument('--data-dir', default=str(Path(os.getenv('XDG_DATA_HOME') or Path.home() / '.local/share') / 'omarchy-squats'))
    a = p.parse_args()
    expected = {'add': 1, 'settings': 2}.get(a.action, 0)
    try:
        if len(a.values) != expected:
            raise ValueError('Wrong argument count')
        print(json.dumps(run(a.data_dir, a.action, a.values)))
    except (ValueError, KeyError, TypeError, OSError) as error:
        print(json.dumps({'error': 'Could not read or save squat ledger'}))
        import sys
        print(str(error), file=sys.stderr)
        raise SystemExit(1)


if __name__ == '__main__':
    main()
