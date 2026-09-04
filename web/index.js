const commitWordWithSpace = document.querySelector("#commitWordWithSpace");
const genderAgreement = document.querySelector("#genderAgreement");
const substitutionForm = document.querySelector("#substitutionForm");
const substitutionKey = document.querySelector("#substitutionKey");
const substitutionValue = document.querySelector("#substitutionValue");
const substitutionsBody = document.querySelector("#substitutions");
const emptyState = document.querySelector("#emptyState");
const statusText = document.querySelector("#status");
const checkUpdateButton = document.querySelector("#checkUpdateButton");
const updateStatus = document.querySelector("#updateStatus");
const resetLearningButton = document.querySelector("#resetLearningButton");
const resetLearningStatus = document.querySelector("#resetLearningStatus");

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
    throw new Error(`Échec de la requête : ${response.status}`);
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
    removeButton.textContent = "Supprimer";
    removeButton.addEventListener("click", async () => {
      await requestJSON(`/substitutions/${encodeURIComponent(key)}`, {
        method: "DELETE",
      });
      setStatus("Substitution supprimée.");
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
  genderAgreement.value = preference.genderAgreement || "unspecified";
}

async function savePreference() {
  await requestJSON("/preference", {
    method: "POST",
    body: JSON.stringify({
      commitWordWithSpace: commitWordWithSpace.checked,
      genderAgreement: genderAgreement.value,
    }),
  });
  setStatus("Préférence enregistrée.");
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
  setStatus("Substitution enregistrée.");
  await loadSubstitutions();
});

commitWordWithSpace.addEventListener("change", savePreference);
genderAgreement.addEventListener("change", savePreference);

checkUpdateButton.addEventListener("click", async () => {
  checkUpdateButton.disabled = true;
  updateStatus.textContent = "Vérification…";
  try {
    const result = await requestJSON("/update-check", { method: "POST" });
    if (result.updateAvailable) {
      updateStatus.replaceChildren(
        document.createTextNode(`La version ${result.latestVersion} est disponible (vous avez la ${result.currentVersion}). `)
      );
      const link = document.createElement("a");
      link.href = result.releaseUrl;
      link.target = "_blank";
      link.rel = "noopener";
      link.textContent = "Ouvrir la page de version";
      updateStatus.append(link);
    } else {
      updateStatus.textContent = `Vous êtes à jour (${result.currentVersion}).`;
    }
  } catch (error) {
    updateStatus.textContent = `Impossible de vérifier les mises à jour : ${error.message}`;
  } finally {
    checkUpdateButton.disabled = false;
  }
});

resetLearningButton.addEventListener("click", async () => {
  resetLearningButton.disabled = true;
  try {
    await requestJSON("/reset-learned-selections", { method: "POST" });
    resetLearningStatus.textContent = "Apprentissage réinitialisé.";
  } catch (error) {
    resetLearningStatus.textContent = `Échec de la réinitialisation : ${error.message}`;
  } finally {
    resetLearningButton.disabled = false;
  }
});

Promise.all([loadPreference(), loadSubstitutions()]).catch((error) => {
  setStatus(error.message);
});
