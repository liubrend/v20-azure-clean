# Multi-stage build for the sample-service. Build context is the backend/ root
# (multi-module Gradle build). Runs on Azure Container Apps.
#   docker build -f sample-service/Dockerfile -t sample-service:dev .
FROM eclipse-temurin:21-jdk AS build
WORKDIR /workspace
COPY gradlew settings.gradle.kts build.gradle.kts ./
COPY gradle ./gradle
COPY api-gateway/build.gradle.kts api-gateway/build.gradle.kts
COPY sample-service/build.gradle.kts sample-service/build.gradle.kts
RUN chmod +x gradlew && ./gradlew :sample-service:dependencies --no-daemon || true
COPY sample-service/src sample-service/src
RUN ./gradlew :sample-service:bootJar --no-daemon

FROM eclipse-temurin:21-jre
WORKDIR /app
RUN useradd --uid 10001 --create-home app
COPY --from=build /workspace/sample-service/build/libs/*.jar app.jar
USER app
EXPOSE 8081
# DATABASE_URL / BLOB_CONNECTION_STRING injected at runtime (Key Vault -> Container Apps).
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
