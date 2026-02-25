const app = document.getElementById('app');
const stockGrid = document.getElementById('stockGrid');
const membersTableBody = document.getElementById('membersTableBody');
const btnAddMember = document.getElementById('btnAddMember');
const logsList = document.getElementById('logsList');
const productionStagesEl = document.getElementById('productionStages');
const statusLogEl = document.getElementById('statusLog');
const productionAlert = document.getElementById('productionAlert');
const productionAlertText = document.getElementById('productionAlertText');
const keypadOverlay = document.getElementById('keypadOverlay');
const keypadDisplay = document.getElementById('keypadDisplay');
const headerLocation = document.getElementById('headerLocation');
const addMemberModal = document.getElementById('addMemberModal');
const memberIdentifierEl = document.getElementById('memberIdentifier');
const memberNameEl = document.getElementById('memberName');
const tabSettings = document.getElementById('tabSettings');
const settingsCodeSection = document.getElementById('settingsCodeSection');
const btnChangeCode = document.getElementById('btnChangeCode');
const changeCodeModal = document.getElementById('changeCodeModal');
const newCodeInput = document.getElementById('newCodeInput');
const changeCodeConfirm = document.getElementById('changeCodeConfirm');
const changeCodeCancel = document.getElementById('changeCodeCancel');

let keypadCode = '';
const TERMINAL_LOADING_MIN_MS = 1500;
let terminalLoadingShownAt = 0;

