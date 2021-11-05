FROM rust:1 as builder
MAINTAINER Xuejie Xiao <x@nervos.org>

RUN apt-get update
RUN apt-get -y install --no-install-recommends llvm-dev clang libclang-dev libssl-dev

RUN cargo install moleculec --version 0.7.2

RUN rustup component add rustfmt
