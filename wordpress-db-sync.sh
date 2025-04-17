#!/bin/bash

# ================================================================
# WordPress Database Synchronization Script
# ================================================================
# Этот скрипт синхронизирует базу данных с производственного 
# сервера WordPress на локальную машину WSL Debian/Ubuntu
# ================================================================

# Цветовая кодировка для сообщений
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Настройки удаленного сервера
REMOTE_HOST="your-server.com"
REMOTE_USER="server_username"
REMOTE_PORT="22"
REMOTE_PATH="/path/to/wordpress"

# Настройки локального сервера
LOCAL_PATH="/path/to/local/wordpress"

# Настройки для замены URL
PROD_URL="https://www.your-production-site.com"
LOCAL_URL="http://localhost/wordpress"

# Временные файлы
TIMESTAMP=$(date +"%Y%m%d%H%M%S")
BACKUP_DIR="$LOCAL_PATH/backups"
DB_BACKUP="$BACKUP_DIR/db_backup_$TIMESTAMP.sql"

# ===== Функции =====

# Функция вывода информации
info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

# Функция вывода предупреждений
warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Функция вывода ошибок
error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# Создание директории для бэкапов, если она не существует
create_backup_dir() {
    if [ ! -d "$BACKUP_DIR" ]; then
        info "Создание директории для бэкапов..."
        mkdir -p "$BACKUP_DIR"
        if [ $? -ne 0 ]; then
            error "Не удалось создать директорию для бэкапов"
        fi
    fi
}

# Проверка наличия WP-CLI
check_wp_cli() {
    info "Проверка WP-CLI..."
    if ! command -v wp &> /dev/null; then
        error "WP-CLI не установлен. Установите его с помощью: curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar && chmod +x wp-cli.phar && sudo mv wp-cli.phar /usr/local/bin/wp"
    fi
}

# Бэкап локальной базы данных перед синхронизацией
backup_local_db() {
    info "Создание резервной копии локальной базы данных..."
    cd "$LOCAL_PATH" || error "Не удалось перейти в локальную директорию WordPress"
    
    wp db export "$DB_BACKUP" --allow-root
    if [ $? -ne 0 ]; then
        error "Ошибка создания резервной копии локальной базы данных"
    fi
    
    info "Резервная копия локальной базы данных создана: $DB_BACKUP"
}

# Экспорт удаленной базы данных
export_remote_db() {
    info "Экспорт базы данных с производственного сервера..."
    
    # Создаем временный файл на удаленном сервере
    REMOTE_TEMP_FILE="/tmp/wp_export_$TIMESTAMP.sql"
    
    ssh -p "$REMOTE_PORT" "$REMOTE_USER@$REMOTE_HOST" "cd $REMOTE_PATH && wp db export $REMOTE_TEMP_FILE --allow-root"
    if [ $? -ne 0 ]; then
        error "Ошибка при экспорте удаленной базы данных"
    fi
    
    # Скачиваем файл с удаленного сервера
    info "Загрузка базы данных с удаленного сервера..."
    LOCAL_TEMP_FILE="/tmp/wp_remote_db_$TIMESTAMP.sql"
    scp -P "$REMOTE_PORT" "$REMOTE_USER@$REMOTE_HOST:$REMOTE_TEMP_FILE" "$LOCAL_TEMP_FILE"
    if [ $? -ne 0 ]; then
        error "Ошибка при загрузке файла с удаленного сервера"
    fi
    
    # Удаляем временный файл на удаленном сервере
    ssh -p "$REMOTE_PORT" "$REMOTE_USER@$REMOTE_HOST" "rm $REMOTE_TEMP_FILE"
    
    info "База данных успешно загружена"
    echo "$LOCAL_TEMP_FILE"
}

# Импорт базы данных в локальную среду
import_db() {
    local db_file=$1
    
    info "Импорт базы данных в локальную среду..."
    cd "$LOCAL_PATH" || error "Не удалось перейти в локальную директорию WordPress"
    
    wp db import "$db_file" --allow-root
    if [ $? -ne 0 ]; then
        error "Ошибка при импорте базы данных"
    fi
    
    info "База данных успешно импортирована"
}

# Замена URL в базе данных
replace_urls() {
    info "Замена URL в базе данных ($PROD_URL -> $LOCAL_URL)..."
    cd "$LOCAL_PATH" || error "Не удалось перейти в локальную директорию WordPress"
    
    # Замена протокола и домена
    wp search-replace "$PROD_URL" "$LOCAL_URL" --all-tables --allow-root
    if [ $? -ne 0 ]; then
        error "Ошибка при замене URL"
    fi
    
    # Также заменяем URL без протокола
    PROD_DOMAIN=$(echo "$PROD_URL" | sed -e 's|^[^/]*//||' -e 's|/.*$||')
    LOCAL_DOMAIN=$(echo "$LOCAL_URL" | sed -e 's|^[^/]*//||' -e 's|/.*$||')
    
    wp search-replace "www.$PROD_DOMAIN" "$LOCAL_DOMAIN" --all-tables --allow-root
    wp search-replace "$PROD_DOMAIN" "$LOCAL_DOMAIN" --all-tables --allow-root
    
    info "URL успешно заменены"
}

# Очистка временных файлов
cleanup() {
    info "Очистка временных файлов..."
    if [ -f "$LOCAL_TEMP_FILE" ]; then
        rm "$LOCAL_TEMP_FILE"
    fi
}

# Сброс кэша WordPress
flush_cache() {
    info "Сброс кэша WordPress..."
    cd "$LOCAL_PATH" || error "Не удалось перейти в локальную директорию WordPress"
    
    wp cache flush --allow-root
    if [ $? -ne 0 ]; then
        warn "Не удалось сбросить кэш WordPress"
    fi
}

# ===== Основной скрипт =====

# Вывод приветствия
echo "======================================================"
echo "     WordPress Database Synchronization Script"
echo "======================================================"
echo ""

# Проверка зависимостей
check_wp_cli
create_backup_dir

# Создание резервной копии
backup_local_db

# Синхронизация базы данных
remote_db_file=$(export_remote_db)
import_db "$remote_db_file"
replace_urls
flush_cache
cleanup

echo ""
echo "======================================================"
echo "База данных WordPress успешно синхронизирована!"
echo "======================================================"

# Инструкции по использованию скрипта
cat << EOF

ИНСТРУКЦИЯ ПО ИСПОЛЬЗОВАНИЮ:
1. Отредактируйте переменные в начале скрипта:
   - REMOTE_HOST - адрес вашего производственного сервера
   - REMOTE_USER - пользователь SSH на сервере
   - REMOTE_PORT - порт SSH на сервере
   - REMOTE_PATH - путь к WordPress на сервере
   - LOCAL_PATH - путь к WordPress на локальной машине
   - PROD_URL - URL производственного сайта
   - LOCAL_URL - URL локального сайта

2. Сделайте скрипт исполняемым:
   chmod +x wordpress-db-sync.sh

3. Запустите скрипт:
   ./wordpress-db-sync.sh

EOF