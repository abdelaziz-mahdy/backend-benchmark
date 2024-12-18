# Backend Benchmark Repository

## Table of Contents
- [Introduction](#introduction)
- [Prerequisites](#prerequisites)
- [Completed Benchmarks](#completed-benchmarks)
  - [Python](#python)
  - [Dart](#dart)
  - [JavaScript/TypeScript](#javascripttypescript)
  - [C#](#c)
  - [Go](#go)
  - [Rust](#rust)
- [Testing Tool: Locust](#testing-tool-locust)
- [Benchmark Visualization](#benchmark-visualization)
- [Database Endpoints](#database-endpoints)
- [Static Endpoints](#static-endpoints)

## Introduction
This repository serves as a comprehensive resource for comparing backend technologies based on speed and load capabilities. Our benchmarks focus on write and read operations, as well as requests to static endpoints, reflecting real-world usage scenarios to assist developers and decision-makers in choosing the most suitable backend framework for their needs.

## Prerequisites
- Docker installed on the system to run the benchmarks.
- The `scripts/start_tests.sh` script is used to launch each test and create the graphs.

## Completed Benchmarks
Benchmarks are categorized into:
1. **Database Tests (`db_test`):** Involving database operations such as read and write requests.
2. **Static Endpoint Tests (`no_db_test`):** Involving requests to static endpoints without database interaction.

### Python
- **Django** (Sync and Async) - Connection Pooling with PgBouncer.

### Dart
- **Serverpod**

### JavaScript/TypeScript
- **Express** (Node and Bun)

### C#
- **.Net Core**

### Go

### Rust

## Testing Tool: Locust
- **Configuration:**
  - Users: 10000
  - Spawn Rate: 10 users/second
  - Test Duration: 1000 seconds

## Benchmark Visualization
Visual comparisons for database endpoints and static endpoints are provided to showcase performance differences across technologies.

# Database Endpoints

## Comparison Graph with db endpoints
![Comparison Graph](comparison_graph_db_test.png?v=1734546950)

## Detailed Graphs for each backend
- **go mux db_test**
![go mux db_test Benchmark Graph](backends/go/mux/tests/results/db_test/graph.png?v=1734546950)

- **c_sharp dot net db_test**
![c_sharp dot net db_test Benchmark Graph](backends/c_sharp/dot-net/tests/results/db_test/graph.png?v=1734546950)

- **python django sync db_test**
![python django sync db_test Benchmark Graph](backends/python/django-sync/tests/results/db_test/graph.png?v=1734546950)

- **python fast api db_test**
![python fast api db_test Benchmark Graph](backends/python/fast-api/tests/results/db_test/graph.png?v=1734546950)

- **python django async db_test**
![python django async db_test Benchmark Graph](backends/python/django-async/tests/results/db_test/graph.png?v=1734546950)

- **dart server pod db_test**
![dart server pod db_test Benchmark Graph](backends/dart/server-pod/tests/results/db_test/graph.png?v=1734546950)

- **rust actix web db_test**
![rust actix web db_test Benchmark Graph](backends/rust/actix-web/tests/results/db_test/graph.png?v=1734546950)

- **java spring boot db_test**
![java spring boot db_test Benchmark Graph](backends/java/spring-boot/tests/results/db_test/graph.png?v=1734546950)

- **javascript express bun db_test**
![javascript express bun db_test Benchmark Graph](backends/javascript/express-bun/tests/results/db_test/graph.png?v=1734546950)

- **javascript express node db_test**
![javascript express node db_test Benchmark Graph](backends/javascript/express-node/tests/results/db_test/graph.png?v=1734546950)



# Static Endpoints

## Comparison Graph with static endpoints
![Comparison Graph](comparison_graph_no_db_test.png?v=1734546950)

## Detailed Graphs for each backend
- **go mux no_db_test**
![go mux no_db_test Benchmark Graph](backends/go/mux/tests/results/no_db_test/graph.png?v=1734546950)

- **c_sharp dot net no_db_test**
![c_sharp dot net no_db_test Benchmark Graph](backends/c_sharp/dot-net/tests/results/no_db_test/graph.png?v=1734546950)

- **python django sync no_db_test**
![python django sync no_db_test Benchmark Graph](backends/python/django-sync/tests/results/no_db_test/graph.png?v=1734546950)

- **python fast api no_db_test**
![python fast api no_db_test Benchmark Graph](backends/python/fast-api/tests/results/no_db_test/graph.png?v=1734546950)

- **python django async no_db_test**
![python django async no_db_test Benchmark Graph](backends/python/django-async/tests/results/no_db_test/graph.png?v=1734546950)

- **dart server pod no_db_test**
![dart server pod no_db_test Benchmark Graph](backends/dart/server-pod/tests/results/no_db_test/graph.png?v=1734546950)

- **rust actix web no_db_test**
![rust actix web no_db_test Benchmark Graph](backends/rust/actix-web/tests/results/no_db_test/graph.png?v=1734546950)

- **java spring boot no_db_test**
![java spring boot no_db_test Benchmark Graph](backends/java/spring-boot/tests/results/no_db_test/graph.png?v=1734546950)

- **javascript express bun no_db_test**
![javascript express bun no_db_test Benchmark Graph](backends/javascript/express-bun/tests/results/no_db_test/graph.png?v=1734546950)

- **javascript express node no_db_test**
![javascript express node no_db_test Benchmark Graph](backends/javascript/express-node/tests/results/no_db_test/graph.png?v=1734546950)


