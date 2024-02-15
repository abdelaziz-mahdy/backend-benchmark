# Use the official Golang image as the base image
FROM golang:latest as builder

# Set the working directory inside the container
WORKDIR /app

# Copy the go.mod and go.sum files to the working directory
COPY go.mod go.sum ./

# Download the Go modules
RUN go mod download

# Copy the rest of the application code
COPY . .

# Build the Go app
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o server .

# Use a Docker multi-stage build to create a lean production image
# Start with a smaller image that does not include build tools
FROM alpine:latest  

# Set the working directory inside the container
WORKDIR /root/

# Install ca-certificates, required for making HTTPS requests
RUN apk --no-cache add ca-certificates
# Install curl
RUN apk --no-cache add curl
COPY --from=builder /app/ .

# Copy the compiled binary file from the builder stage
COPY --from=builder /app/server .


EXPOSE 8000

# Command to run the executable
CMD ["./server"]


