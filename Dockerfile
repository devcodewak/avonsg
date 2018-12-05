FROM alpine:3.7 as builder

ENV GOLANG_MASTER_VERSION go1.12.1205
ENV GOLANG_COMMIT 9be01c2eab928f9899c67eb7bcdb164728f85a2c
ENV GOLANG_SRC_URL https://github.com/golang/go/archive/$GOLANG_COMMIT.tar.gz 

ENV GOPATH /go

RUN set -eux; \
	apk add --no-cache ca-certificates; \
	apk add --no-cache --virtual .build-deps \
		bash \
		gcc \
		musl-dev \
		openssl \
		curl \
		go \
	; \
	export \
# set GOROOT_BOOTSTRAP such that we can actually build Go
		GOROOT_BOOTSTRAP="$(go env GOROOT)" \
# ... and set "cross-building" related vars to the installed system's values so that we create a build targeting the proper arch
# (for example, if our build host is GOARCH=amd64, but our build env/image is GOARCH=386, our build needs GOARCH=386)
		GOOS="$(go env GOOS)" \
		GOARCH="$(go env GOARCH)" \
		GOHOSTOS="$(go env GOHOSTOS)" \
		GOHOSTARCH="$(go env GOHOSTARCH)" \
	; \
# also explicitly set GO386 and GOARM if appropriate
# https://github.com/docker-library/golang/issues/184
	apkArch="$(apk --print-arch)"; \
	case "$apkArch" in \
		armhf) export GOARM='6' ;; \
		x86) export GO386='387' ;; \
	esac; \
	\
	mkdir -p /usr/local/go; \
	curl -fSL $GOLANG_SRC_URL | tar -zxC /usr/local/go --strip-components=1; \
	echo $GOLANG_MASTER_VERSION > /usr/local/go/VERSION; \
	\
	cd /usr/local/go/src; \
	./make.bash; \
	\
	export PATH="/usr/local/go/bin:$PATH"; \
	go version; \
	\
	\
	mkdir -p "$GOPATH/src" "$GOPATH/bin"; \
	chmod -R 777 "$GOPATH"; \
	\
	\
	apk add --update git; \
	go get -d github.com/devcodewak/avonsg_openshift/cmd; \
	go build -ldflags="-s -w" -o /go/bin/web github.com/devcodewak/avonsg_openshift/cmd; \
	\
	\
	export PATH="$GOPATH/bin:$PATH"; \
	/go/bin/web -version


FROM alpine:3.7

WORKDIR /bin/

COPY --from=builder /go/bin/web .

RUN web -version

CMD ["/bin/web", "-server", "-cmd", "-key", "809240d3a021449f6e67aa73221d42df942a308a", "-listen", "http2://:8443", "-listen", "http://:8444", "-log", "null"]

EXPOSE 8443 8444