@echo off
chcp 65001 >nul
title Dart Pro Flutter Web

echo ========================================
echo    Dart Pro Flutter Web - Запуск
echo ========================================
echo.

:: Переходим в корень проекта
cd /d "%~dp0"

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
echo    🌐 Открой на телефоне:
echo    http://%IP%:3000
echo ========================================
echo.
echo Запускаем Flutter Web...
echo.

:: Запускаем Flutter Web на всех интерфейсах (чтобы было видно с телефона)
:: Адрес сервера определяется автоматически из адресной строки браузера
C:\src\flutter\flutter\bin\flutter run -d web-server --web-hostname 0.0.0.0 --web-port 3000

:: Если произошла ошибка
if errorlevel 1 (
    echo.
    echo ОШИБКА! Flutter не запустился.
    echo Убедись что Flutter установлен и выполни: flutter pub get
    pause
)
