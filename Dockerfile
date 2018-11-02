FROM elixir:alpine as builder

ENV MIX_ENV=prod REPLACE_OS_VARS=true TERM=xterm

WORKDIR /opt/app

RUN mix local.rebar --force &&\
    mix local.hex --force

# Cache elixir deps
COPY mix.exs mix.lock ./
RUN mix deps.get
COPY config ./config
RUN mix deps.compile

COPY . .

RUN mix release --env=prod --verbose \
    && mv _build/prod/rel/redex /opt/release \
    && mv /opt/release/bin/redex /opt/release/bin/start_server

FROM alpine:latest

RUN apk update && apk --no-cache --update add bash openssl-dev

ENV MIX_ENV=prod REPLACE_OS_VARS=true

WORKDIR /opt/app

EXPOSE 6379

COPY --from=builder /opt/release .

CMD ["bin/start_server", "foreground"]