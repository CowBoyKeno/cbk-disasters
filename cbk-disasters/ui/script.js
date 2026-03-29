const RESOURCE_NAME = window.GetParentResourceName ? window.GetParentResourceName() : 'cbk-disasters';
const panel = document.getElementById('panel');
const listContainer = document.getElementById('disaster-list');
const activeLabel = document.getElementById('active-label');
const activeTimer = document.getElementById('active-timer');
const nextEvent = document.getElementById('next-event');
const closeBtn = document.getElementById('close-btn');
const refreshBtn = document.getElementById('refresh-btn');
const stopBtn = document.getElementById('stop-btn');
const systemStatus = document.getElementById('system-status');
const toggleSystemBtn = document.getElementById('toggle-system-btn');

let panelData = null;
let visible = false;
let alertAudioContext = null;
let activeAlertNodes = [];
let windAudioState = null;

const stopAlertTone = () => {
    activeAlertNodes.forEach(({ sources, gainNode }) => {
        try {
            gainNode.gain.cancelScheduledValues(0);
            gainNode.gain.setTargetAtTime(0.0001, alertAudioContext ? alertAudioContext.currentTime : 0, 0.03);
        } catch (e) {}

        (sources || []).forEach((sourceNode) => {
            try {
                sourceNode.stop();
            } catch (e) {}
        });
    });

    activeAlertNodes = [];
};

const ensureAudioContext = async () => {
    if (!alertAudioContext) {
        const AudioCtor = window.AudioContext || window.webkitAudioContext;
        if (!AudioCtor) {
            return null;
        }
        alertAudioContext = new AudioCtor();
    }

    if (alertAudioContext.state === 'suspended') {
        await alertAudioContext.resume();
    }

    return alertAudioContext;
};

const createAlertGain = (context, startTime, duration, volume) => {
    const gainNode = context.createGain();
    gainNode.gain.setValueAtTime(0.0001, startTime);
    gainNode.gain.linearRampToValueAtTime(volume, startTime + 0.015);
    gainNode.gain.setValueAtTime(volume, startTime + (duration * 0.82));
    gainNode.gain.exponentialRampToValueAtTime(0.0001, startTime + duration);
    gainNode.connect(context.destination);
    return gainNode;
};

const queueBulletinTone = (context, startTime, duration, lowHz, highHz, volume) => {
    const lowTone = context.createOscillator();
    const highTone = context.createOscillator();
    const gainNode = createAlertGain(context, startTime, duration, volume);
    const endTime = startTime + duration;

    lowTone.type = 'sine';
    highTone.type = 'sine';
    lowTone.frequency.setValueAtTime(lowHz, startTime);
    highTone.frequency.setValueAtTime(highHz, startTime);

    lowTone.connect(gainNode);
    highTone.connect(gainNode);

    lowTone.start(startTime);
    highTone.start(startTime);
    lowTone.stop(endTime + 0.01);
    highTone.stop(endTime + 0.01);

    activeAlertNodes.push({ sources: [lowTone, highTone], gainNode });
};

const queueStaticBurst = (context, startTime, duration, volume) => {
    const frameCount = Math.max(1, Math.floor(context.sampleRate * duration));
    const buffer = context.createBuffer(1, frameCount, context.sampleRate);
    const data = buffer.getChannelData(0);
    for (let i = 0; i < frameCount; i += 1) {
        data[i] = (Math.random() * 2 - 1) * 0.55;
    }

    const source = context.createBufferSource();
    source.buffer = buffer;
    const bandpass = context.createBiquadFilter();
    bandpass.type = 'bandpass';
    bandpass.frequency.setValueAtTime(1800, startTime);
    bandpass.Q.setValueAtTime(0.9, startTime);
    const gainNode = createAlertGain(context, startTime, duration, volume);

    source.connect(bandpass);
    bandpass.connect(gainNode);

    source.start(startTime);
    source.stop(startTime + duration + 0.01);

    activeAlertNodes.push({ sources: [source], gainNode });
};

