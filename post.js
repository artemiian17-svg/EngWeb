const postPageState = window.appState || {
  formatDate(value) {
    const date = new Date(value);
    return Number.isNaN(date.getTime()) ? value : date.toLocaleDateString("ru-RU");
  },
  markdownToHtml(text) {
    const safe = String(text)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;");

    return safe
      .split(/\n{2,}/)
      .map((block) => `<p>${block.replace(/\*\*(.+?)\*\*/g, "<strong>$1</strong>").replace(/\*(.+?)\*/g, "<em>$1</em>").replace(/\n/g, "<br>")}</p>`)
      .join("");
  },
};

const postShell = document.getElementById("post-shell");
const params = new URLSearchParams(window.location.search);
const postId = params.get("id");

function renderAttachment(post) {
  if (!post.attachment) {
    return "";
  }
  const isImage = post.attachment.type && post.attachment.type.startsWith("image/");
  if (isImage && post.image) {
    return "";
  }
  return `
    <div class="file-box">
      <p><strong>Вложение:</strong> ${post.attachment.name}</p>
      <a class="button ghost" href="${post.attachment.data}" download="${post.attachment.name}">СКАЧАТЬ ФАЙЛ</a>
    </div>
  `;
}

async function renderPostPage() {
  if (!postShell) {
    return;
  }

  const post = window.appService ? await window.appService.posts.getById(postId) : null;

  postShell.innerHTML = post
    ? `
      <p class="eyebrow">ПУБЛИКАЦИЯ</p>
      <h1>${post.title}</h1>
      <p class="meta-text">${postPageState.formatDate(post.date)}</p>
      ${post.summary ? `<p class="lead compact">${post.summary}</p>` : ""}
      ${post.image ? `<img class="blog-thumb" src="${post.image}" alt="${post.title}">` : ""}
      ${renderAttachment(post)}
      <div class="article-body">${postPageState.markdownToHtml(post.body)}</div>
    `
    : '<div class="empty-state">Публикация не найдена.</div>';
}

void renderPostPage();

document.addEventListener("app-store-ready", () => void renderPostPage());
document.addEventListener("app-store-updated", () => void renderPostPage());
