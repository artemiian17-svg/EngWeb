const requestAppState = window.appState || {
  formatDate(value) {
    const date = new Date(value);
    return Number.isNaN(date.getTime()) ? value : date.toLocaleDateString("ru-RU");
  },
};

const requestList = document.getElementById("request-list");

async function renderRequests() {
  if (!requestList) {
    return;
  }

  if (!window.appService) {
    requestList.innerHTML = '<div class="empty-state">Сервис данных недоступен.</div>';
    return;
  }

  const isAuthorized = await window.appService.auth.status();
  if (!isAuthorized) {
    requestList.innerHTML = '<div class="empty-state">Просмотр заявок доступен только авторизованному сотруднику.</div>';
    return;
  }

  let requests;
  try {
    requests = await window.appService.requests.list();
  } catch (error) {
    requestList.innerHTML = `<div class="empty-state">${error.message || "Не удалось загрузить заявки."}</div>`;
    return;
  }

  requestList.innerHTML = requests.length
    ? requests.map((item) => `
      <article class="request-card" data-id="${item.id}">
        <h3>${item.fullname}</h3>
        <p><strong>Телефон:</strong> ${item.phone}</p>
        <p><strong>E-mail:</strong> ${item.email}</p>
        <p><strong>Дата:</strong> ${requestAppState.formatDate(item.date)}</p>
        <p><strong>Сообщение:</strong> ${item.message}</p>
        <button class="button ghost delete-request" type="button">УДАЛИТЬ</button>
      </article>
    `).join("")
    : '<div class="empty-state">Новых заявок пока нет.</div>';

  document.querySelectorAll(".delete-request").forEach((button) => {
    button.addEventListener("click", async () => {
      const card = button.closest(".request-card");
      const id = card?.dataset.id;
      if (!id || !window.confirm("Удалить заявку?")) {
        return;
      }

      try {
        await window.appService.requests.remove(id);
      } catch (error) {
        window.alert(error.message || "Не удалось удалить заявку.");
        return;
      }

      await renderRequests();
    });
  });
}

void renderRequests();

document.addEventListener("app-store-ready", () => void renderRequests());
document.addEventListener("app-store-updated", () => void renderRequests());
