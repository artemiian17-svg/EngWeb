const lessonsList = document.getElementById("lessons-list");
const lessonForm = document.getElementById("lesson-form");
const lessonSubmit = document.getElementById("lesson-submit");
const lessonStatus = document.getElementById("lesson-status");
const lessonResult = document.getElementById("lesson-result");
const lessonAdminSection = document.getElementById("lesson-admin-section");
const lessonAccessNote = document.getElementById("lesson-access-note");

const lessonFields = {
  language: document.getElementById("lesson-language"),
  level: document.getElementById("lesson-level"),
  title: document.getElementById("lesson-title"),
  duration: document.getElementById("lesson-duration"),
  goal: document.getElementById("lesson-goal"),
  tasks: document.getElementById("lesson-tasks"),
};

const lessonErrors = {
  language: document.getElementById("lesson-language-error"),
  level: document.getElementById("lesson-level-error"),
  title: document.getElementById("lesson-title-error"),
  duration: document.getElementById("lesson-duration-error"),
  goal: document.getElementById("lesson-goal-error"),
  tasks: document.getElementById("lesson-tasks-error"),
};

let canManageLessons = false;

function setLessonError(element, show) {
  if (!element) {
    return;
  }
  element.classList.toggle("hidden", !show);
}

function syncLessonAccess() {
  if (lessonAdminSection) {
    lessonAdminSection.classList.toggle("hidden", !canManageLessons);
  }
  if (lessonAccessNote) {
    lessonAccessNote.classList.toggle("hidden", canManageLessons);
  }
}

function getLessonPayload() {
  return {
    language: (lessonFields.language?.value || "").trim(),
    level: (lessonFields.level?.value || "").trim(),
    title: (lessonFields.title?.value || "").trim(),
    duration: (lessonFields.duration?.value || "").trim(),
    goal: (lessonFields.goal?.value || "").trim(),
    tasks: (lessonFields.tasks?.value || "")
      .split("\n")
      .map((item) => item.trim())
      .filter(Boolean),
  };
}

function validateLessonForm() {
  const payload = getLessonPayload();
  const checks = {
    language: payload.language.length > 0,
    level: payload.level.length >= 2,
    title: payload.title.length >= 4,
    duration: payload.duration.length >= 3,
    goal: payload.goal.length >= 10,
    tasks: payload.tasks.length >= 1,
  };

  setLessonError(lessonErrors.language, !checks.language);
  setLessonError(lessonErrors.level, !checks.level && payload.level.length > 0);
  setLessonError(lessonErrors.title, !checks.title && payload.title.length > 0);
  setLessonError(lessonErrors.duration, !checks.duration && payload.duration.length > 0);
  setLessonError(lessonErrors.goal, !checks.goal && payload.goal.length > 0);
  setLessonError(lessonErrors.tasks, !checks.tasks && payload.tasks.length > 0);

  const valid = Object.values(checks).every(Boolean) && canManageLessons;
  if (lessonSubmit) {
    lessonSubmit.disabled = !valid;
  }
  if (lessonStatus) {
    if (!canManageLessons) {
      lessonStatus.textContent = "Создание уроков доступно только авторизованному сотруднику.";
    } else {
      lessonStatus.textContent = valid ? "Урок готов к созданию." : "Исправьте ошибки в форме урока.";
    }
  }
  return valid;
}

async function renderLessons() {
  if (!lessonsList) {
    return;
  }

  const lessons = window.appService ? await window.appService.lessons.list() : [];
  lessonsList.innerHTML = lessons.length
    ? lessons.map((lesson) => `
      <article class="lesson-card" data-lesson-id="${lesson.id}">
        <div class="lesson-top">
          <span class="meta-text">${lesson.level}</span>
          <span class="lesson-chip">${lesson.language}</span>
        </div>
        <h3>${lesson.title}</h3>
        <p>${lesson.goal}</p>
        <p><strong>Длительность:</strong> ${lesson.duration}</p>
        <ul class="service-points">
          ${lesson.tasks.map((task) => `<li>${task}</li>`).join("")}
        </ul>
        <div class="card-actions">
          <a class="button ghost" href="contacts.html">ЗАПИСАТЬСЯ НА ПРАКТИКУ</a>
          ${canManageLessons ? '<button class="button ghost delete-lesson" type="button">УДАЛИТЬ</button>' : ""}
        </div>
      </article>
    `).join("")
    : '<div class="empty-state">Уроков пока нет.</div>';

  if (!canManageLessons) {
    return;
  }

  document.querySelectorAll(".delete-lesson").forEach((button) => {
    button.addEventListener("click", async () => {
      const card = button.closest("[data-lesson-id]");
      const lessonId = card?.dataset.lessonId;
      if (!lessonId || !window.confirm("Удалить урок?")) {
        return;
      }
      if (window.appService) {
        await window.appService.lessons.remove(lessonId);
      }
      await renderLessons();
    });
  });
}

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

Object.values(lessonFields).forEach((field) => {
  if (field) {
    field.addEventListener("input", validateLessonForm);
    field.addEventListener("change", validateLessonForm);
    field.addEventListener("blur", validateLessonForm);
  }
});

if (lessonForm) {
  validateLessonForm();

  lessonForm.addEventListener("submit", async (event) => {
    event.preventDefault();

    if (!validateLessonForm() || !window.appService || !canManageLessons) {
      return;
    }

    const payload = getLessonPayload();
    const lesson = await window.appService.lessons.create(payload);

    if (lessonResult) {
      lessonResult.classList.remove("hidden");
      lessonResult.innerHTML = `
        <p class="eyebrow">УРОК СОЗДАН</p>
        <h3>${lesson.title}</h3>
        <p><strong>Язык:</strong> ${lesson.language}</p>
        <p><strong>Уровень:</strong> ${lesson.level}</p>
        <p><strong>Длительность:</strong> ${lesson.duration}</p>
      `;
    }

    lessonForm.reset();
    Object.values(lessonErrors).forEach((element) => setLessonError(element, false));
    lessonStatus.textContent = "Урок создан через сервис.";
    validateLessonForm();
    await renderLessons();
  });
}

void refreshLessonPermissions();

document.addEventListener("app-store-ready", () => void refreshLessonPermissions());
document.addEventListener("app-store-updated", () => void refreshLessonPermissions());
