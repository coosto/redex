# Redex

Cloud-native strong consistent masterless high available Redis implemented in Elixir.

## What is Redex?

Redex is an attempt to implement a Redis alternative with cloud-native apps in mind.
It can be used as a sidecar container for your app, so that you can easily scale up/down
your app and be sure that your cache storage is in sync between all replicas.
Your app only interacts with its local sidecar cache and doesn't need to know anything
about cluster topology.
Redex cluster is similar to a high available Redis Sentinel setup, but unlike Redis
which asynchounosly replicates master node to slaves, Redex is masterless
and write operations are strong consistent across the cluster.

## Why not Redis Sentinel?

Redis Sentinel is not suitable for dynamic clusters. You can not scale it up and down
dynamically, and it needs at least 3 Sentinel instances, and in case of failure it takes
some time to elect a new master.
Also writes are not consistent across the cluster and replication is asynchronous.
But Redex is masterless, strong consistent, dynamically scalable, and works
even with one node.

## What use cases Redex is/isn't suitable for?

Redex is well suited for read intensive use cases within a small cluster where
strong consistency is a requirement. But strong consistency makes write operations
gradually slower by adding nodes, hence Redex is not suitable for write intensive use cases,
nor for clusters with a large number of nodes.

Redex is only suitable for datasets that fit into ram, it does not support partitioning
data over multiple nodes, nor persisting data to disk.

## Redex key features

- Uses battle-tested Mnesia in-memory database for storage
- Extremely fast Redis protocol parser implemented with NimbleParsec
- Writes are strong consistent across the cluster
- Reads are local and fast, and comparable to Redis
- Write performance is comparable to Redis in a single node setup, but gradually degrades by adding nodes
- Supports distributed Publish/Subscribe using erlang's distributed process groups (pg2)
- Supports automatic cluster formation/healing using Gossip protocol
- Supports automatic cluster formation/healing using Kubernetes selectors
- Ease of use (your app interacts with Redex like a local single-node Redis instance)
- In case of scaling up/down data is preserved as far as one node remains running
- Automatic recovery from netsplits (quorum size can be configured to prevent data inconsistency)

## Configurations

Redex can be configured using the following env variables:

- REDEX_IP
  must be configured to current node's IP address on which other nodes can communicate with it
- REDEX_CLUSTER
  cluster strategy k8s/gossip (default: k8s)
- REDEX_K8S_NAMESPACE and REDEX_K8S_SELECTOR
  is used to discover cluster nodes (Using k8s API)
- REDEX_GOSSIP_SECRET
  secret to be used in gossip strategy
- REDEX_QUORUM
  minimum number of nodes that redex cluster has to obtain in order to become operational
- REDEX_PORT
  redex port number (defaults to 6379).

## Recovering from network partitions

By setting a proper quorum size, you can enforce consistency in netsplits.
In case of a network partition, the partition containing at least the quorum size number
of nodes will remain fully functional, and other side will become readonly.
Once they are connected again, readonly part will update itself by copying data from the other side.

## Supported Commands

For now only a small subset of the commands are supported:

- GET
- MGET
- SET
- SETEX
- MSET
- GETSET
- INCR
- INCRBY
- DECR
- DECRBY
- DEL
- LPUSH
- LPOP
- LLEN
- LRANGE
- LINDEX
- RPUSH
- RPOP
- PUBLISH
- SUBSCRIBE
- EXPIRE
- PEXPIRE
- TTL
- PTTL
- PING
- SELECT
- FLUSHALL (without ASYNC argument)
- INFO (keyspace section only)
- QUIT

## License

Redex source code is released under Apache 2 License.

## Credits

Made with :heart: by [@farhadi](https://github.com/farhadi), supported by [Coosto](https://www.coosto.com/en), [@coostodev](https://twitter.com/coostodev)
