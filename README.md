# Redex

An Elixir implementaion of Redis

## Why Redex

Running a distributed/replicated redis setup in a dynamic cluster environment like k8s is a nightmare.
Redis Sentinel is not suitable for dynamic clusters and is too complicated. It needs at least 3
sentinel instances and in case of failover it takes too long to elect a new master.
Also writes are not consistent across the cluster and replication is done in an asynchronous manner.

Redex solves all of the above issues.

- Uses replicated Mnesia in-memory database for storage
- Writes are strong consistent across the cluster
- Reads are local and fast
- Read/Write performance is comparable to Redis in a single node setup
- Supports automatic cluster formation/healing (using k8s API)
- Zero configuration setup
- In case of scaling up/down your data will be preserved as far as one pod remains running

## Usage

Just drop an instance of redex container in your pod and you are done!
You can access it using Redis protocol from localhost in your pod.

## Supported Commands

For now only a small subset of the commands are supported:

- GET
- SET (without NX and XX arguments)
- DEL
- TTL
- PTTL
- PING
- SELECT
- INFO (keyspace section only)
- QUIT
