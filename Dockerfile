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

# Stage 2: Runtime
FROM debian:bookworm-slim AS app

RUN apt-get update -y && \
  apt-get install -y libstdc++6 openssl libncurses5 locales ca-certificates \
  && apt-get clean && rm -f /var/lib/apt/lists/*_*

RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen

ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

WORKDIR /app
RUN chown nobody /app

COPY --from=build --chown=nobody:root /app/_build/prod/rel/it_whist ./

USER nobody

CMD ["/bin/sh", "-c", "/app/bin/it_whist eval 'ItWhist.Release.migrate()' && exec /app/bin/server"]