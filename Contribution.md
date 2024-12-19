
# Contribution Guide for Backend Benchmark Frameworks

## Overview

This guide provides details on how to contribute to the backend benchmarking project by adding or removing frameworks, running tests, and configuring the benchmarking environment. It also explains how to use the `start_tests.sh` script to include specific frameworks for testing.

---

## Adding a Framework

To add a new framework:

1. **Create the Framework Directory Structure**:
   - Use an existing framework directory as a reference.
   - Example structure:
     ```
     backends/<language>/<framework_name>
     backends/<language>/<framework_name>/<the app>
     backends/<language>/<framework_name>/tests
     backends/<language>/<framework_name>/docker_build_and_run.sh
     backends/<language>/<framework_name>/docker-compose.yml
     ```

2. **Prepare Scripts**:
   - Copy the `docker_build_and_run.sh` from an existing framework. Minimal edits are needed to adjust paths.
   - Prepare a `docker-compose.yml` file with the required services:
     - Database, all services uses postgres and its name should be `db`
     - Benchmark, it should be the main app and name should be `benchmark`
     - Tester, same configuration as the any other framework and name should be `tester`

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
- **Option 2**: Modify the `INCLUDE` variable in the `start_tests.sh` script to exclude the framework by not listing it.

---

## Running Tests

The benchmarking process is managed using the `scripts/start_tests.sh` script. This script identifies frameworks to test and supports running all frameworks or only specific frameworks specified in the `INCLUDE` variable.

### Using `start_tests.sh`

- **Purpose**: Runs benchmarks for all frameworks or only the ones specified in the `INCLUDE` variable.

---

### Examples

#### 1. Running All Frameworks

If you want to run all frameworks, do not set the `INCLUDE` variable.

**Command**:
```bash
bash scripts/start_tests.sh
```

**Output**:
```
Warning: INCLUDE variable not set. All scripts will be included.
Found 10 scripts in total:
./backends/go/mux/docker_build_and_run.sh
./backends/python/flask/docker_build_and_run.sh
...
```

---

#### 2. Including Specific Frameworks or Languages

The `INCLUDE` variable can be used to include tests for a specific language, a specific framework, or a combination of both.

##### Example 1: Include Specific Frameworks
To include only tests for `fast-api` and `mux` frameworks:

**Command**:
```bash
INCLUDE="fast-api,mux" bash scripts/start_tests.sh
```

**Output**:
```
Found 10 scripts in total:
./backends/go/mux/docker_build_and_run.sh
./backends/python/flask/docker_build_and_run.sh
Including ./backends/go/mux/docker_build_and_run.sh as it matches include pattern mux
Including ./backends/python/flask/docker_build_and_run.sh as it matches include pattern flask
Found scripts 10 and after filtering 2 scripts to run:
./backends/go/mux/docker_build_and_run.sh
./backends/python/flask/docker_build_and_run.sh
```

##### Example 2: Include Specific Languages
To include only tests for `python` and `go` languages:

**Command**:
```bash
INCLUDE="python,go" bash scripts/start_tests.sh
```
---

### Customizing Test Configurations

- **LOCUST_RUNTIME**:
  - Defines the runtime for each test in seconds.
  - Example:
    ```bash
    LOCUST_RUNTIME=10 bash scripts/start_tests.sh
    ```

- **Other LOCUST Variables**:
  - `LOCUST_USERS`: Number of simulated users (Default: 10,000).
  - `LOCUST_SPAWN_RATE`: User spawn rate per second (Default: 10).

  Example:
  ```bash
  LOCUST_USERS=5000 LOCUST_SPAWN_RATE=5 LOCUST_RUNTIME=20 bash scripts/start_tests.sh
  ```

---

## Configuration

- The environment variables required for tests are set by `internal_scripts/set_required_envs.sh`.
  - [Link to `set_required_envs.sh`](https://github.com/abdelaziz-mahdy/backend-benchmark/blob/main/internal_scripts/set_required_envs.sh)
  - Pass the required variables to any script:
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

## Notes on Scripts

### `start_tests.sh`

- **Includes logic to**:
  - Search for all `docker_build_and_run.sh` files.
  - Include scripts matching patterns in the `INCLUDE` variable.
  - Run the filtered scripts for `db_test` and `no_db_test`.

---

## Example Workflow

### Running All Tests:
```bash
bash scripts/start_tests.sh
```

### Including Specific Frameworks or Languages:
To include only `python` and `mux` frameworks:
```bash
INCLUDE="python,mux" bash scripts/start_tests.sh
```

---

## Contribution Guidelines

- **Adding a Framework**:
  - Place the `docker_build_and_run.sh` script in the corresponding language directory.
  - Example structure:
    ```
    backends/<language>/<framework>/docker_build_and_run.sh
    ```

---

Contributions that follow this guide will ensure consistency and maintainability. If you encounter any issues, feel free to raise them in the project's repository!