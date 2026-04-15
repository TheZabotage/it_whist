FROM elixir:1.19.5-otp-28-slim AS build

RUN apt-get update -y && apt-get install -y build-essential git curl \
  && apt-get clean && rm -f /var/lib/apt/lists/*_*

WORKDIR /app

RUN mix local.hex --force && mix local.rebar --force

ENV MIX_ENV=prod

COPY mix.exs mix.lock ./
RUN mix deps.get --only prod
RUN mkdir config

COPY config/config.exs config/prod.exs config/
RUN mix deps.compile

COPY assets assets
COPY priv priv
COPY lib lib

RUN mix compile
RUN mix assets.deploy

COPY config/runtime.exs config/
RUN mix release