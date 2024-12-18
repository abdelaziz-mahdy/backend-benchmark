# Contribution Guide for Backend Benchmark Frameworks

## Overview

This guide explains how to contribute to the backend benchmarking project by adding or removing frameworks, running tests, and configuring the benchmarking environment.

---

## Adding a Framework

To add a new framework:

1. **Create the Framework Directory Structure**:
   - Use an existing framework directory as a reference.
   - For example:
     ```
     backends/<language>/<framework_name>
     backends/<language>/<framework_name>/<the app>
     backends/<language>/<framework_name>/tests
     backends/<language>/<framework_name>/docker_build_and_run.sh
     backends/<language>/<framework_name>/docker-compose.yml
     ```

2. **Prepare Scripts**:
   - Copy the `docker_build_and_run.sh` from an existing framework. Minimal edits are needed to adjust paths.
   - Prepare a `docker-compose.yml` file with standard services:
     - Database
     - Benchmark
     - Tester (e.g., Locust)

3. **Dockerfile for the App**:
   - Place the `Dockerfile` inside the source directory of the framework (e.g., `src`).
   - Example:
     ```
     backends/<language>/<framework_name>/<the app>/Dockerfile
     ```

4. **Add Test Files**:
   - Create a `tests` folder with at least two test scripts:
     - **`db_test.py`**: Includes tests for endpoints requiring database interactions.
     - **`no_db_test.py`**: Includes tests for endpoints not interacting with databases.

   Example content:
   - `db_test.py`:
     ```python
     from locust import FastHttpUser, task

     class NoteUser(FastHttpUser):
         @task
         def write_note(self):
             self.client.post("/notes/", json={"title": "Sample Note", "content": "This is a note content."})

         @task
         def read_notes(self):
             self.client.get("/notes/")
     ```
   - `no_db_test.py`:
     ```python
     from locust import FastHttpUser, task

     class NoteUser(FastHttpUser):
         @task
         def no_db_endpoint(self):
             self.client.get("/no_db_endpoint/")
     ```

---

## Removing a Framework

- **Option 1**: Delete the framework directory:
  ```
  backends/<language>/<framework_name>
  ```
- **Option 2**: Mark the framework directory to be ignored in `scripts/start_tests.sh`.

---

## Running Tests

The main script for launching tests is `scripts/start_tests.sh`.

- **Run All Benchmarks**:
  ```bash
  bash scripts/start_tests.sh
  ```

- **Customize Runtime**:
  - Example: Run benchmarks with a runtime of 10 seconds.
    ```bash
    LOCUST_RUNTIME=10 bash scripts/start_tests.sh
    ```

- **Set Locust Variables**:
  - Adjust the following environment variables as needed:
    - `LOCUST_USERS`: Number of simulated users. Default: 10,000.
    - `LOCUST_SPAWN_RATE`: User spawn rate per second. Default: 10.

  Example:
  ```bash
  LOCUST_USERS=5000 LOCUST_SPAWN_RATE=5 LOCUST_RUNTIME=20 bash scripts/start_tests.sh
  ```

---

## Configuration

- The environment variables required for tests are set by `internal_scripts/set_required_envs.sh`.
  - [Link to `set_required_envs.sh`](https://github.com/abdelaziz-mahdy/backend-benchmark/blob/main/internal_scripts/set_required_envs.sh)
  - Pass the required variables to `start_tests.sh`:
    ```bash
    source internal_scripts/set_required_envs.sh
    ```

---

## Directory Structure Example

Here’s an example of how a framework directory might look:

```
backends/go/mux/
├── benchmark/
├── results/
├── src/
│   ├── Dockerfile
│   ├── go.mod
│   ├── go.sum
│   ├── main.go
│   └── migration.sql
├── tests/
│   ├── db_test.py
│   ├── no_db_test.py
│   └── results/
├── docker_build_and_run.sh
└── docker-compose.yml
```

---

## Notes

- The `internal_scripts` directory contains reusable scripts that prevent duplication across frameworks.
- Example `docker-compose.yml` configurations should be identical except for framework-specific paths or environment variables.

Contributions that follow this guide will ensure consistency and maintainability. If you encounter any issues, feel free to raise them in the project's repository!