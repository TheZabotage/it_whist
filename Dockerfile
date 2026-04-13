# Stage 1: Build
FROM elixir:1.19.5-otp-28-slim AS build

# Install build deps
RUN apt-get update -y && apt-get install -y build-essential git curl nodejs npm \
  && apt-get clean && rm -f /var/lib/apt/lists/*_*

WORKDIR /app

# Install hex + rebar
RUN mix local.hex --force && mix local.rebar --force

ENV MIX_ENV=prod

# Install mix dependencies
COPY mix.exs mix.lock ./
RUN mix deps.get --only prod
RUN mkdir config

# Copy compile-time config
COPY config/config.exs config/prod.exs config/
RUN mix deps.compile

# Install Node / esbuild / tailwind deps and build assets
COPY assets assets
COPY priv priv
COPY lib lib

RUN cd assets && npm install
RUN mix assets.deploy

# Compile app and create release
COPY config/runtime.exs config/
RUN mix compile
RUN mix release

# Stage 2: Runtime (minimal image)
FROM debian:bookworm-slim AS app

RUN apt-get update -y && \
  apt-get install -y libstdc++6 openssl libncurses5 locales ca-certificates \
  && apt-get clean && rm -f /var/lib/apt/lists/*_*

# Set locale
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen

ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

WORKDIR /app
RUN chown nobody /app

# Copy release from build stage
COPY --from=build --chown=nobody:root /app/_build/prod/rel/it_whist ./

USER nobody

# This sets PHX_SERVER=true which tells the release to start the HTTP server
CMD ["/bin/sh", "-c", "/app/bin/it_whist eval 'ItWhist.Release.migrate()' && exec /app/bin/server"]