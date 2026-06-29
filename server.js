const http = require("http");
const fs = require("fs");
const path = require("path");
const crypto = require("crypto");

const host = "0.0.0.0";
const port = 8000;
const root = __dirname;
const dataPath = path.join(root, "backend-data.json");
const authCookieName = "lingoflux_session";
const sessions = new Map();

const adminUsers = [
  { login: "admin", password: "admin2026" },
  { login: "lingoflux", password: "lingoflux2026" },
];

const messages = {
  invalidJson: "Invalid JSON payload.",
  unauthorized: "Authorization required.",
  storageInitialized: "Storage is already initialized.",
  invalidCredentials: "Invalid login or password.",
  postNotFound: "Post not found.",
  apiRouteNotFound: "API route not found.",
  internalServerError: "Internal server error.",
  forbidden: "Access denied.",
  notFound: "Resource not found.",
  started: `Server started: http://localhost:${port}`,
  phone: "Open from phone: http://192.168.0.101:8000",
  dataFile: `Backend data file: ${dataPath}`,
};

const mimeTypes = {
  ".html": "text/html; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".js": "application/javascript; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".png": "image/png",
  ".jpg": "image/jpeg",
  ".jpeg": "image/jpeg",
  ".svg": "image/svg+xml",
  ".ico": "image/x-icon",
  ".txt": "text/plain; charset=utf-8",
};

function createDefaultData() {
  return { posts: [], requests: [], lessons: [] };
}

function ensureDataFile() {
  if (!fs.existsSync(dataPath)) {
    fs.writeFileSync(dataPath, JSON.stringify(createDefaultData(), null, 2), "utf8");
  }
}

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

function resolvePath(urlPath) {
  const cleanPath = decodeURIComponent((urlPath || "/").split("?")[0]);
  const relativePath = cleanPath === "/" ? "/index.html" : cleanPath;
  const fullPath = path.normalize(path.join(root, relativePath));
  if (!fullPath.startsWith(root)) {
    return null;
  }
  return fullPath;
}

function parseCookies(cookieHeader) {
  const cookies = {};
  if (!cookieHeader) {
    return cookies;
  }
  cookieHeader.split(";").forEach((chunk) => {
    const [name, ...rest] = chunk.split("=");
    if (!name || rest.length === 0) {
      return;
    }
    cookies[name.trim()] = rest.join("=").trim();
  });
  return cookies;
}

function readJsonBody(req) {
  return new Promise((resolve, reject) => {
    let body = "";
    req.on("data", (chunk) => {
      body += chunk;
    });
    req.on("end", () => {
      if (!body) {
        resolve({});
        return;
      }
      try {
        resolve(JSON.parse(body));
      } catch {
        reject(new Error(messages.invalidJson));
      }
    });
    req.on("error", reject);
  });
}

function sendJson(res, statusCode, payload, extraHeaders = {}) {
  const body = Buffer.from(JSON.stringify(payload), "utf8");
  res.writeHead(statusCode, {
    "Content-Type": "application/json; charset=utf-8",
    "Content-Length": body.length,
    Connection: "close",
    ...extraHeaders,
  });
  res.end(body);
}

function sendText(res, statusCode, text) {
  const body = Buffer.from(text, "utf8");
  res.writeHead(statusCode, {
    "Content-Type": "text/plain; charset=utf-8",
    "Content-Length": body.length,
    Connection: "close",
  });
  res.end(body);
}

function getSessionId(req) {
  const cookies = parseCookies(req.headers.cookie);
  return cookies[authCookieName] || "";
}

function isAuthorized(req) {
  const sessionId = getSessionId(req);
  return Boolean(sessionId && sessions.has(sessionId));
}

function requireAuthorized(req, res) {
  if (!isAuthorized(req)) {
    sendJson(res, 401, { error: messages.unauthorized });
    return false;
  }
  return true;
}

function routeId(urlPath, prefix) {
  return decodeURIComponent(urlPath.slice(prefix.length)).replace(/^\/+/, "");
}

