const contactAppState = window.appState || {
  formatDate(value) {
    const date = new Date(value);
    return Number.isNaN(date.getTime()) ? value : date.toLocaleDateString("ru-RU");
  },
};

const contactForm = document.getElementById("contact-form");
const contactStatus = document.getElementById("contact-status");
const contactSubmit = document.getElementById("contact-submit");
const contactPreviewButton = document.getElementById("contact-preview-button");
const contactResult = document.getElementById("contact-result");
const contactPreviewModal = document.getElementById("contact-preview-modal");
const contactPreviewContent = document.getElementById("contact-preview-content");
const contactFields = {
  fullname: document.getElementById("contact-name"),
  phone: document.getElementById("contact-phone"),
  email: document.getElementById("contact-email"),
  message: document.getElementById("contact-message"),
};
const contactErrors = {
  fullname: document.getElementById("contact-name-error"),
  phone: document.getElementById("contact-phone-error"),
  email: document.getElementById("contact-email-error"),
  message: document.getElementById("contact-message-error"),
};

function getContactPayload() {
  return {
    fullname: (contactFields.fullname?.value || "").trim(),
    phone: (contactFields.phone?.value || "").trim(),
    email: (contactFields.email?.value || "").trim(),
    message: (contactFields.message?.value || "").trim(),
  };
}

function validateEmail(value) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value);
}

function validatePhone(value) {
  return /^[+\d][\d\s\-()]{5,}$/.test(value);
}

function setErrorState(element, show) {
  if (!element) {
    return;
  }
  element.classList.toggle("hidden", !show);
}

function validateContactForm() {
  const payload = getContactPayload();
  const checks = {
    fullname: payload.fullname.length >= 5,
    phone: validatePhone(payload.phone),
    email: validateEmail(payload.email),
    message: payload.message.length >= 10,
  };

  setErrorState(contactErrors.fullname, !checks.fullname && payload.fullname.length > 0);
  setErrorState(contactErrors.phone, !checks.phone && payload.phone.length > 0);
  setErrorState(contactErrors.email, !checks.email && payload.email.length > 0);
  setErrorState(contactErrors.message, !checks.message && payload.message.length > 0);

  const valid = Object.values(checks).every(Boolean);

  if (contactSubmit) {
    contactSubmit.disabled = !valid;
  }

  if (contactStatus) {
    if (!payload.fullname && !payload.phone && !payload.email && !payload.message) {
      contactStatus.textContent = "Заполните все поля формы.";
    } else if (!valid) {
      contactStatus.textContent = "Исправьте ошибки в форме.";
    } else {
      contactStatus.textContent = "Форма готова к отправке.";
    }
  }

  return valid;
}

function renderContactPreview(payload) {
  if (!contactPreviewContent || !contactPreviewModal) {
    return;
  }

  contactPreviewContent.innerHTML = `
    <p class="eyebrow">ПРЕДПРОСМОТР ЗАЯВКИ</p>
    <h2>${payload.fullname || "Без имени"}</h2>
    <div class="preview-stack">
      <p><strong>Телефон:</strong> ${payload.phone || "Не указан"}</p>
      <p><strong>Email:</strong> ${payload.email || "Не указан"}</p>
      <p><strong>Сообщение:</strong> ${payload.message || "Пусто"}</p>
    </div>
  `;
  contactPreviewModal.classList.remove("hidden");
}

function closeContactPreview() {
  if (contactPreviewModal) {
    contactPreviewModal.classList.add("hidden");
  }
}

Object.values(contactFields).forEach((field) => {
  if (field) {
    field.addEventListener("input", validateContactForm);
    field.addEventListener("change", validateContactForm);
    field.addEventListener("blur", validateContactForm);
  }
});

document.querySelectorAll("[data-close-contact-modal]").forEach((element) => {
  element.addEventListener("click", closeContactPreview);
});

if (contactPreviewButton) {
  contactPreviewButton.addEventListener("click", () => {
    renderContactPreview(getContactPayload());
  });
}

if (contactForm) {
  validateContactForm();

  contactForm.addEventListener("submit", async (event) => {
    event.preventDefault();

    if (!validateContactForm() || !window.appService) {
      return;
    }

    const payload = getContactPayload();
    const request = await window.appService.requests.create(payload);

    if (contactResult) {
      contactResult.classList.remove("hidden");
      contactResult.innerHTML = `
        <p class="eyebrow">ЗАЯВКА ПРИНЯТА</p>
        <h3>${payload.fullname}</h3>
        <p><strong>Дата:</strong> ${contactAppState.formatDate(request.date)}</p>
        <p><strong>Телефон:</strong> ${payload.phone}</p>
        <p><strong>Email:</strong> ${payload.email}</p>
        <p><strong>Сообщение:</strong> ${payload.message}</p>
      `;
    }

    contactForm.reset();
    Object.values(contactErrors).forEach((element) => setErrorState(element, false));
    contactStatus.textContent = "Данные отправлены и сохранены через сервис.";
    validateContactForm();
  });
}
