#!/bin/bash

# ================================================================
# WordPress Files Synchronization Script
# ================================================================
# Этот скрипт синхронизирует файлы с производственного 
# сервера WordPress на локальную машину WSL Debian/Ubuntu
# Скрипт создает резервные копии локальных файлов перед синхронизацией
# и исправляет права доступа к файлам после синхронизации
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

# Каталоги для синхронизации (относительно корня WordPress)
SYNC_DIRS=(
    "wp-content/themes"
    "wp-content/plugins"
    "wp-content/uploads"
    "wp-content/mu-plugins"
    "wp-content/languages"
)

# Каталоги и файлы для исключения из синхронизации
EXCLUDE=(
    "wp-content/cache"
    "wp-content/upgrade"
    "wp-content/uploads/cache"
    "wp-content/plugins/*/cache"
    "wp-content/debug.log"
    ".git"
    "node_modules"
    ".sass-cache"
    ".DS_Store"
    "*.log"
    "*.sql"
    "*.tar"
    "*.gz"
    "*.zip"
)

# Временные файлы
TIMESTAMP=$(date +"%Y%m%d%H%M%S")
BACKUP_DIR="$LOCAL_PATH/backups"
LOG_FILE="$BACKUP_DIR/file_sync_$TIMESTAMP.log"

# ===== Функции =====

# Функция вывода информации
info() {
    echo -e "${GREEN}[INFO]${NC} $1"
    echo "[INFO] $1" >> "$LOG_FILE"
}

# Функция вывода предупреждений
warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
    echo "[WARNING] $1" >> "$LOG_FILE"
}

# Функция вывода ошибок
error() {
    echo -e "${RED}[ERROR]${NC} $1"
    echo "[ERROR] $1" >> "$LOG_FILE"
    exit 1
}

# Создание директории для бэкапов и лога, если они не существуют
create_backup_dir() {
    if [ ! -d "$BACKUP_DIR" ]; then
        info "Создание директории для бэкапов..."
        mkdir -p "$BACKUP_DIR"
        if [ $? -ne 0 ]; then
            error "Не удалось создать директорию для бэкапов"
        fi
    fi
    
    # Инициализация лог-файла
    echo "==== WordPress Files Sync Log - $(date) ====" > "$LOG_FILE"
}

# Проверка наличия зависимостей
check_dependencies() {
    info "Проверка зависимостей..."
    
    # Проверка наличия rsync
    if ! command -v rsync &> /dev/null; then
        error "rsync не установлен. Установите его с помощью: sudo apt-get install rsync"
    fi
    
    # Проверка наличия ssh
    if ! command -v ssh &> /dev/null; then
        error "ssh не установлен. Установите его с помощью: sudo apt-get install openssh-client"
    fi  # <-- This was the issue: } instead of fi
    
    # Проверка соединения с удаленным сервером
    info "Проверка подключения к удаленному серверу..."
    ssh -p "$REMOTE_PORT" -o BatchMode=yes -o ConnectTimeout=5 "$REMOTE_USER@$REMOTE_HOST" "echo Connected" &> /dev/null
    if [ $? -ne 0 ]; then
        error "Не удалось подключиться к удаленному серверу. Проверьте настройки SSH и доступность сервера."
    fi
}

# Создание резервных копий локальных директорий перед синхронизацией
backup_local_directories() {
    info "Создание резервных копий локальных директорий..."
    
    for dir in "${SYNC_DIRS[@]}"; do
        local local_dir="$LOCAL_PATH/$dir"
        local backup_dir="$BACKUP_DIR/$(basename "$dir")_$TIMESTAMP"
        
        if [ -d "$local_dir" ]; then
            info "Создание резервной копии директории: $dir"
            mkdir -p "$(dirname "$backup_dir")"
            cp -a "$local_dir" "$backup_dir"
            if [ $? -ne 0 ]; then
                warn "Не удалось создать резервную копию директории: $dir"
            fi
        else
            warn "Локальная директория не существует, создание резервной копии пропущено: $dir"
        fi
    done
    
    info "Резервные копии локальных директорий созданы в $BACKUP_DIR"
}

