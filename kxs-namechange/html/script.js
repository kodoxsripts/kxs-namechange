const $ = (id) => document.getElementById(id);

const dom = {
    app:              $('app'),
    closeBtn:         $('closeBtn'),
    newFirstName:     $('newFirstName'),
    newLastName:      $('newLastName'),
    currentFirstName: $('currentFirstName'),
    currentLastName:  $('currentLastName'),
    preview:          $('preview'),
    previewOld:       $('previewOld'),
    previewNew:       $('previewNew'),
    submitBtn:        $('submitBtn'),
    errorMsg:         $('errorMsg'),
    successMsg:       $('successMsg'),
    firstCount:       $('firstCount'),
    lastCount:        $('lastCount'),
    firstMax:         $('firstMax'),
    lastMax:          $('lastMax'),
};

const submitLabel = dom.submitBtn.querySelector('span');
const NAME_REGEX = /^[a-zA-Z'\-]+$/;

let minLen = 2;
let maxLen = 20;
let busy = false;

function post(name, body) {
    return fetch(`https://kxs-namechange/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body || {}),
    }).then((r) => r.text());
}

function capitalize(s) {
    return s.charAt(0).toUpperCase() + s.slice(1).toLowerCase();
}

function setVisible(el, visible) {
    if (visible) {
        el.style.display = '';
        el.classList.remove('hidden');
    } else {
        el.style.display = 'none';
        el.classList.add('hidden');
    }
}

function showError(msg) {
    dom.errorMsg.textContent = msg;
    setVisible(dom.errorMsg, true);
    setVisible(dom.successMsg, false);
}

function showSuccess(msg) {
    dom.successMsg.textContent = msg;
    setVisible(dom.successMsg, true);
    setVisible(dom.errorMsg, false);
}

function resetSubmitState() {
    busy = false;
    submitLabel.textContent = 'Confirm Name Change';
}

function openUI(data) {
    dom.currentFirstName.textContent = data.firstName || 'Unknown';
    dom.currentLastName.textContent = data.lastName || 'Player';

    minLen = data.minLength || 2;
    maxLen = data.maxLength || 20;

    dom.newFirstName.setAttribute('maxlength', maxLen);
    dom.newLastName.setAttribute('maxlength', maxLen);
    dom.firstMax.textContent = maxLen;
    dom.lastMax.textContent = maxLen;

    dom.newFirstName.value = '';
    dom.newLastName.value = '';
    dom.firstCount.textContent = '0';
    dom.lastCount.textContent = '0';

    setVisible(dom.errorMsg, false);
    setVisible(dom.successMsg, false);
    setVisible(dom.preview, false);

    dom.submitBtn.disabled = true;
    resetSubmitState();
    setVisible(dom.app, true);

    setTimeout(() => dom.newFirstName.focus(), 100);
}

function closeUI() {
    setVisible(dom.app, false);
    resetSubmitState();
}

function updateForm() {
    const f = dom.newFirstName.value.trim();
    const l = dom.newLastName.value.trim();

    dom.firstCount.textContent = dom.newFirstName.value.length;
    dom.lastCount.textContent = dom.newLastName.value.length;
    setVisible(dom.errorMsg, false);
    setVisible(dom.successMsg, false);

    const valid = f.length >= minLen && l.length >= minLen;
    dom.submitBtn.disabled = !valid;

    if (valid) {
        dom.previewOld.textContent = dom.currentFirstName.textContent + ' ' + dom.currentLastName.textContent;
        dom.previewNew.textContent = capitalize(f) + ' ' + capitalize(l);
        setVisible(dom.preview, true);
    } else {
        setVisible(dom.preview, false);
    }
}

const messageActions = {
    open: openUI,
    close: closeUI,
    error(data) {
        showError(data.message);
        resetSubmitState();
    },
};

window.addEventListener('message', (event) => {
    const d = event.data;
    if (!d || !d.action) return;
    const handler = messageActions[d.action];
    if (handler) handler(d);
});

dom.closeBtn.addEventListener('click', () => {
    closeUI();
    post('closeui');
});

dom.newFirstName.addEventListener('input', updateForm);
dom.newLastName.addEventListener('input', updateForm);

dom.submitBtn.addEventListener('click', () => {
    if (busy || dom.submitBtn.disabled) return;

    const f = dom.newFirstName.value.trim();
    const l = dom.newLastName.value.trim();

    if (f.length < minLen || l.length < minLen) {
        showError('Names must be at least ' + minLen + ' characters.');
        return;
    }

    if (!NAME_REGEX.test(f) || !NAME_REGEX.test(l)) {
        showError('Names can only contain letters, hyphens, and apostrophes.');
        return;
    }

    busy = true;
    submitLabel.textContent = 'Processing...';

    post('submit', { firstName: f, lastName: l }).then((resp) => {
        try {
            const res = JSON.parse(resp);
            if (res.ok) {
                showSuccess('Name change submitted!');
            } else {
                showError(res.err || 'Name change failed.');
                resetSubmitState();
            }
        } catch {
            showSuccess('Name change submitted!');
        }
    });
});
