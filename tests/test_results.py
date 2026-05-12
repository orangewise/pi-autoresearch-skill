import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(
    0,
    str(
        Path(__file__).parent.parent
        / "plugins/autoresearch/skills/autoresearch/scripts"
    ),
)
from results import find_best, format_table, load_runs


def make_run(run, status, metric, description="test", commit="abc1234"):
    return {
        "run": run,
        "status": status,
        "metric": metric,
        "description": description,
        "commit": commit,
    }


def write_jsonl(runs):
    f = tempfile.NamedTemporaryFile(mode="w", suffix=".jsonl", delete=False)
    for r in runs:
        f.write(json.dumps(r) + "\n")
    f.close()
    return f.name


class TestLoadRuns(unittest.TestCase):
    def test_loads_valid_jsonl(self):
        path = write_jsonl([make_run(1, "baseline", 42.3), make_run(2, "kept", 39.1)])
        runs = load_runs(path)
        self.assertEqual(len(runs), 2)
        self.assertEqual(runs[0]["metric"], 42.3)

    def test_skips_blank_lines(self):
        f = tempfile.NamedTemporaryFile(mode="w", suffix=".jsonl", delete=False)
        f.write(json.dumps(make_run(1, "baseline", 42.3)) + "\n\n")
        f.close()
        self.assertEqual(len(load_runs(f.name)), 1)

    def test_empty_file(self):
        f = tempfile.NamedTemporaryFile(mode="w", suffix=".jsonl", delete=False)
        f.close()
        self.assertEqual(load_runs(f.name), [])


class TestFindBest(unittest.TestCase):
    def test_lower_is_better(self):
        runs = [
            make_run(1, "baseline", 42.3),
            make_run(2, "kept", 39.1),
            make_run(3, "reverted", 45.0),
        ]
        self.assertEqual(find_best(runs, "lower"), 39.1)

    def test_higher_is_better(self):
        runs = [
            make_run(1, "baseline", 0.7),
            make_run(2, "kept", 0.85),
            make_run(3, "reverted", 0.6),
        ]
        self.assertEqual(find_best(runs, "higher"), 0.85)

    def test_only_baseline_counts(self):
        runs = [make_run(1, "baseline", 42.3), make_run(2, "reverted", 10.0)]
        self.assertEqual(find_best(runs, "lower"), 42.3)

    def test_no_baseline_or_kept_returns_none(self):
        runs = [make_run(1, "reverted", 42.3), make_run(2, "failed", 10.0)]
        self.assertIsNone(find_best(runs, "lower"))

    def test_empty_runs_returns_none(self):
        self.assertIsNone(find_best([], "lower"))

    def test_checks_failed_not_considered_for_best(self):
        runs = [make_run(1, "baseline", 42.3), make_run(2, "checks_failed", 10.0)]
        self.assertEqual(find_best(runs, "lower"), 42.3)


class TestFormatTable(unittest.TestCase):
    def _table(self, runs, direction="lower"):
        return format_table(runs, direction)

    def test_best_marker_on_correct_run(self):
        runs = [make_run(1, "baseline", 42.3), make_run(2, "kept", 39.1)]
        table = self._table(runs, "lower")
        lines = table.splitlines()
        kept_line = next(l for l in lines if "kept" in l)
        self.assertIn("◄ best", kept_line)
        baseline_line = next(l for l in lines if "baseline" in l)
        self.assertNotIn("◄ best", baseline_line)

    def test_best_marker_higher_is_better(self):
        runs = [make_run(1, "baseline", 42.3), make_run(2, "kept", 39.1)]
        table = self._table(runs, "higher")
        lines = table.splitlines()
        baseline_line = next(l for l in lines if "baseline" in l)
        self.assertIn("◄ best", baseline_line)

    def test_all_statuses_appear(self):
        runs = [
            make_run(1, "baseline", 42.3),
            make_run(2, "kept", 39.1),
            make_run(3, "reverted", 41.0),
            make_run(4, "failed", 38.5),
            make_run(5, "checks_failed", 37.0),
        ]
        table = self._table(runs)
        for status in ("baseline", "kept", "reverted", "failed", "checks_failed"):
            self.assertIn(status, table)

    def test_footer_counts(self):
        runs = [
            make_run(1, "baseline", 42.3),
            make_run(2, "kept", 39.1),
            make_run(3, "reverted", 41.0),
            make_run(4, "failed", 38.5),
            make_run(5, "checks_failed", 37.0),
        ]
        table = self._table(runs)
        footer = [l for l in table.splitlines() if "Total:" in l][0]
        self.assertIn("Total: 5", footer)
        self.assertIn("Kept: 1", footer)
        self.assertIn("Failed: 2", footer)  # failed + checks_failed

    def test_footer_best_lower(self):
        runs = [make_run(1, "baseline", 42.3), make_run(2, "kept", 39.1)]
        footer = [l for l in self._table(runs, "lower").splitlines() if "Best" in l][0]
        self.assertIn("lower is better", footer)
        self.assertIn("39.1", footer)

    def test_footer_best_higher(self):
        runs = [make_run(1, "baseline", 42.3), make_run(2, "kept", 39.1)]
        footer = [l for l in self._table(runs, "higher").splitlines() if "Best" in l][0]
        self.assertIn("higher is better", footer)
        self.assertIn("42.3", footer)

    def test_no_best_when_only_reverted(self):
        runs = [make_run(1, "reverted", 42.3)]
        footer = [l for l in self._table(runs).splitlines() if "Best" in l][0]
        self.assertIn("None", footer)

    def test_checks_failed_column_fits(self):
        # checks_failed is 13 chars — must not break column alignment
        runs = [make_run(1, "checks_failed", 37.0)]
        table = self._table(runs)
        data_line = next(l for l in table.splitlines() if "checks_failed" in l)
        # The metric value should still appear after the status column
        self.assertIn("37.0", data_line)


if __name__ == "__main__":
    unittest.main()