# Синхронизация файлов с удаленного сервера
sync_files() {
    info "Начало синхронизации файлов с удаленного сервера..."
    
    # Построение строки исключений для rsync
    EXCLUDE_OPTS=""
    for item in "${EXCLUDE[@]}"; do
        EXCLUDE_OPTS="$EXCLUDE_OPTS --exclude=$item"
    done
    
    # Синхронизация каждой директории
    for dir in "${SYNC_DIRS[@]}"; do
        info "Синхронизация директории: $dir"
        
        # Создание локальной директории, если она не существует
        local local_dir="$LOCAL_PATH/$dir"
        if [ ! -d "$local_dir" ]; then
            mkdir -p "$local_dir"
        fi
        
        # Синхронизация с удаленного сервера
        rsync -avz --progress --delete \
            -e "ssh -p $REMOTE_PORT" \
            $EXCLUDE_OPTS \
            "$REMOTE_USER@$REMOTE_HOST:$REMOTE_PATH/$dir/" \
            "$local_dir/" \
            >> "$LOG_FILE" 2>&1
        
        if [ $? -ne 0 ]; then
            warn "Возможные проблемы при синхронизации директории: $dir"
        else
            info "Директория успешно синхронизирована: $dir"
        fi
    done
}

# Исправление прав доступа к файлам
fix_permissions() {
    info "Исправление прав доступа к файлам..."
    
    # Определение группы веб-сервера (обычно www-data)
    local web_user="www-data"
    local web_group="www-data"
    
    # Установка прав доступа
    find "$LOCAL_PATH" -type d -exec chmod 755 {} \;
    find "$LOCAL_PATH" -type f -exec chmod 644 {} \;
    
    # Проверка, запущен ли скрипт с правами root
    if [ "$(id -u)" -eq 0 ]; then
        # Если скрипт запущен с правами root, можно изменить владельца
        chown -R "$web_user:$web_group" "$LOCAL_PATH"
    else
        warn "Скрипт запущен без прав root. Изменение владельца файлов пропущено."
        warn "Для полного исправления прав доступа, запустите скрипт с sudo."
    fi
    
    info "Права доступа исправлены"
}

# Очистка кэша WordPress
flush_cache() {
    if command -v wp &> /dev/null; then
        info "Сброс кэша WordPress..."
        cd "$LOCAL_PATH" && wp cache flush --allow-root
        if [ $? -ne 0 ]; then
            warn "Не удалось сбросить кэш WordPress"
        fi
    else
        warn "WP-CLI не установлен. Пропуск сброса кэша WordPress."
    fi
}

# ===== Основной скрипт =====

# Вывод приветствия
echo "======================================================"
echo "     WordPress Files Synchronization Script"
echo "======================================================"
echo ""

# Проверка зависимостей и создание директорий
create_backup_dir
check_dependencies

# Резервное копирование локальных файлов
backup_local_directories

# Синхронизация файлов
sync_files

# Исправление прав доступа
fix_permissions

# Очистка кэша
flush_cache

echo ""
echo "======================================================"
echo "Файлы WordPress успешно синхронизированы!"
echo "Подробный лог доступен в: $LOG_FILE"
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
   - SYNC_DIRS - список каталогов для синхронизации
   - EXCLUDE - список исключаемых файлов и каталогов

2. Настройте SSH-доступ к удаленному серверу без пароля (рекомендуется):
   ssh-keygen -t rsa
   ssh-copy-id -p $REMOTE_PORT $REMOTE_USER@$REMOTE_HOST

3. Сделайте скрипт исполняемым:
   chmod +x wordpress-files-sync.sh

4. Запустите скрипт (лучше от имени root для правильной установки прав):
   sudo ./wordpress-files-sync.sh

ЗАМЕТКИ:
- Скрипт создает резервные копии локальных файлов перед синхронизацией
- Для больших сайтов синхронизация может занять значительное время
- Чтобы синхронизировать отдельные каталоги, отредактируйте переменную SYNC_DIRS
- Для исключения дополнительных файлов/каталогов, добавьте их в переменную EXCLUDE

EOF
