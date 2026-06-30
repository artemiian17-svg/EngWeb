# Lingoflux C++ Backend Showcase

Небольшой backend-проект на C++20, добавленный как отдельный демонстрационный модуль к основному учебному проекту. Цель проекта — показать навыки backend-разработки на C++: HTTP-обработка, роутинг, авторизация, потокобезопасное состояние, JSON, персистентность и тестируемая архитектура.

## Что демонстрирует проект

- C++20 без тяжелых внешних зависимостей.
- Слой HTTP-запросов и ответов.
- REST-подобный router с параметрами пути.
- Bearer-token авторизация для защищенных операций.
- Потокобезопасное in-memory хранилище с сохранением в JSON-файл.
- Метрики приложения: uptime, количество запросов, количество ошибок.
- Unit-тесты для JSON, авторизации, роутинга и хранилища.
- Разделение на `include/`, `src/`, `tests/`.

## API

| Method | Path | Auth | Description |
|---|---|---:|---|
| `GET` | `/health` | no | Проверка состояния сервера |
| `GET` | `/api/lessons` | no | Получить список уроков |
| `POST` | `/api/auth/login` | no | Получить bearer-token |
| `POST` | `/api/lessons` | yes | Создать урок |
| `DELETE` | `/api/lessons/{id}` | yes | Удалить урок |
| `GET` | `/api/metrics` | yes | Получить технические метрики |

Демо-учетные данные:

```json
{"login":"admin","password":"admin2026"}
```

## Сборка

```bash
cmake -S . -B build
cmake --build build --config Release
ctest --test-dir build --output-on-failure
```

## Запуск

```bash
./build/lingoflux-server --port 8080 --data data/lessons.json
```

Windows:

```powershell
.\build\Release\lingoflux-server.exe --port 8080 --data data\lessons.json
```

## Примеры запросов

```bash
curl http://localhost:8080/health
curl http://localhost:8080/api/lessons
curl -X POST http://localhost:8080/api/auth/login ^
  -H "Content-Type: application/json" ^
  -d "{\"login\":\"admin\",\"password\":\"admin2026\"}"
```

Полный набор примеров находится в `docs/api.http`.

## Почему это полезно для C++ backend

Проект не пытается заменить production-фреймворк. Он показывает понимание базовых backend-механизмов: как HTTP-запрос превращается в доменную операцию, как отделить роутинг от бизнес-логики, как ограничить доступ к защищенным операциям, как хранить состояние безопасно при параллельных запросах и как сделать код проверяемым тестами.
