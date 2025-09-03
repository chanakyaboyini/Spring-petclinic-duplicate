# Stage 1: build the fat JAR with Maven on OpenJDK 17
FROM maven:3-openjdk-17 AS builder
WORKDIR /app

# Cache and download dependencies
COPY pom.xml .
RUN mvn dependency:go-offline -B

# Compile and package
COPY src/ ./src
RUN mvn clean package -DskipTests -B

# Stage 2: runtime on OpenJDK 17.0.11 slim (includes cgroup fix)
FROM openjdk:17.0.11-jdk-slim AS runtime
WORKDIR /app

# Copy the packaged JAR from builder stage
COPY --from=builder /app/target/*.jar app.jar

# Expose Spring Boot port
EXPOSE 8080

# Launch the application
ENTRYPOINT ["java", "-jar", "app.jar"]
