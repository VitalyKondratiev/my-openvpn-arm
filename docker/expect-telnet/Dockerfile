FROM alpine:3.14
RUN apk update && \
    apk add --no-cache busybox-extras tcl-dev build-base && \
    mkdir expect && cd expect && \
    wget -O expect.tar.gz https://sourceforge.net/projects/expect/files/latest/download && \
    tar -xvzf expect.tar.gz -C ./ && rm expect.tar.gz && cd $(ls) && \
    ./configure && make install && \
    cd ../.. && rm -rf expect

