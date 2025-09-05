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
FROM bellsoft/liberica-openjre-debian:21-cds

# Add metadata
LABEL maintainer="AmaliTech Training Academy" \
    description="Cloud Insight Pro Project" \
    version="1.0"

# Set default environment variables (can be overridden)
ENV SPRING_PROFILES_ACTIVE=production
ENV SERVER_PORT=8080

# Create a non-root user
RUN useradd -r -u 1001 -g root userservice

WORKDIR /application

# Copy the extracted layers from the build stage
COPY --from=builder --chown=userservice:root /build/target/*.jar ./application.jar

# Configure container
USER 1001
EXPOSE 8080

# Use the standard JAR execution
ENTRYPOINT ["java", "-XX:+UseContainerSupport", "-XX:MaxRAMPercentage=75.0", "-Djava.security.egd=file:/dev/./urandom", "-jar", "application.jar"]