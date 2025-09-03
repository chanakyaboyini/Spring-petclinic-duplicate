# Stage 1: build the fat JAR with Maven on OpenJDK 17
FROM maven:3-openjdk-17 AS builder
WORKDIR /app

# Cache dependencies
COPY pom.xml .
RUN mvn dependency:go-offline -B

# Copy sources and package
COPY src/ ./src
RUN mvn clean package -DskipTests -B

# Stage 2: runtime on a slim OpenJDK 17 JDK (tracks latest 17.x releases)
FROM openjdk:17-jdk-slim AS runtime
WORKDIR /app

# Copy the fat JAR from the builder stage
COPY --from=builder /app/target/*.jar app.jar

# Expose Spring Boot’s default port
EXPOSE 8080

# Launch the app
ENTRYPOINT ["java", "-jar", "app.jar"]
