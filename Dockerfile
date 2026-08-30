# ============================================================
# Dart Pro App — Full Stack Dockerfile
# Собирает Flutter Web + Dart сервер в один образ
# ============================================================

# ---- Стадия 1: Сборка Flutter Web ----
FROM dart:3.11-sdk AS flutter-build

# Устанавливаем Flutter SDK
RUN apt-get update -qq && \
    apt-get install -y -qq curl git unzip xz-utils zip libglu1-mesa && \
    apt-get clean

# Скачиваем Flutter
RUN git clone --depth 1 --branch stable https://github.com/flutter/flutter.git /opt/flutter
ENV PATH="/opt/flutter/bin:${PATH}"

# Включаем веб-платформу
RUN flutter config --enable-web

WORKDIR /app

# Копируем Flutter-проект
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

COPY lib/ ./lib/
COPY web/ ./web/

# Собираем Flutter Web
RUN flutter build web --release

# ---- Стадия 2: Сборка Dart-сервера ----
FROM dart:3.11-sdk AS server-build

WORKDIR /app

# Копируем pubspec сервера
COPY server/pubspec.yaml server/pubspec.lock ./server/
RUN cd server && dart pub get

# Копируем исходники сервера
COPY server/lib/ ./server/lib/

# Компилируем сервер
RUN cd server && dart compile exe lib/main.dart -o /app/dart_pro_server

# ---- Стадия 3: Финальный образ ----
FROM dart:3.11-sdk

# Устанавливаем sqlite3 для работы с БД
RUN apt-get update -qq && \
    apt-get install -y -qq libsqlite3-dev && \
    apt-get clean

WORKDIR /app

# Копируем скомпилированный сервер
COPY --from=server-build /app/dart_pro_server ./dart_pro_server

# Копируем собранный Flutter Web
COPY --from=flutter-build /app/build/web ./build/web

# Порт сервера (реально используется 9090, т.к. 8080 занят другим проектом)
EXPOSE 9090

# Volume для персистентной базы данных
VOLUME ["/app/data"]

# Переменные окружения
ENV DB_PATH=/app/data/dart_pro.db

# Health check (сервер слушает PORT=9090)
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD curl -f http://localhost:9090/health || exit 1

# Запускаем сервер (он сам раздаёт статику из ../build/web)
CMD ["./dart_pro_server"]
