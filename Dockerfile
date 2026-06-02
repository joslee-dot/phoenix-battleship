FROM hexpm/elixir:1.11.4-erlang-23.3.4-debian-bullseye-20260518 AS build

RUN apt-get update && apt-get install -y \
    build-essential \
    git \
    curl \
    xz-utils \
    && rm -rf /var/lib/apt/lists/*

ENV NODE_VERSION=16.20.2
RUN curl -fsSL https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-x64.tar.xz \
    | tar -xJ -C /usr/local --strip-components=1

WORKDIR /app

ENV MIX_ENV=prod

RUN mix local.hex --force && mix local.rebar --force

COPY mix.exs mix.lock ./
RUN mix deps.get --only prod
RUN mix deps.compile

COPY . .

RUN npm install --legacy-peer-deps
RUN node node_modules/brunch/bin/brunch build --production
RUN mix phoenix.digest
RUN mix compile

# Runtime stage
FROM hexpm/elixir:1.11.4-erlang-23.3.4-debian-bullseye-20260518

RUN apt-get update && apt-get install -y \
    libssl1.1 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

ENV MIX_ENV=prod
ENV PORT=8080

RUN mix local.hex --force

COPY --from=build /app /app

CMD ["mix", "phoenix.server"]
