FROM debian:bullseye-slim

RUN apt-get update && apt-get install -y \
    curl \
    wget \
    net-tools \
    iputils-ping \
    && rm -rf /var/lib/apt/lists/*

CMD ["/bin/bash"]