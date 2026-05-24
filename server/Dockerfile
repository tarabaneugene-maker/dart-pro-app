# Используем официальный Dart SDK 3.11
FROM dart:3.11-sdk AS build

WORKDIR /app

# Копируем pubspec и загружаем зависимости
COPY pubspec.yaml pubspec.lock ./
RUN dart pub get

# Копируем исходный код
COPY lib/ ./lib/

# Компилируем в нативный исполняемый файл
RUN dart compile exe lib/main.dart -o /app/server

# Минимальный образ для запуска
FROM dart:3.11-sdk

WORKDIR /app

# Копируем скомпилированный бинарник
COPY --from=build /app/server ./server

# Порт, который использует сервер
EXPOSE 8080

# Volume для персистентной базы данных
VOLUME ["/app/data"]

# Переменные окружения
ENV DB_PATH=/app/data/dart_pro.db

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD curl -f http://localhost:8080/health || exit 1

# Запускаем сервер
CMD ["./server"]
