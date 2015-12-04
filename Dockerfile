FROM alpine:3.2

RUN apk update && apk add nodejs && rm -rf /var/cache/apk/* && mkdir /data
RUN npm install -g yyolk/coffin

VOLUME /data
WORKDIR /data

ENTRYPOINT ["coffin"]
CMD ["-h"]
