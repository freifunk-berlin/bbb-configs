FROM alpine:3.22
ENV LC_ALL=C.UTF-8

RUN apk add \
      argp-standalone asciidoc bash bc binutils bzip2 cdrkit coreutils \
      diffutils elfutils-dev findutils flex musl-fts-dev g++ gawk gcc gettext git \
      grep gzip intltool libxslt linux-headers make musl-libintl musl-obstack-dev \
      ncurses-dev openssl-dev patch perl python3-dev rsync tar \
      unzip util-linux wget zlib-dev jq py3-pip sudo shadow

WORKDIR /work
COPY requirements.txt requirements.txt
RUN python3 -m venv /venv
ENV PATH="/venv/bin:$PATH"
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
RUN make containerlint

ENTRYPOINT ["./generate-images.sh"]