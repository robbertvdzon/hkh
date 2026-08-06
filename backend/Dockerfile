# syntax=docker/dockerfile:1.7

FROM maven:3.9-eclipse-temurin-21 AS build
WORKDIR /src
COPY pom.xml ./
RUN --mount=type=cache,target=/root/.m2 mvn -q -B dependency:go-offline
COPY src ./src
RUN --mount=type=cache,target=/root/.m2 mvn -q -B -DskipTests package \
 && cp target/hkh-backend-*.jar /app.jar

FROM eclipse-temurin:21-jre AS runtime
WORKDIR /opt/app
COPY --from=build /app.jar /opt/app/app.jar
RUN chgrp -R 0 /opt/app && chmod -R g=u /opt/app
USER 1001
EXPOSE 8080

ARG BUILD_SHA=unknown
ARG BUILD_VERSION=0.0.1
ENV SERVER_PORT=8080 \
    HKH_GIT_COMMIT=${BUILD_SHA} \
    HKH_APP_VERSION=${BUILD_VERSION}

ENTRYPOINT ["java", "-jar", "/opt/app/app.jar"]
