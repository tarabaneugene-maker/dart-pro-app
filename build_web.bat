@echo off
chcp 65001 >nul
title Dart Pro - Сборка Flutter Web

echo ========================================
echo    Dart Pro - Сборка Flutter Web
echo ========================================
echo.

:: Переходим в корень проекта
cd /d "%~dp0"

echo Собираем Flutter Web (release)...
echo.
echo    ⏳ Это может занять 1-2 минуты
echo.

C:\src\flutter\flutter\bin\flutter build web --release

if errorlevel 1 (
    echo.
    echo ❌ ОШИБКА! Сборка не удалась.
    echo    Исправь ошибки выше и попробуй снова.
    pause
    exit /b 1
)

echo.
echo ✅ Сборка завершена!
echo.
echo    Теперь запусти сервер: start_server.bat
echo.
pause
