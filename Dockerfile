ARG VERSION=master
FROM python:3.12-slim-bullseye AS builder
LABEL maintainer="ElderBlade <10776624+ElderBlade@users.noreply.github.com>"
ARG VERSION

# Install build dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    git build-essential libssl-dev libleveldb-dev && \
    rm -rf /var/lib/apt/lists/*

# Create a virtual environment
RUN python -m venv /venv

# Install Python dependencies
RUN /venv/bin/pip install --upgrade pip setuptools wheel && \
    /venv/bin/pip install aiohttp pylru plyvel websockets uvloop

# Install ElectrumX
RUN git clone -b $VERSION https://github.com/spesmilo/electrumx.git && \
    cd electrumx && \
    /venv/bin/pip install .

# Final image
FROM python:3.12-slim-bullseye
ARG VERSION

# Install runtime dependencies only
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    libleveldb1d && \
    rm -rf /var/lib/apt/lists/*

# Copy virtual environment from builder
COPY --from=builder /venv /venv
COPY --from=builder /electrumx /electrumx

# Copy custom scripts if needed
COPY ./bin /usr/local/bin
RUN chmod a+x /usr/local/bin/*

# Set environment variables
ENV HOME /data
ENV ALLOW_ROOT 1
ENV EVENT_LOOP_POLICY uvloop
ENV DB_DIRECTORY /data
ENV DB_ENGINE leveldb
ENV SERVICES=tcp://:50001,ssl://:50002,wss://:50004,rpc://0.0.0.0:8000
ENV SSL_CERTFILE ${DB_DIRECTORY}/electrumx.crt
ENV SSL_KEYFILE ${DB_DIRECTORY}/electrumx.key
ENV HOST ""
ENV PATH="/venv/bin:$PATH"

# Create data volume
VOLUME ["/data"]
WORKDIR /data

# Expose ports
EXPOSE 50001 50002 50004 8000

# Set entry point
CMD ["init"]
