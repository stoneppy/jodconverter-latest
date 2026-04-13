# jodconverter-latest

基于 LibreOffice 26.2.2 + JodConverter 的文档转换服务，提供 REST API 接口，通过 Docker 一键部署。

## 功能

- 支持 Word、Excel、PPT、ODT 等格式互转 PDF
- 提供 REST API 和 Web UI 两种调用方式
- 支持自定义字体（中文字体等）
- 支持挂载配置文件覆盖默认参数

## 项目结构

```
├── Dockerfile                  # 多阶段构建：JRE + jodconverter + LibreOffice
├── docker-compose.yml
├── bin/
│   └── docker-entrypoint.sh
├── config/
│   └── application.properties  # 默认配置，可按需修改
└── fonts/                      # 自定义字体目录，放 .ttf/.otf 文件
```

## 快速开始

### 服务器部署

```bash
git clone https://github.com/stoneppy/jodconverter-latest.git
cd jodconverter-latest
docker compose up --build -d
```

启动后访问：`http://服务器IP:8080`

### 更新

```bash
git pull
docker compose up --build -d
```

## 配置

编辑 `config/application.properties`：

```properties
# LibreOffice 实例数（多实例可提升并发）
jodconverter.local.port-numbers=2002

# 上传文件大小限制
spring.servlet.multipart.max-file-size=50MB
spring.servlet.multipart.max-request-size=50MB

# 服务端口
server.port=8080
```

## 自定义字体

将 `.ttf` 或 `.otf` 字体文件放入 `fonts/` 目录，重新构建镜像即可：

```bash
docker compose build --no-cache
docker compose up -d
```

## REST API

### 转换文档

```bash
curl -X POST http://localhost:8080/api/converter/convert \
  -F "file=@document.docx" \
  -F "outputFormat=pdf" \
  -o output.pdf
```

## 环境变量

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `LIBREOFFICE_HOME` | `/opt/libreoffice26.2` | LibreOffice 安装路径 |
| `JAVA_HOME` | `/opt/java/openjdk` | JRE 路径 |
| `JODCONVERTER_LOCAL_OFFICE_HOME` | `/opt/libreoffice26.2` | jodconverter 使用的 LibreOffice 路径 |

## 技术栈

- **LibreOffice** 26.2.2（官网 deb 包）
- **JodConverter** 4.4.7
- **Java** 21（eclipse-temurin jlink 精简 JRE）
- **基础镜像** debian:bookworm
