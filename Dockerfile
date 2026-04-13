ARG JAVA_VERSION=21
ARG LO_VERSION=26.2.2
ARG LO_SHORT=26.2

# ── Stage 1: 构建精简 JRE ──────────────────────────────────────────────────────
FROM eclipse-temurin:${JAVA_VERSION}-jdk-noble AS jre-builder

RUN $JAVA_HOME/bin/jlink \
    --add-modules java.base,java.compiler,java.datatransfer,java.desktop,java.instrument,java.logging,java.management,java.management.rmi,java.naming,java.net.http,java.prefs,java.rmi,java.scripting,java.se,java.security.jgss,java.security.sasl,java.smartcardio,java.sql,java.sql.rowset,java.transaction.xa,java.xml,java.xml.crypto,jdk.accessibility,jdk.charsets,jdk.crypto.cryptoki,jdk.crypto.ec,jdk.dynalink,jdk.httpserver,jdk.jdwp.agent,jdk.jfr,jdk.jsobject,jdk.localedata,jdk.management,jdk.management.agent,jdk.management.jfr,jdk.naming.dns,jdk.naming.rmi,jdk.net,jdk.nio.mapmode,jdk.sctp,jdk.security.auth,jdk.security.jgss,jdk.unsupported,jdk.xml.dom,jdk.zipfs \
    --strip-debug \
    --no-man-pages \
    --no-header-files \
    --compress=2 \
    --output /jre

# ── Stage 2: 构建 jodconverter REST 应用 ───────────────────────────────────────
FROM eclipse-temurin:${JAVA_VERSION}-jdk-noble AS app-builder

RUN apt-get update && apt-get install -y --no-install-recommends git \
    && rm -rf /var/lib/apt/lists/*

RUN git clone https://github.com/jodconverter/jodconverter-samples /src \
    && chmod +x /src/gradlew

WORKDIR /src
RUN ./gradlew --no-daemon -x test :samples:spring-boot-rest:build

# ── Stage 3: 最终运行镜像 ──────────────────────────────────────────────────────
FROM debian:bookworm

ARG LO_VERSION=26.2.2
ARG LO_SHORT=26.2

ENV JAVA_HOME=/opt/java/openjdk \
    LIBREOFFICE_HOME=/opt/libreoffice${LO_SHORT} \
    JAR_FILE_NAME=app.war \
    JAR_FILE_BASEDIR=/opt/app \
    LOG_BASE_DIR=/var/log \
    NONPRIVUSER=jodconverter \
    NONPRIVGROUP=jodconverter \
    JODCONVERTER_LOCAL_OFFICE_EXECUTABLE=soffice \
    JODCONVERTER_LOCAL_PROCESS_MANAGER=org.jodconverter.local.process.UnixProcessManager \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

ENV JODCONVERTER_LOCAL_OFFICE_HOME=${LIBREOFFICE_HOME}
ENV PATH="${JAVA_HOME}/bin:${LIBREOFFICE_HOME}/program:${PATH}"

# 拷贝精简 JRE
COPY --from=jre-builder /jre $JAVA_HOME

# 拷贝 jodconverter REST war 包
COPY --from=app-builder /src/samples/spring-boot-rest/build/libs/*.war /opt/app/app.war

# 安装系统依赖
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget ca-certificates \
    libxinerama1 libcairo2 libcups2 libglib2.0-0 \
    libx11-6 libxext6 libxrender1 libxrandr2 libxcursor1 \
    libdbus-1-3 libfontconfig1 libfreetype6 libsm6 libice6 \
    libpng16-16 libgl1 libxcb-shm0 libxcb-render0 \
    procps gosu \
    && rm -rf /var/lib/apt/lists/*

# 下载并安装 LibreOffice（官网 deb 包）
RUN wget -q \
    "https://download.documentfoundation.org/libreoffice/stable/${LO_VERSION}/deb/x86_64/LibreOffice_${LO_VERSION}_Linux_x86-64_deb.tar.gz" \
    -O /tmp/lo.tar.gz \
    && tar -xzf /tmp/lo.tar.gz -C /tmp \
    && apt-get update \
    && dpkg -i /tmp/LibreOffice_${LO_VERSION}_Linux_x86-64_deb/DEBS/*.deb || true \
    && apt-get install -f -y \
    && rm -rf /tmp/lo.tar.gz /tmp/LibreOffice_* \
    && rm -rf /var/lib/apt/lists/*

# 创建用户和目录
RUN groupadd ${NONPRIVGROUP} \
    && useradd -m ${NONPRIVUSER} -g ${NONPRIVGROUP} \
    && mkdir -p ${JAR_FILE_BASEDIR} /etc/app \
    && touch ${LOG_BASE_DIR}/app.log ${LOG_BASE_DIR}/app.err \
    && chown -R ${NONPRIVUSER}:${NONPRIVGROUP} \
         ${LOG_BASE_DIR}/app.log \
         ${LOG_BASE_DIR}/app.err \
         ${JAR_FILE_BASEDIR}

# 自定义字体（fonts/ 目录下放 .ttf/.otf 文件即可）
COPY fonts/ /usr/share/fonts/custom/
RUN fc-cache -f -v

# 为运行用户预构建字体缓存
USER jodconverter
RUN fc-cache -fr
USER root

COPY bin/docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

EXPOSE 8080

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["--spring.config.additional-location=optional:/etc/app/"]
