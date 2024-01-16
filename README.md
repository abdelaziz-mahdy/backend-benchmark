# Backend Benchmark

**Repository to Track Benchmarks**

## Introduction
This repository serves as a comprehensive resource for comparing backend technologies based on speed and load capabilities. Through detailed benchmarks, we aim to assist developers and decision-makers in choosing the most suitable backend framework for their specific needs. The benchmarks focus on write and read operations, reflecting real-world usage scenarios.

## Prerequisites
- Docker must be installed on the system to run the benchmarks.
- To launch each test and create the graphs, run the script: `scripts/start_tests.sh`.

## Completed Benchmarks
- Python
  - Framework: Django
    - Django Sync
      - Test Types:
        - Write: POST request (writes one note)
        - Read: GET request (reads 100 notes)
    - Django Async
      - Test Types:
        - Write: POST request (writes one note)
        - Read: GET request (reads 100 notes)

- Dart
  - Framework: Serverpod
    - Test Types:
      - Write: POST request (writes one note)
      - Read: POST request (reads 100 notes)

Testing Tool: Locust 
  - Configuration: Which can be changed from `scripts/start_tests.sh`
    - Users: 5000
    - Spawn Rate: 10 users/second
    - Test Duration: 500 seconds

## Pending Benchmarks
1. **Go**
2. **Rust**
3. **JavaScript/TypeScript**

Tests consist of write and read requests. Write operations involve writing a single note, while read operations involve retrieving 100 notes.

## Benchmark Results


| Attribute            | Django Async Backend | Django Sync Backend | Dart Serverpod Backend |
|----------------------|----------------------|---------------------|------------------------|
| Benchmark Graph      | ![Django Async Backend Benchmark Graph](/backends/python/django-async/tests/results/graph.png) | ![Django Sync Backend Benchmark Graph](/backends/python/django-sync/tests/results/graph.png) | ![Dart Serverpod Backend Benchmark Graph](/backends/dart/server-pod/benchmark/tests/results/graph.png) |



These benchmarks provide valuable insights into the performance of various backend technologies. By analyzing these results, users can make informed decisions based on the specific requirements of their applications, such as speed and capacity to handle loads.
