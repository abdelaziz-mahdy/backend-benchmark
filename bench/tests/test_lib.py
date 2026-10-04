from pathlib import Path

from benchlib import machine, manifest, stats


def test_parse_mem_units():
    assert stats.parse_mem_mb("512MiB / 2GiB") == 512
    assert stats.parse_mem_mb("1.5GiB / 2GiB") == 1536
    assert round(stats.parse_mem_mb("512KiB / 2GiB"), 3) == 0.5
    assert stats.parse_mem_mb("garbage") == 0.0


def test_parse_frames_with_ansi_noise():
    text = '\x1b[H{"Name":"bench-benchmark-1","CPUPerc":"150.5%","MemUsage":"100MiB / 2GiB"}\x1b[K' \
           '{"Name":"bench-db-1","CPUPerc":"20%","MemUsage":"50MiB / 2GiB"}' \
           '{"Name":"other","CPUPerc":"1%","MemUsage":"1MiB / 2GiB"}'
    assert list(stats.parse_frames(text)) == [("app", 150.5, 100.0), ("db", 20.0, 50.0)]


def test_k6_run_container_role():
    assert stats.role_of("bench-k6-run-3f2a1b") == "k6"


def test_other_projects_are_ignored():
    assert stats.role_of("foambench-benchmark-1") is None
    assert stats.role_of("foambench-benchmark-1", "foambench") == "app"


def test_machine_slug():
    assert machine.slug("Apple M2 Pro", 10, 32) == "m2pro-10c-32g"
    assert machine.slug("Intel(R) Core(TM) i7-9700K CPU @ 3.60GHz", 8, 16) == "i79700k-8c-16g"


def write_manifest(root: Path, rel: str, text: str):
    d = root / "backends" / rel
    (d / "app").mkdir(parents=True)
    (d / "backend.yaml").write_text(text)


def test_load_items_variants_and_keys(tmp_path):
    write_manifest(tmp_path, "go/mux", "name: go mux\n")
    write_manifest(
        tmp_path,
        "java/foam3",
        "name: foam3\nvariants:\n  - id: embedded\n    db: none\n  - id: postgres\n    db: postgres\n",
    )
    write_manifest(
        tmp_path,
        "python/django-sync",
        "name: django\nvariants:\n  - id: postgres\n    db: postgres\n    pgbouncer: true\n",
    )
    items = {i.key: i for i in manifest.load_items(tmp_path)}
    assert set(items) == {"go-mux", "java-foam3-embedded", "java-foam3-postgres", "python-django-sync"}
    assert items["go-mux"].profiles == ["postgres"]
    assert items["java-foam3-embedded"].profiles == []
    assert items["java-foam3-embedded"].database_host == ""
    assert items["python-django-sync"].database_host == "pgbouncer"
    assert manifest.filter_items(list(items.values()), "foam3,mux") != []
    assert {i.key for i in manifest.filter_items(list(items.values()), "go/")} == {"go-mux"}


def test_cpusets_scale_with_docker_cpus():
    assert machine.cpusets(10) == {"app": "0-1", "db": "2-4", "k6": "5-8", "k6_cores": 4}
    assert machine.cpusets(6) == {"app": "0-1", "db": "2-3", "k6": "4-5", "k6_cores": 2}
    assert machine.cpusets(16)["k6"] == "5-14"
    import pytest
    with pytest.raises(ValueError):
        machine.cpusets(4)
