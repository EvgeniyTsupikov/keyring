#!/bin/bash
# Скрипт для запуска всех тестов

echo "Запуск тестов базы данных..."
flutter test test/database_helper_test.dart

echo ""
echo "Тесты завершены!"

