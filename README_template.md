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
![Comparison Graph](comparison_graph_db_test.png?v={version})

## Detailed Graphs for each backend
{db_endpoint_graphs}

# Static Endpoints

## Comparison Graph with static endpoints
![Comparison Graph](comparison_graph_no_db_test.png?v={version})

## Detailed Graphs for each backend
{static_endpoint_graphs}