const ensureWindAudioState = async () => {
    const context = await ensureAudioContext();
    if (!context) {
        return null;
    }

    if (windAudioState) {
        return windAudioState;
    }

    const frameCount = context.sampleRate * 2;
    const buffer = context.createBuffer(1, frameCount, context.sampleRate);
    const data = buffer.getChannelData(0);
    for (let i = 0; i < frameCount; i += 1) {
        data[i] = (Math.random() * 2.0) - 1.0;
    }

    const source = context.createBufferSource();
    source.buffer = buffer;
    source.loop = true;

    const highpass = context.createBiquadFilter();
    highpass.type = 'highpass';
    highpass.frequency.setValueAtTime(36, context.currentTime);

    const lowpass = context.createBiquadFilter();
    lowpass.type = 'lowpass';
    lowpass.frequency.setValueAtTime(420, context.currentTime);

    const gainNode = context.createGain();
    gainNode.gain.setValueAtTime(0.0001, context.currentTime);

    source.connect(highpass);
    highpass.connect(lowpass);
    lowpass.connect(gainNode);
    gainNode.connect(context.destination);
    source.start();

    windAudioState = { source, highpass, lowpass, gainNode };
    return windAudioState;
};

const setWindAudio = async (config = {}) => {
    const state = await ensureWindAudioState();
    if (!state || !alertAudioContext) {
        return;
    }

    const now = alertAudioContext.currentTime;
    const targetVolume = Math.max(0, Math.min(0.45, Number(config.volume) || 0));
    const lowpassHz = Math.max(120, Number(config.lowpassHz) || 420);
    const highpassHz = Math.max(10, Number(config.highpassHz) || 36);

    state.highpass.frequency.cancelScheduledValues(now);
    state.highpass.frequency.setTargetAtTime(highpassHz, now, 0.08);
    state.lowpass.frequency.cancelScheduledValues(now);
    state.lowpass.frequency.setTargetAtTime(lowpassHz, now, 0.08);
    state.gainNode.gain.cancelScheduledValues(now);
    state.gainNode.gain.setTargetAtTime(Math.max(0.0001, targetVolume), now, targetVolume > 0.001 ? 0.10 : 0.18);
};

const playAlertTone = async (config = {}) => {
    const context = await ensureAudioContext();
    if (!context) {
        return;
    }

    stopAlertTone();

    const mode = String(config.mode || 'bulletin');
    const durationMs = Math.max(1800, Number(config.durationMs) || 6200);
    const duration = durationMs / 1000;
    const volume = Math.min(0.45, Math.max(0.05, Number(config.volume) || 0.30));
    const startTime = context.currentTime + 0.02;
    if (mode === 'bulletin') {
        const lowHz = Math.max(200, Number(config.bulletinLowHz) || 853);
        const highHz = Math.max(lowHz + 40, Number(config.bulletinHighHz) || 960);
        const onMs = Math.max(300, Number(config.bulletinOnMs) || 950);
        const offMs = Math.max(80, Number(config.bulletinOffMs) || 260);
        const staticMs = Math.max(0, Number(config.bulletinStaticMs) || 120);
        const explicitCycles = Math.max(1, Number(config.bulletinCycles) || 4);
        const cycleSec = (onMs + offMs) / 1000;
        const autoCycles = Math.max(1, Math.floor(duration / cycleSec));
        const cycles = Math.max(explicitCycles, autoCycles);

        if (staticMs > 0) {
            queueStaticBurst(context, startTime, staticMs / 1000, volume * 0.65);
        }

        const toneStart = startTime + (staticMs / 1000);
        for (let i = 0; i < cycles; i += 1) {
            const cycleStart = toneStart + (i * cycleSec);
            queueBulletinTone(context, cycleStart, onMs / 1000, lowHz, highHz, volume);
        }
        return;
    }

    queueBulletinTone(context, startTime, duration, 720, 830, volume);
};

