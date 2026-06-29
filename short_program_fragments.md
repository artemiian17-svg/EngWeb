# Приложение А. Фрагменты программного кода

В данном приложении приведены не полные листинги файлов, а наиболее значимые фрагменты программного кода, демонстрирующие реализацию пользовательского интерфейса, клиент-серверного взаимодействия, серверного хранения данных и разграничения прав доступа. Полный исходный код проекта размещается в файлах проекта.

## main.js - формирование общего шаблона страниц

Файл `main.js` содержит общие функции интерфейса. С его помощью на страницах формируются шапка сайта, подвал, навигационное меню и элементы, зависящие от состояния авторизации.

```javascript
function createHeader() {
  const page = document.body.dataset.page;
  const auth = isAuthorized();
  const navLinks = [
    { href: "index.html", label: "ГЛАВНАЯ", key: "home" },
    { href: "services.html", label: "УСЛУГИ", key: "services" },
    { href: "lessons.html", label: "УРОКИ", key: "lessons" },
    { href: "blog.html", label: "БЛОГ", key: "blog" },
    { href: "contacts.html", label: "КОНТАКТЫ", key: "contacts" },
  ];

  const hiddenLinks = auth
    ? `
      <a href="create-post.html" class="${location.pathname.endsWith("create-post.html") ? "active" : ""}">ПУБЛИКАЦИИ</a>
      <a href="requests.html" class="${location.pathname.endsWith("requests.html") ? "active" : ""}">ЗАЯВКИ</a>
    `
    : "";

  const authControl = auth
    ? `<button class="link-button" id="logout-button" type="button">ВЫХОД</button>`
    : `<a href="login.html">ВХОД</a>`;

  return `
    <header class="site-header">
      <div class="site-header-inner">
        <a class="brand" href="index.html">
          <span class="brand-mark">LF</span>
          <span class="brand-text">LingoFlux</span>
        </a>
        <nav class="menu-links" id="menu-links">
          ${navLinks.map((link) => `<a href="${link.href}" class="${page === link.key ? "active" : ""}">${link.label}</a>`).join("")}
          ${hiddenLinks}
        </nav>
        <div class="header-controls">
          ${authControl}
          <button class="menu-toggle" id="menu-toggle" type="button" aria-label="Меню"><span></span></button>
        </div>
      </div>
    </header>
  `;
}
```

## data-service.js - сервисный слой клиентской части

Файл `data-service.js` выступает посредником между страницами сайта и серверной частью. Клиентские страницы не обращаются к хранилищу напрямую, а используют методы сервиса.

```javascript
async function apiRequest(method, path, body) {
  const response = await fetch(`${API_BASE}${path}`, {
    method,
    credentials: "same-origin",
    headers: {
      Accept: "application/json",
      ...(body !== undefined ? { "Content-Type": "application/json; charset=utf-8" } : {}),
    },
    body: body !== undefined ? JSON.stringify(body) : undefined,
  });

  const contentType = response.headers.get("content-type") || "";
  const payload = contentType.includes("application/json")
    ? await response.json()
    : null;

  if (!response.ok) {
    const error = new Error(payload?.error || payload?.message || `HTTP ${response.status}`);
    error.status = response.status;
    throw error;
  }

  return payload;
}
```

```javascript
window.appService = {
  posts: {
    async list() {
      await backendReady;
      return backendMode === "server"
        ? apiRequest("GET", "/posts")
        : localService.listPosts();
    },
    async create(payload) {
      await backendReady;
      const created = backendMode === "server"
        ? await apiRequest("POST", "/posts", {
            id: createId("post"),
            title: payload.title,
            summary: payload.summary || "",
            body: payload.body,
            date: new Date().toISOString(),
            image: payload.image || "",
            attachment: payload.attachment || null,
          })
        : await localService.createPost(payload);

      markUpdated();
      return created;
    },
  },
};
```

## server.js - серверная часть и API

Файл `server.js` реализует локальный backend. Он принимает HTTP-запросы, обрабатывает маршруты API, выполняет проверку авторизации и сохраняет данные в файл `backend-data.json`.

