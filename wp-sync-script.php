#!/bin/bash

# =============================================================================
# WordPress сайт: Скрипт миграции с продакшена на локальную WSL среду
# =============================================================================
# Данный скрипт следует философии WordPress и лучшим практикам для копирования
# WordPress сайта с продакшен-сервера на локальную среду WSL.
# 
# Скрипт выполняет:
# 1. Экспорт базы данных с продакшен-сервера
# 2. Копирование файлов WordPress с продакшен-сервера
# 3. Импорт базы данных в локальную среду
# 4. Обновление URL в базе данных
# =============================================================================

# ------------------------------
# Конфигурация: измените переменные под свои нужды
# ------------------------------
# Данные для подключения к продакшен-серверу
PROD_SSH_USER="your_ssh_username"
PROD_SSH_HOST="your_ssh_host"
PROD_SSH_PORT="22"
PROD_SSH_KEY="$HOME/.ssh/id_rsa"  # Путь к SSH ключу

# Пути на продакшен-сервере
PROD_WP_PATH="/path/to/wordpress"  # Путь к WordPress на продакшен-сервере
PROD_DB_NAME="prod_db_name"        # Имя базы данных
PROD_DB_USER="prod_db_user"        # Пользователь базы данных
PROD_DB_PASS="prod_db_password"    # Пароль базы данных
PROD_SITE_URL="https://example.com" # URL продакшен-сайта

# Пути на локальном компьютере (WSL)
LOCAL_WP_PATH="$HOME/www/wordpress" # Путь для сохранения WordPress на локальном компьютере
LOCAL_DB_NAME="local_db_name"      # Имя локальной базы данных
LOCAL_DB_USER="local_db_user"      # Пользователь локальной базы данных
LOCAL_DB_PASS="local_db_password"  # Пароль локальной базы данных
LOCAL_SITE_URL="http://localhost"  # URL локального сайта

# Временные файлы
DUMP_FILE="wp_database_dump.sql"
BACKUP_DIR="$HOME/wp_backups/$(date +%Y%m%d_%H%M%S)"

# ------------------------------
# Функция для вывода статуса
# ------------------------------
status_message() {
    echo -e "\n\033[1;34m===> $1\033[0m"
}

error_message() {
    echo -e "\n\033[1;31mОШИБКА: $1\033[0m"
    exit 1
}

# ------------------------------
# Создание директории для бэкапов
# ------------------------------
status_message "Создание директории для бэкапов: $BACKUP_DIR"
mkdir -p "$BACKUP_DIR" || error_message "Не удалось создать директорию для бэкапов"

# ------------------------------
# Экспорт базы данных с продакшен-сервера
# ------------------------------
status_message "Экспорт базы данных с продакшен-сервера"
ssh -i "$PROD_SSH_KEY" -p "$PROD_SSH_PORT" "$PROD_SSH_USER@$PROD_SSH_HOST" "cd $PROD_WP_PATH && wp db export $DUMP_FILE --add-drop-table" || error_message "Не удалось экспортировать базу данных с продакшен-сервера"

# ------------------------------
# Копирование дампа базы данных на локальный компьютер
# ------------------------------
status_message "Копирование дампа базы данных на локальный компьютер"
scp -i "$PROD_SSH_KEY" -P "$PROD_SSH_PORT" "$PROD_SSH_USER@$PROD_SSH_HOST:$PROD_WP_PATH/$DUMP_FILE" "$BACKUP_DIR/" || error_message "Не удалось скопировать дамп базы данных"

# ------------------------------
# Копирование файлов WordPress с продакшен-сервера
# ------------------------------
status_message "Копирование файлов WordPress с продакшен-сервера"
rsync -avz -e "ssh -i $PROD_SSH_KEY -p $PROD_SSH_PORT" \
    --exclude=".git" \
    --exclude=".gitignore" \
    --exclude="node_modules" \
    --exclude="wp-content/uploads/cache" \
    --exclude="wp-content/cache" \
    --exclude="wp-content/debug.log" \
    --exclude="wp-content/upgrade" \
    --exclude="wp-content/backup*" \
    --exclude="wp-content/uploads/backup*" \
    --exclude="wp-content/ai1wm-backups" \
    "$PROD_SSH_USER@$PROD_SSH_HOST:$PROD_WP_PATH/" "$LOCAL_WP_PATH/" || error_message "Не удалось скопировать файлы WordPress"

