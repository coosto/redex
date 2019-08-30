# Redex

Cloud-native strong consistent masterless high available Redis implemented in Elixir.

[![Docker Image](https://images.microbadger.com/badges/version/coosto/redex.svg)](https://hub.docker.com/r/coosto/redex)
[![Build Status](https://travis-ci.org/coosto/redex.svg?branch=master)](https://travis-ci.org/coosto/redex)
[![Coverage Status](https://coveralls.io/repos/github/coosto/redex/badge.svg?branch=master)](https://coveralls.io/github/coosto/redex?branch=master)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)

## What is Redex?

Redex is an attempt to implement a Redis alternative with cloud-native apps in mind.

## What problem does Redex solve?

When running your applications in the cloud, you can easily scale up your app by running
multiple instances of it. Now let's assume your application uses Redis to cache some frequently
accessed resources or uses its pub/sub features to send events around. What happens when you
scale up your application? If you use Redis as a sidecar container to your app, by scaling up
your app, you will have standalone instances of Redis running, which is very difficult to manage.
Whenever you invalidate a cache entry, you probably want to invalidate it in all instances.
Whenever you publish an event, you most likely want that event being published in all instances.
You might also want your writes to be immediately available in all instances. What if you use atomic
increments/decrements? How can you perform atomic operations across the cluster?

The easiest solution is to run a single instance of Redis so that all instances of your app
communicate with that single Redis instance, but then you will lose the fast-access and low-latency
benefits of running Redis as a sidecar container, and also this single instance of Redis will become a
bottleneck and a single point of failure, preventing scalability and high-availability of your service.

You might also think of setting up a [Redis Cluster](https://redis.io/topics/cluster-tutorial),
but it has its drawbacks. It is difficult to setup, and it needs at least 3 master nodes
to work as expected, and 3 slaves for high-availability. Furthermore, it is mainly designed for
partitioning/sharding data sets that don't fit in a single instance or for write-intensive use cases
where a single instance can not handle all the writes, but in most cases, we don't need partitioning,
what we need is replication.

The official solution to have a replicated cluster of Redis nodes is [Redis Sentinel](https://redis.io/topics/sentinel),
but it also has its downsides. You need at least 3 Sentinel instances for a robust deployment,
you need Sentinel support in your clients, you need to do lots of tweaks and scripting
to get it to work in dynamic cluster environments like Kubernetes, and there is no guarantee
that acknowledged writes are retained during failures, since Redis uses asynchronous replication.

Redex came out of the need for a simple Redis solution that can be used just like a single local
Redis instance, while being able to form a replicated cluster once scaled up to multiple instances.
You can use Redex as a sidecar container for your apps/microservices, and easily scale up/down
your app without worrying about data inconsistencies between nodes. Redex is masterless,
clients don't need to know anything about cluster topology, they can interact with the local
Redex instance just like a single Redis instance, and unlike Redis, write operations are
strong consistent across the cluster.

## Is Redex a replacement for Redis?

Of course not. Redex is a solution for use cases where you need a replicated Redis cluster in a
dynamic cluster environment like Kubernetes, without all the hassles of official Redis solutions.
It is well suited for read-intensive use cases within a small cluster where strong consistency is
a requirement, but strong consistency makes write operations gradually slower by adding nodes, hence
Redex is not suitable for write-intensive use cases, nor clusters with a large number of nodes.

Redex does not support all the features and commands that Redis provides, it is only suitable
for data sets that fit into RAM, and it does not support partitioning data over multiple nodes,
nor persisting data to disk.

## Redex key features

- Uses battle-tested [Mnesia](http://erlang.org/doc/man/mnesia.html) in-memory database for storage
- Extremely fast Redis protocol parser implemented with [NimbleParsec](https://github.com/plataformatec/nimble_parsec)
- Writes are strong consistent across the cluster
- Reads are local, fast, and comparable to Redis
- Write performance is comparable to Redis in a single node setup, but gradually degrades by adding nodes
- Supports distributed Publish/Subscribe using erlang's distributed process groups (pg2)
- Supports automatic cluster formation/healing using Gossip protocol
- Supports automatic cluster formation/healing using Kubernetes selectors
- Ease of use (your app interacts with Redex like a local single-node Redis instance)
- In case of scaling up/down, data is preserved as far as one node remains running
- Automatic recovery from netsplits (quorum size can be configured to prevent data inconsistency)

## Configurations

Redex can be configured using the following env variables:

- REDEX_IP
  node's IP address on which other nodes can communicate with it.
  By default `hostname -i` is used to detect node's IP address.
- REDEX_K8S_NAMESPACE and REDEX_K8S_SELECTOR
  are used to discover redex pods using k8s API to form/heal redex cluster.
  in case these configs are not set, gossip strategy will be used to discover other nodes in the cluster.
- REDEX_GOSSIP_SECRET
  secret to be used in gossip strategy. Defaults to "REDEX".
- REDEX_QUORUM
  minimum number of nodes that redex cluster has to obtain in order to become operational. Defaults to 1.
- REDEX_PORT
  redex port number (defaults to 6379).

## Recovering from network partitions

By setting a proper quorum size, you can enforce consistency in netsplits.
In case of a network partition, the partition containing at least the quorum size number
of nodes will remain fully functional, and the other side will become read-only.
Once they are connected again, read-only part will update itself by copying data from the other side.

## Benchmarks

For benchmarks, we can use Redis official benchmark tool `redis-benchmark`.

First, make sure you have [docker-compose](https://docs.docker.com/compose/install/) installed,
then inside benchmark folder run the following command:

```
docker-compose up -d redex redis
```

This will start a single node of both Redex and Redis.

Now use these commands to run benchmarks for both Redis and Redex:

```
docker-compose run redis-benchmark
docker-compose run redex-benchmark
```

Here is the results on my machine:

```
# redis-benchmark
SET: 60975.61 requests per second
GET: 61349.69 requests per second

# redex-benchmark
SET: 33557.05 requests per second
GET: 41841.00 requests per second
```

Now lets scale redex to mutiple nodes and run benchmarks again:

```
REDEX_QUORUM=2 docker-compose up -d --scale redex=2 redex
docker-compose run redex-benchmark

REDEX_QUORUM=2 docker-compose up -d --scale redex=3 redex
docker-compose run redex-benchmark

REDEX_QUORUM=2 docker-compose up -d --scale redex=4 redex
docker-compose run redex-benchmark
```

Here is the results on my machine:

```
# redex-benchmark with 2 nodes
SET: 1974.72 requests per second
GET: 40650.41 requests per second

# redex-benchmark with 3 nodes
SET: 1234.72 requests per second
GET: 40816.32 requests per second

# redex-benchmark with 4 nodes
SET: 996.81 requests per second
GET: 42016.80 requests per second
```

Of course results would be different if you run each node on a different machine.

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