```javascript
function readData() {
  ensureDataFile();
  try {
    const raw = fs.readFileSync(dataPath, "utf8");
    const parsed = JSON.parse(raw);
    return {
      posts: Array.isArray(parsed.posts) ? parsed.posts : [],
      requests: Array.isArray(parsed.requests) ? parsed.requests : [],
      lessons: Array.isArray(parsed.lessons) ? parsed.lessons : [],
    };
  } catch {
    const fallback = createDefaultData();
    fs.writeFileSync(dataPath, JSON.stringify(fallback, null, 2), "utf8");
    return fallback;
  }
}

function writeData(data) {
  fs.writeFileSync(dataPath, JSON.stringify(data, null, 2), "utf8");
}
```

```javascript
if (req.method === "POST" && cleanPath === "/api/auth/login") {
  const payload = await readJsonBody(req);
  const login = String(payload.login || "");
  const password = String(payload.password || "");
  const match = adminUsers.find((item) => item.login === login && item.password === password);

  if (!match) {
    sendJson(res, 401, { success: false, error: messages.invalidCredentials });
    return;
  }

  const sessionId = crypto.randomBytes(24).toString("hex");
  sessions.set(sessionId, { login, createdAt: new Date().toISOString() });
  sendJson(res, 200, { success: true, authorized: true }, {
    "Set-Cookie": `${authCookieName}=${sessionId}; Path=/; HttpOnly; SameSite=Lax`,
  });
  return;
}
```

```javascript
if (req.method === "POST" && cleanPath === "/api/requests") {
  const payload = await readJsonBody(req);
  const data = readData();
  const created = {
    id: String(payload.id || ""),
    fullname: String(payload.fullname || ""),
    phone: String(payload.phone || ""),
    email: String(payload.email || ""),
    message: String(payload.message || ""),
    date: String(payload.date || new Date().toISOString()),
  };

  data.requests.unshift(created);
  writeData(data);
  sendJson(res, 201, created);
  return;
}
```

## contacts.js - отправка заявки пользователя

Форма обратной связи проверяет данные пользователя, после чего отправляет заявку через сервисный слой. В зависимости от режима работы данные сохраняются на сервере или в резервном локальном хранилище.

```javascript
contactForm.addEventListener("submit", async (event) => {
  event.preventDefault();

  if (!validateContactForm() || !window.appService) {
    return;
  }

  const payload = getContactPayload();
  const request = await window.appService.requests.create(payload);

  contactResult.classList.remove("hidden");
  contactResult.innerHTML = `
    <p class="eyebrow">ЗАЯВКА ПРИНЯТА</p>
    <h3>${payload.fullname}</h3>
    <p><strong>Дата:</strong> ${contactAppState.formatDate(request.date)}</p>
    <p><strong>Телефон:</strong> ${payload.phone}</p>
    <p><strong>Email:</strong> ${payload.email}</p>
    <p><strong>Сообщение:</strong> ${payload.message}</p>
  `;

  contactForm.reset();
  validateContactForm();
});
```

## lessons.js - разграничение доступа к управлению уроками

На странице уроков обычный пользователь может просматривать материалы, но создание и удаление уроков доступно только авторизованному сотруднику.

```javascript
let canManageLessons = false;

async function refreshLessonPermissions() {
  if (window.appService) {
    canManageLessons = await window.appService.auth.status();
  } else {
    canManageLessons = false;
  }

  syncLessonAccess();
  validateLessonForm();
  await renderLessons();
}
```

```javascript
if (lessonForm) {
  lessonForm.addEventListener("submit", async (event) => {
    event.preventDefault();

    if (!validateLessonForm() || !window.appService || !canManageLessons) {
      return;
    }

    const payload = getLessonPayload();
    const lesson = await window.appService.lessons.create(payload);

    lessonResult.classList.remove("hidden");
    lessonResult.innerHTML = `
      <p class="eyebrow">УРОК СОЗДАН</p>
      <h3>${lesson.title}</h3>
      <p><strong>Язык:</strong> ${lesson.language}</p>
    `;

    lessonForm.reset();
    await renderLessons();
  });
}
```

## Вывод по приложению

Приведенные фрагменты демонстрируют основные программные решения проекта: формирование общего интерфейса страниц, работу сервисного слоя, обработку API-запросов на сервере, сохранение данных, отправку пользовательских заявок и разграничение доступа к административным действиям. Полный листинг программы не приводится в пояснительной записке из-за большого объема исходного кода.
