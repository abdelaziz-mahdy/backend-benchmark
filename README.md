# Backend Benchmark

**Repository to Track Benchmarks**

## Introduction

This repository serves as a comprehensive resource for comparing backend technologies based on speed and load capabilities. Through detailed benchmarks, we aim to assist developers and decision-makers in choosing the most suitable backend framework for their specific needs. The benchmarks focus on write and read operations, reflecting real-world usage scenarios.

## Prerequisites

- Docker must be installed on the system to run the benchmarks.
- To launch each test and create the graphs, run the script: `scripts/start_tests.sh`.


## Completed Benchmarks

The benchmarks are categorized into two sections:

1. **Database Tests (`db_test`)**: These tests involve database operations such as read and write requests.
2. **Static Endpoint Tests (`no_db_test`)**: These tests involve requests to static endpoints, which do not interact with the database.

### Python

- **Framework:** Django
  - **Django Sync**
    - **Test Types:**
      - **Write (db_test):** POST request (writes one note)
      - **Read (db_test):** GET request (reads 100 notes)
      - **Static Endpoints (no_db_test):**
        - **Static Text 1 and 2:** GET requests (return static text)
    - **Connection Pooling (pgbouncer):** PgBouncer used for managing database connections.
  - **Django Async**
    - **Test Types:** Similar to Django Sync.

### Dart

- **Framework:** Serverpod
  - **Test Types:**
    - **Write (db_test):** POST request (writes one note)
    - **Read (db_test):** POST request (reads 100 notes)
    - **Static Endpoints (no_db_test):**
      - **Static Text 1 and 2:** POST requests (return static text)

### JavaScript/TypeScript

- **Framework:** Express (Node and Bun)
  - **Test Types:** Same as Python Django Sync, but without pgbouncer.

### C#

- **Framework:** .Net Core
  - **Test Types:** Same as Python Django Sync, but without pgbouncer .

### Go
  - **Test Types:** Same as Python Django Sync, but without pgbouncer.

### Rust 
  - **Test Types:** Same as Python Django Sync, but without pgbouncer.
### Testing Tool: Locust

- **Configuration:**
  - **Users:** 10000
  - **Spawn Rate:** 10 users/second
  - **Test Duration:** 1000 seconds



## Benchmark Visualization

Before delving into the detailed benchmark results, let's visualize the performance differences across the various backend technologies. These visual representations offer an immediate understanding of the comparative performance in terms of speed and load handling capabilities. Below are the benchmark graphs for different metrics.


# Database Endpoints

## Comparison Graph with db endpoints

![Comparison Graph](comparison_graph_db_test.png?v=1707922326)

## Detailed Graphs for each backend

| Attribute       | Django Async Backend                                                                                                | Django Sync Backend                                                                                               | Dart Serverpod Backend                                                                                            | Express Bun Backend                                                                                                   | Express Node Backend                                                                                                    | C# .NET Backend                                                                                            | Go Mux Backend                                                                                           |
| --------------- | ------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------- |
| Benchmark Graph | ![Django Async Backend Benchmark Graph](/backends/python/django-async/tests/results/db_test/graph.png?v=1707922326) | ![Django Sync Backend Benchmark Graph](/backends/python/django-sync/tests/results/db_test/graph.png?v=1707922326) | ![Dart Serverpod Backend Benchmark Graph](/backends/dart/server-pod/tests/results/db_test/graph.png?v=1707922326) | ![Express Bun Backend Benchmark Graph](/backends/javascript/express-bun/tests/results/db_test/graph.png?v=1707922326) | ![Express Node Backend Benchmark Graph](/backends/javascript/express-node/tests/results/db_test/graph.png?v=1707922326) | ![C# .NET Backend Benchmark Graph](/backends/c_sharp/dot-net/tests/results/db_test/graph.png?v=1707922326) | ![Go Mux Backend Benchmark Graph](/backends/go/mux/tests/results/db_test/graph.png?v=1707922326)          |

# Static Endpoints

## Comparison Graph with static endpoints

![Comparison Graph](comparison_graph_no_db_test.png?v=1707922326)

## Detailed Graphs for each backend

| Attribute       | Django Async Backend                                                                                                   | Django Sync Backend                                                                                                  | Dart Serverpod Backend                                                                                               | Express Bun Backend                                                                                                      | Express Node Backend                                                                                                       | C# .NET Backend                                                                                               | Go Mux Backend                                                                                              |
| --------------- | ---------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------- |
| Benchmark Graph | ![Django Async Backend Benchmark Graph](/backends/python/django-async/tests/results/no_db_test/graph.png?v=1707922326) | ![Django Sync Backend Benchmark Graph](/backends/python/django-sync/tests/results/no_db_test/graph.png?v=1707922326) | ![Dart Serverpod Backend Benchmark Graph](/backends/dart/server-pod/tests/results/no_db_test/graph.png?v=1707922326) | ![Express Bun Backend Benchmark Graph](/backends/javascript/express-bun/tests/results/no_db_test/graph.png?v=1707922326) | ![Express Node Backend Benchmark Graph](/backends/javascript/express-node/tests/results/no_db_test/graph.png?v=1707922326) | ![C# .NET Backend Benchmark Graph](/backends/c_sharp/dot-net/tests/results/no_db_test/graph.png?v=1707922326) | ![Go Mux Backend Benchmark Graph](/backends/go/mux/tests/results/no_db_test/graph.png?v=1707922326)       |

