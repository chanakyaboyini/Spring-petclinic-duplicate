# Stage 1: build the JAR with Maven on OpenJDK 17
FROM maven:3-openjdk-17 AS builder
WORKDIR /app

# Cache Maven dependencies
COPY pom.xml .
RUN mvn dependency:go-offline -B

# Copy sources and build the application
COPY src/ ./src
RUN mvn clean package -DskipTests -B

# Stage 2: runtime on a slim OpenJDK 17 JRE
FROM openjdk:17-slim AS runtime
WORKDIR /app

# Copy the fat JAR from builder stage
COPY --from=builder /app/target/*.jar app.jar

# Expose Spring Boot’s default port
EXPOSE 8080

# Run the application
ENTRYPOINT ["java", "-jar", "app.jar"]
