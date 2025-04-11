# Скрипт миграции WordPress с продакшен-сервера на локальную WSL среду

Данный скрипт предназначен для автоматизации процесса копирования WordPress сайта с продакшен-сервера (виртуальный хостинг) на локальную среду разработки в Windows Subsystem for Linux (WSL). Скрипт выполняет экспорт базы данных, копирование файлов и настройку локального окружения для корректной работы сайта.

## Возможности скрипта

- Экспорт базы данных с продакшен-сервера с помощью WP-CLI
- Безопасное копирование файлов WordPress через SSH с исключением ненужных файлов и директорий
- Импорт базы данных в локальную среду
- Автоматическое обновление URL в базе данных для корректной работы в локальном окружении
- Настройка оптимальных прав доступа к файлам
- Деактивация плагинов, которые не нужны или могут мешать работе в локальной среде
- Очистка кэша и временных файлов
- Создание резервных копий в процессе миграции

## Требования

Для работы скрипта требуются следующие компоненты:

- Linux или Windows с установленной WSL
- WP-CLI (установленный как на продакшен-сервере, так и на локальной машине)
- SSH-клиент
- MySQL клиент
- rsync
- Права на доступ к продакшен-серверу через SSH
- Доступ к базе данных на продакшен-сервере

## Подготовка к использованию

1. Скопируйте скрипт в удобную директорию в вашей WSL среде.
2. Откройте скрипт в текстовом редакторе и отредактируйте секцию конфигурации:
   - Настройте данные для подключения к продакшен-серверу (SSH)
   - Укажите пути к WordPress на продакшен-сервере и локальной машине
   - Введите данные для доступа к базам данных (продакшен и локальная)
   - При необходимости измените URL сайтов
3. Сделайте скрипт исполняемым:
   ```bash
   chmod +x имя_скрипта.sh
   ```

## Настройка параметров

Основные параметры, которые нужно изменить перед запуском:

```bash
# Данные для подключения к продакшен-серверу
PROD_SSH_USER="your_ssh_username"
PROD_SSH_HOST="your_ssh_host"
PROD_SSH_PORT="22"
PROD_SSH_KEY="$HOME/.ssh/id_rsa"

# Пути на продакшен-сервере
PROD_WP_PATH="/path/to/wordpress"
PROD_DB_NAME="prod_db_name"
PROD_DB_USER="prod_db_user"
PROD_DB_PASS="prod_db_password"
PROD_SITE_URL="https://example.com"

# Пути на локальном компьютере (WSL)
LOCAL_WP_PATH="$HOME/www/wordpress"
LOCAL_DB_NAME="local_db_name"
LOCAL_DB_USER="local_db_user"
LOCAL_DB_PASS="local_db_password"
LOCAL_SITE_URL="http://localhost"
```

## Использование

Запустите скрипт из командной строки:

```bash
./имя_скрипта.sh
```

Скрипт последовательно выполнит все операции, отображая информацию о каждом этапе процесса. В случае возникновения ошибок, скрипт остановит выполнение и выведет сообщение об ошибке.

## Процесс выполнения

1. Создание директории для бэкапов с текущей датой и временем
2. Экспорт базы данных с продакшен-сервера с помощью WP-CLI
3. Копирование дампа базы данных на локальный компьютер
4. Копирование файлов WordPress с продакшен-сервера с исключением кэшей и временных файлов
5. Удаление временного дампа с продакшен-сервера
6. Создание локальной базы данных (если не существует)
7. Импорт базы данных в локальную среду
8. Создание локального wp-config.php (если не существует)
9. Обновление URL в базе данных (home, siteurl и контент)
10. Настройка прав доступа к файлам и директориям
11. Очистка кэша WordPress
12. Деактивация плагинов, не нужных для локальной разработки

## Исключаемые файлы и директории

При копировании файлов WordPress, скрипт исключает следующие элементы:

- `.git` и `.gitignore` (системные файлы Git)
- `node_modules` (модули Node.js)
- Кэши и временные файлы WordPress
- Директории с бэкапами
- Журналы отладки

## Безопасность

Скрипт содержит пароли в текстовом виде, поэтому рекомендуется:

1. Убедиться, что файл скрипта имеет безопасные права доступа (рекомендуется 700)
2. Не хранить скрипт в общедоступных репозиториях
3. Рассмотреть возможность получения паролей из переменных окружения или файла конфигурации с ограниченными правами доступа

## Дополнительные настройки

Вы можете адаптировать скрипт под свои нужды, например:

- Изменить список исключаемых файлов и директорий в команде rsync
- Добавить или удалить плагины в списке деактивации
- Настроить дополнительные параметры wp-config.php для локальной среды
- Добавить шаги для установки дополнительных плагинов, необходимых для разработки

## Устранение неполадок

Если скрипт завершается с ошибкой, обратите внимание на следующее:

1. Проверьте правильность данных для подключения к SSH и базе данных
2. Убедитесь, что у пользователя SSH есть права на чтение файлов WordPress и экспорт базы данных
3. Проверьте наличие WP-CLI на продакшен-сервере и локальной машине
4. Убедитесь, что на локальной машине установлены необходимые утилиты (mysql, rsync)
5. Проверьте, что у локального пользователя MySQL есть права на создание базы данных

## Соответствие лучшим практикам WordPress

Скрипт разработан в соответствии с лучшими практиками WordPress:

- Использование WP-CLI для работы с базой данных и настройками WordPress
- Правильное обновление URL через функции WordPress вместо прямых SQL-запросов
- Сохранение структуры каталогов WordPress
- Корректное обновление прав доступа к файлам и директориям
- Деактивация плагинов, которые могут вызвать проблемы в локальной среде
- Очистка кэша для корректной работы сайта после миграции

## Лицензия

Этот скрипт распространяется под лицензией MIT.

## Отказ от ответственности

Перед использованием скрипта на рабочих сайтах рекомендуется сделать полный бэкап данных. Автор не несет ответственности за возможные проблемы или потерю данных, возникшие в результате использования скрипта.
