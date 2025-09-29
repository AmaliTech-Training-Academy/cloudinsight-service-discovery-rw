# Build stage: Compile the application
FROM maven:3.9-eclipse-temurin-21 AS builder

WORKDIR /build

# Copy pom.xml first for better caching
COPY pom.xml .
# Download dependencies (will be cached if pom.xml doesn't change)
RUN mvn dependency:go-offline -B

# Copy source code
COPY src ./src/

# Build the application
RUN mvn package -DskipTests

# Runtime stage: Setup the actual runtime environment
# Using Eclipse Temurin distroless - optimized for microservices with minimal attack surface
FROM eclipse-temurin:21-jre-jammy

# Add metadata
LABEL maintainer="AmaliTech Training Academy" \
    description="Cloud Insight Pro Service Discovery" \
    version="1.0"

# Install jq for JSON processing and clean up in same layer
RUN apt-get update && \
    apt-get install -y --no-install-recommends jq && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Set default environment variables (can be overridden)
ENV SPRING_PROFILES_ACTIVE=production
ENV SERVER_PORT=8761

# Create a non-root user for security
RUN groupadd -r -g 1001 userservice && \
    useradd -r -u 1001 -g userservice userservice

WORKDIR /application

# Copy the extracted layers from the build stage
COPY --from=builder --chown=userservice:userservice /build/target/*.jar ./application.jar

# Copy the entrypoint script
COPY --chown=userservice:userservice entrypoint.sh ./entrypoint.sh
RUN chmod +x /application/entrypoint.sh

# Configure container
USER 1001
EXPOSE 8761

# Use entrypoint script before launching the application
ENTRYPOINT ["/bin/bash", "-c", "source ./entrypoint.sh && java -XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0 -Djava.security.egd=file:/dev/./urandom -jar application.jar"]