async function handleApi(req, res) {
  const cleanPath = decodeURIComponent((req.url || "/").split("?")[0]);

  if (req.method === "GET" && cleanPath === "/api/health") {
    sendJson(res, 200, { ok: true, backend: "node" });
    return;
  }

  if (req.method === "GET" && cleanPath === "/api/bootstrap-status") {
    const data = readData();
    const postsCount = data.posts.length;
    const requestsCount = data.requests.length;
    const lessonsCount = data.lessons.length;
    sendJson(res, 200, {
      postsCount,
      requestsCount,
      lessonsCount,
      totalCount: postsCount + requestsCount + lessonsCount,
      canBootstrap: postsCount === 0 && requestsCount === 0 && lessonsCount === 0,
    });
    return;
  }

  if (req.method === "POST" && cleanPath === "/api/bootstrap") {
    let payload;
    try {
      payload = await readJsonBody(req);
    } catch (error) {
      sendJson(res, 400, { error: error.message });
      return;
    }

    const current = readData();
    if (current.posts.length || current.requests.length || current.lessons.length) {
      sendJson(res, 409, { error: messages.storageInitialized });
      return;
    }

    writeData({
      posts: Array.isArray(payload.posts) ? payload.posts : [],
      requests: Array.isArray(payload.requests) ? payload.requests : [],
      lessons: Array.isArray(payload.lessons) ? payload.lessons : [],
    });
    sendJson(res, 200, { success: true });
    return;
  }

  if (req.method === "GET" && cleanPath === "/api/auth/status") {
    sendJson(res, 200, { authorized: isAuthorized(req) });
    return;
  }

  if (req.method === "POST" && cleanPath === "/api/auth/login") {
    let payload;
    try {
      payload = await readJsonBody(req);
    } catch (error) {
      sendJson(res, 400, { error: error.message });
      return;
    }

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

  if (req.method === "POST" && cleanPath === "/api/auth/logout") {
    const sessionId = getSessionId(req);
    if (sessionId) {
      sessions.delete(sessionId);
    }
    sendJson(res, 200, { success: true, authorized: false }, {
      "Set-Cookie": `${authCookieName}=; Path=/; Expires=Thu, 01 Jan 1970 00:00:00 GMT; HttpOnly; SameSite=Lax`,
    });
    return;
  }

  if (req.method === "GET" && cleanPath === "/api/posts") {
    sendJson(res, 200, readData().posts);
    return;
  }

  if (req.method === "GET" && cleanPath.startsWith("/api/posts/")) {
    const id = routeId(cleanPath, "/api/posts/");
    const post = readData().posts.find((item) => item.id === id) || null;
    if (!post) {
      sendJson(res, 404, { error: messages.postNotFound });
      return;
    }
    sendJson(res, 200, post);
    return;
  }

  if (req.method === "POST" && cleanPath === "/api/posts") {
    if (!requireAuthorized(req, res)) {
      return;
    }
    let payload;
    try {
      payload = await readJsonBody(req);
    } catch (error) {
      sendJson(res, 400, { error: error.message });
      return;
    }
    const data = readData();
    const created = {
      id: String(payload.id || ""),
      title: String(payload.title || ""),
      summary: String(payload.summary || ""),
      body: String(payload.body || ""),
      date: String(payload.date || new Date().toISOString()),
      image: String(payload.image || ""),
      attachment: payload.attachment || null,
    };
    data.posts.unshift(created);
    writeData(data);
    sendJson(res, 201, created);
    return;
  }

  if (req.method === "DELETE" && cleanPath.startsWith("/api/posts/")) {
    if (!requireAuthorized(req, res)) {
      return;
    }
    const id = routeId(cleanPath, "/api/posts/");
    const data = readData();
    const before = data.posts.length;
    data.posts = data.posts.filter((item) => item.id !== id);
    writeData(data);
    sendJson(res, 200, { success: before !== data.posts.length });
    return;
  }

  if (req.method === "GET" && cleanPath === "/api/lessons") {
    sendJson(res, 200, readData().lessons);
    return;
  }

  if (req.method === "POST" && cleanPath === "/api/lessons") {
    if (!requireAuthorized(req, res)) {
      return;
    }
    let payload;
    try {
      payload = await readJsonBody(req);
    } catch (error) {
      sendJson(res, 400, { error: error.message });
      return;
    }
    const data = readData();
    const created = {
      id: String(payload.id || ""),
      language: String(payload.language || ""),
      level: String(payload.level || ""),
      title: String(payload.title || ""),
      duration: String(payload.duration || ""),
      goal: String(payload.goal || ""),
      tasks: Array.isArray(payload.tasks) ? payload.tasks : [],
    };
    data.lessons.unshift(created);
    writeData(data);
    sendJson(res, 201, created);
    return;
  }

  if (req.method === "DELETE" && cleanPath.startsWith("/api/lessons/")) {
    if (!requireAuthorized(req, res)) {
      return;
    }
    const id = routeId(cleanPath, "/api/lessons/");
    const data = readData();
    const before = data.lessons.length;
    data.lessons = data.lessons.filter((item) => item.id !== id);
    writeData(data);
    sendJson(res, 200, { success: before !== data.lessons.length });
    return;
  }

  if (req.method === "GET" && cleanPath === "/api/requests") {
    if (!requireAuthorized(req, res)) {
      return;
    }
    sendJson(res, 200, readData().requests);
    return;
  }

  if (req.method === "POST" && cleanPath === "/api/requests") {
    let payload;
    try {
      payload = await readJsonBody(req);
    } catch (error) {
      sendJson(res, 400, { error: error.message });
      return;
    }
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

  if (req.method === "DELETE" && cleanPath.startsWith("/api/requests/")) {
    if (!requireAuthorized(req, res)) {
      return;
    }
    const id = routeId(cleanPath, "/api/requests/");
    const data = readData();
    const before = data.requests.length;
    data.requests = data.requests.filter((item) => item.id !== id);
    writeData(data);
    sendJson(res, 200, { success: before !== data.requests.length });
    return;
  }

  sendJson(res, 404, { error: messages.apiRouteNotFound });
}

const server = http.createServer(async (req, res) => {
  const cleanPath = decodeURIComponent((req.url || "/").split("?")[0]);
  if (cleanPath.startsWith("/api/")) {
    try {
      await handleApi(req, res);
    } catch (error) {
      sendJson(res, 500, { error: error.message || messages.internalServerError });
    }
    return;
  }

  let filePath = resolvePath(req.url);
  if (!filePath) {
    sendText(res, 403, messages.forbidden);
    return;
  }

  fs.stat(filePath, (statError, stat) => {
    if (!statError && stat.isDirectory()) {
      filePath = path.join(filePath, "index.html");
    }
    fs.readFile(filePath, (readError, data) => {
      if (readError) {
        sendText(res, 404, messages.notFound);
        return;
      }
      const ext = path.extname(filePath).toLowerCase();
      const type = mimeTypes[ext] || "application/octet-stream";
      res.writeHead(200, {
        "Content-Type": type,
        "Content-Length": data.length,
        Connection: "close",
      });
      res.end(data);
    });
  });
});

server.listen(port, host, () => {
  console.log(messages.started);
  console.log(messages.phone);
  console.log(messages.dataFile);
});
