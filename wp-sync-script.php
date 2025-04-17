#!/bin/bash
echo "==== Запуск полной синхронизации WordPress ===="
echo ""

# Путь к скриптам
DB_SCRIPT="./wordpress-db-sync.sh"
FILES_SCRIPT="./wordpress-files-sync.sh"

# Сначала синхронизируем файлы
echo "Шаг 1: Синхронизация файлов..."
bash "$FILES_SCRIPT"

# Затем синхронизируем базу данных
echo ""
echo "Шаг 2: Синхронизация базы данных..."
bash "$DB_SCRIPT"

echo ""
echo "==== Синхронизация успешно завершена! ===="