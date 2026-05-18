# syntax=docker/dockerfile:1.7
# check=error=true

# -----------------------------------------------------------------------------
# Production-only Dockerfile. Built and deployed by Kamal.
#   docker build -t stripe_pdf_generation_demo .
#   docker run -d -p 80:80 -e RAILS_MASTER_KEY=<value> stripe_pdf_generation_demo
#
# Three stages for maximum caching:
#   1. base   -- runtime OS packages and ENV. Shared between build and final.
#   2. build  -- compiles native gem extensions, precompiles bootsnap, builds
#                assets. Throw-away; never shipped.
#   3. final  -- minimal runtime image with non-root user.
#
# Uses BuildKit cache mounts so apt downloads, gem downloads, and bootsnap
# caches survive across builds even when their layers are invalidated.
# -----------------------------------------------------------------------------

ARG RUBY_VERSION=4.0.0


# === base ====================================================================
FROM docker.io/library/ruby:${RUBY_VERSION}-slim AS base

WORKDIR /rails

# Runtime-only OS packages. Build tools (gcc, headers) live in the build stage.
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    rm -f /etc/apt/apt.conf.d/docker-clean && \
    apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      curl \
      libjemalloc2 \
      libvips \
      postgresql-client && \
    ln -s /usr/lib/$(uname -m)-linux-gnu/libjemalloc.so.2 /usr/local/lib/libjemalloc.so

ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development:test" \
    LD_PRELOAD="/usr/local/lib/libjemalloc.so"


# === build ===================================================================
FROM base AS build

# Build-only OS packages.
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    rm -f /etc/apt/apt.conf.d/docker-clean && \
    apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      build-essential \
      git \
      libpq-dev \
      libyaml-dev \
      pkg-config

# Gem install. Gemfile/Gemfile.lock are copied first so changes elsewhere in
# the source tree don't invalidate this layer.
COPY Gemfile Gemfile.lock ./
COPY vendor/ ./vendor/

RUN --mount=type=cache,target=/root/.bundle/cache,sharing=locked \
    --mount=type=cache,target=/usr/local/bundle/cache,sharing=locked \
    bundle install && \
    rm -rf "${BUNDLE_PATH}"/ruby/*/cache \
           "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    bundle exec bootsnap precompile -j 1 --gemfile

# Copy the rest of the app after gem install so source edits don't bust the
# gem layer.
COPY . .

# Precompile bootsnap for app + lib (-j 1 avoids a QEMU bug on cross-arch builds).
RUN bundle exec bootsnap precompile -j 1 app/ lib/

# Precompile assets without the real RAILS_MASTER_KEY.
RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile


# === final ===================================================================
FROM base

# Non-root runtime user.
RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash

USER 1000:1000

COPY --chown=rails:rails --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --chown=rails:rails --from=build /rails /rails

# Entrypoint prepares the DB (runs migrations if needed).
ENTRYPOINT ["/rails/bin/docker-entrypoint"]

# Thruster fronts Puma for asset caching + compression + X-Sendfile.
EXPOSE 80
CMD ["./bin/thrust", "./bin/rails", "server"]
