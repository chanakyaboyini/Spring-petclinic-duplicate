# Stage 1: build the JAR
FROM maven:3.8.5-jdk-11 AS builder
WORKDIR /app

# Copy Maven files and download dependencies
COPY pom.xml .
RUN mvn dependency:go-offline -B

# Copy source and build
COPY src ./src
RUN mvn clean package -DskipTests -B

# Stage 2: runtime image
FROM openjdk:11-jre-slim
WORKDIR /app

# Copy executable JAR
COPY --from=builder /app/target/*.jar app.jar

# Expose port and launch
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