const sendNative = (endpoint, payload = {}) => {
    return fetch(`https://${RESOURCE_NAME}/${endpoint}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload)
    }).catch(() => null);
};

const formatSeconds = (value) => {
    const total = Math.max(0, Math.floor(value));
    const mins = Math.floor(total / 60);
    const secs = total % 60;
    return mins > 0 ? `${mins}m ${secs}s` : `${secs}s`;
};

const getElapsed = () => {
    if (!panelData || !panelData.timestamp) {
        return 0;
    }
    const now = Date.now() / 1000;
    return Math.max(0, now - panelData.timestamp);
};

const toNumber = (value, fallback = 0) => {
    const num = parseInt(String(value), 10);
    return Number.isFinite(num) ? num : fallback;
};

const renderPanel = () => {
    if (!panelData) {
        activeLabel.textContent = 'None';
        activeTimer.textContent = '-';
        nextEvent.textContent = '-';
        listContainer.innerHTML = '<p class="muted">Awaiting disaster data...</p>';
        if (systemStatus) {
            systemStatus.textContent = 'Unknown';
            systemStatus.className = 'meta-value system-status unknown';
        }
        if (toggleSystemBtn) {
            toggleSystemBtn.textContent = 'Enable system';
            toggleSystemBtn.disabled = true;
        }
        if (stopBtn) {
            stopBtn.disabled = true;
        }
        return;
    }

    const elapsed = getElapsed();
    const systemEnabled = panelData.systemEnabled !== false;
    const automationEnabled = panelData.automationEnabled !== false;

    if (panelData.active) {
        activeLabel.textContent = panelData.active.label;
        const remaining = Math.max(0, (panelData.active.remainingSeconds || 0) - elapsed);
        activeTimer.textContent = formatSeconds(remaining);
    } else {
        activeLabel.textContent = 'None';
        activeTimer.textContent = '-';
    }

    if (systemStatus) {
        systemStatus.textContent = systemEnabled ? 'Enabled' : 'Disabled';
        systemStatus.className = `meta-value system-status ${systemEnabled ? 'enabled' : 'disabled'}`;
    }

    if (toggleSystemBtn) {
        toggleSystemBtn.textContent = systemEnabled ? 'Disable system' : 'Enable system';
        toggleSystemBtn.disabled = false;
    }

    if (stopBtn) {
        stopBtn.disabled = !panelData.active;
    }

    if (!systemEnabled) {
        nextEvent.textContent = 'Disabled';
    } else if (!automationEnabled) {
        nextEvent.textContent = 'Off';
    } else {
        const nextSeconds = Math.max(0, (panelData.automationNextEventSeconds || 0) - elapsed);
        nextEvent.textContent = nextSeconds > 0 ? formatSeconds(nextSeconds) : '-';
    }

    if (!panelData.disasters || panelData.disasters.length === 0) {
        listContainer.innerHTML = '<p class="muted">No disasters configured.</p>';
        return;
    }

    listContainer.innerHTML = '';
    panelData.disasters.forEach((entry) => {
        const card = document.createElement('article');
        card.className = `disaster-card status-${entry.status || 'ready'}`;

        const header = document.createElement('div');
        header.className = 'header';
        const title = document.createElement('strong');
        title.textContent = entry.label;
        const status = document.createElement('span');
        status.className = `status ${entry.status || 'ready'}`;
        const statusLabels = {
            active: 'Active',
            blocked: 'Busy',
            cooldown: 'Cooldown',
            disabled: 'Disabled',
            unavailable: 'Config issue',
            ready: 'Ready'
        };
        status.textContent = statusLabels[entry.status] || 'Ready';
        header.appendChild(title);
        header.appendChild(status);

        const body = document.createElement('div');
        body.className = 'body';
        const duration = document.createElement('span');
        const durationMin = toNumber(entry.duration && entry.duration.min, 1);
        const durationMax = toNumber(entry.duration && entry.duration.max, durationMin);
        duration.textContent = `Duration: ${durationMin}m - ${durationMax}m`;
        const detailTwo = document.createElement('span');
        if (entry.status === 'active') {
            const remaining = Math.max(0, (entry.remainingSeconds || 0) - elapsed);
            detailTwo.textContent = `Remaining: ${formatSeconds(remaining)}`;
        } else if (entry.status === 'blocked') {
            detailTwo.textContent = `Blocked by: ${entry.blockedByLabel || 'another active event'}`;
        } else if (entry.status === 'disabled') {
            detailTwo.textContent = 'Disabled in config';
        } else if (entry.status === 'unavailable') {
            detailTwo.textContent = 'Zones missing or invalid';
        } else {
            detailTwo.textContent = `Cooldown: ${formatSeconds(entry.cooldownRemaining || 0)}`;
        }
        body.appendChild(duration);
        body.appendChild(detailTwo);

        const actionRow = document.createElement('div');
        actionRow.className = 'action-row';
        const startButton = document.createElement('button');
        startButton.className = 'ghost small';
        startButton.textContent = 'Start event';
        startButton.disabled = !systemEnabled || entry.canStart !== true;
        startButton.addEventListener('click', () => {
            sendNative('startDisaster', { key: entry.key });
        });
        actionRow.appendChild(startButton);

        const timeControls = document.createElement('div');
        timeControls.className = 'time-controls';
        const cooldownMinutes = toNumber(entry.cooldownMinutes, 0);
        timeControls.innerHTML = `
            <div class="time-field">
                <span>Min (m)</span>
                <input class="time-input time-input-min" type="number" min="1" value="${durationMin}" />
            </div>
            <div class="time-field">
                <span>Max (m)</span>
                <input class="time-input time-input-max" type="number" min="1" value="${durationMax}" />
            </div>
            <div class="time-field">
                <span>Cooldown (m)</span>
                <input class="time-input time-input-cooldown" type="number" min="0" value="${cooldownMinutes}" />
            </div>
        `;
        const minInput = timeControls.querySelector('.time-input-min');
        const maxInput = timeControls.querySelector('.time-input-max');
        const cooldownInput = timeControls.querySelector('.time-input-cooldown');
        const saveButton = document.createElement('button');
        saveButton.className = 'ghost small';
        saveButton.textContent = 'Save times';
        saveButton.addEventListener('click', () => {
            const newMin = toNumber(minInput.value, durationMin);
            const newMax = toNumber(maxInput.value, durationMax);
            const newCooldown = toNumber(cooldownInput.value, cooldownMinutes);
            const adjustedMax = newMax < newMin ? newMin : newMax;
            const adjustedCooldown = Math.max(0, newCooldown);
            sendNative('updateDisasterTimes', {
                key: entry.key,
                durationMin: newMin,
                durationMax: adjustedMax,
                cooldownMinutes: adjustedCooldown
            });
        });
        timeControls.appendChild(saveButton);

        card.appendChild(header);
        card.appendChild(body);
        card.appendChild(actionRow);
        card.appendChild(timeControls);
        listContainer.appendChild(card);
    });
};
window.addEventListener('message', (event) => {
    const data = event.data;
    if (!data) return;

    if (data.action === 'showPanel') {
        visible = true;
        panel.classList.add('visible');
        renderPanel();
    } else if (data.action === 'hidePanel') {
        visible = false;
        panel.classList.remove('visible');
    } else if (data.action === 'setData') {
        panelData = data.data;
        renderPanel();
    } else if (data.action === 'playAlertTone') {
        playAlertTone(data.config || {});
    } else if (data.action === 'setTornadoWindAudio') {
        setWindAudio(data.config || {});
    }
});

closeBtn.addEventListener('click', () => sendNative('closePanel'));
refreshBtn.addEventListener('click', () => sendNative('requestPanelData'));
if (toggleSystemBtn) {
    toggleSystemBtn.addEventListener('click', () => {
        const enabled = !(panelData && panelData.systemEnabled !== false);
        sendNative('setSystemEnabled', { enabled });
    });
}
if (stopBtn) {
    stopBtn.addEventListener('click', () => sendNative('stopDisaster'));
}

setInterval(() => {
    if (visible) {
        renderPanel();
    }
}, 1000);

