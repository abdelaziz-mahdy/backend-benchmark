"""Machine fingerprint, so results are only compared within one machine."""
import os
import platform
import re
import subprocess


def _sysctl(name):
    return subprocess.run(["sysctl", "-n", name], capture_output=True, text=True).stdout.strip()


def describe():
    system = platform.system()
    if system == "Darwin":
        cpu = _sysctl("machdep.cpu.brand_string")
        cores = int(_sysctl("hw.ncpu"))
        ram_gb = round(int(_sysctl("hw.memsize")) / 2**30)
    else:
        cpu = "unknown"
        try:
            with open("/proc/cpuinfo") as f:
                for line in f:
                    if line.startswith("model name"):
                        cpu = line.split(":", 1)[1].strip()
                        break
            with open("/proc/meminfo") as f:
                kb = int(f.readline().split()[1])
            ram_gb = round(kb / 2**20)
        except OSError:
            ram_gb = 0
        cores = os.cpu_count() or 0
    return {
        "cpu": cpu,
        "cores": cores,
        "ram_gb": ram_gb,
        "os": f"{system} {platform.release()}",
        "slug": slug(cpu, cores, ram_gb),
    }


def slug(cpu, cores, ram_gb):
    name = cpu.lower()
    for noise in ("apple", "intel(r)", "core(tm)", "amd", "cpu", "processor", "with radeon graphics"):
        name = name.replace(noise, "")
    name = re.sub(r"@.*$", "", name)
    name = re.sub(r"[^a-z0-9]", "", name)[:16] or "cpu"
    return f"{name}-{cores}c-{ram_gb}g"


MIN_DOCKER_CPUS = 6


def cpusets(docker_cpus):
    """Split the Docker VM's CPUs: app 2, db 2 (3 from 10 CPUs up, since the
    DB scenarios otherwise measure Postgres), k6 the rest minus one spare for
    Docker itself from 10 CPUs up. Needs at least 6 CPUs."""
    if docker_cpus < MIN_DOCKER_CPUS:
        raise ValueError(f"Docker has {docker_cpus} CPUs; the benchmark needs at least {MIN_DOCKER_CPUS}")
    big = docker_cpus >= 10
    db_last = 4 if big else 3
    k6_first = db_last + 1
    k6_last = docker_cpus - 1 - (1 if big else 0)
    return {"app": "0-1", "db": f"2-{db_last}", "k6": f"{k6_first}-{k6_last}", "k6_cores": k6_last - k6_first + 1}
