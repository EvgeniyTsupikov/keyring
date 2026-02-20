#!/usr/bin/env bash
# Скрипт для запуска всех unit-тестов проекта.

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_ROOT"

if ! command -v flutter >/dev/null 2>&1; then
  echo "Ошибка: flutter CLI не найден в PATH." >&2
  echo "Установите Flutter SDK и добавьте <flutter>/bin в PATH, затем повторите запуск." >&2
  exit 127
fi

echo "Flutter: $(flutter --version | head -n 1)"
echo "Запуск unit-тестов..."

flutter test \
  test/database_helper_test.dart \
  test/credential_model_test.dart \
  test/encryption_service_test.dart

echo
echo "Все unit-тесты завершены успешно."
