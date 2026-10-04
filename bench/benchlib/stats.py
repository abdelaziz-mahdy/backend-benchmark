"""Samples container CPU and memory from a streaming `docker stats`."""
import json
import re
import subprocess
import threading
import time

_FRAME = re.compile(r"\{[^{}]*\}")


def parse_mem_mb(value):
    """'123.4MiB / 2GiB' -> 123.4"""
    used = value.split("/")[0].strip()
    m = re.match(r"([\d.]+)\s*([KMG]i?B|B)", used)
    if not m:
        return 0.0
    num, unit = float(m.group(1)), m.group(2)
    scale = {"B": 1 / 2**20, "KiB": 1 / 1024, "KB": 1 / 1024, "MiB": 1, "MB": 1, "GiB": 1024, "GB": 1024}
    return num * scale.get(unit, 1)


def role_of(name, project="bench"):
    """Map this compose project's container names to roles
    (bench-benchmark-1 -> app); other containers are ignored."""
    if not name.startswith(f"{project}-"):
        return None
    if "-benchmark-" in name:
        return "app"
    if "-db-" in name:
        return "db"
    if "-pgbouncer-" in name:
        return "pgbouncer"
    if "-k6-" in name:
        return "k6"
    return None


def _percent(value):
    """'150.5%' -> 150.5; docker prints '--' while a container starts or stops."""
    try:
        return float(str(value).rstrip("%"))
    except ValueError:
        return None


def parse_frames(text, project="bench"):
    """Yield (role, cpu_percent, mem_mb) for every JSON frame in text.
    Frames without a CPU reading are skipped."""
    for raw in _FRAME.findall(text):
        try:
            frame = json.loads(raw)
        except json.JSONDecodeError:
            continue
        role = role_of(frame.get("Name", ""), project)
        if role is None:
            continue
        cpu = _percent(frame.get("CPUPerc", "0%"))
        if cpu is None:
            continue
        yield role, cpu, parse_mem_mb(frame.get("MemUsage", "0B / 0B"))


class Sampler:
    """Background reader; samples are (epoch_seconds, role, cpu, mem_mb)."""

    def __init__(self, project="bench"):
        self.project = project
        self.samples = []
        self._proc = None
        self._thread = None

    def start(self):
        self._proc = subprocess.Popen(
            ["docker", "stats", "--format", "{{json .}}"],
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            text=True,
            bufsize=1,
        )
        self._thread = threading.Thread(target=self._read, daemon=True)
        self._thread.start()

    def _read(self):
        for line in self._proc.stdout:
            now = time.time()
            # One bad frame must never end sampling for the rest of the rep.
            try:
                for role, cpu, mem in parse_frames(line, self.project):
                    self.samples.append((now, role, cpu, mem))
            except Exception as e:  # noqa: BLE001
                print(f"stats: skipped frame ({e})", flush=True)

    def stop(self):
        if self._proc:
            self._proc.terminate()
            try:
                self._proc.wait(timeout=5)
            except subprocess.TimeoutExpired:
                self._proc.kill()
        if self._thread:
            self._thread.join(timeout=5)

    def window(self, start, end):
        """Average cpu/mem per role between start and end."""
        acc = {}
        for t, role, cpu, mem in self.samples:
            if start <= t <= end:
                a = acc.setdefault(role, [0.0, 0.0, 0])
                a[0] += cpu
                a[1] += mem
                a[2] += 1
        return {role: {"cpu": a[0] / a[2], "mem_mb": a[1] / a[2]} for role, a in acc.items()}
