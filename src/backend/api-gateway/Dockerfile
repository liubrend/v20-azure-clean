# Multi-stage build for the api-gateway service. Build context is the src/backend/ root
# (multi-module Gradle build). Runs on Azure Container Apps.
#   docker build -f api-gateway/Dockerfile -t api-gateway:dev .
FROM eclipse-temurin:21-jdk AS build
WORKDIR /workspace
COPY gradlew settings.gradle.kts build.gradle.kts ./
COPY gradle ./gradle
COPY api-gateway/build.gradle.kts api-gateway/build.gradle.kts
COPY sample-service/build.gradle.kts sample-service/build.gradle.kts
RUN chmod +x gradlew && ./gradlew :api-gateway:dependencies --no-daemon || true
COPY api-gateway/src api-gateway/src
RUN ./gradlew :api-gateway:bootJar --no-daemon

FROM eclipse-temurin:21-jre
WORKDIR /app
RUN useradd --uid 10001 --create-home app
COPY --from=build /workspace/api-gateway/build/libs/*.jar app.jar
USER app
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
