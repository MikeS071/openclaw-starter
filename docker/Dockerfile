FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive
ENV OPENCLAW_ENV=docker
RUN apt-get update && apt-get install -y sudo curl git
WORKDIR /mnt
COPY .. .
CMD ["/bin/bash"]
