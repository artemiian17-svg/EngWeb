const STORAGE_KEYS = {
  posts: "lingoflux-posts",
  requests: "lingoflux-requests",
  auth: "lingoflux-auth",
  lessons: "lingoflux-lessons",
  app: "lingoflux-app-store",
};

const AUTH_QUERY_VALUE = "granted";
const AUTH_COOKIE_NAME = "lingoflux_auth";
const DB_NAME = "lingoflux-nosql";
const DB_VERSION = 1;
const DB_STORE_NAME = "appState";
const DB_RECORD_KEY = "primary";

const DEFAULT_POSTS = [
  {
    id: "post-1",
    title: "Как перейти от изучения слов к реальной речи",
    body: "**Главная ошибка** начинающих состоит в том, что слова учатся отдельно от контекста.\n\n- Используйте короткие диалоги.\n- Повторяйте лексику в готовых фразах.\n- Возвращайтесь к словам через 2-3 дня.\n\nТак язык быстрее становится рабочим инструментом.",
    date: "2026-04-27",
    image: "",
  },
  {
    id: "post-2",
    title: "Почему короткие занятия работают лучше марафонов",
    body: "Регулярность важнее редких интенсивов. **15 минут в день** дают устойчивую привычку и уменьшают перегрузку.\n\nТакая модель особенно удобна для взрослых пользователей, совмещающих обучение с работой.",
    date: "2026-04-24",
    image: "",
  },
  {
    id: "post-3",
    title: "Три шага для практики английского перед поездкой",
    body: "Перед путешествием важно потренировать **типовые диалоги**.\n\n- Вопросы в аэропорту.\n- Бронирование и заселение.\n- Заказ еды и уточнение маршрута.\n\nТакой набор дает быстрый прикладной результат и снижает стресс в поездке.",
    date: "2026-04-22",
    image: "",
  },
  {
    id: "post-4",
    title: "Как не бросить язык после первой недели",
    body: "Секрет в том, чтобы не строить обучение вокруг больших обещаний.\n\nЛучше зафиксировать **один короткий ритуал**: открыть урок утром, пройти мини-упражнение днем или повторить лексику вечером. Постоянство важнее объема.",
    date: "2026-04-20",
    image: "",
  },
];

const DEFAULT_LESSONS = [
  {
    id: "lesson-1",
    level: "Beginner",
    title: "Знакомство и первый small talk",
    duration: "12 минут",
    language: "Английский",
    goal: "Научиться представляться, задавать простые вопросы и поддерживать короткий диалог.",
    tasks: ["Прочитать 8 фраз", "Повторить 6 реплик", "Собрать мини-диалог"],
  },
  {
    id: "lesson-2",
    level: "Intermediate",
    title: "Путешествие: аэропорт и регистрация",
    duration: "18 минут",
    language: "Английский",
    goal: "Отработать лексику и типовые вопросы для перемещения по аэропорту.",
    tasks: ["Лексика по теме", "Диалог в аэропорту", "Проверка понимания"],
  },
  {
    id: "lesson-3",
    level: "Beginner",
    title: "Испанский для кафе и заказов",
    duration: "14 минут",
    language: "Испанский",
    goal: "Научиться заказывать блюда, уточнять состав и вежливо общаться с персоналом.",
    tasks: ["5 ключевых конструкций", "Меню и ингредиенты", "Практика реплик"],
  },
  {
    id: "lesson-4",
    level: "Upper-Intermediate",
    title: "Рабочая встреча на немецком",
    duration: "20 минут",
    language: "Немецкий",
    goal: "Закрепить лексику делового общения и вежливые формулировки на встречах.",
    tasks: ["Фразы для начала встречи", "Согласование действий", "Итоговое упражнение"],
  },
];

const APP_DEFAULT_STATE = {
  posts: DEFAULT_POSTS,
  requests: [],
  lessons: DEFAULT_LESSONS,
  auth: false,
};

const storageBridge = (() => {
  const memoryStore = {};

  function readWindowName() {
    try {
      return window.name ? JSON.parse(window.name) : {};
    } catch (error) {
      return {};
    }
  }

  function writeWindowName(payload) {
    try {
      window.name = JSON.stringify(payload);
    } catch (error) {
      window.name = "";
    }
  }

  function canUseLocalStorage() {
    try {
      const probe = "__lingoflux_probe__";
      window.localStorage.setItem(probe, "1");
      window.localStorage.removeItem(probe);
      return true;
    } catch (error) {
      return false;
    }
  }

  const localStorageEnabled = canUseLocalStorage();

  function getItem(key) {
    if (localStorageEnabled) {
      return window.localStorage.getItem(key);
    }

    const payload = readWindowName();
    if (Object.prototype.hasOwnProperty.call(payload, key)) {
      return payload[key];
    }
    if (Object.prototype.hasOwnProperty.call(memoryStore, key)) {
      return memoryStore[key];
    }
    return null;
  }

  function setItem(key, value) {
    if (localStorageEnabled) {
      window.localStorage.setItem(key, value);
      return;
    }

    const payload = readWindowName();
    payload[key] = value;
    memoryStore[key] = value;
    writeWindowName(payload);
  }

  return {
    getItem,
    setItem,
    canUseLocalStorage,
  };
})();

