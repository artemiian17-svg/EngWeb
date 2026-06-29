const postAppState = window.appState || {
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

const postForm = document.getElementById("post-form");
const postTitle = document.getElementById("post-title");
const postSummary = document.getElementById("post-summary");
const postBody = document.getElementById("post-body");
const postFile = document.getElementById("post-file");
const fileName = document.getElementById("file-name");
const attachmentPreview = document.getElementById("attachment-preview");
const publishButton = document.getElementById("publish-button");
const previewButton = document.getElementById("preview-button");
const postStatus = document.getElementById("post-status");
const postResult = document.getElementById("post-result");
const previewModal = document.getElementById("preview-modal");
const previewContent = document.getElementById("preview-content");
const titleError = document.getElementById("post-title-error");
const bodyError = document.getElementById("post-body-error");
const editorPostList = document.getElementById("editor-post-list");

let fileData = "";
let fileMeta = null;
let canManagePosts = false;

function getPostPayload() {
  return {
    title: (postTitle?.value || "").trim(),
    summary: (postSummary?.value || "").trim(),
    body: (postBody?.value || "").trim(),
  };
}

function setErrorState(element, show) {
  if (!element) {
    return;
  }
  element.classList.toggle("hidden", !show);
}

function syncPostAccess() {
  const fields = [postTitle, postSummary, postBody, postFile, previewButton];
  fields.forEach((field) => {
    if (field) {
      field.disabled = !canManagePosts;
    }
  });
}

function validatePostForm() {
  const payload = getPostPayload();
  const titleValid = payload.title.length >= 4;
  const bodyValid = payload.body.length >= 20;
  const valid = titleValid && bodyValid && canManagePosts;

  setErrorState(titleError, !titleValid && payload.title.length > 0);
  setErrorState(bodyError, !bodyValid && payload.body.length > 0);

  if (publishButton) {
    publishButton.disabled = !valid;
  }

  if (postStatus) {
    if (!canManagePosts) {
      postStatus.textContent = "Создание и удаление публикаций доступно только авторизованному сотруднику.";
    } else if (!payload.title && !payload.body) {
      postStatus.textContent = "Заполните заголовок и содержание публикации.";
    } else if (!valid) {
      postStatus.textContent = "Исправьте ошибки в форме публикации.";
    } else {
      postStatus.textContent = "Публикация готова к отправке.";
    }
  }

  return valid;
}

function renderAttachmentCard() {
  if (!attachmentPreview) {
    return;
  }

  if (!fileMeta) {
    attachmentPreview.classList.add("hidden");
    attachmentPreview.innerHTML = "";
    return;
  }

  attachmentPreview.classList.remove("hidden");
  attachmentPreview.innerHTML = `
    <p class="eyebrow">ПРИКРЕПЛЕНИЕ</p>
    <p><strong>Файл:</strong> ${fileMeta.name}</p>
    <p><strong>Тип:</strong> ${fileMeta.type || "не указан"}</p>
    <p><strong>Размер:</strong> ${Math.ceil(fileMeta.size / 1024)} КБ</p>
    ${fileMeta.type && fileMeta.type.startsWith("image/") ? `<img class="blog-thumb" src="${fileData}" alt="${fileMeta.name}">` : ""}
  `;
}

function buildAttachmentMarkup() {
  if (!fileMeta) {
    return "";
  }

  const isImage = fileMeta.type && fileMeta.type.startsWith("image/");
  if (isImage) {
    return `<img class="blog-thumb" src="${fileData}" alt="${fileMeta.name}">`;
  }

  return `
    <div class="file-box">
      <p><strong>Прикрепленный файл:</strong> ${fileMeta.name}</p>
      <a class="button ghost" href="${fileData}" download="${fileMeta.name}">СКАЧАТЬ ФАЙЛ</a>
    </div>
  `;
}

async function renderEditorPosts() {
  if (!editorPostList) {
    return;
  }

  if (window.appService) {
    canManagePosts = await window.appService.auth.status();
  }

  const posts = window.appService ? await window.appService.posts.list() : [];
  editorPostList.innerHTML = posts.length
    ? posts.map((post) => `
      <article class="blog-card" data-editor-post-id="${post.id}">
        ${post.image ? `<img class="blog-thumb" src="${post.image}" alt="${post.title}">` : '<div class="blog-thumb"></div>'}
        <span class="meta-text">${postAppState.formatDate(post.date)}</span>
        <div>
          <h3>${post.title}</h3>
          <p>${(post.summary || post.body || "").replace(/[*#-]/g, "").slice(0, 140)}...</p>
          ${post.attachment ? `<p class="meta-inline">Вложение: ${post.attachment.name}</p>` : ""}
        </div>
        <div class="card-actions">
          <a class="button ghost" href="post.html?id=${post.id}">ОТКРЫТЬ</a>
          ${canManagePosts ? '<button class="button ghost delete-editor-post" type="button">УДАЛИТЬ</button>' : ""}
        </div>
      </article>
    `).join("")
    : '<div class="empty-state">Публикаций пока нет.</div>';

  syncPostAccess();
  validatePostForm();

  if (!canManagePosts) {
    return;
  }

  document.querySelectorAll(".delete-editor-post").forEach((button) => {
    button.addEventListener("click", async () => {
      const card = button.closest("[data-editor-post-id]");
      const postId = card?.dataset.editorPostId;
      if (!postId || !window.confirm("Удалить публикацию?")) {
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

      await renderEditorPosts();
    });
  });
}

function openPreview() {
  const payload = getPostPayload();

  if (!previewContent || !previewModal || !canManagePosts) {
    return;
  }

  previewContent.innerHTML = `
    <p class="eyebrow">ПРЕДПРОСМОТР</p>
    <h2>${payload.title || "Без заголовка"}</h2>
    ${payload.summary ? `<p class="lead compact">${payload.summary}</p>` : ""}
    ${buildAttachmentMarkup()}
    <div class="article-body">${postAppState.markdownToHtml(payload.body || "")}</div>
  `;
  previewModal.classList.remove("hidden");
}

function closePreview() {
  if (previewModal) {
    previewModal.classList.add("hidden");
  }
}

[postTitle, postSummary, postBody].forEach((field) => {
  if (field) {
    field.addEventListener("input", validatePostForm);
    field.addEventListener("change", validatePostForm);
    field.addEventListener("blur", validatePostForm);
  }
});

if (postFile) {
  postFile.addEventListener("change", () => {
    const file = postFile.files && postFile.files[0];
    fileName.textContent = file ? file.name : "Файл не выбран";

    if (!file) {
      fileData = "";
      fileMeta = null;
      renderAttachmentCard();
      return;
    }

    fileMeta = {
      name: file.name,
      type: file.type,
      size: file.size,
    };

    const reader = new FileReader();
    reader.onload = () => {
      fileData = reader.result;
      renderAttachmentCard();
    };
    reader.readAsDataURL(file);
  });
}

if (previewButton) {
  previewButton.addEventListener("click", openPreview);
}

document.querySelectorAll("[data-close-modal]").forEach((item) => {
  item.addEventListener("click", closePreview);
});

if (postForm) {
  validatePostForm();

  postForm.addEventListener("submit", async (event) => {
    event.preventDefault();

    if (!validatePostForm() || !window.appService || !canManagePosts) {
      return;
    }

    const payload = getPostPayload();
    let createdPost;

    try {
      createdPost = await window.appService.posts.create({
        title: payload.title,
        summary: payload.summary,
        body: payload.body,
        image: fileMeta && fileMeta.type && fileMeta.type.startsWith("image/") ? fileData : "",
        attachment: fileMeta ? {
          name: fileMeta.name,
          type: fileMeta.type,
          data: fileData,
        } : null,
      });
    } catch (error) {
      postStatus.textContent = error.message || "Не удалось сохранить публикацию.";
      return;
    }

    if (postResult) {
      postResult.classList.remove("hidden");
      postResult.innerHTML = `
        <p class="eyebrow">ПУБЛИКАЦИЯ СОХРАНЕНА</p>
        <h3>${createdPost.title}</h3>
        <p><strong>Дата:</strong> ${postAppState.formatDate(createdPost.date)}</p>
        ${createdPost.summary ? `<p><strong>Описание:</strong> ${createdPost.summary}</p>` : ""}
        ${createdPost.attachment ? `<p><strong>Файл:</strong> ${createdPost.attachment.name}</p>` : "<p><strong>Файл:</strong> не прикреплен</p>"}
      `;
    }

    postForm.reset();
    setErrorState(titleError, false);
    setErrorState(bodyError, false);
    fileData = "";
    fileMeta = null;
    fileName.textContent = "Файл не выбран";
    renderAttachmentCard();
    postStatus.textContent = "Публикация сохранена через сервис.";
    validatePostForm();
    await renderEditorPosts();
  });
}

void renderEditorPosts();

document.addEventListener("app-store-ready", () => void renderEditorPosts());
document.addEventListener("app-store-updated", () => void renderEditorPosts());
