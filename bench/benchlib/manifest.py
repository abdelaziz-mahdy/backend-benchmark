"""Backend discovery from backends/<lang>/<framework>/backend.yaml."""
from dataclasses import dataclass, field
from pathlib import Path

import yaml

ALL_SCENARIOS = ["no_db", "db_read", "db_write", "db_mixed"]
DB_SCENARIOS = {"db_read", "db_write", "db_mixed"}


@dataclass
class Variant:
    id: str
    db: str = "postgres"  # "postgres" or "none"
    pgbouncer: bool = False


@dataclass
class Item:
    """One thing that gets benchmarked: a backend in one variant."""

    key: str  # results folder name, e.g. "go-mux" or "java-foam3-embedded"
    path: str  # "go/mux"
    app_dir: Path
    manifest: dict
    variant: Variant
    scenarios: list = field(default_factory=lambda: list(ALL_SCENARIOS))
    # Set for an older release listed under `history:` in backend.yaml. The
    # app is built with FRAMEWORK_VERSION=<version>; empty for the current one.
    history_version: str = ""

    @property
    def version(self):
        return self.history_version or self.manifest.get("version")

    @property
    def api_style(self):
        """"rest" (default), "serverpod_rpc" or "foam_rpc"; see bench/scenarios/lib.js."""
        return self.manifest.get("api_style", "rest")

    @property
    def health_path(self):
        return self.manifest.get("health_path", "/health")

    @property
    def profiles(self):
        profiles = []
        if self.variant.db == "postgres":
            profiles.append("postgres")
            if self.variant.pgbouncer:
                profiles.append("pgbouncer")
        return profiles

    @property
    def database_host(self):
        if self.variant.db != "postgres":
            return ""
        return "pgbouncer" if self.variant.pgbouncer else "db"


def load_items(root: Path):
    items = []
    for manifest_path in sorted(root.glob("backends/*/*/backend.yaml")):
        backend_dir = manifest_path.parent
        manifest = yaml.safe_load(manifest_path.read_text()) or {}
        rel = backend_dir.relative_to(root / "backends").as_posix()
        slug = rel.replace("/", "-")
        variants = [Variant(**v) for v in manifest.get("variants") or [{"id": "postgres"}]]
        scenarios = manifest.get("scenarios") or list(ALL_SCENARIOS)
        history = [str(h["version"]) for h in manifest.get("history") or []]
        for variant in variants:
            key = slug if len(variants) == 1 else f"{slug}-{variant.id}"
            for version in [""] + history:
                items.append(
                    Item(
                        # Docker image names can't hold "@", hence "-v".
                        key=f"{key}-v{version}" if version else key,
                        path=rel,
                        app_dir=backend_dir / "app",
                        manifest=manifest,
                        variant=variant,
                        scenarios=list(scenarios),
                        history_version=version,
                    )
                )
    return items


def filter_items(items, only):
    """Keep items whose path or key contains any comma-separated pattern."""
    if not only:
        return items
    patterns = [p.strip() for p in only.split(",") if p.strip()]
    return [i for i in items if any(p in i.path or p in i.key for p in patterns)]
