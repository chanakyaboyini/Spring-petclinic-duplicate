# Stage 1: build the fat JAR with Maven on OpenJDK 17
FROM maven:3-openjdk-17 AS builder
WORKDIR /app

# Cache dependencies
COPY pom.xml .
RUN mvn dependency:go-offline -B

# Copy sources and package
COPY src/ ./src
RUN mvn clean package -DskipTests -B

# Stage 2: runtime on Eclipse Temurin JRE 17 (includes cgroup-v2 fix)
FROM eclipse-temurin:17-jre-jammy AS runtime
WORKDIR /app

# Copy the packaged JAR from builder stage
COPY --from=builder /app/target/*.jar app.jar

# Expose Spring Boot’s default port
EXPOSE 8080

# Launch the application
ENTRYPOINT ["java", "-jar", "app.jar"]
