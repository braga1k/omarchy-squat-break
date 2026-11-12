import concurrent.futures
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('store', Path(__file__).parents[1] / 'store.py')
store = importlib.util.module_from_spec(spec)
spec.loader.exec_module(store)


class LedgerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.directory = Path(self.temp.name)
        self.now = 1_800_000_000
        self.day = '2026-11-12'

    def run_action(self, action='status', *args, now=None, day=None):
        return store.run(self.directory, action, args, self.now if now is None else now, day or self.day)

    def test_initial_counts_and_persistence(self):
        self.assertEqual(self.run_action()['total'], 0)
        self.assertEqual(self.run_action('add', '20')['total'], 20)
        result = self.run_action('add', '13')
        self.assertEqual((result['today'], result['total']), (33, 33))
        self.assertEqual(self.run_action()['total'], 33)
        self.assertEqual((self.directory/'ledger.json').stat().st_mode & 0o777, 0o600)

    def test_midnight_and_undo_previous_day(self):
        self.run_action('add', '20')
        result = self.run_action(day='2026-11-13')
        self.assertEqual((result['today'], result['total']), (0, 20))
        result = self.run_action('undo', day='2026-11-13')
        self.assertEqual((result['today'], result['total'], result['canUndo']), (0, 0, False))
        self.run_action('undo')
        self.assertEqual(self.run_action()['total'], 0)

    def test_recurring_alerts_no_counts_or_catchup_spam(self):
        self.run_action()
        self.assertFalse(self.run_action('tick', now=self.now+3599)['alert'])
        self.assertTrue(self.run_action('tick', now=self.now+3600)['alert'])
        self.assertFalse(self.run_action('tick', now=self.now+3600)['alert'])
        result = self.run_action('tick', now=self.now+36000)
        self.assertTrue(result['alert'])
        self.assertEqual(result['total'], 0)
        self.assertFalse(self.run_action('tick', now=self.now+36001)['alert'])
        self.assertTrue(self.run_action('tick', now=self.now+39600)['alert'])

    def test_pause_resume_persists_remaining(self):
        self.run_action()
        self.run_action('pause', now=self.now+1000)
        self.assertFalse(self.run_action('tick', now=self.now+10000)['alert'])
        result = self.run_action('resume', now=self.now+10000)
        self.assertEqual(result['remaining'], 2600)
        self.assertFalse(self.run_action('tick', now=self.now+12599)['alert'])
        self.assertTrue(self.run_action('tick', now=self.now+12600)['alert'])

    def test_snooze_and_completed_set_restart_timer(self):
        self.run_action()
        self.run_action('snooze')
        self.assertFalse(self.run_action('tick', now=self.now+299)['alert'])
        self.assertTrue(self.run_action('tick', now=self.now+300)['alert'])
        result = self.run_action('add', '20', now=self.now+301)
        self.assertFalse(result['due'])
        self.assertEqual(result['remaining'], 3600)

    def test_settings_validate_and_do_not_count_reps(self):
        result = self.run_action('settings', '45', '15')
        self.assertEqual((result['interval'], result['suggested'], result['total']), (45, 15, 0))
        self.assertEqual(self.run_action('settings', '45', '10', now=self.now+100)['remaining'], 2600)
        before = (self.directory/'ledger.json').read_bytes()
        for args in [('settings', '0', '20'), ('add', '-1'), ('add', '1001'), ('add', '<img src=x>')]:
            with self.assertRaises(ValueError):
                self.run_action(*args)
            self.assertEqual((self.directory/'ledger.json').read_bytes(), before)

    def test_corrupt_ledger_is_never_overwritten(self):
        path = self.directory/'ledger.json'
        for content in ['{broken', '{"version": 42}', json.dumps(dict(store.initial(self.now), days={'<img src=x>': 20}))]:
            path.write_text(content)
            with self.assertRaises((ValueError, KeyError)):
                self.run_action('add', '20')
            self.assertEqual(path.read_text(), content)

    def test_parallel_monitors_cannot_double_alert_or_lose_counts(self):
        self.run_action()
        with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
            results = list(pool.map(lambda _: self.run_action('tick', now=self.now+3600), range(16)))
            self.assertEqual(sum(r['alert'] for r in results), 1)
            list(pool.map(lambda _: self.run_action('add', '10'), range(32)))
        self.assertEqual(self.run_action()['total'], 320)


if __name__ == '__main__':
    unittest.main()
