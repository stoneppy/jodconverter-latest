#!/usr/bin/env bash
if [ "$1" = "java" ]; then
    exec gosu jodconverter "$@" > >(tee -a ${LOG_BASE_DIR}/app.log) 2> >(tee -a ${LOG_BASE_DIR}/app.err >&2)
elif [ "$1" = "./gradlew" ]; then
    exec "$@"
else
    exec gosu jodconverter java -jar ${JAR_FILE_BASEDIR}/${JAR_FILE_NAME} "$@" > >(tee -a ${LOG_BASE_DIR}/app.log) 2> >(tee -a ${LOG_BASE_DIR}/app.err >&2)
fi
