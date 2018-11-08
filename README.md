# Redex

An Elixir implementaion of Redis

## Why Redex?

Running a distributed/replicated redis setup in a dynamic cluster environment like k8s is a nightmare.
Redis Sentinel is not suitable for dynamic clusters and is too complicated. It needs at least 3
sentinel instances and in case of failover it takes too long to elect a new master.
Also writes are not consistent across the cluster and replication is done in an asynchronous manner.

Redex solves all of the above issues.

- Uses replicated Mnesia in-memory database for storage
- Writes are strong consistent across the cluster
- Reads are local and as fast as Redis
- Write performance is comparable to Redis in a single node setup and gradually degrades by adding nodes.
- Supports automatic cluster formation/healing (using k8s API)
- Zero configuration setup
- In case of scaling up/down your data will be preserved as far as one pod remains running
- Quorum size can be configured to prevent data inconsistency in netsplits.

## Usage

Just drop an instance of redex container in your pod and you are done!
You can access it using Redis protocol from localhost in your pod.

## Settings

Redex can be configured using the following env variables:

- REDEX_IP must to configured to current node's IP address on which other nodes can communicate with it
- REDEX_SELECTOR is used to discover cluster nodes (Using k8s API)
- REDEX_QUORUM minimum number of nodes that redex cluster has to obtain in order to become operational
- REDEX_PORT redex port number (defaults to 6379).

## Recovering from network partitions

In case of a network partition, the partition containing at least the quorum size number of nodes will remain fully functional,
and other side will become readonly. Once they are connected again, readonly part will update itself by copying data from the other side.
This can be used to enforce consistency in netsplits.

## Supported Commands

For now only a small subset of the commands are supported:

- GET
- SET (without NX and XX arguments)
- DEL
- TTL
- PTTL
- PING
- SELECT
- FLUSHALL (without ASYNC argument)
- INFO (keyspace section only)
- QUIT
