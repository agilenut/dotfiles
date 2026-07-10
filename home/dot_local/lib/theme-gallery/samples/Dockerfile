# Palette sample: Dockerfile — instructions, strings, comments, args.
FROM alpine:3.20 AS build

ARG VERSION=1.2.0
ENV APP_HOME=/opt/app

WORKDIR ${APP_HOME}
COPY . .
RUN apk add --no-cache curl \
    && echo "building ${VERSION}" \
    && ./build.sh

EXPOSE 8080
CMD ["./app", "--serve"]
