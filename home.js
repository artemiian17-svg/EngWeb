const languageButtons = document.querySelectorAll(".language-pill");
const languageOutput = document.getElementById("language-output");

if (languageButtons.length && languageOutput) {
  languageButtons.forEach((button) => {
    button.addEventListener("click", () => {
      languageButtons.forEach((item) => item.classList.remove("active"));
      button.classList.add("active");
      languageOutput.textContent = button.dataset.language;
    });
  });
}
