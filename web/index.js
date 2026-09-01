const commitWordWithSpace = document.querySelector("#commitWordWithSpace");
const substitutionForm = document.querySelector("#substitutionForm");
const substitutionKey = document.querySelector("#substitutionKey");
const substitutionValue = document.querySelector("#substitutionValue");
const substitutionsBody = document.querySelector("#substitutions");
const emptyState = document.querySelector("#emptyState");
const statusText = document.querySelector("#status");

function setStatus(message) {
  statusText.textContent = message;
}

async function requestJSON(url, options = {}) {
  const response = await fetch(url, {
    headers: {
      "Content-Type": "application/json",
      Accept: "application/json",
      ...options.headers,
    },
    ...options,
  });

  if (!response.ok) {
    throw new Error(`Request failed: ${response.status}`);
  }

  return response.json();
}

function renderSubstitutions(substitutions) {
  const entries = Object.entries(substitutions).sort(([left], [right]) =>
    left.localeCompare(right, "fr", { sensitivity: "base" })
  );

  substitutionsBody.replaceChildren();
  emptyState.hidden = entries.length > 0;

  for (const [key, value] of entries) {
    const row = document.createElement("tr");
    const keyCell = document.createElement("td");
    const valueCell = document.createElement("td");
    const actionCell = document.createElement("td");
    const removeButton = document.createElement("button");

    keyCell.textContent = key;
    valueCell.textContent = value;
    removeButton.type = "button";
    removeButton.className = "icon-button";
    removeButton.textContent = "Remove";
    removeButton.addEventListener("click", async () => {
      await requestJSON(`/substitutions/${encodeURIComponent(key)}`, {
        method: "DELETE",
      });
      setStatus("Substitution removed.");
      await loadSubstitutions();
    });

    actionCell.append(removeButton);
    row.append(keyCell, valueCell, actionCell);
    substitutionsBody.append(row);
  }
}

async function loadPreference() {
  const preference = await requestJSON("/preference");
  commitWordWithSpace.checked = Boolean(preference.commitWordWithSpace);
}

async function savePreference() {
  await requestJSON("/preference", {
    method: "POST",
    body: JSON.stringify({
      commitWordWithSpace: commitWordWithSpace.checked,
    }),
  });
  setStatus("Preference saved.");
}

async function loadSubstitutions() {
  renderSubstitutions(await requestJSON("/substitutions"));
}

substitutionForm.addEventListener("submit", async (event) => {
  event.preventDefault();

  await requestJSON("/substitutions", {
    method: "POST",
    body: JSON.stringify({
      key: substitutionKey.value.trim(),
      value: substitutionValue.value.trim(),
    }),
  });

  substitutionForm.reset();
  substitutionKey.focus();
  setStatus("Substitution saved.");
  await loadSubstitutions();
});

commitWordWithSpace.addEventListener("change", savePreference);

Promise.all([loadPreference(), loadSubstitutions()]).catch((error) => {
  setStatus(error.message);
});
