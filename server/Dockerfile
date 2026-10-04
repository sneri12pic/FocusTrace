FROM eclipse-temurin:21-jre
WORKDIR /app
COPY build/libs/*-SNAPSHOT.jar app.jar
USER 10001:10001
ENTRYPOINT ["java", "-XX:MaxRAMPercentage=60", "-jar", "/app/app.jar"]
