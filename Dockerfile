# syntax=docker/dockerfile:1
# check=error=true

# This Dockerfile is designed for production, not development. Render uses it directly; to run it by hand:
# docker build -t rails-app .
# docker run -d -p 80:80 -e SECRET_KEY_BASE=<any value> --name rails-app rails-app

# For a containerized dev environment, see Dev Containers: https://guides.rubyonrails.org/getting_started_with_devcontainer.html

# Make sure RUBY_VERSION matches the Ruby version in .ruby-version
ARG RUBY_VERSION=4.0.5
FROM docker.io/library/ruby:$RUBY_VERSION-slim AS base

# Rails app lives here
WORKDIR /rails

# Install base packages
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y curl libjemalloc2 postgresql-client && \
    ln -s /usr/lib/$(uname -m)-linux-gnu/libjemalloc.so.2 /usr/local/lib/libjemalloc.so && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Set production environment variables and enable jemalloc for reduced memory usage and latency.
ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development:test" \
    LD_PRELOAD="/usr/local/lib/libjemalloc.so" \
    MALLOC_CONF="dirty_decay_ms:1000,narenas:2,background_thread:true"

# Throw-away build stage to reduce size of final image
FROM base AS build

# Install packages needed to build gems and node modules
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential git libpq-dev libyaml-dev pkg-config && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Install an exact Node release from nodejs.org. Keep both architecture checksums
# beside the version so a changed or partial download can never enter the image.
ARG NODE_VERSION=24.18.0
ARG NODE_SHA256_AMD64=783130984963db7ba9cbd01089eaf2c2efb055c7c1693c943174b967b3050cb8
ARG NODE_SHA256_ARM64=6b4484c2190274175df9aa8f28e2d758a819cb1c1fe6ab481e2f95b463ab8508
ARG TARGETARCH
ENV PATH=/usr/local/node/bin:$PATH
RUN case "${TARGETARCH}" in \
      amd64) node_arch=x64; node_sha256="${NODE_SHA256_AMD64}" ;; \
      arm64) node_arch=arm64; node_sha256="${NODE_SHA256_ARM64}" ;; \
      *) echo "Unsupported Docker architecture: ${TARGETARCH}" >&2; exit 1 ;; \
    esac && \
    node_archive="node-v${NODE_VERSION}-linux-${node_arch}.tar.gz" && \
    curl --fail --location --retry 3 --output "/tmp/${node_archive}" \
      "https://nodejs.org/dist/v${NODE_VERSION}/${node_archive}" && \
    echo "${node_sha256}  /tmp/${node_archive}" | sha256sum --check --strict && \
    mkdir -p /usr/local/node && \
    tar --extract --gzip --file "/tmp/${node_archive}" --strip-components=1 --directory /usr/local/node && \
    rm "/tmp/${node_archive}"

# Install application gems
COPY vendor/* ./vendor/
COPY Gemfile Gemfile.lock ./

RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    # -j 1 disable parallel compilation to avoid a QEMU bug: https://github.com/rails/bootsnap/issues/495
    bundle exec bootsnap precompile -j 1 --gemfile

# Install node modules
COPY package.json package-lock.json ./
RUN npm ci

# Copy application code
COPY . .

# A second package-manager lock can make Rails silently choose a tool other
# than npm. Reject it after the full source tree enters the build context.
RUN bin/package-manager-check

# Precompile bootsnap code for faster boot times.
# -j 1 disable parallel compilation to avoid a QEMU bug: https://github.com/rails/bootsnap/issues/495
RUN bundle exec bootsnap precompile -j 1 app/ lib/

# Precompiling assets for production without requiring secret RAILS_MASTER_KEY
RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile

RUN rm -rf node_modules

# Final stage for app image
FROM base

# Run and own only the runtime files as a non-root user for security
RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash
USER 1000:1000

# Copy built artifacts: gems, application
COPY --chown=rails:rails --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --chown=rails:rails --from=build /rails /rails

# Entrypoint prepares the database.
ENTRYPOINT ["/rails/bin/docker-entrypoint"]

# Start server via Thruster by default, this can be overwritten at runtime
EXPOSE 80

# Container-level liveness: Thruster (port 80) proxies to the Rails health
# endpoint. Orchestrators (Compose, Render, an agent watching `docker ps`) read
# this to know the app booted, not just that the process is up.
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD curl -fsS http://localhost/up || exit 1

CMD ["./bin/thrust", "./bin/rails", "server"]
