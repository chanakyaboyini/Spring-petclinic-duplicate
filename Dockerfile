# Stage 1: build the JAR with JDK 17
FROM maven:3.8.6-jdk-17 AS builder
WORKDIR /app

# Cache and download dependencies
COPY pom.xml .
RUN mvn dependency:go-offline -B

# Copy source and build application
COPY src ./src
RUN mvn clean package -DskipTests -B

# Stage 2: runtime image on a slim JRE 17
FROM openjdk:17-slim AS runtime
WORKDIR /app

# Copy the packaged JAR from builder stage
COPY --from=builder /app/target/*.jar app.jar

# Expose the Spring Boot port
EXPOSE 8080

# Run the application
ENTRYPOINT ["java", "-jar", "app.jar"]
