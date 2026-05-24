@echo off
chcp 65001 >nul
title Dart Pro Server

echo ========================================
echo    Dart Pro - Запуск сервера
echo ========================================
echo.

:: Переходим в корень проекта
cd /d "%~dp0"

:: Проверяем, собрана ли статика Flutter Web
if not exist "build\web\index.html" (
    echo ⚠️  Статика Flutter Web не найдена!
    echo.
    echo    Сначала выполни сборку:
    echo    build_web.bat
    echo.
    echo    Или нажми любую клавишу чтобы собрать сейчас...
    pause >nul
    echo.
    echo Собираем Flutter Web...
    echo.
    C:\src\flutter\flutter\bin\flutter build web --release
    if errorlevel 1 (
        echo.
        echo ❌ ОШИБКА! Сборка Flutter Web не удалась.
        echo    Исправь ошибки и попробуй снова.
        pause
        exit /b 1
    )
    echo ✅ Flutter Web собран
    echo.
)

:: Очищаем порт 8080 (убиваем старый процесс, если висит)
echo Проверяем порт 8080...
for /f "tokens=*" %%a in ('netstat -ano ^| findstr :8080 ^| findstr LISTENING') do (
    for /f "tokens=5" %%b in ("%%a") do (
        echo Порт 8080 занят процессом PID %%b — завершаем...
        taskkill /F /PID %%b >nul 2>&1
        timeout /t 1 /nobreak >nul
    )
)
echo.

:: Переходим в папку сервера
cd /d "%~dp0server"

:: Показываем IP адрес ПК в сети
echo Определяем IP адрес...
for /f "tokens=2 delims=:" %%a in ('ipconfig ^| findstr /C:"IPv4" /C:"IP Address"') do (
    set "IP=%%a"
    goto :showip
)
:showip
set "IP=%IP: =%"
echo.
echo ========================================
echo    🌐 IP твоего ПК: %IP%
echo    🌐 Открой на телефоне: http://%IP%:8080
echo    🌐 Сервер раздаёт и сайт, и WebSocket
echo ========================================
echo.
echo Запускаем сервер...
echo.
echo    ⏳ Нажми Ctrl+C чтобы остановить сервер
echo    ❌ Закрой это окно когда закончишь
echo.

:: Запускаем сервер
C:\src\flutter\flutter\bin\cache\dart-sdk\bin\dart run lib\main.dart

:: Если произошла ошибка - показываем и ждём
if errorlevel 1 (
    echo.
    echo ❌ ОШИБКА! Сервер не запустился.
    echo    Убедись что ты в папке server и выполнил: dart pub get
    pause
)