# ------------------------------
# Удаление бэкапа базы данных с продакшен-сервера
# ------------------------------
status_message "Удаление временного дампа с продакшен-сервера"
ssh -i "$PROD_SSH_KEY" -p "$PROD_SSH_PORT" "$PROD_SSH_USER@$PROD_SSH_HOST" "rm $PROD_WP_PATH/$DUMP_FILE" || error_message "Не удалось удалить временный дамп с продакшен-сервера"

# ------------------------------
# Создание локальной базы данных (если не существует)
# ------------------------------
status_message "Создание локальной базы данных (если не существует)"
mysql -u "$LOCAL_DB_USER" -p"$LOCAL_DB_PASS" -e "CREATE DATABASE IF NOT EXISTS $LOCAL_DB_NAME CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" || error_message "Не удалось создать локальную базу данных"

# ------------------------------
# Импорт базы данных в локальную среду
# ------------------------------
status_message "Импорт базы данных в локальную среду"
mysql -u "$LOCAL_DB_USER" -p"$LOCAL_DB_PASS" "$LOCAL_DB_NAME" < "$BACKUP_DIR/$DUMP_FILE" || error_message "Не удалось импортировать базу данных"

# ------------------------------
# Создание локального wp-config.php если он не существует
# ------------------------------
status_message "Проверка wp-config.php"
if [ ! -f "$LOCAL_WP_PATH/wp-config.php" ]; then
    status_message "Создание wp-config.php для локальной среды"
    cd "$LOCAL_WP_PATH" || error_message "Не удалось перейти в директорию WordPress"
    
    wp config create \
        --dbname="$LOCAL_DB_NAME" \
        --dbuser="$LOCAL_DB_USER" \
        --dbpass="$LOCAL_DB_PASS" \
        --dbhost="localhost" \
        --dbcharset="utf8mb4" \
        --dbcollate="utf8mb4_unicode_ci" \
        --extra-php <<PHP
define('WP_DEBUG', true);
define('WP_DEBUG_LOG', true);
define('WP_DEBUG_DISPLAY', false);
define('WP_ENVIRONMENT_TYPE', 'local');
PHP
fi

# ------------------------------
# Обновление URL в базе данных с использованием wp-cli
# ------------------------------
status_message "Обновление URL в базе данных"
cd "$LOCAL_WP_PATH" || error_message "Не удалось перейти в директорию WordPress"

# Обновление home и siteurl
wp option update home "$LOCAL_SITE_URL" || error_message "Не удалось обновить home URL"
wp option update siteurl "$LOCAL_SITE_URL" || error_message "Не удалось обновить site URL"

# Замена URL в контенте
status_message "Замена URL в контенте и мета-данных"
wp search-replace "$PROD_SITE_URL" "$LOCAL_SITE_URL" --all-tables --skip-columns=guid || error_message "Не удалось заменить URL в контенте"

# ------------------------------
# Обновление прав доступа к файлам
# ------------------------------
status_message "Обновление прав доступа к файлам"
find "$LOCAL_WP_PATH" -type d -exec chmod 755 {} \;
find "$LOCAL_WP_PATH" -type f -exec chmod 644 {} \;

# ------------------------------
# Очистка кэша и временных файлов
# ------------------------------
status_message "Очистка кэша"
wp cache flush || true

# ------------------------------
# Деактивация определенных плагинов для локальной среды
# ------------------------------
status_message "Деактивация плагинов, не нужных для локальной среды"
wp plugin deactivate \
    w3-total-cache \
    wp-super-cache \
    wordfence \
    wp-rocket \
    better-wp-security \
    all-in-one-wp-security-and-firewall \
    wp-optimize \
    autoptimize \
    --skip-plugins --skip-themes || true

# ------------------------------
# Финальное сообщение
# ------------------------------
status_message "Миграция завершена успешно!"
echo "Ваш WordPress сайт был успешно скопирован с продакшен-сервера на локальную WSL среду."
echo "Локальный URL: $LOCAL_SITE_URL"
echo "Локальный путь: $LOCAL_WP_PATH"
echo "Бэкап сохранен в: $BACKUP_DIR"
echo "Для доступа к админке используйте те же учетные данные, что и на продакшен-сервере."
