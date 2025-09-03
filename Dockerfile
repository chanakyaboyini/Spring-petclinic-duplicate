# Stage 1: build the JAR with JDK 17
FROM maven:3.8.5-openjdk-17 AS builder
WORKDIR /app

# Copy Maven descriptor and go offline
COPY pom.xml .
RUN mvn dependency:go-offline -B

# Copy source code, then compile/package
COPY src ./src
RUN mvn clean package -DskipTests -B

# Stage 2: runtime image on JRE 17
FROM openjdk:17-oraclelinux8-slim AS runtime
WORKDIR /app

# Pull in the fat JAR
COPY --from=builder /app/target/*.jar app.jar

# Expose default Spring Boot port
EXPOSE 8080

# Launch the app
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
