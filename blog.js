const blogState = window.appState || {
  formatDate(value) {
    const date = new Date(value);
    return Number.isNaN(date.getTime()) ? value : date.toLocaleDateString("ru-RU");
  },
};

const blogList = document.getElementById("blog-list");
let canManagePosts = false;

function getExcerpt(post) {
  const source = post.summary || post.body || "";
  return source.replace(/[*#-]/g, "").slice(0, 150);
}

async function renderBlog() {
  if (!blogList) {
    return;
  }

  if (window.appService) {
    canManagePosts = await window.appService.auth.status();
  }

  const posts = window.appService ? await window.appService.posts.list() : [];

  blogList.innerHTML = posts.length
    ? posts.map((post) => `
      <article class="blog-card" data-post-id="${post.id}">
        ${post.image ? `<img class="blog-thumb" src="${post.image}" alt="${post.title}">` : '<div class="blog-thumb"></div>'}
        <span class="meta-text">${blogState.formatDate(post.date)}</span>
        <div>
          <h3>${post.title}</h3>
          <p>${getExcerpt(post)}...</p>
          ${post.attachment ? `<p class="meta-inline">Есть вложение: ${post.attachment.name}</p>` : ""}
        </div>
        <div class="card-actions">
          <a class="button ghost" href="post.html?id=${post.id}">ЧИТАТЬ ПОЛНОСТЬЮ</a>
          ${canManagePosts ? '<button class="button ghost delete-post" type="button">УДАЛИТЬ</button>' : ""}
        </div>
      </article>
    `).join("")
    : '<div class="empty-state">Публикаций пока нет.</div>';

  document.querySelectorAll(".delete-post").forEach((button) => {
    button.addEventListener("click", async () => {
      const card = button.closest("[data-post-id]");
      const postId = card?.dataset.postId;
      if (!postId) {
        return;
      }

      if (!window.confirm("Удалить публикацию?")) {
        return;
      }

      if (window.appService) {
        try {
          await window.appService.posts.remove(postId);
        } catch (error) {
          window.alert(error.message || "Не удалось удалить публикацию.");
          return;
        }
      }

      await renderBlog();
    });
  });
}

void renderBlog();

document.addEventListener("app-store-ready", () => void renderBlog());
document.addEventListener("app-store-updated", () => void renderBlog());