function safeJsonParse(value, fallback) {
  try {
    return value ? JSON.parse(value) : fallback;
  } catch (error) {
    return fallback;
  }
}

function cloneDefaultState() {
  return JSON.parse(JSON.stringify(APP_DEFAULT_STATE));
}

function normalizeState(value) {
  return {
    posts: Array.isArray(value?.posts) ? value.posts : [...DEFAULT_POSTS],
    requests: Array.isArray(value?.requests) ? value.requests : [],
    lessons: Array.isArray(value?.lessons) ? value.lessons : [...DEFAULT_LESSONS],
    auth: value?.auth === true,
  };
}

function dispatchStoreEvent(name) {
  document.dispatchEvent(new CustomEvent(name, { detail: { source: "appState" } }));
}

function setCookieAuth(value) {
  try {
    document.cookie = `${AUTH_COOKIE_NAME}=${value ? "true" : "false"}; path=/; max-age=2592000`;
  } catch (error) {
    document.cookie = `${AUTH_COOKIE_NAME}=${value ? "true" : "false"}`;
  }
}

function getCookieAuth() {
  return document.cookie
    .split(";")
    .map((item) => item.trim())
    .some((item) => item === `${AUTH_COOKIE_NAME}=true`);
}

function hasAuthQuery() {
  const params = new URLSearchParams(window.location.search);
  return params.get("auth") === AUTH_QUERY_VALUE;
}

function writeWindowAuth(value) {
  const payload = safeJsonParse(storageBridge.getItem("__window_auth_state__"), {});
  payload.authorized = value;
  storageBridge.setItem("__window_auth_state__", JSON.stringify(payload));
}

function readWindowAuth() {
  const payload = safeJsonParse(storageBridge.getItem("__window_auth_state__"), {});
  return payload.authorized === true;
}

function readLegacyAuth() {
  return storageBridge.getItem(STORAGE_KEYS.auth) === "true";
}

function readLegacyState() {
  const migrated = cloneDefaultState();
  const legacyPosts = safeJsonParse(storageBridge.getItem(STORAGE_KEYS.posts), null);
  const legacyRequests = safeJsonParse(storageBridge.getItem(STORAGE_KEYS.requests), null);
  const legacyLessons = safeJsonParse(storageBridge.getItem(STORAGE_KEYS.lessons), null);

  if (Array.isArray(legacyPosts) && legacyPosts.length) {
    migrated.posts = legacyPosts;
  }
  if (Array.isArray(legacyRequests)) {
    migrated.requests = legacyRequests;
  }
  if (Array.isArray(legacyLessons) && legacyLessons.length) {
    migrated.lessons = legacyLessons;
  }
  migrated.auth = readLegacyAuth();
  return migrated;
}

function mirrorToLegacyStores(store) {
  storageBridge.setItem(STORAGE_KEYS.app, JSON.stringify(store));
  storageBridge.setItem(STORAGE_KEYS.posts, JSON.stringify(store.posts));
  storageBridge.setItem(STORAGE_KEYS.requests, JSON.stringify(store.requests));
  storageBridge.setItem(STORAGE_KEYS.lessons, JSON.stringify(store.lessons));
  storageBridge.setItem(STORAGE_KEYS.auth, store.auth ? "true" : "false");
}

function createDbClient() {
  if (!("indexedDB" in window)) {
    return {
      supported: false,
      async read() {
        return null;
      },
      async write() {
        return false;
      },
    };
  }

  function open() {
    return new Promise((resolve, reject) => {
      const request = window.indexedDB.open(DB_NAME, DB_VERSION);

      request.onupgradeneeded = () => {
        const db = request.result;
        if (!db.objectStoreNames.contains(DB_STORE_NAME)) {
          db.createObjectStore(DB_STORE_NAME, { keyPath: "id" });
        }
      };

      request.onsuccess = () => resolve(request.result);
      request.onerror = () => reject(request.error);
    });
  }

  async function withStore(mode, callback) {
    const db = await open();
    return new Promise((resolve, reject) => {
      const transaction = db.transaction(DB_STORE_NAME, mode);
      const store = transaction.objectStore(DB_STORE_NAME);
      const request = callback(store);

      request.onsuccess = () => resolve(request.result);
      request.onerror = () => reject(request.error);
      transaction.oncomplete = () => db.close();
      transaction.onerror = () => {
        db.close();
        reject(transaction.error);
      };
    });
  }

  return {
    supported: true,
    async read() {
      const record = await withStore("readonly", (store) => store.get(DB_RECORD_KEY));
      return record?.value || null;
    },
    async write(value) {
      await withStore("readwrite", (store) => store.put({ id: DB_RECORD_KEY, value }));
      return true;
    },
  };
}

const dbClient = createDbClient();
let appStore = normalizeState(readLegacyState());

