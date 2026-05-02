# ============================================
# Stage 1: Build com JDK 21 (GraalVM ou Temurin)
# ============================================
FROM ghcr.io/graalvm/native-image-community:21 AS builder

WORKDIR /build

# Copiar arquivos de configuração do Maven
COPY mvnw .
COPY .mvn .mvn
COPY pom.xml .
RUN chmod +x mvnw

# Baixar dependências para cache
RUN ./mvnw dependency:go-offline

# Copiar código fonte e gerar o JAR
COPY src src
RUN ./mvnw clean package -DskipTests

# ============================================
# Stage 2: Runtime com JRE 21 (Otimizada para Dev)
# ============================================
FROM eclipse-temurin:21-jre-jammy

WORKDIR /app

# Instalar curl para o Healthcheck
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copia o JAR gerado no estágio anterior
# O uso do asterisco (*) garante que pegue o arquivo indepedente da versão no pom.xml
COPY --from=builder /build/target/controlroom-*.jar /app/controlroom.jar

EXPOSE 8080

# Healthcheck configurado para o Actuator do Spring
HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
    CMD curl -f http://localhost:8080/actuator/health || exit 1

# Comando para rodar o JAR tradicional
ENTRYPOINT ["java", "-jar", "controlroom.jar"]