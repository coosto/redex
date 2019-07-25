FROM elixir:alpine as builder

ENV MIX_ENV=prod

WORKDIR /opt/redex

RUN mix local.rebar --force &&\
    mix local.hex --force

# Cache dependencies
COPY mix.exs mix.lock ./
RUN mix deps.get --only prod
COPY config ./config
RUN mix deps.compile

COPY rel ./rel
COPY lib ./lib

RUN mix release --path=/opt/release

FROM alpine:3.9

RUN apk update && apk --no-cache --update add ncurses-libs openssl

WORKDIR /opt/redex

EXPOSE 6379

COPY --from=builder /opt/release .

CMD ["./bin/redex", "start"]
