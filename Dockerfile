FROM elixir:alpine as builder

RUN apk update && apk --no-cache --update add git

ENV MIX_ENV=prod REPLACE_OS_VARS=true TERM=xterm

WORKDIR /opt/redex

RUN mix local.rebar --force &&\
    mix local.hex --force

# Cache elixir deps
COPY mix.exs mix.lock ./
RUN mix deps.get
COPY config ./config
RUN mix deps.compile

COPY . .

RUN mix release --env=prod --verbose \
    && mkdir /opt/release \
    && tar xf _build/prod/rel/redex/releases/0.3.0/redex.tar.gz -C /opt/release

FROM alpine:latest

RUN apk update && apk --no-cache --update add bash openssl

ENV MIX_ENV=prod REPLACE_OS_VARS=true

WORKDIR /opt/redex

EXPOSE 6379

COPY --from=builder /opt/release .

CMD ["bin/redex", "foreground"]