async function persistStore() {
  mirrorToLegacyStores(appStore);
  if (dbClient.supported) {
    try {
      await dbClient.write(appStore);
    } catch (error) {
      console.error("IndexedDB write error:", error);
    }
  }
  dispatchStoreEvent("app-store-updated");
}

async function hydrateStore() {
  mirrorToLegacyStores(appStore);
  if (!dbClient.supported) {
    dispatchStoreEvent("app-store-ready");
    return;
  }

  try {
    const dbState = await dbClient.read();
    if (dbState) {
      appStore = normalizeState(dbState);
      mirrorToLegacyStores(appStore);
    } else {
      await dbClient.write(appStore);
    }
  } catch (error) {
    console.error("IndexedDB read error:", error);
  }

  dispatchStoreEvent("app-store-ready");
}

function getPosts() {
  return [...appStore.posts];
}

function savePosts(posts) {
  appStore.posts = Array.isArray(posts) ? posts : [];
  void persistStore();
}

function getRequests() {
  return [...appStore.requests];
}

function saveRequests(items) {
  appStore.requests = Array.isArray(items) ? items : [];
  void persistStore();
}

function getLessons() {
  return [...appStore.lessons];
}

function saveLessons(items) {
  appStore.lessons = Array.isArray(items) ? items : [];
  void persistStore();
}

function isAuthorized() {
  if (hasAuthQuery()) {
    return true;
  }
  if (appStore.auth === true) {
    return true;
  }
  if (getCookieAuth()) {
    return true;
  }
  return readWindowAuth();
}

function setAuthorized(value) {
  appStore.auth = value === true;
  setCookieAuth(value);
  writeWindowAuth(value);
  void persistStore();
}

function formatDate(isoDate) {
  const date = new Date(isoDate);
  if (Number.isNaN(date.getTime())) {
    return isoDate;
  }
  return date.toLocaleDateString("ru-RU", {
    day: "2-digit",
    month: "long",
    year: "numeric",
  });
}

function inlineMarkdown(text) {
  return text.replace(/\*\*(.+?)\*\*/g, "<strong>$1</strong>").replace(/\*(.+?)\*/g, "<em>$1</em>");
}

function markdownToHtml(text) {
  const safe = String(text)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;");

  return safe
    .split(/\n{2,}/)
    .map((block) => {
      if (block.startsWith("- ")) {
        const items = block
          .split("\n")
          .map((line) => line.replace(/^- /, "").trim())
          .filter(Boolean)
          .map((line) => `<li>${inlineMarkdown(line)}</li>`)
          .join("");
        return `<ul>${items}</ul>`;
      }

      return `<p>${inlineMarkdown(block.replace(/\n/g, "<br>"))}</p>`;
    })
    .join("");
}

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
      <a href="create-post.html?auth=${AUTH_QUERY_VALUE}" class="${location.pathname.endsWith("create-post.html") ? "active" : ""}">ПУБЛИКАЦИИ</a>
      <a href="requests.html?auth=${AUTH_QUERY_VALUE}" class="${location.pathname.endsWith("requests.html") ? "active" : ""}">ЗАЯВКИ</a>
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

function createFooter() {
  return `
    <footer class="site-footer">
      <div class="site-footer-inner">
        <div>
          <strong>LingoFlux</strong>
          <p class="footer-note">Сервис практики иностранных языков с акцентом на регулярные короткие занятия, живые сценарии общения и удобную траекторию обучения.</p>
        </div>
        <div>
          <strong>Контакты</strong>
          <p class="footer-note">Пн-Пт, 10:00-19:00<br>+7 (812) 555-24-18<br>hello@lingoflux.ru</p>
        </div>
      </div>
    </footer>
  `;
}

function renderShell() {
  const header = document.getElementById("site-header");
  const footer = document.getElementById("site-footer");

  if (header) {
    header.innerHTML = createHeader();
  }
  if (footer) {
    footer.innerHTML = createFooter();
  }

  const toggle = document.getElementById("menu-toggle");
  const menu = document.getElementById("menu-links");

  if (toggle && menu) {
    toggle.addEventListener("click", () => {
      toggle.classList.toggle("open");
      menu.classList.toggle("open");
    });
  }

  const logout = document.getElementById("logout-button");
  if (logout) {
    logout.addEventListener("click", () => {
      setAuthorized(false);
      window.location.href = "index.html";
    });
  }
}

function protectHiddenPage() {
  if (document.body.dataset.page !== "hidden") {
    return;
  }

  if (!isAuthorized() && !location.pathname.endsWith("login.html")) {
    window.location.href = "login.html";
  }
}

protectHiddenPage();
renderShell();
const appStoreReady = hydrateStore();

window.appState = {
  getPosts,
  savePosts,
  getRequests,
  saveRequests,
  getLessons,
  saveLessons,
  isAuthorized,
  setAuthorized,
  formatDate,
  markdownToHtml,
  authQueryValue: AUTH_QUERY_VALUE,
  ready: appStoreReady,
  storageMode: dbClient.supported ? "indexedDB" : (storageBridge.canUseLocalStorage() ? "localStorage" : "window.name"),
};
