(function () {
  const state = window.appState;
  const API_BASE = "/api";
  let backendMode = "local";

  function ensureState() {
    if (!state) {
      throw new Error("Сервис данных недоступен: appState не инициализирован.");
    }
    return state;
  }

  async function waitReady() {
    const current = ensureState();
    if (current.ready && typeof current.ready.then === "function") {
      await current.ready;
    }
    return current;
  }

  function sortByDateDesc(items) {
    return [...items].sort((a, b) => new Date(b.date) - new Date(a.date));
  }

  function createId(prefix) {
    return `${prefix}-${Date.now()}`;
  }

  function dispatchStoreEvent(name) {
    document.dispatchEvent(new CustomEvent(name, {
      detail: {
        source: backendMode,
      },
    }));
  }

  function buildLocalService() {
    return {
      async listPosts() {
        const current = await waitReady();
        return sortByDateDesc(current.getPosts());
      },
      async getPostById(id) {
        const current = await waitReady();
        return current.getPosts().find((item) => item.id === id) || null;
      },
      async createPost(payload) {
        const current = await waitReady();
        const posts = current.getPosts();
        const created = {
          id: createId("post"),
          title: payload.title,
          summary: payload.summary || "",
          body: payload.body,
          date: new Date().toISOString(),
          image: payload.image || "",
          attachment: payload.attachment || null,
        };
        posts.unshift(created);
        current.savePosts(posts);
        return created;
      },
      async removePost(id) {
        const current = await waitReady();
        const next = current.getPosts().filter((item) => item.id !== id);
        current.savePosts(next);
        return true;
      },
      async listRequests() {
        const current = await waitReady();
        return sortByDateDesc(current.getRequests());
      },
      async createRequest(payload) {
        const current = await waitReady();
        const requests = current.getRequests();
        const created = {
          id: createId("request"),
          fullname: payload.fullname,
          phone: payload.phone,
          email: payload.email,
          message: payload.message,
          date: new Date().toISOString(),
        };
        requests.unshift(created);
        current.saveRequests(requests);
        return created;
      },
      async removeRequest(id) {
        const current = await waitReady();
        const next = current.getRequests().filter((item) => item.id !== id);
        current.saveRequests(next);
        return true;
      },
      async listLessons() {
        const current = await waitReady();
        return current.getLessons();
      },
      async createLesson(payload) {
        const current = await waitReady();
        const lessons = current.getLessons();
        const created = {
          id: createId("lesson"),
          language: payload.language,
          level: payload.level,
          title: payload.title,
          duration: payload.duration,
          goal: payload.goal,
          tasks: payload.tasks,
        };
        lessons.unshift(created);
        current.saveLessons(lessons);
        return created;
      },
      async removeLesson(id) {
        const current = await waitReady();
        const next = current.getLessons().filter((item) => item.id !== id);
        current.saveLessons(next);
        return true;
      },
      async login(login, password) {
        const current = await waitReady();
        const normalized = String(login || "").trim().toLowerCase();
        const rawPassword = String(password || "").trim();
        const success = (normalized === "admin" || normalized === "lingoflux")
          && (rawPassword === "lingoflux2026" || rawPassword === "admin2026");

        if (success) {
          current.setAuthorized(true);
        }

        return success;
      },
      async logout() {
        const current = await waitReady();
        current.setAuthorized(false);
      },
      async authStatus() {
        const current = await waitReady();
        return current.isAuthorized();
      },
      async getLocalSnapshot() {
        const current = await waitReady();
        return {
          posts: current.getPosts(),
          requests: current.getRequests(),
          lessons: current.getLessons(),
        };
      },
    };
  }

  const localService = buildLocalService();

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

  async function bootstrapServerFromLocal() {
    const summary = await apiRequest("GET", "/bootstrap-status");
    if (!summary.canBootstrap || summary.totalCount > 0) {
      return;
    }

    const snapshot = await localService.getLocalSnapshot();
    const hasContent = snapshot.posts.length || snapshot.requests.length || snapshot.lessons.length;
    if (!hasContent) {
      return;
    }

    await apiRequest("POST", "/bootstrap", snapshot);
  }

  async function initializeBackend() {
    await waitReady();

    try {
      await apiRequest("GET", "/health");
      backendMode = "server";
      try {
        await bootstrapServerFromLocal();
      } catch (error) {
        console.warn("Bootstrap sync failed, backend mode stays server.", error);
      }
    } catch (error) {
      backendMode = "local";
    }

    dispatchStoreEvent("app-store-ready");
    return backendMode;
  }

  const backendReady = initializeBackend();

  function markUpdated() {
    dispatchStoreEvent("app-store-updated");
  }

  window.appService = {
    async ready() {
      await backendReady;
      return {
        mode: backendMode,
      };
    },
    backend: {
      async mode() {
        await backendReady;
        return backendMode;
      },
      async isServerEnabled() {
        await backendReady;
        return backendMode === "server";
      },
    },
    posts: {
      async list() {
        await backendReady;
        if (backendMode === "server") {
          return apiRequest("GET", "/posts");
        }
        return localService.listPosts();
      },
      async getById(id) {
        await backendReady;
        if (backendMode === "server") {
          return apiRequest("GET", `/posts/${encodeURIComponent(id)}`);
        }
        return localService.getPostById(id);
      },
      async create(payload) {
        await backendReady;
        if (backendMode === "server") {
          const created = await apiRequest("POST", "/posts", {
            id: createId("post"),
            title: payload.title,
            summary: payload.summary || "",
            body: payload.body,
            date: new Date().toISOString(),
            image: payload.image || "",
            attachment: payload.attachment || null,
          });
          markUpdated();
          return created;
        }
        const created = await localService.createPost(payload);
        markUpdated();
        return created;
      },
      async remove(id) {
        await backendReady;
        if (backendMode === "server") {
          await apiRequest("DELETE", `/posts/${encodeURIComponent(id)}`);
          markUpdated();
          return true;
        }
        const removed = await localService.removePost(id);
        markUpdated();
        return removed;
      },
    },
    requests: {
      async list() {
        await backendReady;
        if (backendMode === "server") {
          return apiRequest("GET", "/requests");
        }
        return localService.listRequests();
      },
      async create(payload) {
        await backendReady;
        if (backendMode === "server") {
          const created = await apiRequest("POST", "/requests", {
            id: createId("request"),
            fullname: payload.fullname,
            phone: payload.phone,
            email: payload.email,
            message: payload.message,
            date: new Date().toISOString(),
          });
          markUpdated();
          return created;
        }
        const created = await localService.createRequest(payload);
        markUpdated();
        return created;
      },
      async remove(id) {
        await backendReady;
        if (backendMode === "server") {
          await apiRequest("DELETE", `/requests/${encodeURIComponent(id)}`);
          markUpdated();
          return true;
        }
        const removed = await localService.removeRequest(id);
        markUpdated();
        return removed;
      },
    },
    lessons: {
      async list() {
        await backendReady;
        if (backendMode === "server") {
          return apiRequest("GET", "/lessons");
        }
        return localService.listLessons();
      },
      async create(payload) {
        await backendReady;
        if (backendMode === "server") {
          const created = await apiRequest("POST", "/lessons", {
            id: createId("lesson"),
            language: payload.language,
            level: payload.level,
            title: payload.title,
            duration: payload.duration,
            goal: payload.goal,
            tasks: payload.tasks,
          });
          markUpdated();
          return created;
        }
        const created = await localService.createLesson(payload);
        markUpdated();
        return created;
      },
      async remove(id) {
        await backendReady;
        if (backendMode === "server") {
          await apiRequest("DELETE", `/lessons/${encodeURIComponent(id)}`);
          markUpdated();
          return true;
        }
        const removed = await localService.removeLesson(id);
        markUpdated();
        return removed;
      },
    },
    auth: {
      async login(login, password) {
        await backendReady;
        if (backendMode === "server") {
          const payload = await apiRequest("POST", "/auth/login", {
            login,
            password,
          });
          markUpdated();
          return payload.success === true;
        }
        const success = await localService.login(login, password);
        markUpdated();
        return success;
      },
      async logout() {
        await backendReady;
        if (backendMode === "server") {
          await apiRequest("POST", "/auth/logout", {});
          markUpdated();
          return;
        }
        await localService.logout();
        markUpdated();
      },
      async status() {
        await backendReady;
        if (backendMode === "server") {
          const payload = await apiRequest("GET", "/auth/status");
          return payload.authorized === true;
        }
        return localService.authStatus();
      },
    },
  };
})();
