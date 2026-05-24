@echo off
chcp 65001 >nul
title Dart Pro - Сборка и запуск

echo ========================================
echo    Dart Pro - Сборка release + запуск
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
echo Собираем и запускаем release-версию...
echo.
echo    ⏳ Первый запуск может быть долгим (1-2 мин)
echo    ❌ Закрой это окно когда закончишь
echo.

:: Запускаем Flutter Web в release-режиме (оптимизировано, быстро на телефоне)
:: Адрес сервера определяется автоматически из адресной строки браузера
C:\src\flutter\flutter\bin\flutter run -d web-server --release --web-hostname 0.0.0.0 --web-port 3000

:: Если произошла ошибка
if errorlevel 1 (
    echo.
    echo ОШИБКА! Что-то пошло не так.
    pause
)
