# Two stages: the image builds the jar itself, so `docker compose up -d --build` on a
# clean checkout needs no local JDK and cannot ship a stale build/libs jar.
# Tests are not run here; CI and `./gradlew test` (Testcontainers) own that.
FROM eclipse-temurin:21-jdk AS build
WORKDIR /src
# Wrapper and build scripts first, so the dependency layer is reused until they change.
COPY gradlew settings.gradle.kts build.gradle.kts ./
COPY gradle gradle
RUN chmod +x gradlew && ./gradlew --no-daemon dependencies --configuration runtimeClasspath > /dev/null
COPY src src
RUN ./gradlew --no-daemon bootJar && cp build/libs/*.jar /app.jar

FROM eclipse-temurin:21-jre
WORKDIR /app
COPY --from=build /app.jar app.jar
USER 10001:10001
ENTRYPOINT ["java", "-XX:MaxRAMPercentage=60", "-jar", "/app/app.jar"]
