FROM golang:1.17.0-alpine3.13
ENV GOOGLE_CLOUD_PROJECT=roi-takeoff-user75
RUN mkdir /app
ADD . /app
WORKDIR /app
RUN go build -o main .
CMD ["/app/main"]