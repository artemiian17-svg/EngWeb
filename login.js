(function () {
  const loginForm = document.getElementById("login-form");
  const loginButton = document.getElementById("login-button");
  const loginStatus = document.getElementById("login-status");
  const loginField = document.getElementById("login-name");
  const passwordField = document.getElementById("login-password");

  function redirectToHiddenPage() {
    const target = new URL("create-post.html?auth=granted", window.location.href).toString();
    window.location.assign(target);
  }

  async function authorize() {
    const login = (loginField?.value || "").trim();
    const password = (passwordField?.value || "").trim();

    if (!window.appService) {
      if (loginStatus) {
        loginStatus.textContent = "Сервис авторизации недоступен.";
      }
      return;
    }

    const success = await window.appService.auth.login(login, password);
    if (success) {
      if (loginStatus) {
        loginStatus.textContent = "Авторизация успешна. Выполняется переход...";
      }
      redirectToHiddenPage();
      return;
    }

    if (loginStatus) {
      loginStatus.textContent = "Неверный логин или пароль.";
    }
  }

  if (loginButton) {
    loginButton.addEventListener("click", () => {
      void authorize();
    });
  }

  if (loginForm) {
    loginForm.addEventListener("submit", (event) => {
      event.preventDefault();
      void authorize();
    });
  }

  if (passwordField) {
    passwordField.addEventListener("keydown", (event) => {
      if (event.key === "Enter") {
        event.preventDefault();
        void authorize();
      }
    });
  }
})();
