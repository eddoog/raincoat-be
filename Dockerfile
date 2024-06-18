# Copyright 2020 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# [START cloudrun_helloworld_dockerfile]
# [START run_helloworld_dockerfile]

# Use the offical golang image to create a binary.
# This is based on Debian and sets the GOPATH to /go.
# https://hub.docker.com/_/golang
FROM golang:1.22-bookworm AS builder


RUN apt-get update && apt-get install -y wget git gcc build-essential && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Download and install TensorFlow C library
RUN wget https://storage.googleapis.com/tensorflow/libtensorflow/libtensorflow-cpu-linux-x86_64-2.15.0.tar.gz && \
    tar -C /usr -xzf libtensorflow-cpu-linux-x86_64-2.15.0.tar.gz && \
    ldconfig && \
    rm libtensorflow-cpu-linux-x86_64-2.15.0.tar.gz

# Set the environment variables to help the Go compiler find the TensorFlow C library
ENV LD_LIBRARY_PATH /usr/local/lib
ENV CGO_CFLAGS "-I/usr/local/include"
ENV CGO_LDFLAGS "-L/usr/local/lib"

# Create and change to the app directory.
WORKDIR /app

# This allows the container build to reuse cached dependencies.
# Expecting to copy go.mod and if present go.sum.
COPY go.* ./
RUN go mod download

# Copy local code to the container image.
COPY . ./
ENV PORT=8080

RUN echo "PORT=$PORT" > .env

# Build the binary.
RUN go build -v -o server

# Use the official Debian slim image for a lean production container.
# https://hub.docker.com/_/debian
# https://docs.docker.com/develop/develop-images/multistage-build/#use-multi-stage-builds
FROM debian:bookworm-slim

RUN set -x && apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# Copy the binary to the production image from the builder stage.
COPY --from=builder /app/server /app/server
COPY --from=builder /app/.env .
COPY --from=builder /app/model /model
COPY --from=builder /usr/lib/libtensorflow.so.2 /usr/local/lib/
COPY --from=builder /usr/lib/libtensorflow_framework.so.2 /usr/local/lib/

# Set the environment variables to help the runtime find the TensorFlow C library
ENV LD_LIBRARY_PATH /usr/local/lib

# Run the web service on container startup.

CMD ["/app/server"]

# [END run_helloworld_dockerfile]
# [END cloudrun_helloworld_dockerfile]