function nuiFetch(name, payload) {
    return fetch(`https://${GetParentResourceName()}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload || {}),
    }).then(() => {});
}

function escapeHtml(s) {
    if (s == null) return '';
    const div = document.createElement('div');
    div.textContent = s;
    return div.innerHTML;
}

function renderStock(data) {
    if (!stockGrid) return;
    const stash = data.stashInventory || data.inventory;
    const items = Array.isArray(stash) && stash.length ? stash : [];
    stockGrid.classList.remove('stock-grid--empty');
    if (items.length === 0) {
        stockGrid.classList.add('stock-grid--empty');
        stockGrid.innerHTML = '<div class="stock-empty">Lager Tomt</div>';
        return;
    }
    stockGrid.innerHTML = items.map((item) => {
        const name = escapeHtml(item.name || item.key || '');
        const qty = item.quantity != null ? item.quantity : 0;
        const unit = escapeHtml(item.unit || 'stk');
        return `<div class="stash-item"><span class="stash-item-name">${name}</span><span class="stash-item-qty">${qty} ${unit}</span></div>`;
    }).join('');
}

function renderMembers(members, isOwner) {
    if (!membersTableBody) return;
    const list = Array.isArray(members) ? members : [];
    membersTableBody.innerHTML = list.length === 0
        ? '<tr><td colspan="3" style="padding: 1.5rem; color: var(--text-secondary);">Ingen medlemmer.</td></tr>'
        : list.map((m) => {
            const name = escapeHtml(m.player_name || m.identifier || '–');
            const ident = escapeHtml(m.identifier || '');
            const removeBtn = isOwner ? `<button type="button" class="action-btn" data-identifier="${escapeHtml(m.identifier)}">Fjern</button>` : '';
            return `<tr><td class="member-name">${name}</td><td style="font-size: 0.85rem; color: var(--text-secondary);">${ident}</td><td class="member-actions">${removeBtn}</td></tr>`;
        }).join('');
    if (btnAddMember) btnAddMember.style.display = isOwner ? 'block' : 'none';
}

function renderLogs(accessLog, productionLog) {
    if (!logsList) return;
    const entries = [];
    if (Array.isArray(accessLog) && accessLog.length) {
        accessLog.forEach((e) => {
            const action = e.action === 'exited' ? 'Forlod lab' : 'Gik ind';
            const name = escapeHtml(e.player_name || e.identifier || '');
            const time = e.created_at ? new Date(e.created_at).toLocaleString('da-DK') : '';
            entries.push({ message: `${name} – ${action}`, meta: time, type: 'action' });
        });
    }
    if (Array.isArray(productionLog) && productionLog.length) {
        productionLog.slice(-20).forEach((e) => {
            const type = (e.type || 'action').toLowerCase();
            const typeClass = type === 'error' ? 'error' : type === 'warning' ? 'warning' : type === 'success' ? 'success' : 'action';
            entries.push({ message: escapeHtml(e.message || ''), meta: e.time || '', type: typeClass });
        });
    }
    entries.sort((a, b) => (b.meta || '').localeCompare(a.meta || ''));
    logsList.innerHTML = entries.length === 0
        ? '<div class="log-entry"><div class="log-content"><div class="log-message">Ingen logførte aktiviteter.</div></div></div>'
        : entries.map((e) => `
            <div class="log-entry">
                <div class="log-content">
                    <div class="log-message">${e.message}</div>
                    <div class="log-meta">${escapeHtml(e.meta)}</div>
                </div>
                <span class="log-type ${e.type}">${e.type === 'action' ? 'ADGANG' : e.type.toUpperCase()}</span>
            </div>
        `).join('');
}

function renderProduction(production) {
    if (!productionStagesEl) return;
    const progress = production && production.stageProgress ? production.stageProgress : [0, 0, 0];
    const stageNames = ['Trin 1: Ekstraktion', 'Trin 2: Rensning', 'Trin 3: Pakning'];
    let html = '';
    for (let i = 0; i < 3; i++) {
        const p = progress[i] || 0;
        let status = 'Venter';
        let statusClass = '';
        if (p >= 100) status = 'Færdig', statusClass = 'success';
        else if (production && production.active && !production.paused) status = `I gang – ${Math.round(p)}%`, statusClass = 'warning';
        html += `
            <div class="production-stage">
                <div class="stage-title">${stageNames[i]}</div>
                <div class="stock-card-bar"><div class="stock-card-fill" style="width: ${p}%;"></div></div>
                <div class="log-meta" style="margin-top: 4px;">${status}</div>
            </div>
        `;
    }
    productionStagesEl.innerHTML = html;
}

function renderStatusLog(log) {
    if (!statusLogEl) return;
    const entries = Array.isArray(log) ? log : [];
    statusLogEl.innerHTML = entries.slice(-10).map((e) => {
        const type = e.type ? ` log-type ${e.type}` : '';
        return `<div class="log-entry${type}">[${escapeHtml(e.time || '')}] ${escapeHtml(e.message || '')}</div>`;
    }).join('');
    statusLogEl.scrollTop = statusLogEl.scrollHeight;
}

function applyData(data) {
    if (!data) return;
    if (data.inventory || data.stockLevels) renderStock(data);
    if (data.members != null) renderMembers(data.members, !!data.isOwner);
    if (data.accessLog != null || data.log != null) renderLogs(data.accessLog || [], data.log || []);
    if (data.production) renderProduction(data.production);
    if (data.log) renderStatusLog(data.log);
    if (productionAlert && productionAlertText) {
        if (data.alert) {
            productionAlert.classList.add('show');
            productionAlertText.textContent = data.alert;
        } else {
            productionAlert.classList.remove('show');
        }
    }
    if (headerLocation) headerLocation.textContent = 'Lab: ' + (data.labId || 'Lab');
    const headerTitle = document.getElementById('headerTitle');
    if (headerTitle) headerTitle.textContent = 'Druglab' + (data.drug_type_label ? ' - ' + escapeHtml(data.drug_type_label) : data.drug_type ? ' - ' + escapeHtml(data.drug_type) : '');
    if (tabSettings) tabSettings.style.display = data.isOwner ? '' : 'none';
    if (settingsCodeSection) settingsCodeSection.style.display = data.isOwner ? '' : 'none';
}

window.addEventListener('message', (event) => {
    const msg = event.data;
    if (msg.action === 'open') {
        app.style.display = 'flex';
        app.classList.add('app-visible');
        const data = msg.data;
        const loadingEl = document.getElementById('terminalLoading');
        if (loadingEl) {
            if (data != null && typeof data === 'object') {
                const elapsed = Date.now() - terminalLoadingShownAt;
                const wait = Math.max(0, TERMINAL_LOADING_MIN_MS - elapsed);
                if (wait > 0) {
                    setTimeout(() => {
                        loadingEl.classList.add('hidden');
                        applyData(data);
                    }, wait);
                } else {
                    loadingEl.classList.add('hidden');
                    applyData(data);
                }
            } else {
                terminalLoadingShownAt = Date.now();
                loadingEl.classList.remove('hidden');
            }
        } else {
            applyData(data || {});
        }
    } else if (msg.action === 'update') {
        const loadingEl = document.getElementById('terminalLoading');
        const data = msg.data || {};
        if (loadingEl) {
            const elapsed = Date.now() - terminalLoadingShownAt;
            const wait = Math.max(0, TERMINAL_LOADING_MIN_MS - elapsed);
            if (wait > 0) {
                setTimeout(() => {
                    loadingEl.classList.add('hidden');
                    applyData(data);
                }, wait);
            } else {
                loadingEl.classList.add('hidden');
                applyData(data);
            }
        } else {
            applyData(data);
        }
    } else if (msg.action === 'close') {
        app.classList.remove('app-visible');
        app.classList.add('app-fade-out');
        setTimeout(() => {
            app.classList.remove('app-fade-out');
            app.style.display = 'none';
        }, 350);
    } else if (msg.action === 'openKeypad') {
        keypadCode = '';
        if (keypadDisplay) keypadDisplay.textContent = '____';
        if (keypadOverlay) keypadOverlay.classList.add('show');
    } else if (msg.action === 'closeKeypad') {
        if (keypadOverlay) keypadOverlay.classList.remove('show');
    }
});

document.querySelectorAll('.tab-button').forEach((btn) => {
    btn.addEventListener('click', function() {
        const tabName = this.dataset.tab;
        document.querySelectorAll('.tab-button').forEach((b) => b.classList.remove('active'));
        document.querySelectorAll('.tab-content').forEach((c) => c.classList.remove('active'));
        this.classList.add('active');
        const panel = document.getElementById(tabName);
        if (panel) panel.classList.add('active');
    });
});

document.getElementById('btnClose').addEventListener('click', () => nuiFetch('closeUI'));
const btnOpenStash = document.getElementById('btnOpenStash');
if (btnOpenStash) btnOpenStash.addEventListener('click', () => nuiFetch('openLabStash'));

if (membersTableBody) {
    membersTableBody.addEventListener('click', (e) => {
        const btn = e.target.closest('.action-btn[data-identifier]');
        if (!btn) return;
        const identifier = btn.getAttribute('data-identifier');
        if (identifier) nuiFetch('removeLabMember', { identifier });
    });
}

if (btnAddMember) btnAddMember.addEventListener('click', () => { addMemberModal.classList.add('active'); });
document.getElementById('modalAddCancel').addEventListener('click', () => {
    addMemberModal.classList.remove('active');
    if (memberIdentifierEl) memberIdentifierEl.value = '';
    if (memberNameEl) memberNameEl.value = '';
});
document.getElementById('modalAddConfirm').addEventListener('click', () => {
    const ident = memberIdentifierEl && memberIdentifierEl.value ? memberIdentifierEl.value.trim() : '';
    const name = memberNameEl && memberNameEl.value ? memberNameEl.value.trim() : '';
    if (!ident) return;
    nuiFetch('addLabMember', { identifier: ident, playerName: name || ident });
    addMemberModal.classList.remove('active');
    if (memberIdentifierEl) memberIdentifierEl.value = '';
    if (memberNameEl) memberNameEl.value = '';
});
addMemberModal.addEventListener('click', (e) => { if (e.target === addMemberModal) addMemberModal.classList.remove('active'); });

if (btnChangeCode) btnChangeCode.addEventListener('click', () => {
    if (changeCodeModal) changeCodeModal.classList.add('active');
    if (newCodeInput) { newCodeInput.value = ''; newCodeInput.focus(); }
});
if (changeCodeCancel) changeCodeCancel.addEventListener('click', () => {
    if (changeCodeModal) changeCodeModal.classList.remove('active');
    if (newCodeInput) newCodeInput.value = '';
});
if (changeCodeModal) changeCodeModal.addEventListener('click', (e) => { if (e.target === changeCodeModal) changeCodeModal.classList.remove('active'); });
if (newCodeInput) {
    newCodeInput.addEventListener('input', () => {
        newCodeInput.value = newCodeInput.value.replace(/\D/g, '').slice(0, 4);
    });
    newCodeInput.addEventListener('keydown', (e) => {
        if (e.key === 'Enter') {
            const v = newCodeInput.value.replace(/\D/g, '');
            if (v.length === 4) { nuiFetch('changeLabCode', { code: v }); changeCodeModal.classList.remove('active'); newCodeInput.value = ''; }
        }
    });
}
if (changeCodeConfirm) changeCodeConfirm.addEventListener('click', () => {
    const v = newCodeInput && newCodeInput.value ? newCodeInput.value.replace(/\D/g, '') : '';
    if (v.length !== 4) return;
    nuiFetch('changeLabCode', { code: v });
    if (changeCodeModal) changeCodeModal.classList.remove('active');
    if (newCodeInput) newCodeInput.value = '';
});

function updateKeypadDisplay() {
    if (!keypadDisplay) return;
    let t = '';
    for (let i = 0; i < 4; i++) t += keypadCode.length > i ? '*' : '_';
    keypadDisplay.textContent = t;
}

if (keypadOverlay) {
    keypadOverlay.addEventListener('click', (e) => {
        const btn = e.target.closest('.keypad-btn');
        if (!btn) return;
        const digit = btn.getAttribute('data-digit');
        if (digit !== null) {
            if (keypadCode.length < 4) { keypadCode += digit; updateKeypadDisplay(); }
        } else if (btn.classList.contains('keypad-back')) {
            keypadCode = keypadCode.slice(0, -1);
            updateKeypadDisplay();
        } else if (btn.classList.contains('keypad-ok')) {
            if (keypadCode.length === 4) nuiFetch('submitCode', { code: keypadCode });
        }
    });
    document.getElementById('keypadCancel').addEventListener('click', () => nuiFetch('closeKeypad'));
}

document.addEventListener('keydown', (e) => {
    const keypadOpen = keypadOverlay && keypadOverlay.classList.contains('show');
    if (keypadOpen) {
        if (e.key === 'Escape') {
            nuiFetch('closeKeypad');
            e.preventDefault();
            return;
        }
        if (e.key >= '0' && e.key <= '9') {
            if (keypadCode.length < 4) {
                keypadCode += e.key;
                updateKeypadDisplay();
            }
            e.preventDefault();
            return;
        }
        if (e.key === 'Backspace') {
            keypadCode = keypadCode.slice(0, -1);
            updateKeypadDisplay();
            e.preventDefault();
            return;
        }
        if (e.key === 'Enter') {
            if (keypadCode.length === 4) nuiFetch('submitCode', { code: keypadCode });
            e.preventDefault();
            return;
        }
    }
    if (e.key === 'Escape') {
        if (changeCodeModal && changeCodeModal.classList.contains('active')) {
            changeCodeModal.classList.remove('active');
        } else if (addMemberModal && addMemberModal.classList.contains('active')) {
            addMemberModal.classList.remove('active');
        } else if (app && app.style.display !== 'none') {
            nuiFetch('closeUI');
        }
    }
});
